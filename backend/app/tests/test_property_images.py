import io
from unittest.mock import MagicMock, patch
import uuid
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.property import Property, PropertyImage
from app.models.user import User

client = TestClient(app)

# Valid image headers for testing
VALID_JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00test-jpeg-body"
VALID_PNG_BYTES = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRtest-png-body"
VALID_WEBP_BYTES = b"RIFF\x1a\x00\x00\x00WEBPVP8 \x0e\x00\x00\x00test-webp-body"


def create_user(role: str = "owner") -> tuple[User, str]:
    db = SessionLocal()
    try:
        user = User(
            name=f"Image Test {role.capitalize()}",
            email=f"{role}_{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password("password123"),
            role=role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        token = create_access_token(user.id)
        return user, token
    finally:
        db.close()


def create_property(owner_id: int) -> Property:
    db = SessionLocal()
    try:
        prop = Property(
            owner_id=owner_id,
            title="Image Test Property",
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
# 1. UPLOAD TESTS
# -------------------------------------------------------------

def test_owner_can_upload_property_image():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    with patch("app.routers.properties.upload_property_image") as mock_upload:
        mock_upload.return_value = {
            "storage_path": f"properties/{prop.id}/mock-uuid.jpg",
            "public_url": f"https://mock.supabase.co/storage/v1/object/public/property-images/properties/{prop.id}/mock-uuid.jpg",
        }

        response = client.post(
            f"/properties/{prop.id}/images",
            files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 201
    data = response.json()
    assert data["property_id"] == prop.id
    assert "mock-uuid.jpg" in data["storage_path"]
    assert "https://mock.supabase.co/" in data["image_url"]
    assert "id" in data

    # Verify property detail includes the new image
    res_detail = client.get(f"/properties/{prop.id}")
    assert res_detail.status_code == 200
    images = res_detail.json()["images"]
    assert any(img["id"] == data["id"] for img in images)


def test_admin_can_upload_property_image():
    owner, _ = create_user("owner")
    _, admin_token = create_user("admin")
    prop = create_property(owner.id)

    with patch("app.routers.properties.upload_property_image") as mock_upload:
        mock_upload.return_value = {
            "storage_path": f"properties/{prop.id}/admin-upload.png",
            "public_url": f"https://mock.supabase.co/storage/v1/object/public/property-images/properties/{prop.id}/admin-upload.png",
        }

        response = client.post(
            f"/properties/{prop.id}/images",
            files={"file": ("photo.png", io.BytesIO(VALID_PNG_BYTES), "image/png")},
            headers={"Authorization": f"Bearer {admin_token}"},
        )

    assert response.status_code == 201
    assert response.json()["property_id"] == prop.id


def test_unauthenticated_upload_rejected():
    owner, _ = create_user("owner")
    prop = create_property(owner.id)

    response = client.post(
        f"/properties/{prop.id}/images",
        files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
    )
    assert response.status_code == 401


def test_student_upload_rejected():
    owner, _ = create_user("owner")
    _, student_token = create_user("student")
    prop = create_property(owner.id)

    response = client.post(
        f"/properties/{prop.id}/images",
        files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert response.status_code == 403


def test_another_owner_upload_rejected():
    owner_a, _ = create_user("owner")
    _, token_b = create_user("owner")
    prop_a = create_property(owner_a.id)

    response = client.post(
        f"/properties/{prop_a.id}/images",
        files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert response.status_code == 403
    assert "Not authorized" in response.json()["detail"]


def test_upload_to_missing_property_returns_404():
    _, token = create_user("owner")

    response = client.post(
        "/properties/999999/images",
        files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Property not found"


def test_upload_invalid_image_content_rejected():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    # Text content disguised as image
    fake_image_bytes = b"This is plain text disguised as an image file."
    response = client.post(
        f"/properties/{prop.id}/images",
        files={"file": ("fake.jpg", io.BytesIO(fake_image_bytes), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 400
    assert "Invalid image content" in response.json()["detail"]


def test_upload_oversized_image_rejected():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    # Valid JPEG header followed by > 5 MB of data
    oversized_bytes = VALID_JPEG_BYTES + b"0" * (5 * 1024 * 1024)
    response = client.post(
        f"/properties/{prop.id}/images",
        files={"file": ("large.jpg", io.BytesIO(oversized_bytes), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 400
    assert "exceeds maximum allowed limit" in response.json()["detail"]


# -------------------------------------------------------------
# 2. DELETE TESTS
# -------------------------------------------------------------

def test_owner_can_delete_property_image():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    db = SessionLocal()
    try:
        img = PropertyImage(
            property_id=prop.id,
            image_url="https://mock.supabase.co/storage/v1/object/public/property-images/prop.jpg",
            storage_path=f"properties/{prop.id}/to-delete.jpg",
        )
        db.add(img)
        db.commit()
        db.refresh(img)
        img_id = img.id
        img_path = img.storage_path
    finally:
        db.close()

    with patch("app.routers.properties.delete_property_image") as mock_delete:
        response = client.delete(
            f"/properties/{prop.id}/images/{img_id}",
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 204
    mock_delete.assert_called_once_with(img_path)

    # Verify record is deleted from PostgreSQL
    db = SessionLocal()
    try:
        assert db.scalar(select(PropertyImage).where(PropertyImage.id == img_id)) is None
    finally:
        db.close()


def test_unauthorized_delete_rejected():
    owner, _ = create_user("owner")
    _, other_token = create_user("owner")
    prop = create_property(owner.id)

    db = SessionLocal()
    try:
        img = PropertyImage(
            property_id=prop.id,
            image_url="https://mock.supabase.co/img.jpg",
            storage_path=f"properties/{prop.id}/img.jpg",
        )
        db.add(img)
        db.commit()
        db.refresh(img)
        img_id = img.id
    finally:
        db.close()

    # Another owner cannot delete
    res_other = client.delete(
        f"/properties/{prop.id}/images/{img_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert res_other.status_code == 403

    # Unauthenticated user cannot delete
    res_unauth = client.delete(f"/properties/{prop.id}/images/{img_id}")
    assert res_unauth.status_code == 401


def test_delete_property_image_mismatch_returns_404():
    owner, token = create_user("owner")
    prop1 = create_property(owner.id)
    prop2 = create_property(owner.id)

    db = SessionLocal()
    try:
        img = PropertyImage(
            property_id=prop1.id,
            image_url="https://mock.supabase.co/prop1.jpg",
            storage_path=f"properties/{prop1.id}/prop1.jpg",
        )
        db.add(img)
        db.commit()
        db.refresh(img)
        img_id = img.id
    finally:
        db.close()

    # Request to delete from prop2 when image belongs to prop1 -> 404
    response = client.delete(
        f"/properties/{prop2.id}/images/{img_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
    assert "does not belong" in response.json()["detail"]


def test_delete_nonexistent_image_returns_404():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    response = client.delete(
        f"/properties/{prop.id}/images/999999",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Image not found"


# -------------------------------------------------------------
# 3. FAILURE HANDLING & ORPHAN CLEANUP
# -------------------------------------------------------------

def test_storage_upload_failure_returns_500():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    with patch("app.routers.properties.upload_property_image", side_effect=Exception("S3 network timeout")):
        response = client.post(
            f"/properties/{prop.id}/images",
            files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 500
    assert "Storage upload failed" in response.json()["detail"]


def test_database_failure_cleans_up_uploaded_storage_file():
    owner, token = create_user("owner")
    prop = create_property(owner.id)

    mock_storage_path = f"properties/{prop.id}/rollback-test.jpg"

    with patch("app.routers.properties.upload_property_image") as mock_upload, \
         patch("app.routers.properties.save_property_image_record", side_effect=Exception("Database lock error")), \
         patch("app.routers.properties.delete_property_image") as mock_delete:

        mock_upload.return_value = {
            "storage_path": mock_storage_path,
            "public_url": f"https://mock.supabase.co/{mock_storage_path}",
        }

        response = client.post(
            f"/properties/{prop.id}/images",
            files={"file": ("photo.jpg", io.BytesIO(VALID_JPEG_BYTES), "image/jpeg")},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 500
    assert "Database persistence failed" in response.json()["detail"]
    # Verify cleanup of the orphaned storage object was triggered
    mock_delete.assert_called_once_with(mock_storage_path)
