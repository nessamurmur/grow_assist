from unittest.mock import patch
import io
from fastapi.testclient import TestClient
from langchain_core.language_models import FakeListChatModel
from .main import app


def test_root_endpoint_returns_200():
    """Test that the root endpoint returns a successful response."""
    client = TestClient(app)
    response = client.get("/")
    assert response.status_code == 200
    assert "Grow Assist" in response.text


def test_root_endpoint_contains_form():
    """Test that the root endpoint contains the form elements."""
    client = TestClient(app)
    response = client.get("/")
    assert response.status_code == 200
    assert '<form method="post" action="/analyze"' in response.text
    assert 'name="growth_stage"' in response.text
    assert 'name="csv_file"' in response.text


@patch('src.main.get_model')
def test_analyze_endpoint_successful_response(mock_get_model):
    """Test that submitting CSV data to the API endpoint returns a successful response."""
    mock_llm = FakeListChatModel(
        responses=["Your VPD is within the optimal range for vegetation stage."]
    )
    mock_get_model.return_value = mock_llm
    
    # Create sample CSV data
    csv_content = "temperature,humidity,ppfd\n78,65,800\n79,63,820\n"
    csv_file = io.BytesIO(csv_content.encode('utf-8'))
    
    client = TestClient(app)
    response = client.post(
        "/analyze",
        data={"growth_stage": "vegetation"},
        files={"csv_file": ("test_data.csv", csv_file, "text/csv")}
    )
    
    assert response.status_code == 200
    assert "Your VPD is within the optimal range" in response.text


@patch('src.main.get_model')
def test_analyze_endpoint_preserves_growth_stage(mock_get_model):
    """Test that the growth stage and filename are preserved in the response."""
    mock_llm = FakeListChatModel(responses=["Test AI response"])
    mock_get_model.return_value = mock_llm
    
    csv_content = "temperature,humidity\n75,60\n"
    csv_file = io.BytesIO(csv_content.encode('utf-8'))
    
    client = TestClient(app)
    response = client.post(
        "/analyze",
        data={"growth_stage": "flowering"},
        files={"csv_file": ("my_data.csv", csv_file, "text/csv")}
    )
    
    assert response.status_code == 200
    assert "Test AI response" in response.text


def test_analyze_endpoint_requires_csv_file():
    """Test that the endpoint requires a CSV file."""
    client = TestClient(app)
    response = client.post("/analyze", data={"growth_stage": "vegetation"})
    
    assert response.status_code == 422


def test_analyze_endpoint_requires_growth_stage():
    """Test that the endpoint requires a growth stage."""
    csv_content = "temperature,humidity\n75,60\n"
    csv_file = io.BytesIO(csv_content.encode('utf-8'))
    
    client = TestClient(app)
    response = client.post(
        "/analyze",
        files={"csv_file": ("test.csv", csv_file, "text/csv")}
    )
    
    assert response.status_code == 422
