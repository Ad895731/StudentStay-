from datetime import timedelta
import uuid
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import create_access_token, hash_password, verify_password
from app.main import app
from app.models.user import User

client = TestClient(app)


def test_user_registration_success():
    unique_email = f"student_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Aditya Sharma",
        "email": unique_email,
        "password": "strongPassword123",
    }

    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    data = response.json()
    assert data["name"] == payload["name"]
    assert data["email"] == payload["email"]
    assert data["role"] == "student"
    assert "id" in data
    assert "created_at" in data


def test_public_registration_creates_student_account():
    unique_email = f"student_default_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Default Student",
        "email": unique_email,
        "password": "strongPassword123",
    }

    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    data = response.json()
    assert data["role"] == "student"

    # Verify directly in the database
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == unique_email))
        assert user is not None
        assert user.role == "student"
    finally:
        db.close()


def test_public_registration_cannot_create_admin_account():
    unique_email = f"fake_admin_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Fake Admin",
        "email": unique_email,
        "password": "strongPassword123",
        "role": "admin",
    }

    # Public registration must ignore/not trust client-provided role
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    data = response.json()
    assert data["role"] == "student"
    assert data["role"] != "admin"

    # Confirm database does not store admin role
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == unique_email))
        assert user is not None
        assert user.role == "student"
        assert user.role != "admin"
    finally:
        db.close()


def test_user_registration_duplicate_email():
    unique_email = f"duplicate_{uuid.uuid4().hex[:8]}@example.com"
    payload = {
        "name": "Rohan Verma",
        "email": unique_email,
        "password": "securePass456",
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
    }

    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201

    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == unique_email))
        assert user is not None
        assert user.password_hash != plain_password
        assert verify_password(plain_password, user.password_hash) is True
    finally:
        db.close()


def test_login_success():
    email = f"login_success_{uuid.uuid4().hex[:8]}@example.com"
    password = "validPassword123"
    register_payload = {
        "name": "Login User",
        "email": email,
        "password": password,
    }
    reg_response = client.post("/auth/register", json=register_payload)
    assert reg_response.status_code == 201

    login_response = client.post(
        "/auth/login",
        json={"email": email, "password": password},
    )
    assert login_response.status_code == 200

    token_data = login_response.json()
    assert "access_token" in token_data
    assert token_data["token_type"] == "bearer"
    assert "password" not in token_data
    assert "password_hash" not in token_data


def test_login_incorrect_password():
    email = f"login_wrong_pw_{uuid.uuid4().hex[:8]}@example.com"
    register_payload = {
        "name": "Wrong Password User",
        "email": email,
        "password": "correctPassword123",
    }
    client.post("/auth/register", json=register_payload)

    login_response = client.post(
        "/auth/login",
        json={"email": email, "password": "wrongPassword321"},
    )
    assert login_response.status_code == 401
    assert login_response.json()["detail"] == "Invalid email or password"


def test_login_unknown_email():
    unknown_email = f"unknown_{uuid.uuid4().hex[:8]}@example.com"
    login_response = client.post(
        "/auth/login",
        json={"email": unknown_email, "password": "somePassword123"},
    )
    assert login_response.status_code == 401
    assert login_response.json()["detail"] == "Invalid email or password"


def test_get_me_success():
    email = f"me_success_{uuid.uuid4().hex[:8]}@example.com"
    password = "userPassword456"
    register_payload = {
        "name": "Me User",
        "email": email,
        "password": password,
    }
    reg_response = client.post("/auth/register", json=register_payload)
    assert reg_response.status_code == 201

    login_response = client.post(
        "/auth/login",
        json={"email": email, "password": password},
    )
    assert login_response.status_code == 200
    token = login_response.json()["access_token"]

    me_response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me_response.status_code == 200
    me_data = me_response.json()
    assert me_data["email"] == email
    assert me_data["name"] == "Me User"
    assert me_data["role"] == "student"
    assert "id" in me_data
    assert "created_at" in me_data
    assert "password" not in me_data
    assert "password_hash" not in me_data


def test_get_me_without_token():
    response = client.get("/auth/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Not authenticated"


def test_get_me_invalid_token():
    response = client.get(
        "/auth/me",
        headers={"Authorization": "Bearer invalid.token.value"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired token"


def test_get_me_expired_token():
    email = f"expired_{uuid.uuid4().hex[:8]}@example.com"
    register_payload = {
        "name": "Expired User",
        "email": email,
        "password": "userPassword456",
    }
    reg_response = client.post("/auth/register", json=register_payload)
    user_id = reg_response.json()["id"]

    # Generate an already-expired token (-10 seconds)
    expired_token = create_access_token(
        subject=user_id,
        expires_delta=timedelta(seconds=-10),
    )

    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {expired_token}"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired token"


def test_password_hash_never_returned():
    email = f"no_hash_{uuid.uuid4().hex[:8]}@example.com"
    password = "secretPassword789"
    reg_payload = {
        "name": "No Hash User",
        "email": email,
        "password": password,
    }
    reg_res = client.post("/auth/register", json=reg_payload)
    assert "password_hash" not in reg_res.json()

    login_res = client.post(
        "/auth/login",
        json={"email": email, "password": password},
    )
    assert "password_hash" not in login_res.json()

    token = login_res.json()["access_token"]
    me_res = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert "password_hash" not in me_res.json()


def test_student_cannot_access_admin_dashboard():
    # Register student account
    email = f"student_user_{uuid.uuid4().hex[:8]}@example.com"
    password = "studentPassword123"
    reg_res = client.post("/auth/register", json={
        "name": "Student User",
        "email": email,
        "password": password,
    })
    assert reg_res.status_code == 201

    # Login to obtain student JWT
    login_res = client.post("/auth/login", json={
        "email": email,
        "password": password,
    })
    token = login_res.json()["access_token"]

    # Attempt to access admin dashboard
    admin_res = client.get(
        "/admin/dashboard",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert admin_res.status_code == 403
    assert admin_res.json()["detail"] == "Operation not permitted"


def test_admin_can_access_admin_dashboard():
    # Safely create an admin account directly in test database
    admin_email = f"admin_user_{uuid.uuid4().hex[:8]}@example.com"
    admin_password = "adminPassword123"
    db = SessionLocal()
    try:
        admin_user = User(
            name="Super Admin",
            email=admin_email,
            password_hash=hash_password(admin_password),
            role="admin",
        )
        db.add(admin_user)
        db.commit()
    finally:
        db.close()

    # Login as admin
    login_res = client.post("/auth/login", json={
        "email": admin_email,
        "password": admin_password,
    })
    assert login_res.status_code == 200
    admin_token = login_res.json()["access_token"]

    # Access admin dashboard
    admin_res = client.get(
        "/admin/dashboard",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert admin_res.status_code == 200
    data = admin_res.json()
    assert data["message"] == "Welcome to the admin dashboard"
    assert data["admin_email"] == admin_email
    assert data["role"] == "admin"


def test_admin_dashboard_missing_or_invalid_jwt_rejected():
    # Missing token -> 401
    res_missing = client.get("/admin/dashboard")
    assert res_missing.status_code == 401
    assert res_missing.json()["detail"] == "Not authenticated"

    # Invalid token -> 401
    res_invalid = client.get(
        "/admin/dashboard",
        headers={"Authorization": "Bearer invalid.token.xyz"},
    )
    assert res_invalid.status_code == 401
    assert res_invalid.json()["detail"] == "Invalid or expired token"
