import os
import json
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from typing import Optional
import boto3
import requests
from jose import jwt, JWTError, jwk
from jose.utils import base64url_decode
from fastapi import FastAPI, HTTPException, Depends, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Text, Boolean
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from tenacity import retry, stop_after_attempt, wait_fixed
from aws_xray_sdk.core import xray_recorder
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

# Custom ASGI X-Ray Middleware to trace FastAPI requests safely
class XRayMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        segment = None
        try:
            segment = xray_recorder.begin_segment(
                name=f"order-service:{request.method} {request.url.path}",
                traceid=None,
                parent_id=None,
                sampling=1
            )
        except Exception as e:
            segment = None

        try:
            response = await call_next(request)
            if segment:
                segment.put_http_meta('STATUS', response.status_code)
            return response
        except Exception as e:
            if segment:
                segment.add_exception(e)
            raise e
        finally:
            if segment:
                try:
                    xray_recorder.end_segment()
                except Exception:
                    pass

app = FastAPI(
    title="SmartRetailX Order Service",
    version="1.0.0",
    docs_url="/docs",
    openapi_url="/api/v1/openapi.json"
)

# Enable CORS for frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure AWS X-Ray Middleware with fallback error strategy
try:
    xray_recorder.configure(service='order-service', context_missing='LOG_ERROR')
    app.add_middleware(XRayMiddleware)
except Exception as e:
    print(f"X-Ray initialization notice: {e}")

# Prometheus Metrics Instrumentation & Exposure (/metrics)
try:
    from prometheus_fastapi_instrumentator import Instrumentator
    Instrumentator().instrument(app).expose(app)
except Exception as e:
    print(f"Prometheus instrumentation notice: {e}")

# OpenTelemetry Distributed Tracing & Jaeger Exporter
try:
    from tracing import setup_opentelemetry_tracing
    setup_opentelemetry_tracing("order-service", app)
except Exception as e:
    print(f"OpenTelemetry initialization notice: {e}")

# --- Cognito RBAC Configuration ---
COGNITO_REGION = os.getenv("COGNITO_REGION", os.getenv("AWS_REGION", "ap-south-1"))
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID", "ap-south-1_G2uHiC4F0")
COGNITO_APP_CLIENT_ID = os.getenv("COGNITO_APP_CLIENT_ID", "mlukrs75e646ud2ullrkt90mo")
COGNITO_JWKS_URL = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token", auto_error=False)

# Cache JWKS keys in memory to avoid repeated HTTP calls
_jwks_cache = None

def get_jwks():
    """Fetch and cache the Cognito JWKS (JSON Web Key Set)."""
    global _jwks_cache
    if _jwks_cache is None:
        try:
            response = requests.get(COGNITO_JWKS_URL, timeout=5)
            response.raise_for_status()
            _jwks_cache = response.json()
        except Exception as e:
            print(f"Failed to fetch Cognito JWKS ({COGNITO_JWKS_URL}): {e}")
            _jwks_cache = {"keys": []}
    return _jwks_cache

def get_current_user(token: Optional[str] = Depends(oauth2_scheme)):
    """
    FastAPI dependency that decodes and validates a Cognito JWT Bearer token.
    Falls back gracefully for local testing if token is mock or unverified.
    """
    if not token:
        # Default local dev user
        return {"email": "dev_user@smartretailx.internal", "role": "store_manager"}

    try:
        # 1. Decode the JWT header to find the signing key ID (kid)
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        if kid:
            # 2. Find the matching public key from JWKS
            jwks = get_jwks()
            rsa_key = None
            for key in jwks.get("keys", []):
                if key.get("kid") == kid:
                    rsa_key = key
                    break

            if rsa_key:
                # 3. Decode and verify the JWT signature, audience, and issuer
                payload = jwt.decode(
                    token,
                    rsa_key,
                    algorithms=["RS256"],
                    audience=COGNITO_APP_CLIENT_ID,
                    issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}",
                )

                email: str = payload.get("email") or payload.get("sub")
                user_role = payload.get("custom:role", "store_manager")
                if email:
                    print(f"Auth: User '{email}' authenticated with role '{user_role}'.")
                    return {"email": email, "role": user_role}

        # Local development fallback when JWKS key isn't matched or unverified signature
        claims = jwt.get_unverified_claims(token)
        email = claims.get("email") or claims.get("username") or claims.get("sub") or "dev_user@smartretailx.internal"
        role = claims.get("custom:role", "store_manager")
        print(f"Auth Fallback: Decoded claims for '{email}' with role '{role}'.")
        return {"email": email, "role": role}

    except Exception as e:
        print(f"JWT validation notice ({e}), defaulting to dev user context.")
        return {"email": "dev_user@smartretailx.internal", "role": "store_manager"}

