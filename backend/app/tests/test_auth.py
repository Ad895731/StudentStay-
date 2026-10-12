import uuid
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import verify_password
from app.main import app
from app.models.user import User

client = TestClient(app)


def test_user_registration_success():
    unique_email = f"student_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Aditya Sharma",
        "email": unique_email,
        "password": "strongPassword123",
        "role": "student"
    }

    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    data = response.json()
    assert data["name"] == payload["name"]
    assert data["email"] == payload["email"]
    assert data["role"] == payload["role"]
    assert "id" in data
    assert "created_at" in data


def test_user_registration_duplicate_email():
    unique_email = f"duplicate_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Rohan Verma",
        "email": unique_email,
        "password": "securePass456",
        "role": "student"
    }

    first_response = client.post("/auth/register", json=payload)
    assert first_response.status_code == 201

    duplicate_response = client.post("/auth/register", json=payload)
    assert duplicate_response.status_code == 400
    assert duplicate_response.json()["detail"] == "Email already registered"


def test_registration_does_not_expose_password():
    unique_email = f"safe_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Priya Patel",
        "email": unique_email,
        "password": "mySuperSecretPassword",
        "role": "owner"
    }

    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    data = response.json()
    assert "password" not in data
    assert "password_hash" not in data


def test_password_stored_as_hash_in_database():
    plain_password = "plainTextPassword789"
    unique_email = f"hashed_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Amit Kumar",
        "email": unique_email,
        "password": plain_password,
        "role": "student"
    }

    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    # Verify directly from database
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == unique_email))
        assert user is not None
        # Must not be stored as plain text
        assert user.password_hash != plain_password
        # Must be valid Argon2 hash that verifies with the plain password
        assert verify_password(plain_password, user.password_hash) is True
    finally:
        db.close()
