import sys
import os
import pytest
from fastapi.testclient import TestClient

@pytest.fixture
def client():
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

    from main import app
    with TestClient(app) as test_client:
        yield test_client

def test_user_healthcheck(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "user-service"