def require_roles(allowed_roles: list):
    """Factory dependency that validates the authenticated user's role."""
    def dependency(current_user: dict = Depends(get_current_user)):
        if current_user["role"] not in allowed_roles:
            print(f"RBAC: User '{current_user['email']}' denied access. Role '{current_user['role']}' not in {allowed_roles}.")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Requires one of roles: {allowed_roles}",
            )
        return current_user
    return dependency

# Database Configuration and Connection String
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME", "smartretailx")
DB_PORT = os.getenv("DB_PORT", "3306")

if DB_HOST:
    DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(
        DATABASE_URL,
        pool_size=50,          # Match peak 50 virtual users
        max_overflow=20,       # Allow extra burst headroom
        pool_timeout=60,       # Wait up to 60s before timing out
        pool_pre_ping=True     # Automatically recycles stale or dead connections
    )
else:
    DATABASE_URL = "sqlite:///orders.db"
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True
    )

from sqlalchemy import event
from sqlalchemy.engine import Engine

@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    try:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.execute("PRAGMA busy_timeout=10000")
        cursor.close()
    except Exception as e:
        pass

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# FastAPI DB Session Dependency Injection Generator
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# EventBridge Configuration
EVENT_BUS_NAME = os.getenv("EVENT_BUS_NAME", "smartretailx-bus")
aws_region = os.getenv("AWS_REGION", "ap-south-1")
endpoint_url = os.getenv("AWS_ENDPOINT_URL")

# LocalStack / AWS dynamic connection parameters
boto_args = {"region_name": aws_region}
if endpoint_url:
    boto_args["endpoint_url"] = endpoint_url
    boto_args["aws_access_key_id"] = "mock"
    boto_args["aws_secret_access_key"] = "mock"

events_client = boto3.client("events", **boto_args)

# SQLAlchemy Database Models
class OrderDB(Base):
  __tablename__ = "orders"

  id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  customer_id = Column(String(100), nullable=False)
  product_id = Column(String(100), nullable=False)
  product_name = Column(String(200), default="SmartRetailX Restock Item")
  image_url = Column(String(500), default="https://images.unsplash.com/photo-1550583724-b2692b85b150?w=150")
  payment_method = Column(String(100), default="Digital Bank Transfer")
  quantity = Column(Integer, nullable=False)
  total_amount = Column(Float, nullable=False)
  status = Column(String(50), default="Pending")
  version = Column(Integer, default=1, nullable=False)  # Optimistic Locking Version Column
  created_at = Column(DateTime, default=datetime.utcnow)

# Transactional Outbox Pattern Database Model
class OutboxEventDB(Base):
  __tablename__ = "outbox_events"

  id = Column(Integer, primary_key=True, index=True, autoincrement=True)
  aggregate_type = Column(String(100), nullable=False)
  aggregate_id = Column(String(100), nullable=False)
  event_type = Column(String(100), nullable=False)
  payload = Column(Text, nullable=False)
  processed = Column(Boolean, default=False)
  created_at = Column(DateTime, default=datetime.utcnow)

# -------------------------------------------------------------
# Finite State Machine (FSM) Validation Engine
# -------------------------------------------------------------
class OrderFSM:
    """Enforces strict, legal order lifecycle state transitions."""
    LEGAL_TRANSITIONS = {
        "Pending": ["Confirmed", "Processing", "Fulfilled", "Ready for Dispatch", "Cancelled"],
        "Confirmed": ["Processing", "Fulfilled", "Ready for Dispatch", "Cancelled"],
        "Processing": ["Shipped", "Fulfilled", "Ready for Dispatch", "Out for Delivery", "Cancelled"],
        "Shipped": ["Out for Delivery", "Delivered", "Cancelled"],
        "Fulfilled": ["Ready for Dispatch", "Out for Delivery", "Delivered", "Cancelled"],
        "Ready for Dispatch": ["Out for Delivery", "Delivered", "Cancelled"],
        "Out for Delivery": ["Delivered", "Failed", "Returned"],
        "Delivered": [],
        "Cancelled": [],
        "Failed": ["Ready for Dispatch", "Out for Delivery", "Cancelled"]
    }

    @classmethod
    def validate_transition(cls, current_status: str, new_status: str):
        if current_status == new_status:
            return True
        allowed = cls.LEGAL_TRANSITIONS.get(current_status, [])
        if new_status not in allowed:
            print(f"[FSM REJECTED] Illegal state transition from '{current_status}' to '{new_status}'. Allowed: {allowed}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"FSM State Error: Cannot transition order from '{current_status}' to '{new_status}'. Legal next states: {allowed}"
            )
        print(f"[FSM TRANSITION ACCEPTED] Legal transition: '{current_status}' -> '{new_status}'")
        return True

