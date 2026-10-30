import uuid
from decimal import Decimal
from fastapi.testclient import TestClient
from sqlalchemy import select
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
            address="12 FC Road",
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
def test_toggle_favorite_add_and_remove():
    owner, _ = create_user("owner")
    student, student_token = create_user("student")
    prop = create_property(owner.id)
    headers = {"Authorization": f"Bearer {student_token}"}
    # 1. Initially check should be false
    check_res = client.get(f"/favorites/check/{prop.id}", headers=headers)
    assert check_res.status_code == 200
    assert check_res.json()["is_favorite"] is False
    # 2. Toggle ON (Add)
    add_res = client.post(f"/favorites/{prop.id}/toggle", headers=headers)
    assert add_res.status_code == 200
    assert add_res.json()["is_favorite"] is True
    # Check now should be true
    check_res2 = client.get(f"/favorites/check/{prop.id}", headers=headers)
    assert check_res2.json()["is_favorite"] is True
    # 3. List my favorites should contain this property
    my_res = client.get("/favorites/my", headers=headers)
    assert my_res.status_code == 200
    items = my_res.json()
    assert len(items) == 1
    assert items[0]["property_id"] == prop.id
    assert items[0]["property"]["title"] == prop.title
    # 4. Toggle OFF (Remove)
    remove_res = client.post(f"/favorites/{prop.id}/toggle", headers=headers)
    assert remove_res.status_code == 200
    assert remove_res.json()["is_favorite"] is False
    # 5. List my favorites should now be empty
    my_res2 = client.get("/favorites/my", headers=headers)
    assert len(my_res2.json()) == 0
def test_unauthenticated_user_cannot_favorite():
    owner, _ = create_user("owner")
    prop = create_property(owner.id)
    res = client.post(f"/favorites/{prop.id}/toggle")
    assert res.status_code == 401
def test_favorite_nonexistent_property_returns_404():
    _, token = create_user("student")
    res = client.post(
        "/favorites/99999999/toggle",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 404