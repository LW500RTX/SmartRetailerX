"""
SmartRetailX Order Service — test_main.py
FastAPI TestClient suite to test health status and route validations.
"""
import sys
import os
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch

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


@pytest.fixture(autouse=True)
def setup_test_env(monkeypatch):
    """Setup mock environment variables for testing."""
    monkeypatch.setenv("DB_HOST", "")  # Bypasses RDS setup to trigger SQLite in-memory db
    monkeypatch.setenv("COGNITO_USER_POOL_ID", "ap-south-1_testPool")
    monkeypatch.setenv("COGNITO_APP_CLIENT_ID", "test-app-client-id")
    monkeypatch.setenv("AWS_REGION", "ap-south-1")

@pytest.fixture
def client():
    """Returns a TestClient with overridden Cognito JWT validation for endpoints testing."""
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

    from main import app, get_current_user

    
    # Bypass auth verification by returning a mock authenticated manager user
    def mock_current_user():
        return {"email": "manager@smartretailx.com", "role": "store_manager"}
        
    app.dependency_overrides[get_current_user] = mock_current_user
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()

def test_health_check(client):
    """Tests the GET /health status check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy", "service": "order-service"}

def test_order_creation_invalid_payload(client):
    """Tests that posting an incomplete payload to order creation yields validation error (422)."""
    response = client.post("/api/v1/orders", json={"customer_id": "cust-1"})
    assert response.status_code == 422

def test_get_non_existent_order(client):
    """Tests that querying a non-existent order correctly returns a 404 response."""
    response = client.get("/api/v1/orders/99999")
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()
