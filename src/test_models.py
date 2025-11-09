import pytest
from pydantic import ValidationError
from .models import ProductLink, Recommendation, AnalysisResponse


class TestProductLink:
    """Tests for the ProductLink model."""

    def test_product_link_with_all_fields(self):
        """Test creating a ProductLink with all fields."""
        product = ProductLink(
            name="LEVOIT Humidifier",
            url="https://htgsupply.com/products/levoit-humidifier",
            price_range="$40-50"
        )
        assert product.name == "LEVOIT Humidifier"
        assert product.url == "https://htgsupply.com/products/levoit-humidifier"
        assert product.price_range == "$40-50"

    def test_product_link_without_price_range(self):
        """Test that price_range is optional."""
        product = ProductLink(
            name="AC Infinity Fan",
            url="https://acinfinity.com/hvac-home-ventilation/inline-duct-fan-systems/"
        )
        assert product.name == "AC Infinity Fan"
        assert product.url == "https://acinfinity.com/hvac-home-ventilation/inline-duct-fan-systems/"
        assert product.price_range is None

    def test_product_link_requires_name(self):
        """Test that name is required."""
        with pytest.raises(ValidationError) as exc_info:
            ProductLink(url="https://amazon.com/dp/B01MYGNGKK")
        assert "name" in str(exc_info.value)

    def test_product_link_requires_url(self):
        """Test that url is required."""
        with pytest.raises(ValidationError) as exc_info:
            ProductLink(name="Test Product")
        assert "url" in str(exc_info.value)

    def test_product_link_rejects_malformed_urls(self):
        """Test that malformed URLs are rejected."""
        invalid_urls = [
            "not-a-url",
            "ftp://invalid-protocol.com",
            "www.missing-protocol.com",
            "https://nodomain",
        ]
        for url in invalid_urls:
            with pytest.raises(ValidationError) as exc_info:
                ProductLink(name="Test Product", url=url)
            # Should fail validation
            assert exc_info.value is not None


class TestRecommendation:
    """Tests for the Recommendation model."""

    def test_recommendation_with_product(self):
        """Test creating a recommendation with a product link."""
        rec = Recommendation(
            title="Add a Humidifier",
            description="Increase humidity levels to reach optimal VPD range",
            priority="high",
            product=ProductLink(
                name="LEVOIT Humidifier",
                url="https://htgsupply.com/products/levoit-humidifier",
                price_range="$40-50"
            )
        )
        assert rec.title == "Add a Humidifier"
        assert rec.description == "Increase humidity levels to reach optimal VPD range"
        assert rec.priority == "high"
        assert rec.product is not None
        assert rec.product.name == "LEVOIT Humidifier"

    def test_recommendation_without_product(self):
        """Test that product is optional."""
        rec = Recommendation(
            title="Adjust Plant Spacing",
            description="Increase airflow by spacing plants further apart",
            priority="medium"
        )
        assert rec.title == "Adjust Plant Spacing"
        assert rec.priority == "medium"
        assert rec.product is None

    def test_recommendation_requires_title(self):
        """Test that title is required."""
        with pytest.raises(ValidationError) as exc_info:
            Recommendation(
                description="Test description",
                priority="low"
            )
        assert "title" in str(exc_info.value)

    def test_recommendation_requires_description(self):
        """Test that description is required."""
        with pytest.raises(ValidationError) as exc_info:
            Recommendation(
                title="Test Title",
                priority="low"
            )
        assert "description" in str(exc_info.value)

    def test_recommendation_requires_priority(self):
        """Test that priority is required."""
        with pytest.raises(ValidationError) as exc_info:
            Recommendation(
                title="Test Title",
                description="Test description"
            )
        assert "priority" in str(exc_info.value)

    def test_recommendation_priority_must_be_valid(self):
        """Test that priority must be high, medium, or low."""
        with pytest.raises(ValidationError) as exc_info:
            Recommendation(
                title="Test Title",
                description="Test description",
                priority="urgent"  # Invalid priority
            )
        assert "priority" in str(exc_info.value).lower()


