from fastapi import FastAPI
from app.core.config import settings
from app.routers import health_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API for StudentStay accommodation discovery platform"
)

# Include routers
app.include_router(health_router)


@app.get("/")
def root():
    return {
        "message": "Welcome to StudentStay API",
        "docs": "/docs",
        "health": "/health"
    }
