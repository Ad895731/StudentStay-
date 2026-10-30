from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
from app.schemas.property import PropertyResponse


class UserSummary(BaseModel):
    id: int
    name: str
    email: str

    model_config = ConfigDict(from_attributes=True)


class InquiryCreate(BaseModel):
    property_id: int
    visit_date: datetime
    sharing_preference: str = Field("any", min_length=1, max_length=50)
    contact_phone: str = Field(..., min_length=7, max_length=20)
    message: str | None = Field(None, max_length=1000)

    model_config = ConfigDict(extra="forbid")


class InquiryStatusUpdate(BaseModel):
    status: str = Field(..., pattern="^(confirmed|rejected|completed)$")

    model_config = ConfigDict(extra="forbid")


class InquiryResponse(BaseModel):
    id: int
    property_id: int
    student_id: int
    owner_id: int
    visit_date: datetime
    sharing_preference: str
    contact_phone: str
    message: str | None
    status: str
    created_at: datetime
    updated_at: datetime
    property: PropertyResponse
    student: UserSummary

    model_config = ConfigDict(from_attributes=True)

