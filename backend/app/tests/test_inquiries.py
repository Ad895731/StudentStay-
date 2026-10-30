import uuid
from datetime import datetime, timezone
from decimal import Decimal
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.property import Property
from app.models.user import User

client = TestClient(app)


def create_user(role: str = "student") -> tuple[User, str]:
    db = SessionLocal()
    try:
        user = User(
            name=f"User {role.capitalize()}",
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
            title=f"Hostel {uuid.uuid4().hex[:6]}",
            property_type="hostel",
            address="15 FC Road",
            city="Pune",
            latitude=18.5204,
            longitude=73.8567,
            security_deposit=Decimal("3000.00"),
            is_verified=True,
            is_available=True,
        )
        db.add(prop)
        db.commit()
        db.refresh(prop)
        return prop
    finally:
        db.close()


def test_student_can_create_inquiry_and_phone_is_masked_for_owner_until_confirmed():
    owner, owner_token = create_user("owner")
    student, student_token = create_user("student")
    prop = create_property(owner.id)

    raw_phone = "+919876543210"
    payload = {
        "property_id": prop.id,
        "visit_date": datetime.now(timezone.utc).isoformat(),
        "sharing_preference": "single",
        "contact_phone": raw_phone,
        "message": "Hi, I want to visit this Sunday morning.",
    }

    # 1. Student submits inquiry
    res = client.post(
        "/inquiries",
        json=payload,
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert res.status_code == 201
    inquiry_data = res.json()
    assert inquiry_data["status"] == "pending"
    # Student sees their own full phone number
    assert inquiry_data["contact_phone"] == raw_phone
    inquiry_id = inquiry_data["id"]

    # 2. Owner checks received inquiries while status is PENDING
    owner_res = client.get(
        "/inquiries/my-received",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert owner_res.status_code == 200
    owner_inquiries = owner_res.json()
    assert len(owner_inquiries) == 1
    # SECURITY & PRIVACY CHECK: Owner sees MASKED phone number while pending!
    assert owner_inquiries[0]["contact_phone"] != raw_phone
    assert "*" in owner_inquiries[0]["contact_phone"]

    # 3. Owner confirms the visit request
    patch_res = client.patch(
        f"/inquiries/{inquiry_id}/status",
        json={"status": "confirmed"},
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert patch_res.status_code == 200
    updated_data = patch_res.json()
    assert updated_data["status"] == "confirmed"
    # PRIVACY UNLOCKED: Now that visit is confirmed, owner sees full contact number!
    assert updated_data["contact_phone"] == raw_phone


def test_owner_cannot_inquire_on_own_property():
    owner, owner_token = create_user("owner")
    prop = create_property(owner.id)

    res = client.post(
        "/inquiries",
        json={
            "property_id": prop.id,
            "visit_date": datetime.now(timezone.utc).isoformat(),
            "sharing_preference": "single",
            "contact_phone": "+919876543210",
        },
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert res.status_code == 400
    assert "own property" in res.json()["detail"].lower()

