from typing import Literal
from pydantic import BaseModel, Field, field_validator


class ProductLink(BaseModel):
    """A product recommendation with purchase link."""
    name: str = Field(description="Product name")
    url: str = Field(description="URL to purchase the product (preferably Amazon)")
    price_range: str | None = Field(
        default=None,
        description="Estimated price range (e.g., '$40-50')"
    )


class Recommendation(BaseModel):
    """A single actionable recommendation for grow optimization."""
    title: str = Field(description="Short, actionable title for the recommendation")
    description: str = Field(
        description="Detailed explanation of the recommendation and why it helps"
    )
    priority: Literal["high", "medium", "low"] = Field(
        description="Priority level based on impact on plant health"
    )
    product: ProductLink | None = Field(
        default=None,
        description="Optional product recommendation to implement this suggestion"
    )


class AnalysisResponse(BaseModel):
    """Complete analysis response with summary and recommendations."""
    summary: str = Field(
        description="Brief overview of the current environmental conditions and main issues"
    )
    recommendations: list[Recommendation] = Field(
        min_length=2,
        max_length=3,
        description="Between 2-3 actionable recommendations"
    )

    @field_validator("recommendations")
    @classmethod
    def must_have_at_least_one_product(cls, recommendations: list[Recommendation]) -> list[Recommendation]:
        """Ensure at least one recommendation includes a product link."""
        if not any(rec.product is not None for rec in recommendations):
            raise ValueError("At least one recommendation must include a product link")
        return recommendations