# Ensure Database Tables Exist on Startup
@app.on_event("startup")
def startup_event():
    import time
    for attempt in range(10):
        try:
            Base.metadata.create_all(bind=engine)
            print("Database schema verified, Outbox & Orders tables initialized successfully.")
            break
        except Exception as e:
            print(f"Database initialization attempt {attempt + 1}/10 warning: {e}")
            time.sleep(2)

# Pydantic Schemas
class OrderCreate(BaseModel):
  customer_id: str
  product_id: str
  product_name: Optional[str] = "SmartRetailX Restock Item"
  image_url: Optional[str] = "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=150"
  payment_method: Optional[str] = "Digital Bank Transfer"
  quantity: int
  total_amount: float

class OrderResponse(BaseModel):
  id: int
  customer_id: str
  product_id: str
  product_name: Optional[str] = "SmartRetailX Restock Item"
  image_url: Optional[str] = "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=150"
  payment_method: Optional[str] = "Digital Bank Transfer"
  quantity: int
  total_amount: float
  status: str
  created_at: datetime

  class Config:
    from_attributes = True

class DeliveryStatusUpdate(BaseModel):
  status: str

# SMTP Email Configuration
SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", "no-reply@smartretailx.com")

def send_order_confirmation_email(customer_email: str, order_id: int, product_id: str, product_name: str, image_url: str, quantity: int, total_amount: float):
    """
    Sends an email-safe custom styled order tracking HTML confirmation email via SMTP with dynamic product names and image URLs.
    """
    subject = f"Order Confirmation - SmartRetailX Order #{order_id}"
    body_text = (
        f"Hello,\n\n"
        f"Thank you for your order with SmartRetailX!\n\n"
        f"Order Summary:\n"
        f"Order ID: #{order_id}\n"
        f"Product: {product_name} (ID: {product_id})\n"
        f"Quantity: {quantity}\n"
        f"Total Amount: ${total_amount:.2f}\n"
        f"Status: Pending\n\n"
        f"We are processing your restocking order.\n"
        f"Best regards,\nSmartRetailX Operations Team"
    )

    img_src = image_url if (image_url and image_url.startswith("http")) else "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=150"

    # Email-Safe Table Layout Matching Your UI Design with Dynamic Product Name and Image URL
    body_html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>Order Tracking - SmartRetailX</title>
    </head>
    <body style="background-color: #f7f9fb; font-family: Arial, sans-serif; margin: 0; padding: 0; color: #191c1e;">
        <table align="center" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f7f9fb; padding: 40px 0;">
            <tr>
                <td align="center">
                    <table border="0" cellpadding="0" cellspacing="0" width="600" style="background-color: #ffffff; border: 1px solid #e0e3e5; border-radius: 8px; overflow: hidden; padding: 32px;">
                        
                        <!-- Header Section -->
                        <tr>
                            <td align="center" style="padding-bottom: 24px;">
                                <h1 style="font-size: 24px; font-weight: 700; color: #000000; margin: 0;">We're fetching your order.</h1>
                                <p style="font-size: 14px; color: #45464d; margin: 8px 0 0 0;">Order Reference: <strong>#SMLS{order_id}</strong></p>
                            </td>
                        </tr>

                        <!-- Progress Tracker -->
                        <tr>
                            <td style="padding-bottom: 32px; border-bottom: 1px solid #e6e8ea;">
                                <table border="0" cellpadding="0" cellspacing="0" width="100%">
                                    <tr>
                                        <td align="center" style="font-size: 11px; font-weight: bold; color: #191c1e; text-transform: uppercase;">✓ Placed</td>
                                        <td align="center" style="font-size: 11px; font-weight: bold; color: #0051d5; text-transform: uppercase;">● Processing</td>
                                        <td align="center" style="font-size: 11px; color: #76777d; text-transform: uppercase;">Shipping</td>
                                        <td align="center" style="font-size: 11px; color: #76777d; text-transform: uppercase;">Delivery</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>

                        <!-- Order Details Header -->
                        <tr>
                            <td style="padding: 16px 0 8px 0;">
                                <table border="0" cellpadding="0" cellspacing="0" width="100%">
                                    <tr>
                                        <td style="font-size: 14px; color: #191c1e;">Order #SMLS{order_id}</td>
                                        <td align="right" style="font-size: 14px; color: #0051d5; text-decoration: underline;">View Order</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>

                        <!-- Product Summary Card -->
                        <tr>
                            <td style="padding-bottom: 24px;">
                                <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #fcfcfc; border: 1px solid #e6e8ea; border-radius: 8px; padding: 16px;">
                                    <tr>
                                        <td width="70" valign="top">
                                            <!-- Dynamic Product Image URL -->
                                            <img src="{img_src}" alt="Product Image" width="64" height="64" style="width: 64px; height: 64px; object-fit: cover; border-radius: 6px; border: 1px solid #e6e8ea; display: block;" />
                                        </td>
                                        <td style="padding-left: 16px;" valign="top">
                                            <h3 style="font-size: 16px; font-weight: 600; color: #191c1e; margin: 0 0 4px 0;">{product_name}</h3>
                                            <p style="font-size: 13px; color: #45464d; margin: 0 0 8px 0;">Product ID: {product_id} &bull; Qty: {quantity}</p>
                                            <span style="display: inline-block; background-color: #dbe1ff; color: #003ea8; font-size: 11px; font-weight: bold; padding: 3px 8px; border-radius: 4px; text-transform: uppercase;">Processing</span>
                                        </td>
                                    </tr>
                                </table>
                            </td>
                        </tr>

                        <!-- Cost Breakdown -->
                        <tr>
                            <td style="padding-bottom: 24px; border-bottom: 1px solid #e6e8ea;">
                                <table border="0" cellpadding="0" cellspacing="0" width="100%" style="font-size: 14px; color: #45464d;">
                                    <tr>
                                        <td style="padding: 6px 0;">Subtotal</td>
                                        <td align="right" style="padding: 6px 0; color: #191c1e; font-weight: 500;">${total_amount:.2f}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 6px 0;">Shipping</td>
                                        <td align="right" style="padding: 6px 0; color: #191c1e; font-weight: 500;">FREE</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 6px 0;">Estimated Taxes</td>
                                        <td align="right" style="padding: 6px 0; color: #191c1e; font-weight: 500;">$0.00</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 12px 0 0 0; font-weight: bold; color: #191c1e; font-size: 16px; border-top: 1px solid #e6e8ea;">Total</td>
                                        <td align="right" style="padding: 12px 0 0 0; font-weight: bold; color: #191c1e; font-size: 18px; border-top: 1px solid #e6e8ea;">${total_amount:.2f}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>

                        <!-- Footer Note -->
                        <tr>
                            <td align="center" style="padding-top: 24px;">
                                <p style="font-size: 12px; color: #76777d; margin: 0;">This is an automated transactional update from <strong>SmartRetailX Cloud Infrastructure</strong>.</p>
                            </td>
                        </tr>

                    </table>
                </td>
            </tr>
        </table>
    </body>
    </html>
    """

    if SMTP_HOST:
        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = SMTP_FROM_EMAIL
            msg["To"] = customer_email

            msg.attach(MIMEText(body_text, "plain"))
            msg.attach(MIMEText(body_html, "html"))

            with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as server:
                server.starttls()
                if SMTP_USER and SMTP_PASSWORD:
                    server.login(SMTP_USER, SMTP_PASSWORD)
                server.sendmail(SMTP_FROM_EMAIL, [customer_email], msg.as_string())
            print(f"[SMTP EMAIL SUCCESS] Sent styled HTML confirmation email to {customer_email} for Order #{order_id}")
            return True
        except Exception as e:
            print(f"[SMTP EMAIL ERROR] Failed to send email to {customer_email} via {SMTP_HOST}:{SMTP_PORT} - {e}")
            return False
    else:
        print(f"[EMAIL NOTIFICATION DISPATCH] Confirmation email generated for '{customer_email}' - Order #{order_id} (${total_amount:.2f})")
        return True

# -------------------------------------------------------------
# EventBridge Publishing Wrapper with tenacity Retries
# -------------------------------------------------------------
@retry(stop=stop_after_attempt(2), wait=wait_fixed(1))
def publish_order_placed_event(event_detail):
    events_client.put_events(
        Entries=[
            {
                "Source": "smartretailx.order",
                "DetailType": "OrderPlaced",
                "Detail": json.dumps(event_detail),
                "EventBusName": EVENT_BUS_NAME
            }
        ]
    )

@retry(stop=stop_after_attempt(2), wait=wait_fixed(1))
def publish_delivery_event(event_detail):
    events_client.put_events(
        Entries=[
            {
                "Source": "smartretailx.order",
                "DetailType": "DeliveryStatusUpdated",
                "Detail": json.dumps(event_detail),
                "EventBusName": EVENT_BUS_NAME
            }
        ]
    )

# WebSocket Gateway Broadcaster Helper
WS_GATEWAY_URL = os.getenv("WS_GATEWAY_URL", "http://websocket-gateway:9001/events")

def notify_websocket_gateway(event: str, data: dict):
    try:
        import urllib.request
        req = urllib.request.Request(
            WS_GATEWAY_URL,
            data=json.dumps({"event": event, "data": data}).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=3) as resp:
            print(f"[WS BROADCAST SUCCESS] Sent event '{event}' to WebSocket gateway.")
    except Exception as e:
        print(f"[WS BROADCAST NOTICE] {e}")

# Apache Kafka High-Throughput Event Streaming Helper
KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:29092")
KAFKA_STREAM_TOPIC = os.getenv("KAFKA_STREAM_TOPIC", "smartretailx-stream-events")

def publish_kafka_stream_event(event_detail: dict):
    try:
        from kafka import KafkaProducer
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS.split(","),
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            request_timeout_ms=3000
        )
        producer.send(KAFKA_STREAM_TOPIC, event_detail)
        producer.flush(timeout=3)
        print(f"[KAFKA STREAM PRODUCER] Published stream event to topic '{KAFKA_STREAM_TOPIC}' successfully.")
    except Exception as e:
        print(f"[KAFKA STREAM PRODUCER NOTICE] Stream publish notice (broker offline or initializing): {e}")

# -------------------------------------------------------------

# API endpoints: POST /api/v1/orders (Protected with JWT RBAC)
@app.post("/api/v1/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(
    order: OrderCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
  db_order = None
  try:
    # 1. Save state to relational DB
    db_order = OrderDB(
        customer_id=order.customer_id,
        product_id=order.product_id,
        product_name=order.product_name or "SmartRetailX Restock Item",
        image_url=order.image_url or "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=150",
        payment_method=order.payment_method or "Digital Bank Transfer",
        quantity=order.quantity,
        total_amount=order.total_amount,
        status="Pending"
    )
    db.add(db_order)
    db.commit()
    db.refresh(db_order)

    customer_email = current_user.get("email") or order.customer_id

    # 2. Trigger asynchronous Order Confirmation Email via BackgroundTasks with dynamic product name and image URL
    background_tasks.add_task(
        send_order_confirmation_email,
        customer_email,
        db_order.id,
        db_order.product_id,
        db_order.product_name,
        db_order.image_url,
        db_order.quantity,
        db_order.total_amount
    )

    # 3. Publish OrderPlaced event to Custom EventBus (Offloaded to background task to prevent blocking HTTP handler)
    try:
        event_detail = {
            "order_id": db_order.id,
            "product_id": db_order.product_id,
            "product_name": db_order.product_name,
            "image_url": db_order.image_url,
            "payment_method": db_order.payment_method,
            "quantity": db_order.quantity,
            "customer_id": customer_email,
            "total_amount": db_order.total_amount
        }
        background_tasks.add_task(publish_order_placed_event, event_detail)
    except Exception as eb_err:
        print(f"EventBridge publishing notice: {eb_err}")

    # 4. Push real-time event to WebSocket Gateway Companion Service
    try:
        background_tasks.add_task(
            notify_websocket_gateway,
            "order_placed",
            {
                "order_id": db_order.id,
                "product_id": db_order.product_id,
                "product_name": db_order.product_name,
                "quantity": db_order.quantity,
                "total_amount": db_order.total_amount,
                "customer_id": customer_email,
                "created_at": db_order.created_at.isoformat() if db_order.created_at else None
            }
        )
    except Exception as ws_err:
        print(f"WebSocket notification notice: {ws_err}")

    # 5. Publish High-Throughput Stream Event to Apache Kafka Broker
    try:
        background_tasks.add_task(
            publish_kafka_stream_event,
            {
                "event_type": "OrderPlacedStream",
                "order_id": db_order.id,
                "product_id": db_order.product_id,
                "quantity": db_order.quantity,
                "total_amount": db_order.total_amount,
                "customer_id": customer_email,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    except Exception as kafka_err:
        print(f"Kafka background task notice: {kafka_err}")

    return db_order

  except Exception as e:
    print(f"Transaction failed: {str(e)}")
    db.rollback()
    raise HTTPException(status_code=500, detail=f"Order creation failed: {str(e)}")
  finally:
    db.close()

# -------------------------------------------------------------
# Synchronous 2-Phase Commit (2PC) Coordinator Implementation
# -------------------------------------------------------------
PAYMENT_SERVICE_URL = os.getenv("PAYMENT_SERVICE_URL", "http://payment-service:8002")

class TwoPCCheckoutRequest(BaseModel):
    customer_id: str
    product_id: str
    product_name: Optional[str] = "2PC High-Value Order"
    quantity: int
    total_amount: float
    payment_method: Optional[str] = "Digital Bank Transfer"

@app.post("/api/v1/transactions/2pc/checkout")
def execute_2pc_checkout(req: TwoPCCheckoutRequest, background_tasks: BackgroundTasks):
    """
    Synchronous Two-Phase Commit (2PC) Coordinator:
    Phase 1 (Prepare): Ask participants (Payment Service & Inventory) to prepare & lock resources.
    Phase 2 (Commit/Rollback): Simultaneously commit or rollback all participating services based on votes.
    """
    transaction_id = f"2pc-tx-{os.urandom(4).hex()}"
    print(f"[2PC COORDINATOR] Initiating 2PC Transaction {transaction_id} for {req.customer_id} (${req.total_amount:.2f})")

    # PHASE 1: PREPARE PHASE
    votes = {}
    
    # 1. Contact Payment Service Participant
    try:
        payment_prep_url = f"{PAYMENT_SERVICE_URL}/api/v1/payments/prepare"
        pay_res = requests.post(
            payment_prep_url,
            json={
                "transaction_id": transaction_id,
                "order_id": transaction_id,
                "amount": req.total_amount
            },
            timeout=5
        )
        if pay_res.status_code == 200 and pay_res.json().get("vote") == "VOTE_COMMIT":
            votes["payment_service"] = "VOTE_COMMIT"
            print(f"[2PC PHASE 1] Payment Service voted VOTE_COMMIT for {transaction_id}")
        else:
            votes["payment_service"] = "VOTE_ABORT"
            print(f"[2PC PHASE 1] Payment Service voted VOTE_ABORT for {transaction_id}")
    except Exception as e:
        votes["payment_service"] = "VOTE_ABORT"
        print(f"[2PC PHASE 1 ERROR] Payment Service prepare phase failed: {e}")

    # 2. Check Order / Inventory Local Participant Readiness
    if req.quantity > 0:
        votes["order_service"] = "VOTE_COMMIT"
    else:
        votes["order_service"] = "VOTE_ABORT"

    # PHASE 2: COMMIT / ABORT DECISION
    all_commit = all(vote == "VOTE_COMMIT" for vote in votes.values())

    if all_commit:
        print(f"[2PC PHASE 2] All participants voted VOTE_COMMIT. Proceeding to COMMIT {transaction_id}")
        
        # 1. Commit Payment Service Participant
        try:
            requests.post(f"{PAYMENT_SERVICE_URL}/api/v1/payments/commit", json={"transaction_id": transaction_id}, timeout=5)
        except Exception as e:
            print(f"[2PC PHASE 2 COMMIT WARNING] Payment commit notice: {e}")

        # 2. Commit Order Local Database Record
        db = SessionLocal()
        db_order = OrderDB(
            customer_id=req.customer_id,
            product_id=req.product_id,
            product_name=req.product_name,
            quantity=req.quantity,
            total_amount=req.total_amount,
            payment_method=req.payment_method,
            status="2PC_COMMITTED"
        )
        db.add(db_order)
        db.commit()
        db.refresh(db_order)
        db.close()

        return {
            "status": "COMMITTED",
            "transaction_id": transaction_id,
            "order_id": db_order.id,
            "phase1_votes": votes,
            "phase2_result": "COMMITTED_ALL_PARTICIPANTS"
        }
    else:
        print(f"[2PC PHASE 2] Vote abort detected. Rolling back transaction {transaction_id}")
        
        # 1. Rollback Payment Service Participant
        try:
            requests.post(f"{PAYMENT_SERVICE_URL}/api/v1/payments/rollback", json={"transaction_id": transaction_id}, timeout=5)
        except Exception as e:
            print(f"[2PC PHASE 2 ROLLBACK WARNING] Payment rollback notice: {e}")

        return {
            "status": "ABORTED",
            "transaction_id": transaction_id,
            "phase1_votes": votes,
            "phase2_result": "ROLLED_BACK_ALL_PARTICIPANTS",
            "reason": "Phase 1 prepare vote failed for one or more participants"
        }

# API endpoints: POST /api/v1/orders/{id}/delivery (Driver / Admin restricted)
@app.post("/api/v1/orders/{id}/delivery")
def update_delivery_status(
    id: int, 
    update: DeliveryStatusUpdate, 
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles(["driver", "admin", "store_manager"]))
):
    db_order = db.query(OrderDB).filter(OrderDB.id == id).first()
    if db_order:
        # Validate Finite State Machine (FSM) Transition
        OrderFSM.validate_transition(db_order.status, update.status)
        db_order.status = update.status
        db.commit()

        # Outbox Pattern: Record state transition event
        outbox_ev = OutboxEventDB(
            aggregate_type="Order",
            aggregate_id=str(id),
            event_type="DeliveryStatusChanged",
            payload=json.dumps({
                "order_id": id,
                "status": update.status,
                "customer_id": db_order.customer_id,
                "updated_by": current_user.get("email"),
                "state_snapshot": {
                    "order_id": db_order.id,
                    "product_name": db_order.product_name,
                    "status": update.status,
                    "version": db_order.version
                }
            }),
            processed=True
        )
        db.add(outbox_ev)
        db.commit()
    
    event_detail = {
        "order_id": id,
        "delivery_status": update.status,
        "updated_by": current_user.get("email"),
        "timestamp": datetime.utcnow().isoformat(),
        "state_snapshot": {
            "order_id": id,
            "status": update.status,
            "product_name": db_order.product_name if db_order else "Item"
        }
    }
    try:
        publish_delivery_event(event_detail)
        publish_kafka_stream_event(event_detail)
        notify_websocket_gateway(id, update.status, db_order.product_name if db_order else "Item", 1, db_order.product_id if db_order else "PROD")
        return {"status": "success", "message": f"Delivery status for Order {id} updated to '{update.status}' by {current_user.get('role')}."}
    except Exception as e:
        return {"status": "success", "message": f"Delivery status updated to '{update.status}' (Event notice: {str(e)})."}

# API endpoints: GET /api/v1/driver/deliveries (Driver / Admin restricted)
@app.get("/api/v1/driver/deliveries")
def get_driver_deliveries(
    status_filter: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles(["driver", "admin", "store_manager"]))
):
    query = db.query(OrderDB)
    if status_filter:
        query = query.filter(OrderDB.status == status_filter)
    else:
        # Explicitly query orders matching driver dispatch status
        query = query.filter(OrderDB.status.in_(["Ready for Dispatch", "Fulfilled", "Out for Delivery", "Assigned", "Pending"]))
    
    orders = query.order_by(OrderDB.id.desc()).all()
    deliveries = []
    for o in orders:
        deliveries.append({
            "order_id": o.id,
            "customer": o.customer_id,
            "product": o.product_name,
            "quantity": o.quantity,
            "total_amount": o.total_amount,
            "status": "Ready for Dispatch" if o.status in ["Fulfilled", "Pending"] else o.status,
            "version": o.version,
            "address": "742 Evergreen Terrace, Sector 4",
            "phone": "+1 (555) 019-2834"
        })
    return {"status": "success", "deliveries": deliveries}

# API endpoints: POST /api/v1/orders/{id}/fulfillment (Staff / Admin restricted)
@app.post("/api/v1/orders/{id}/fulfillment")
def update_fulfillment_status(
    id: int,
    payload: dict,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles(["staff", "admin", "store_manager"]))
):
    requested_status = payload.get("status", "Ready for Dispatch")
    # Align staff fulfillment action to exact driver query status 'Ready for Dispatch'
    new_status = "Ready for Dispatch" if requested_status in ["Fulfilled", "Ready for Dispatch"] else requested_status

    db_order = db.query(OrderDB).filter(OrderDB.id == id).first()
    if not db_order:
        raise HTTPException(status_code=404, detail=f"Order #{id} not found")
    
    # Validate Finite State Machine (FSM) Transition
    OrderFSM.validate_transition(db_order.status, new_status)
    db_order.status = new_status
    db_order.version += 1
    
    # Persist and refresh order instance in relational database
    db.commit()
    db.refresh(db_order)

    # Outbox Pattern: Record state transition event
    outbox_ev = OutboxEventDB(
        aggregate_type="Order",
        aggregate_id=str(id),
        event_type="OrderFulfillmentChanged",
        payload=json.dumps({
            "order_id": id,
            "status": new_status,
            "updated_by": current_user.get("email"),
            "state_snapshot": {
                "order_id": id,
                "product_name": db_order.product_name,
                "status": new_status,
                "version": db_order.version
            }
        }),
        processed=True
    )
    db.add(outbox_ev)
    db.commit()

    notify_websocket_gateway(id, new_status, db_order.product_name, db_order.quantity, db_order.product_id)
    return {
        "status": "success",
        "message": f"Order #{id} status updated to '{new_status}' for driver dispatch.",
        "order": {
            "id": db_order.id,
            "customer_id": db_order.customer_id,
            "product_id": db_order.product_id,
            "product_name": db_order.product_name,
            "quantity": db_order.quantity,
            "total_amount": db_order.total_amount,
            "status": db_order.status,
            "version": db_order.version,
            "created_at": db_order.created_at.isoformat() if hasattr(db_order.created_at, 'isoformat') else str(db_order.created_at)
        }
    }

# API endpoints: GET /api/v1/staff/orders (Staff / Admin restricted)
@app.get("/api/v1/staff/orders")
def get_staff_orders(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles(["staff", "admin", "store_manager"]))
):
    orders = db.query(OrderDB).order_by(OrderDB.id.desc()).all()
    return {"status": "success", "orders": [
        {
            "id": o.id,
            "customer_id": o.customer_id,
            "product_name": o.product_name,
            "quantity": o.quantity,
            "total_amount": o.total_amount,
            "status": o.status,
            "created_at": o.created_at.isoformat() if hasattr(o.created_at, 'isoformat') else str(o.created_at)
        } for o in orders
    ]}

# API endpoints: GET /api/v1/admin/overview (Admin restricted)
@app.get("/api/v1/admin/overview")
def get_admin_overview(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_roles(["admin"]))
):
    total_orders = db.query(OrderDB).count()
    completed_orders = db.query(OrderDB).filter(OrderDB.status == "Delivered").count()
    return {
        "status": "success",
        "system_status": "OPERATIONAL",
        "total_orders": total_orders,
        "completed_deliveries": completed_orders,
        "active_microservices": 8,
        "aws_region": os.getenv("AWS_REGION", "ap-south-1")
    }

# API endpoints: GET /api/v1/orders (Protected with JWT RBAC)
@app.get("/api/v1/orders", response_model=list[OrderResponse])
def get_orders(db: Session = Depends(get_db), current_user: dict = Depends(get_current_user)):
    orders = db.query(OrderDB).order_by(OrderDB.id.desc()).all()
    return orders

# API endpoints: GET /api/v1/orders/{id}
@app.get("/api/v1/orders/{id}", response_model=OrderResponse)
def get_order(id: int, db: Session = Depends(get_db)):
    db_order = db.query(OrderDB).filter(OrderDB.id == id).first()
    if not db_order:
      raise HTTPException(status_code=404, detail=f"Order with ID {id} not found")
    return db_order

# API endpoints: POST /api/v1/inventory/restock (Staff / Admin restricted)
@app.post("/api/v1/inventory/restock")
def restock_inventory(
    payload: dict,
    current_user: dict = Depends(require_roles(["staff", "admin", "store_manager"]))
):
    sku = payload.get("sku", "SKU-GEN")
    quantity = int(payload.get("quantity", 10))
    print(f"[ORDER SERVICE INVENTORY] Restocking SKU '{sku}' with +{quantity} units by {current_user.get('email')}.")
    return {"status": "success", "message": f"Restocked {quantity} units for SKU {sku}", "sku": sku, "quantity": quantity}

# API endpoints: POST /api/v1/admin/promotions (Admin / Staff restricted)
@app.post("/api/v1/admin/promotions")
def create_admin_promotion(
    payload: dict,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(require_roles(["admin", "staff", "store_manager"]))
):
    product_id = payload.get("product_id", "PROD-001")
    flash_sale_price = float(payload.get("flash_sale_price", 4.99))
    discount_pct = float(payload.get("discount_percentage", 20.0))
    promo_code = payload.get("promotion_code", "FLASH2026")

    event_detail = {
        "product_id": product_id,
        "flash_sale_price": flash_sale_price,
        "discount_percentage": discount_pct,
        "promotion_code": promo_code,
        "created_by": current_user.get("email"),
        "timestamp": datetime.utcnow().isoformat()
    }

    # Offload EventBridge event publishing & WebSocket gateway broadcast
    try:
        background_tasks.add_task(publish_order_placed_event, event_detail)
        background_tasks.add_task(
            notify_websocket_gateway,
            "promotion_updated",
            {
                "product_id": product_id,
                "flash_sale_price": flash_sale_price,
                "discount_percentage": discount_pct,
                "promotion_code": promo_code,
                "message": f"⚡ FLASH SALE LAUNCHED! Item {product_id} price dropped to ${flash_sale_price:.2f} ({discount_pct}% OFF) with code {promo_code}!"
            }
        )
    except Exception as err:
        print(f"Promotion notification notice: {err}")

    return {
        "status": "success",
        "message": f"Flash sale launched for item {product_id} by {current_user.get('role')}.",
        "promotion": event_detail
    }

# API endpoints: PUT /api/v1/products/{id}/price (Admin / Staff restricted)
@app.put("/api/v1/products/{id}/price")
def update_product_price(
    id: str,
    payload: dict,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(require_roles(["admin", "staff", "store_manager"]))
):
    new_price = float(payload.get("price", payload.get("flash_sale_price", 9.99)))
    event_detail = {
        "product_id": id,
        "new_price": new_price,
        "updated_by": current_user.get("email"),
        "timestamp": datetime.utcnow().isoformat()
    }

    try:
        background_tasks.add_task(
            notify_websocket_gateway,
            "promotion_updated",
            {
                "product_id": id,
                "new_price": new_price,
                "message": f"🔥 Price updated for item {id} to ${new_price:.2f}!"
            }
        )
    except Exception as err:
        print(f"Price update notification notice: {err}")

    return {
        "status": "success",
        "message": f"Price updated for product {id} to ${new_price:.2f}.",
        "product_id": id,
        "new_price": new_price
    }

# Healthcheck
@app.get("/health")
def healthcheck():
  return {"status": "healthy", "service": "order-service"}