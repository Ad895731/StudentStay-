from datetime import datetime, timezone
import uuid
from decimal import Decimal
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.inquiry import Inquiry
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
            address="20 FC Road",
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


def create_inquiry(property_id: int, student_id: int, owner_id: int, status: str = "confirmed") -> Inquiry:
    db = SessionLocal()
    try:
        inquiry = Inquiry(
            property_id=property_id,
            student_id=student_id,
            owner_id=owner_id,
            visit_date=datetime.now(timezone.utc),
            sharing_preference="single",
            contact_phone="9876543210",
            message="Looking forward to staying here",
            status=status,
        )
        db.add(inquiry)
        db.commit()
        db.refresh(inquiry)
        return inquiry
    finally:
        db.close()


def test_unverified_student_cannot_post_fake_review():
    """Unverified student who never visited/stayed gets 403 Forbidden."""
    owner, _ = create_user("owner")
    student, student_token = create_user("student")
    prop = create_property(owner.id)

    headers = {"Authorization": f"Bearer {student_token}"}

    # Check can-review endpoint returns False
    can_rev = client.get(f"/properties/{prop.id}/can-review", headers=headers)
    assert can_rev.status_code == 200
    assert can_rev.json()["can_review"] is False

    # Attempting to post review fails with 403
    res = client.post(
        f"/properties/{prop.id}/reviews",
        json={"rating": 5, "comment": "Fake 5-star review"},
        headers=headers,
    )
    assert res.status_code == 403
    assert "verified" in res.json()["detail"].lower()


def test_verified_student_can_submit_and_update_review():
    """Verified student with confirmed inquiry can post and update review."""
    owner, _ = create_user("owner")
    student, student_token = create_user("student")
    prop = create_property(owner.id)

    # Give student a confirmed visit inquiry
    create_inquiry(prop.id, student.id, owner.id, status="confirmed")

    headers = {"Authorization": f"Bearer {student_token}"}

    # 1. can-review endpoint returns True
    can_rev = client.get(f"/properties/{prop.id}/can-review", headers=headers)
    assert can_rev.status_code == 200
    assert can_rev.json()["can_review"] is True

    # 2. Initial rating summary is 0
    summary_res = client.get(f"/properties/{prop.id}/rating-summary")
    assert summary_res.status_code == 200
    assert summary_res.json()["average_rating"] == 0.0
    assert summary_res.json()["total_reviews"] == 0

    # 3. Submit Review (4 stars)
    review_payload = {
        "rating": 4,
        "comment": "Great food and high-speed Wi-Fi, peaceful environment.",
    }
    post_res = client.post(
        f"/properties/{prop.id}/reviews",
        json=review_payload,
        headers=headers,
    )
    assert post_res.status_code == 201
    rev_data = post_res.json()
    assert rev_data["rating"] == 4
    assert rev_data["student"]["name"] == student.name

    # 4. Check Rating Summary after review
    summary_res2 = client.get(f"/properties/{prop.id}/rating-summary")
    assert summary_res2.json()["average_rating"] == 4.0
    assert summary_res2.json()["total_reviews"] == 1

    # 5. Same student updates their review to 5 stars (Upsert behavior)
    update_payload = {
        "rating": 5,
        "comment": "Updated: Owner fixed AC promptly, best stay ever!",
    }
    update_res = client.post(
        f"/properties/{prop.id}/reviews",
        json=update_payload,
        headers=headers,
    )
    assert update_res.status_code == 201
    assert update_res.json()["rating"] == 5

    # Count remains 1, rating is updated to 5.0
    summary_res3 = client.get(f"/properties/{prop.id}/rating-summary")
    assert summary_res3.json()["average_rating"] == 5.0
    assert summary_res3.json()["total_reviews"] == 1

    # 6. List reviews endpoint
    list_res = client.get(f"/properties/{prop.id}/reviews")
    assert list_res.status_code == 200
    assert len(list_res.json()) == 1


def test_owner_cannot_review_own_property():
    owner, owner_token = create_user("owner")
    prop = create_property(owner.id)

    res = client.post(
        f"/properties/{prop.id}/reviews",
        json={"rating": 5, "comment": "Self review attempt"},
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert res.status_code == 400
    assert "own property" in res.json()["detail"].lower()
