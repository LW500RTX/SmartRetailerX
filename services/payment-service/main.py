import os
import json
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import boto3
from aws_xray_sdk.core import xray_recorder
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

# Custom ASGI X-Ray Middleware to trace FastAPI requests
class XRayMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        segment = xray_recorder.begin_segment(
            name=f"payment-service:{request.method} {request.url.path}",
            traceid=None,
            parent_id=None,
            sampling=1
        )
        try:
            response = await call_next(request)
            segment.put_http_meta('STATUS', response.status_code)
            return response
        except Exception as e:
            segment.add_exception(e)
            raise e
        finally:
            xray_recorder.end_segment()

app = FastAPI(
    title="SmartRetailX Payment Service",
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

# Configure AWS X-Ray Middleware
xray_recorder.configure(service='payment-service')
app.add_middleware(XRayMiddleware)

# Prometheus Metrics Instrumentation & Exposure (/metrics)
try:
    from prometheus_fastapi_instrumentator import Instrumentator
    Instrumentator().instrument(app).expose(app)
except Exception as e:
    print(f"Prometheus instrumentation notice: {e}")

# OpenTelemetry Distributed Tracing & Jaeger Exporter
try:
    from tracing import setup_opentelemetry_tracing
    setup_opentelemetry_tracing("payment-service", app)
except Exception as e:
    print(f"OpenTelemetry initialization notice: {e}")

EVENT_BUS_NAME = os.getenv("EVENT_BUS_NAME", "smartretailx-bus-production")
aws_region = os.getenv("AWS_REGION", "ap-south-1")
endpoint_url = os.getenv("AWS_ENDPOINT_URL")

boto_args = {"region_name": aws_region}
if endpoint_url:
    boto_args["endpoint_url"] = endpoint_url
    boto_args["aws_access_key_id"] = "mock"
    boto_args["aws_secret_access_key"] = "mock"

events_client = boto3.client("events", **boto_args)

class PaymentCreate(BaseModel):
    order_id: str
    amount: float
    currency: str
    payment_method: str

@app.post("/api/v1/payments", status_code=status.HTTP_201_CREATED)
def create_payment(payment: PaymentCreate):
    try:
        # Generate mock transaction reference
        transaction_id = f"tx-{os.urandom(4).hex()}"
        
        # Publish event PaymentProcessed to EventBridge
        event_detail = {
            "order_id": payment.order_id,
            "amount": payment.amount,
            "currency": payment.currency,
            "payment_method": payment.payment_method,
            "transaction_id": transaction_id,
            "status": "APPROVED"
        }
        
        events_client.put_events(
            Entries=[
                {
                    "Source": "smartretailx.payment",
                    "DetailType": "PaymentProcessed",
                    "Detail": json.dumps(event_detail),
                    "EventBusName": EVENT_BUS_NAME
                }
            ]
        )
        
        print(f"Published PaymentProcessed event for Order ID {payment.order_id} successfully.")
        return {
            "status": "success",
            "transaction_id": transaction_id,
            "message": "Payment processed and event dispatched"
        }
    except Exception as e:
        print(f"Payment processing failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Payment transaction failed: {str(e)}")

@app.get("/health")
def healthcheck():
    return {"status": "healthy", "service": "payment-service"}

# -------------------------------------------------------------
# Synchronous 2-Phase Commit (2PC) Participant Implementation
# -------------------------------------------------------------
PREPARED_LOCKS = {}

class TwoPCPrepareRequest(BaseModel):
    transaction_id: str
    order_id: str
    amount: float

class TwoPCActionRequest(BaseModel):
    transaction_id: str

@app.post("/api/v1/payments/prepare")
def prepare_payment_2pc(req: TwoPCPrepareRequest):
    """Phase 1: Prepare Phase - Lock funds & confirm readiness"""
    if req.amount > 100000:
        return {"vote": "VOTE_ABORT", "reason": "Amount exceeds credit threshold limit"}
    
    PREPARED_LOCKS[req.transaction_id] = {
        "order_id": req.order_id,
        "amount": req.amount,
        "status": "PREPARED_LOCKED"
    }
    print(f"[2PC PHASE 1 PREPARE] Locked funds for transaction {req.transaction_id} (${req.amount:.2f})")
    return {"vote": "VOTE_COMMIT", "transaction_id": req.transaction_id, "locked": True}

@app.post("/api/v1/payments/commit")
def commit_payment_2pc(req: TwoPCActionRequest):
    """Phase 2: Commit Phase - Execute synchronous transaction commit"""
    lock = PREPARED_LOCKS.pop(req.transaction_id, None)
    if not lock:
        return {"status": "NOT_FOUND", "message": "Transaction lock not found"}
    
    print(f"[2PC PHASE 2 COMMIT] Payment committed for transaction {req.transaction_id}")
    return {"status": "COMMITTED", "transaction_id": req.transaction_id}

@app.post("/api/v1/payments/rollback")
def rollback_payment_2pc(req: TwoPCActionRequest):
    """Phase 2: Abort/Rollback Phase - Release locked resources"""
    lock = PREPARED_LOCKS.pop(req.transaction_id, None)
    print(f"[2PC PHASE 2 ROLLBACK] Released locks for transaction {req.transaction_id}")
    return {"status": "ROLLED_BACK", "transaction_id": req.transaction_id}

