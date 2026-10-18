from fastapi import APIRouter, Depends

from app.core.dependencies import require_role
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/dashboard")
def get_admin_dashboard(current_admin: User = Depends(require_role("admin"))):
    """Admin dashboard endpoint restricted to administrators."""
    return {
        "message": "Welcome to the admin dashboard",
        "admin_email": current_admin.email,
        "role": current_admin.role,
    }
