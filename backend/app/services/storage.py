from datetime import datetime, timezone
import uuid
from sqlalchemy import select
from sqlalchemy.orm import Session
from supabase import Client, create_client

from app.core.config import settings
from app.models.property import PropertyImage

# Bucket configuration and constraints
DEFAULT_BUCKET = "property-images"
MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB

ALLOWED_MIME_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


def get_supabase_client() -> Client:
    """Initialize and return a Supabase Client using backend credentials.
    
    Raises RuntimeError if credentials are not configured in environment.
    """
    if not settings.SUPABASE_URL or not settings.SUPABASE_SECRET_KEY:
        raise RuntimeError(
            "Supabase credentials not configured. Please set SUPABASE_URL "
            "and SUPABASE_SECRET_KEY environment variables."
        )
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SECRET_KEY)


def detect_image_content_type(file_bytes: bytes) -> str | None:
    """Inspect actual magic bytes to determine image MIME type.
    
    Supports JPEG, PNG, and WebP.
    """
    if len(file_bytes) >= 3 and file_bytes[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if len(file_bytes) >= 8 and file_bytes[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(file_bytes) >= 12 and file_bytes[:4] == b"RIFF" and file_bytes[8:12] == b"WEBP":
        return "image/webp"
    return None


def validate_image_file(file_bytes: bytes, content_type: str | None = None) -> str:
    """Validate actual image content, MIME type, and file size.
    
    Returns the verified MIME type.
    Raises ValueError on validation failure.
    """
    if not file_bytes:
        raise ValueError("Image file is empty.")

    if len(file_bytes) > MAX_FILE_SIZE_BYTES:
        max_mb = MAX_FILE_SIZE_BYTES / (1024 * 1024)
        size_mb = len(file_bytes) / (1024 * 1024)
        raise ValueError(
            f"File size ({size_mb:.2f} MB) exceeds maximum allowed limit of {max_mb:.0f} MB."
        )

    detected_mime = detect_image_content_type(file_bytes)
    if detected_mime is None:
        allowed = ", ".join(sorted(ALLOWED_MIME_TYPES.keys()))
        raise ValueError(
            f"Invalid image content. Only {allowed} formats are supported."
        )

    if content_type:
        normalized_mime = content_type.strip().lower()
        if normalized_mime in ALLOWED_MIME_TYPES and normalized_mime != detected_mime:
            raise ValueError(
                f"Supplied MIME type '{content_type}' does not match detected content '{detected_mime}'."
            )

    return detected_mime


def generate_storage_path(property_id: int, content_type: str) -> str:
    """Generate a unique, server-controlled storage path.
    
    Format: properties/{property_id}/{uuid4}.{ext}
    Client-supplied filenames are never used.
    """
    normalized_mime = content_type.strip().lower()
    extension = ALLOWED_MIME_TYPES.get(normalized_mime, ".jpg")
    unique_id = uuid.uuid4().hex
    return f"properties/{property_id}/{unique_id}{extension}"


def upload_property_image(
    property_id: int,
    file_bytes: bytes,
    content_type: str,
    bucket_name: str | None = None,
    client: Client | None = None,
) -> dict[str, str]:
    """Validate and upload an image to Supabase Storage bucket.
    
    Returns a dictionary containing storage_path and public_url.
    """
    validate_image_file(file_bytes, content_type)
    storage_path = generate_storage_path(property_id, content_type)
    bucket = bucket_name or settings.SUPABASE_STORAGE_BUCKET or DEFAULT_BUCKET
    storage_client = client or get_supabase_client()

    storage_client.storage.from_(bucket).upload(
        path=storage_path,
        file=file_bytes,
        file_options={"content-type": content_type, "upsert": "false"},
    )

    public_url = storage_client.storage.from_(bucket).get_public_url(storage_path)

    return {
        "storage_path": storage_path,
        "public_url": public_url,
    }


def delete_property_image(
    storage_path: str,
    bucket_name: str | None = None,
    client: Client | None = None,
) -> bool:
    """Delete an image object from the Supabase Storage bucket."""
    bucket = bucket_name or settings.SUPABASE_STORAGE_BUCKET or DEFAULT_BUCKET
    storage_client = client or get_supabase_client()

    storage_client.storage.from_(bucket).remove([storage_path])
    return True


# -------------------------------------------------------------
# Database Metadata Helpers for PropertyImage Model
# -------------------------------------------------------------

def save_property_image_record(
    db: Session,
    property_id: int,
    image_url: str,
    storage_path: str = "",
) -> PropertyImage:
    """Persist image metadata, storage path, and public URL to PostgreSQL database."""
    image_record = PropertyImage(
        property_id=property_id,
        image_url=image_url,
        storage_path=storage_path,
    )
    db.add(image_record)
    db.commit()
    db.refresh(image_record)
    return image_record


def delete_property_image_record(
    db: Session,
    image_id: int,
) -> bool:
    """Remove image record from PostgreSQL database."""
    record = db.scalar(select(PropertyImage).where(PropertyImage.id == image_id))
    if not record:
        return False
    db.delete(record)
    db.commit()
    return True
