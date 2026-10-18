"""API routers package."""
from app.routers.admin import router as admin_router
from app.routers.auth import router as auth_router
from app.routers.health import router as health_router
from app.routers.properties import router as properties_router

__all__ = ["admin_router", "auth_router", "health_router", "properties_router"]
