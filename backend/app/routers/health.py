from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/health")
def get_health():
    """Health check endpoint confirming that the backend service is running."""
    return {
        "status": "healthy",
        "service": "StudentStay Backend",
        "version": "0.1.0"
    }
