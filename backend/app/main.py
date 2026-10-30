from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers import (
    admin_router,
    auth_router,
    favorites_router,
    health_router,
    inquiries_router,
    properties_router,
    reviews_router,
)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API for StudentStay accommodation discovery platform"
)

# Configure CORS for frontend access (Flutter web, mobile, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(properties_router)
app.include_router(favorites_router)
app.include_router(inquiries_router)
app.include_router(reviews_router)


@app.get("/")
def root():
    return {
        "message": "Welcome to StudentStay API",
        "docs": "/docs",
        "health": "/health"
    }
