"""
SmartRetailX Order Service — Unit & Integration Tests
Uses FastAPI TestClient with mocked DB sessions and boto3 EventBridge calls.
"""
import sys
import os
import pytest
import json
from unittest.mock import MagicMock, patch
from datetime import datetime
from fastapi.testclient import TestClient

_service_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _service_dir not in sys.path:
    sys.path.insert(0, _service_dir)
else:
    sys.path.remove(_service_dir)
    sys.path.insert(0, _service_dir)

if "main" in sys.modules:
    _mod_file = getattr(sys.modules["main"], "__file__", "") or ""
    if not os.path.abspath(_mod_file).startswith(_service_dir):
        del sys.modules["main"]



# We must patch external dependencies BEFORE importing the app module
# to prevent real DB connections and AWS API calls during test collection.

@pytest.fixture(autouse=True)
def mock_db_and_aws(monkeypatch):
    """Patch SQLAlchemy engine creation and boto3 EventBridge client."""
    # Patch environment to use SQLite in-memory for test isolation
    monkeypatch.setenv("DB_HOST", "")
    monkeypatch.setenv("COGNITO_USER_POOL_ID", "ap-south-1_TestPool")
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", "test-client-id")


@pytest.fixture
def client():
    """Create a fresh TestClient for each test, bypassing JWT auth."""
    _service_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    if _service_dir not in sys.path:
        sys.path.insert(0, _service_dir)
    else:
        sys.path.remove(_service_dir)
        sys.path.insert(0, _service_dir)

    if "main" in sys.modules:
        _mod_file = getattr(sys.modules["main"], "__file__", "") or ""
        if not os.path.abspath(_mod_file).startswith(_service_dir):
            del sys.modules["main"]

    # Import the app module (uses SQLite fallback since DB_HOST is empty)
    from main import app, get_current_user


    # Override the JWT dependency to bypass Cognito auth in tests
    def mock_current_user():
        return {"email": "test@smartretailx.com", "role": "store_manager"}

    app.dependency_overrides[get_current_user] = mock_current_user

    with TestClient(app) as tc:
        yield tc

    # Clean up overrides
    app.dependency_overrides.clear()


@pytest.fixture
def mock_eventbridge():
    """Mock the boto3 EventBridge put_events call."""
    with patch("main.events_client") as mock_client:
        mock_client.put_events.return_value = {"FailedEntryCount": 0, "Entries": [{"EventId": "mock-event-123"}]}
        yield mock_client


class TestHealthEndpoint:
    """Tests for GET /health"""

    def test_health_returns_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "order-service"


class TestCreateOrder:
    """Tests for POST /api/v1/orders"""

    def test_create_order_success(self, client, mock_eventbridge):
        payload = {
            "customer_id": "customer-001",
            "product_id": "prod-101",
            "quantity": 2,
            "total_amount": 9.98
        }

        response = client.post("/api/v1/orders", json=payload)
        assert response.status_code == 201

        data = response.json()
        assert data["customer_id"] == "customer-001"
        assert data["product_id"] == "prod-101"
        assert data["quantity"] == 2
        assert data["total_amount"] == 9.98
        assert data["status"] == "Pending"
        assert "id" in data
        assert "created_at" in data

        # Verify EventBridge was called
        mock_eventbridge.put_events.assert_called_once()
        call_args = mock_eventbridge.put_events.call_args
        entry = call_args[1]["Entries"][0] if "Entries" in call_args[1] else call_args[0][0] if call_args[0] else None

    def test_create_order_missing_fields(self, client, mock_eventbridge):
        # Missing required fields should return 422 Unprocessable Entity
        payload = {"customer_id": "customer-001"}

        response = client.post("/api/v1/orders", json=payload)
        assert response.status_code == 422

    def test_create_order_invalid_types(self, client, mock_eventbridge):
        payload = {
            "customer_id": "customer-001",
            "product_id": "prod-101",
            "quantity": "not-a-number",
            "total_amount": "invalid"
        }

        response = client.post("/api/v1/orders", json=payload)
        assert response.status_code == 422


class TestGetOrder:
    """Tests for GET /api/v1/orders/{id}"""

    def test_get_order_not_found(self, client):
        response = client.get("/api/v1/orders/99999")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"]

    def test_get_order_after_creation(self, client, mock_eventbridge):
        # First create an order
        payload = {
            "customer_id": "customer-002",
            "product_id": "prod-102",
            "quantity": 1,
            "total_amount": 3.50
        }
        create_response = client.post("/api/v1/orders", json=payload)
        assert create_response.status_code == 201
        order_id = create_response.json()["id"]

        # Then retrieve it
        get_response = client.get(f"/api/v1/orders/{order_id}")
        assert get_response.status_code == 200
        data = get_response.json()
        assert data["customer_id"] == "customer-002"
        assert data["product_id"] == "prod-102"
