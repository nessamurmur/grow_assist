from .main import app
from fastapi.testclient import TestClient

def test_api_endpoint():
    client = TestClient(app)
    response = client.get("/")
    assert response.status_code == 200
