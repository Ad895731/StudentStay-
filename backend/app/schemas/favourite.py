from datetime import datetime
from pydantic import BaseModel, ConfigDict
from app.schemas.property import PropertyResponse

class FavoriteResponse(BaseModel):
    id: int
    user_id: int
    property_id: int
    created_at: datetime
    property: PropertyResponse
    model_config = ConfigDict(from_attributes=True)

class FavoriteToggleResponse(BaseModel):
    property_id: int
    is_favorite: bool
    message: str