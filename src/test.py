from unittest.mock import patch
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
    assert '<form method="post" action="/ask_ai">' in response.text
    assert '<textarea' in response.text
    assert 'name="prompt"' in response.text


@patch('src.main.get_model')
def test_ask_ai_endpoint_successful_response(mock_get_model):
    """Test that submitting a prompt to the API endpoint returns a successful response."""
    mock_llm = FakeListChatModel(
        responses=["Your VPD is within the optimal range for vegetation stage."]
    )
    mock_get_model.return_value = mock_llm
    
    client = TestClient(app)
    response = client.post(
        "/ask_ai",
        data={"prompt": "I'm in vegetation stage. Temp is 78°F, humidity is 65%"}
    )
    
    assert response.status_code == 200
    assert "Your VPD is within the optimal range" in response.text


@patch('src.main.get_model')
def test_ask_ai_endpoint_preserves_prompt(mock_get_model):
    """Test that the submitted prompt is preserved in the response."""
    mock_llm = FakeListChatModel(responses=["Test AI response"])
    mock_get_model.return_value = mock_llm
    
    client = TestClient(app)
    test_prompt = "What is the ideal VPD for flowering?"
    response = client.post(
        "/ask_ai",
        data={"prompt": test_prompt}
    )
    
    assert response.status_code == 200
    assert test_prompt in response.text
    assert "Test AI response" in response.text


def test_ask_ai_endpoint_requires_prompt():
    """Test that the endpoint requires a prompt parameter."""
    client = TestClient(app)
    response = client.post("/ask_ai", data={})
    
    assert response.status_code == 422
