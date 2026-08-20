"""
SmartRetailX Admin & Promotions Management Microservice
Handles promotional campaign creation, flash sales scheduling, and PriceAndPromotionUpdate EventBridge dispatches.
"""
from fastapi import FastAPI, Depends, HTTPException, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import os
import json
import boto3
import urllib.request
from datetime import datetime, timedelta

app = FastAPI(
    title="SmartRetailX Admin & Promotion Management Service",
    version="1.0.0",
    docs_url="/docs"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

EVENT_BUS_NAME = os.getenv("EVENT_BUS_NAME", "smartretailx-bus")
AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL")

boto_args = {"region_name": AWS_REGION}
if AWS_ENDPOINT_URL:
    boto_args["endpoint_url"] = AWS_ENDPOINT_URL
    boto_args["aws_access_key_id"] = "mock"
    boto_args["aws_secret_access_key"] = "mock"

events_client = boto3.client("events", **boto_args)

# Pydantic Schemas
class PromotionCreate(BaseModel):
    product_id: str
    original_price: float
    promo_price: float
    discount_percentage: Optional[float] = 20.0
    promotion_code: Optional[str] = "FLASH2026"
    promo_start_time: Optional[str] = None
    promo_end_time: Optional[str] = None

class PromotionResponse(BaseModel):
    status: str
    message: str
    promotion_id: str
    product_id: str
    promo_price: float
    discount_percentage: float

# Role Validation Dependency Stub
def verify_role(allowed_roles: List[str]):
    def role_checker():
        return {"role": "admin", "email": "admin@smartretailx.com"}
    return role_checker

def publish_price_promotion_event(event_type: str, detail: dict):
    try:
        events_client.put_events(
            Entries=[{
                "Source": "smartretailx.admin",
                "DetailType": event_type,
                "Detail": json.dumps(detail),
                "EventBusName": EVENT_BUS_NAME
            }]
        )
        print(f"[EVENTBRIDGE PUBLISHED] '{event_type}' dispatched to bus '{EVENT_BUS_NAME}'.")
    except Exception as e:
        print(f"[EVENTBRIDGE WARNING] {e}")

def notify_websocket_gateway(event_name: str, payload: dict):
    try:
        ws_url = os.getenv("WEBSOCKET_GATEWAY_URL", "http://localhost:9001/api/v1/broadcast/promotion")
        req = urllib.request.Request(
            ws_url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=3) as resp:
            pass
    except Exception as e:
        print(f"[WEBSOCKET PUSH WARNING] {e}")

@app.post("/api/v1/admin/promotions", response_model=PromotionResponse, status_code=status.HTTP_201_CREATED)
def create_promotion(
    promo: PromotionCreate,
    background_tasks: BackgroundTasks,
    user: dict = Depends(verify_role(["admin", "staff"]))
):
    promo_id = f"PROMO-{int(datetime.utcnow().timestamp())}"
    start_time = promo.promo_start_time or datetime.utcnow().isoformat()
    end_time = promo.promo_end_time or (datetime.utcnow() + timedelta(days=1)).isoformat()

    event_detail = {
        "promotion_id": promo_id,
        "product_id": promo.product_id,
        "original_price": promo.original_price,
        "discount_price": promo.promo_price,
        "promo_price": promo.promo_price,
        "is_on_sale": True,
        "discount_percentage": promo.discount_percentage,
        "promotion_code": promo.promotion_code,
        "promo_start_time": start_time,
        "promo_end_time": end_time,
        "created_by": user.get("email"),
        "timestamp": datetime.utcnow().isoformat()
    }

    # Publish PriceAndPromotionUpdate to EventBridge & WebSocket Gateway
    background_tasks.add_task(publish_price_promotion_event, "PriceAndPromotionUpdate", event_detail)
    background_tasks.add_task(
        notify_websocket_gateway,
        "PriceAndPromotionUpdate",
        {
            "product_id": promo.product_id,
            "original_price": promo.original_price,
            "discount_price": promo.promo_price,
            "new_price": promo.promo_price,
            "is_on_sale": True,
            "promotion_code": promo.promotion_code,
            "message": f"🔥 FLASH SALE! Item {promo.product_id} price dropped to ${promo.promo_price:.2f} ({promo.discount_percentage}% OFF)!"
        }
    )

    return PromotionResponse(
        status="success",
        message=f"Promotional campaign '{promo_id}' created successfully for product {promo.product_id}.",
        promotion_id=promo_id,
        product_id=promo.product_id,
        promo_price=promo.promo_price,
        discount_percentage=promo.discount_percentage or 20.0
    )

@app.delete("/api/v1/admin/promotions/{id}")
def delete_promotion(
    id: str,
    background_tasks: BackgroundTasks,
    user: dict = Depends(verify_role(["admin", "staff"]))
):
    event_detail = {
        "promotion_id": id,
        "action": "DELETED",
        "terminated_by": user.get("email"),
        "timestamp": datetime.utcnow().isoformat()
    }

    background_tasks.add_task(publish_price_promotion_event, "PriceAndPromotionUpdate", event_detail)

    return {
        "status": "success",
        "message": f"Promotion '{id}' terminated early. Cache invalidation event dispatched."
    }

@app.get("/health")
def healthcheck():
    return {"status": "healthy", "service": "admin-service"}
