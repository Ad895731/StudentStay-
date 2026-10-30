from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class StudentReviewer(BaseModel):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)


class ReviewCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comment: str = Field(..., min_length=3, max_length=1500)

    model_config = ConfigDict(extra="forbid")


class ReviewResponse(BaseModel):
    id: int
    property_id: int
    student_id: int
    rating: int
    comment: str
    created_at: datetime
    updated_at: datetime
    student: StudentReviewer

    model_config = ConfigDict(from_attributes=True)


class PropertyRatingSummary(BaseModel):
    average_rating: float
    total_reviews: int
