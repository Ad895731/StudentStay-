from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.favourite import Favourite
from app.models.property import Property
from app.models.user import User
from app.schemas.favourite import FavoriteResponse, FavoriteToggleResponse

router = APIRouter(prefix="/favorites", tags=["Favorites"])
@router.post("/{property_id}/toggle", response_model=FavoriteToggleResponse)
def toggle_favorite(
    property_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):

# 1. Check property exist karti hai ya nahi
    prop = db.scalar(select(Property).where(Property.id == property_id))
    if not prop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found"
        )

        # 2. Check agar pehle se favorite hai
    stmt = select(Favourite).where(
        Favourite.user_id == current_user.id,
        Favourite.property_id == property_id
    )
    fav = db.scalar(stmt)
    if fav:
        # Already favorited -> remove karo
        db.delete(fav)
        db.commit()
        return FavoriteToggleResponse(
            property_id=property_id,
            is_favorite=False,
            message="Property removed from favorites"
        )
    else:
        # Not favorited -> add karo
        new_fav = Favourite(user_id=current_user.id, property_id=property_id)
        db.add(new_fav)
        db.commit()
        return FavoriteToggleResponse(
            property_id=property_id,
            is_favorite=True,
            message="Property added to favorites"
        )

@router.get("/my", response_model=list[FavoriteResponse])
def get_my_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Fetch all properties shortlisted/saved by current user."""
    stmt = (
        select(Favourite)
        .options(
            selectinload(Favourite.property).selectinload(Property.images)
        )
        .where(Favourite.user_id == current_user.id)
        .order_by(Favourite.created_at.desc())
    )
    return db.scalars(stmt).all()
@router.get("/check/{property_id}")
def check_is_favorite(
    property_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Check if specific property is favorited by current user."""
    stmt = select(Favourite).where(
        Favourite.user_id == current_user.id,
        Favourite.property_id == property_id
    )
    fav = db.scalar(stmt)
    return {"is_favorite": fav is not None}