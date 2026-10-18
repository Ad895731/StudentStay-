from decimal import Decimal
import uuid
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.amenity import Amenity
from app.models.property import Property, PropertyImage
from app.models.room import Room
from app.models.user import User

client = TestClient(app)


def create_test_user(role: str = "student") -> tuple[User, str]:
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


def create_test_property(
    owner_id: int,
    is_verified: bool = True,
    is_available: bool = True,
    city: str = "Pune",
    property_type: str = "pg",
) -> Property:
    db = SessionLocal()
    try:
        prop = Property(
            owner_id=owner_id,
            title=f"Test Property {uuid.uuid4().hex[:6]}",
            description="A modern student stay near college.",
            property_type=property_type,
            address="45 Campus Road",
            city=city,
            latitude=18.5204,
            longitude=73.8567,
            security_deposit=Decimal("4000.00"),
            is_verified=is_verified,
            is_available=is_available,
        )
        db.add(prop)
        db.commit()
        db.refresh(prop)
        return prop
    finally:
        db.close()


# 1. CREATE PROPERTY TESTS


def test_owner_can_create_property():
    owner, token = create_test_user("owner")
    payload = {
        "title": "Greenview PG for Students",
        "description": "Clean rooms with high-speed WiFi",
        "property_type": "pg",
        "address": "12 Baker Street",
        "city": "Bengaluru",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "security_deposit": "5000.00",
    }
    response = client.post(
        "/properties",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == payload["title"]
    assert data["owner_id"] == owner.id
    assert data["city"] == payload["city"]
    assert data["is_verified"] is False  # New property not auto-verified
    assert data["is_available"] is True
    assert "id" in data


def test_student_cannot_create_property():
    _, student_token = create_test_user("student")
    payload = {
        "title": "Unauthorized PG",
        "property_type": "pg",
        "address": "12 Street",
        "city": "Delhi",
    }
    response = client.post(
        "/properties",
        json=payload,
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Operation not permitted"


def test_unauthenticated_create_property_rejected():
    payload = {
        "title": "Unauthenticated PG",
        "property_type": "pg",
        "address": "12 Street",
        "city": "Delhi",
    }
    response = client.post("/properties", json=payload)
    assert response.status_code == 401
    assert response.json()["detail"] == "Not authenticated"


def test_client_supplied_owner_id_and_privileged_fields_rejected():
    _, owner_token = create_test_user("owner")
    # Attempting to supply owner_id or is_verified must be rejected (extra="forbid")
    payload = {
        "title": "Tampered Property",
        "property_type": "pg",
        "address": "12 Street",
        "city": "Delhi",
        "owner_id": 99999,
        "is_verified": True,
    }
    response = client.post(
        "/properties",
        json=payload,
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert response.status_code == 422


def test_create_property_validation_rules():
    _, owner_token = create_test_user("owner")

    # Negative security deposit
    res = client.post(
        "/properties",
        json={
            "title": "Invalid Deposit",
            "property_type": "pg",
            "address": "12 Street",
            "city": "Delhi",
            "security_deposit": "-100.00",
        },
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert res.status_code == 422

    # Latitude out of bounds (> 90)
    res = client.post(
        "/properties",
        json={
            "title": "Invalid Lat",
            "property_type": "pg",
            "address": "12 Street",
            "city": "Delhi",
            "latitude": 95.0,
        },
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert res.status_code == 422

    # Longitude out of bounds (< -180)
    res = client.post(
        "/properties",
        json={
            "title": "Invalid Long",
            "property_type": "pg",
            "address": "12 Street",
            "city": "Delhi",
            "longitude": -190.0,
        },
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert res.status_code == 422


# -------------------------------------------------------------
# 2. LIST PROPERTIES TESTS
# -------------------------------------------------------------

def test_list_properties_only_returns_verified_and_available():
    owner, _ = create_test_user("owner")
    city_tag = f"City_{uuid.uuid4().hex[:6]}"

    # Verified & available -> visible
    prop_visible = create_test_property(owner.id, is_verified=True, is_available=True, city=city_tag)
    # Unverified -> hidden
    prop_unverified = create_test_property(owner.id, is_verified=False, is_available=True, city=city_tag)
    # Unavailable -> hidden
    prop_unavailable = create_test_property(owner.id, is_verified=True, is_available=False, city=city_tag)

    response = client.get(f"/properties?city={city_tag}")
    assert response.status_code == 200
    data = response.json()
    item_ids = [item["id"] for item in data["items"]]

    assert prop_visible.id in item_ids
    assert prop_unverified.id not in item_ids
    assert prop_unavailable.id not in item_ids
    assert data["total"] == 1


def test_list_properties_filters_and_pagination():
    owner, _ = create_test_user("owner")
    city_tag = f"TestCity_{uuid.uuid4().hex[:6]}"

    p1 = create_test_property(owner.id, is_verified=True, is_available=True, city=city_tag, property_type="pg")
    p2 = create_test_property(owner.id, is_verified=True, is_available=True, city=city_tag, property_type="hostel")
    p3 = create_test_property(owner.id, is_verified=True, is_available=True, city=city_tag, property_type="pg")

    # Filter by property_type
    res_type = client.get(f"/properties?city={city_tag}&property_type=hostel")
    assert res_type.status_code == 200
    data_type = res_type.json()
    assert data_type["total"] == 1
    assert data_type["items"][0]["id"] == p2.id

    # Pagination: page_size=1
    res_page1 = client.get(f"/properties?city={city_tag}&page=1&page_size=1")
    assert res_page1.status_code == 200
    data_p1 = res_page1.json()
    assert len(data_p1["items"]) == 1
    assert data_p1["page"] == 1
    assert data_p1["page_size"] == 1
    assert data_p1["total"] == 3


# -------------------------------------------------------------
# 3. PROPERTY DETAILS TESTS
# -------------------------------------------------------------

def test_get_property_detail_success():
    owner, _ = create_test_user("owner")
    wifi_name = f"WiFi_{uuid.uuid4().hex[:6]}"
    db = SessionLocal()
    try:
        wifi = Amenity(name=wifi_name)
        db.add(wifi)
        db.commit()

        prop = Property(
            owner_id=owner.id,
            title="Sunrise Hostel",
            description="Nice place",
            property_type="hostel",
            address="100 Road",
            city="Jaipur",
            security_deposit=Decimal("3000.00"),
            is_verified=True,
            is_available=True,
            amenities=[wifi],
        )
        db.add(prop)
        db.commit()
        db.refresh(prop)

        room = Room(
            property_id=prop.id,
            sharing_type="double",
            monthly_rent=Decimal("4500.00"),
            available_beds=2,
        )
        img = PropertyImage(
            property_id=prop.id,
            image_url="https://example.com/p1.jpg",
        )
        db.add_all([room, img])
        db.commit()
        prop_id = prop.id
    finally:
        db.close()

    response = client.get(f"/properties/{prop_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == prop_id
    assert len(data["rooms"]) == 1
    assert data["rooms"][0]["sharing_type"] == "double"
    assert len(data["amenities"]) == 1
    assert data["amenities"][0]["name"] == wifi_name
    assert len(data["images"]) == 1


def test_get_property_detail_hidden_or_nonexistent_returns_404():
    owner, _ = create_test_user("owner")
    prop_unverified = create_test_property(owner.id, is_verified=False, is_available=True)
    prop_unavailable = create_test_property(owner.id, is_verified=True, is_available=False)

    # Unverified returns 404
    assert client.get(f"/properties/{prop_unverified.id}").status_code == 404

    # Unavailable returns 404
    assert client.get(f"/properties/{prop_unavailable.id}").status_code == 404

    # Nonexistent returns 404
    assert client.get("/properties/99999999").status_code == 404


# -------------------------------------------------------------
# 4. UPDATE PROPERTY TESTS
# -------------------------------------------------------------

def test_owner_can_update_own_property():
    owner, owner_token = create_test_user("owner")
    prop = create_test_property(owner.id, city="Kolkata")

    update_payload = {
        "title": "Updated Property Title",
        "security_deposit": "7500.00",
    }
    response = client.patch(
        f"/properties/{prop.id}",
        json=update_payload,
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Updated Property Title"
    assert Decimal(str(data["security_deposit"])) == Decimal("7500.00")
    # Omitted fields remain preserved
    assert data["city"] == "Kolkata"
    assert data["property_type"] == "pg"


def test_owner_cannot_update_another_owner_property():
    owner1, _ = create_test_user("owner")
    _, owner2_token = create_test_user("owner")
    prop1 = create_test_property(owner1.id)

    response = client.patch(
        f"/properties/{prop1.id}",
        json={"title": "Hacked Title"},
        headers={"Authorization": f"Bearer {owner2_token}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Not authorized to update this property"


def test_admin_can_update_any_property():
    owner, _ = create_test_user("owner")
    _, admin_token = create_test_user("admin")
    prop = create_test_property(owner.id)

    response = client.patch(
        f"/properties/{prop.id}",
        json={"title": "Admin Modified Title"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["title"] == "Admin Modified Title"


def test_student_cannot_update_property():
    owner, _ = create_test_user("owner")
    _, student_token = create_test_user("student")
    prop = create_test_property(owner.id)

    response = client.patch(
        f"/properties/{prop.id}",
        json={"title": "Student Modified"},
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Operation not permitted"


def test_unauthenticated_update_rejected():
    owner, _ = create_test_user("owner")
    prop = create_test_property(owner.id)

    response = client.patch(f"/properties/{prop.id}", json={"title": "No Auth"})
    assert response.status_code == 401


def test_client_cannot_change_privileged_fields_on_update():
    owner, owner_token = create_test_user("owner")
    prop = create_test_property(owner.id)

    response = client.patch(
        f"/properties/{prop.id}",
        json={"owner_id": 1234, "is_verified": True},
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert response.status_code == 422


# -------------------------------------------------------------
# 5. DELETE PROPERTY TESTS
# -------------------------------------------------------------

def test_owner_can_delete_own_property_and_cascades_properly():
    owner, owner_token = create_test_user("owner")
    db = SessionLocal()
    try:
        shared_amenity = Amenity(name=f"Gym_{uuid.uuid4().hex[:6]}")
        db.add(shared_amenity)
        db.commit()

        prop = Property(
            owner_id=owner.id,
            title="Delete Me Hostel",
            property_type="hostel",
            address="Delete Ave",
            city="Goa",
            amenities=[shared_amenity],
        )
        db.add(prop)
        db.commit()
        db.refresh(prop)

        room = Room(property_id=prop.id, sharing_type="single", monthly_rent=Decimal("6000.00"), available_beds=1)
        img = PropertyImage(property_id=prop.id, image_url="https://example.com/del.jpg")
        db.add_all([room, img])
        db.commit()

        prop_id = prop.id
        amenity_id = shared_amenity.id
        owner_id = owner.id
    finally:
        db.close()

    response = client.delete(
        f"/properties/{prop_id}",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert response.status_code == 204

    # Verify property is deleted
    db = SessionLocal()
    try:
        assert db.scalar(select(Property).where(Property.id == prop_id)) is None
        # Rooms and images cascaded
        assert db.scalars(select(Room).where(Room.property_id == prop_id)).all() == []
        assert db.scalars(select(PropertyImage).where(PropertyImage.property_id == prop_id)).all() == []
        # Owner and shared amenity remain intact
        assert db.scalar(select(User).where(User.id == owner_id)) is not None
        assert db.scalar(select(Amenity).where(Amenity.id == amenity_id)) is not None
    finally:
        db.close()


def test_owner_cannot_delete_another_owner_property():
    owner1, _ = create_test_user("owner")
    _, owner2_token = create_test_user("owner")
    prop = create_test_property(owner1.id)

    response = client.delete(
        f"/properties/{prop.id}",
        headers={"Authorization": f"Bearer {owner2_token}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Not authorized to delete this property"


def test_admin_can_delete_any_property():
    owner, _ = create_test_user("owner")
    _, admin_token = create_test_user("admin")
    prop = create_test_property(owner.id)

    response = client.delete(
        f"/properties/{prop.id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 204


def test_student_cannot_delete_property():
    owner, _ = create_test_user("owner")
    _, student_token = create_test_user("student")
    prop = create_test_property(owner.id)

    response = client.delete(
        f"/properties/{prop.id}",
        headers={"Authorization": f"Bearer {student_token}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Operation not permitted"


def test_unauthenticated_delete_rejected():
    owner, _ = create_test_user("owner")
    prop = create_test_property(owner.id)

    response = client.delete(f"/properties/{prop.id}")
    assert response.status_code == 401


def test_delete_nonexistent_property_returns_404():
    _, owner_token = create_test_user("owner")
    response = client.delete(
        "/properties/99999999",
        headers={"Authorization": f"Bearer {owner_token}"},
    )
    assert response.status_code == 404
