from unittest.mock import MagicMock, patch
import uuid
import pytest
from sqlalchemy import select

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.property import Property, PropertyImage
from app.models.user import User
from app.services.storage import (
    ALLOWED_MIME_TYPES,
    MAX_FILE_SIZE_BYTES,
    delete_property_image,
    delete_property_image_record,
    generate_storage_path,
    get_supabase_client,
    save_property_image_record,
    upload_property_image,
    validate_image_file,
)


def create_test_property() -> Property:
    db = SessionLocal()
    try:
        user = User(
            name="Storage Test Owner",
            email=f"owner_{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password("securePassword123"),
            role="owner",
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        prop = Property(
            owner_id=user.id,
            title="Storage Test Property",
            property_type="pg",
            address="12 MG Road",
            city="Pune",
            latitude=18.5204,
            longitude=73.8567,
            is_verified=True,
            is_available=True,
        )
        db.add(prop)
        db.commit()
        db.refresh(prop)
        return prop
    finally:
        db.close()


# -------------------------------------------------------------
# 1. Validation Tests
# -------------------------------------------------------------

def test_validate_image_file_valid_types():
    valid_samples = {
        "image/jpeg": b"\xff\xd8\xff\xe0\x00\x10JFIFvalid-jpeg",
        "image/png": b"\x89PNG\r\n\x1a\nvalid-png-data",
        "image/webp": b"RIFF\x00\x00\x00\x00WEBPVP8 valid-webp",
    }
    for mime_type, data in valid_samples.items():
        detected = validate_image_file(data, mime_type)
        assert detected == mime_type


def test_validate_image_file_invalid_type():
    # Random text or invalid magic bytes
    dummy_bytes = b"fake-plain-text-file-content"
    with pytest.raises(ValueError, match="Invalid image content"):
        validate_image_file(dummy_bytes, "image/jpeg")


def test_validate_image_file_empty_bytes():
    with pytest.raises(ValueError, match="Image file is empty"):
        validate_image_file(b"", "image/jpeg")


def test_validate_image_file_size_exceeded():
    # 5 MB + 1 byte with valid JPEG magic bytes
    oversized_bytes = b"\xff\xd8\xff" + b"x" * MAX_FILE_SIZE_BYTES
    with pytest.raises(ValueError, match="File size .* exceeds maximum allowed limit"):
        validate_image_file(oversized_bytes, "image/jpeg")


# -------------------------------------------------------------
# 2. Path Generation Tests
# -------------------------------------------------------------

def test_generate_storage_path_unique_and_untrusted():
    property_id = 42

    path_jpeg = generate_storage_path(property_id, "image/jpeg")
    path_png = generate_storage_path(property_id, "image/png")
    path_webp = generate_storage_path(property_id, "image/webp")

    assert path_jpeg.startswith("properties/42/")
    assert path_jpeg.endswith(".jpg")

    assert path_png.startswith("properties/42/")
    assert path_png.endswith(".png")

    assert path_webp.startswith("properties/42/")
    assert path_webp.endswith(".webp")

    # Successive calls must generate unique random UUID paths
    path1 = generate_storage_path(property_id, "image/jpeg")
    path2 = generate_storage_path(property_id, "image/jpeg")
    assert path1 != path2


# -------------------------------------------------------------
# 3. Client Initialization Tests
# -------------------------------------------------------------

def test_get_supabase_client_missing_credentials():
    with patch.object(settings, "SUPABASE_URL", ""):
        with patch.object(settings, "SUPABASE_SECRET_KEY", ""):
            with pytest.raises(RuntimeError, match="Supabase credentials not configured"):
                get_supabase_client()


def test_get_supabase_client_configured():
    with patch.object(settings, "SUPABASE_URL", "https://mock-proj.supabase.co"):
        with patch.object(settings, "SUPABASE_SECRET_KEY", "mock-service-key-123"):
            client = get_supabase_client()
            assert client is not None


# -------------------------------------------------------------
# 4. Mocked Storage Upload & Delete Operations
# -------------------------------------------------------------

def test_upload_property_image_mocked():
    mock_client = MagicMock()
    mock_bucket = MagicMock()
    mock_client.storage.from_.return_value = mock_bucket
    mock_bucket.get_public_url.return_value = (
        "https://mock-proj.supabase.co/storage/v1/object/public/property-images/properties/10/mock.jpg"
    )

    image_data = b"\xff\xd8\xff\xe0test-jpeg-content"
    result = upload_property_image(
        property_id=10,
        file_bytes=image_data,
        content_type="image/jpeg",
        bucket_name="property-images",
        client=mock_client,
    )

    # Verify upload was called with correct bucket, path, and options
    mock_client.storage.from_.assert_called_with("property-images")
    mock_bucket.upload.assert_called_once()
    call_kwargs = mock_bucket.upload.call_args.kwargs
    assert call_kwargs["path"].startswith("properties/10/")
    assert call_kwargs["path"].endswith(".jpg")
    assert call_kwargs["file"] == image_data
    assert call_kwargs["file_options"] == {"content-type": "image/jpeg", "upsert": "false"}

    assert result["public_url"].startswith("https://mock-proj.supabase.co/")
    assert result["storage_path"] == call_kwargs["path"]


def test_delete_property_image_mocked():
    mock_client = MagicMock()
    mock_bucket = MagicMock()
    mock_client.storage.from_.return_value = mock_bucket

    storage_path = "properties/10/some-unique-uuid.jpg"
    success = delete_property_image(
        storage_path=storage_path,
        bucket_name="property-images",
        client=mock_client,
    )

    assert success is True
    mock_client.storage.from_.assert_called_with("property-images")
    mock_bucket.remove.assert_called_once_with([storage_path])


# -------------------------------------------------------------
# 5. Database Metadata Persistence Tests
# -------------------------------------------------------------

def test_property_image_metadata_persistence_and_deletion():
    prop = create_test_property()
    db = SessionLocal()
    try:
        sample_url = (
            f"https://example.supabase.co/storage/v1/object/public/property-images/properties/{prop.id}/photo.jpg"
        )
        image_record = save_property_image_record(
            db=db,
            property_id=prop.id,
            image_url=sample_url,
        )

        assert image_record.id is not None
        assert image_record.property_id == prop.id
        assert image_record.image_url == sample_url

        # Query back from DB
        fetched = db.scalar(
            select(PropertyImage).where(PropertyImage.id == image_record.id)
        )
        assert fetched is not None
        assert fetched.image_url == sample_url

        # Delete image record
        delete_success = delete_property_image_record(db=db, image_id=image_record.id)
        assert delete_success is True

        # Ensure record no longer exists
        deleted_record = db.scalar(
            select(PropertyImage).where(PropertyImage.id == image_record.id)
        )
        assert deleted_record is None
    finally:
        db.close()