class TestAnalysisResponse:
    """Tests for the AnalysisResponse model."""

    def test_analysis_response_with_two_recommendations(self):
        """Test creating an AnalysisResponse with 2 recommendations (minimum)."""
        response = AnalysisResponse(
            summary="Your VPD is slightly high for flowering stage.",
            recommendations=[
                Recommendation(
                    title="Add a Humidifier",
                    description="Increase humidity to reach optimal range",
                    priority="high",
                    product=ProductLink(
                        name="LEVOIT Humidifier",
                        url="https://htgsupply.com/products/levoit-humidifier"
                    )
                ),
                Recommendation(
                    title="Lower Temperature",
                    description="Reduce temperature by 2-3 degrees",
                    priority="medium"
                )
            ]
        )
        assert response.summary == "Your VPD is slightly high for flowering stage."
        assert len(response.recommendations) == 2
        assert response.recommendations[0].product is not None
        assert response.recommendations[1].product is None

    def test_analysis_response_with_three_recommendations(self):
        """Test creating an AnalysisResponse with 3 recommendations (maximum)."""
        response = AnalysisResponse(
            summary="Multiple adjustments needed for optimal VPD.",
            recommendations=[
                Recommendation(
                    title="Add a Humidifier",
                    description="Increase humidity",
                    priority="high",
                    product=ProductLink(name="LEVOIT", url="https://htgsupply.com/products/levoit")
                ),
                Recommendation(
                    title="Install Circulation Fan",
                    description="Improve airflow",
                    priority="medium",
                    product=ProductLink(name="AC Infinity", url="https://acinfinity.com/products/fan")
                ),
                Recommendation(
                    title="Adjust Plant Spacing",
                    description="Space plants further apart",
                    priority="low"
                )
            ]
        )
        assert len(response.recommendations) == 3

    def test_analysis_response_requires_summary(self):
        """Test that summary is required."""
        with pytest.raises(ValidationError) as exc_info:
            AnalysisResponse(
                recommendations=[
                    Recommendation(
                        title="Test",
                        description="Test",
                        priority="high",
                        product=ProductLink(name="Test", url="https://htgsupply.com/test")
                    ),
                    Recommendation(
                        title="Test 2",
                        description="Test 2",
                        priority="low"
                    )
                ]
            )
        assert "summary" in str(exc_info.value)

    def test_analysis_response_requires_minimum_two_recommendations(self):
        """Test that at least 2 recommendations are required."""
        with pytest.raises(ValidationError) as exc_info:
            AnalysisResponse(
                summary="Test summary",
                recommendations=[
                    Recommendation(
                        title="Single Recommendation",
                        description="Only one recommendation",
                        priority="high",
                        product=ProductLink(name="Test", url="https://test.com")
                    )
                ]
            )
        assert "recommendations" in str(exc_info.value).lower()

    def test_analysis_response_allows_maximum_three_recommendations(self):
        """Test that no more than 3 recommendations are allowed."""
        with pytest.raises(ValidationError) as exc_info:
            AnalysisResponse(
                summary="Test summary",
                recommendations=[
                    Recommendation(
                        title=f"Recommendation {i}",
                        description=f"Description {i}",
                        priority="high" if i == 0 else "medium",
                        product=ProductLink(name="Test", url="https://htgsupply.com/test") if i == 0 else None
                    )
                    for i in range(4)  # 4 recommendations - too many!
                ]
            )
        assert "recommendations" in str(exc_info.value).lower()

    def test_analysis_response_requires_at_least_one_product_link(self):
        """Test that at least one recommendation must include a product link."""
        with pytest.raises(ValidationError) as exc_info:
            AnalysisResponse(
                summary="Test summary",
                recommendations=[
                    Recommendation(
                        title="Recommendation 1",
                        description="No product",
                        priority="high"
                    ),
                    Recommendation(
                        title="Recommendation 2",
                        description="Also no product",
                        priority="medium"
                    )
                ]
            )
        assert "at least one recommendation must include a product link" in str(exc_info.value).lower()

    def test_analysis_response_valid_with_one_product_link(self):
        """Test that having exactly one product link is valid."""
        response = AnalysisResponse(
            summary="Test summary",
            recommendations=[
                Recommendation(
                    title="With Product",
                    description="Has a product link",
                    priority="high",
                    product=ProductLink(name="Test Product", url="https://htgsupply.com/test")
                ),
                Recommendation(
                    title="Without Product",
                    description="No product link",
                    priority="low"
                )
            ]
        )
        assert len(response.recommendations) == 2
        assert response.recommendations[0].product is not None
        assert response.recommendations[1].product is None

    def test_analysis_response_valid_with_multiple_product_links(self):
        """Test that having multiple product links is also valid."""
        response = AnalysisResponse(
            summary="Test summary",
            recommendations=[
                Recommendation(
                    title="First Product",
                    description="First recommendation",
                    priority="high",
                    product=ProductLink(name="Product 1", url="https://htgsupply.com/test1")
                ),
                Recommendation(
                    title="Second Product",
                    description="Second recommendation",
                    priority="medium",
                    product=ProductLink(name="Product 2", url="https://acinfinity.com/test2")
                )
            ]
        )
        assert len(response.recommendations) == 2
        assert all(rec.product is not None for rec in response.recommendations)
