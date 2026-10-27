from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field


class AmenityResponse(BaseModel):
    id: int
    name: str

    model_config = ConfigDict(from_attributes=True)


class RoomResponse(BaseModel):
    id: int
    property_id: int
    sharing_type: str
    monthly_rent: Decimal
    available_beds: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PropertyImageResponse(BaseModel):
    id: int
    property_id: int
    image_url: str
    storage_path: str = ""
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PropertyBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = None
    property_type: str = Field(..., min_length=1, max_length=50)
    address: str = Field(..., min_length=1, max_length=255)
    city: str = Field(..., min_length=1, max_length=100)
    latitude: float | None = Field(None, ge=-90.0, le=90.0)
    longitude: float | None = Field(None, ge=-180.0, le=180.0)
    security_deposit: Decimal | None = Field(None, ge=Decimal("0.00"))


class PropertyCreate(PropertyBase):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)

    model_config = ConfigDict(extra="forbid")


class PropertyUpdate(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    property_type: str | None = Field(None, min_length=1, max_length=50)
    address: str | None = Field(None, min_length=1, max_length=255)
    city: str | None = Field(None, min_length=1, max_length=100)
    latitude: float | None = Field(None, ge=-90.0, le=90.0)
    longitude: float | None = Field(None, ge=-180.0, le=180.0)
    security_deposit: Decimal | None = Field(None, ge=Decimal("0.00"))
    is_available: bool | None = None

    model_config = ConfigDict(extra="forbid")


class PropertyResponse(PropertyBase):
    id: int
    owner_id: int
    is_verified: bool
    is_available: bool
    distance_km: float | None = None
    created_at: datetime
    updated_at: datetime
    images: list[PropertyImageResponse] = []

    model_config = ConfigDict(from_attributes=True)


class PropertyDetailResponse(PropertyResponse):
    rooms: list[RoomResponse] = []
    amenities: list[AmenityResponse] = []
    images: list[PropertyImageResponse] = []

    model_config = ConfigDict(from_attributes=True)


class PropertyListResponse(BaseModel):
    items: list[PropertyResponse]
    page: int
    page_size: int
    total: int


class RoomCreate(BaseModel):
    sharing_type: str = Field(..., min_length=1, max_length=50) # e.g. "single", "double", "triple"
    monthly_rent: Decimal = Field(..., ge=Decimal("0.00"))
    available_beds: int = Field(..., ge=0)

    model_config = ConfigDict(extra="forbid")


class PropertyAmenitiesUpdate(BaseModel):
    amenity_ids: list[int]

    model_config = ConfigDict(extra="forbid")
