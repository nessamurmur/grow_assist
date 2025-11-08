from unittest.mock import patch, MagicMock
import io
from fastapi.testclient import TestClient
from .main import app
from .models import AnalysisResponse, Recommendation, ProductLink


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


@patch('src.main.get_structured_model')
def test_analyze_endpoint_successful_response(mock_get_structured_model):
    """Test that submitting CSV data to the API endpoint returns a successful response."""
    # Create a mock structured response
    mock_analysis = AnalysisResponse(
        summary="Your VPD is within the optimal range for vegetation stage.",
        recommendations=[
            Recommendation(
                title="Maintain Current Conditions",
                description="Your environment is well optimized.",
                priority="low",
                product=ProductLink(
                    name="LEVOIT Humidifier",
                    url="https://amazon.com/dp/B01MYGNGKK",
                    price_range="$40-50"
                )
            ),
            Recommendation(
                title="Monitor VPD Daily",
                description="Continue monitoring to maintain optimal conditions.",
                priority="medium"
            )
        ]
    )
    
    mock_model = MagicMock()
    mock_model.invoke.return_value = mock_analysis
    mock_get_structured_model.return_value = mock_model
    
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
    assert "Maintain Current Conditions" in response.text


@patch('src.main.get_structured_model')
def test_analyze_endpoint_preserves_growth_stage(mock_get_structured_model):
    """Test that the growth stage and filename are preserved in the response."""
    mock_analysis = AnalysisResponse(
        summary="Test AI response",
        recommendations=[
            Recommendation(
                title="Test Recommendation",
                description="Test description",
                priority="high",
                product=ProductLink(name="Test Product", url="https://amazon.com/test")
            ),
            Recommendation(
                title="Another Recommendation",
                description="Another description",
                priority="low"
            )
        ]
    )
    
    mock_model = MagicMock()
    mock_model.invoke.return_value = mock_analysis
    mock_get_structured_model.return_value = mock_model
    
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
