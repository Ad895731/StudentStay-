from app.models import Property
from fastapi import APIRouter, Depends ,HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import require_role
from app.models.user import User


router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/dashboard")
def get_admin_dashboard(current_admin: User = Depends(require_role("admin"))):
    """Admin dashboard endpoint restricted to administrators."""
    # admin operation ke liye code bna rakha hai 
    return {
        "message": "Welcome to the admin dashboard",
        "admin_email": current_admin.email,
        "role": current_admin.role,
    }
    
#abhi tk jin property ko admin ne verify nhi kiya hai 
@router.get("/properties/pending")
def get_pending_properties(current_admin: User = Depends(require_role("admin")), db : Session = Depends(get_db)):
    """Admin endpoint to fetch properties which are not approved by admin."""
    stmt = (select(Property).options(
        selectinload(Property.rooms), 
        selectinload(Property.images)).where(
            Property.is_verified.is_(False)).order_by(Property.created_at.desc())
            )
    pending_properties = db.scalars(stmt).all()
    
    return {
        "message": "Pending properties endpoint",
        "pending_properties":pending_properties
    }

@router.patch("/properties/{property_id}/verify")
def verify_property( property_id: int , current_admin : User = Depends(require_role("admin")),db:Session = Depends(get_db),):
    """admin endpoint property ko verify krne ke liye"""
    stmt = select(Property).where (Property.id==property_id)
    property_obj = db.scalar(stmt)
    if not property_obj:
        raise HTTPException(status_code = status.HTTP_404_NOT_FOUND, detail = "Property not found")
    property_obj.is_verified = True
    db.commit()
    db.refresh(property_obj)
    return {
        "message":"Property verified successfully",
        "property_id" : property_id,
        "is_verified":property_obj.is_verified,
    }
    
