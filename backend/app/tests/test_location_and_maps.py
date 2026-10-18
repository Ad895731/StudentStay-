from decimal import Decimal
import uuid
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.property import Property
from app.models.user import User

client = TestClient(app)


def create_user(role: str = "owner") -> tuple[User, str]:
    db = SessionLocal()
    try:
        user = User(
            name=f"Location Test {role.capitalize()}",
            email=f"{role}_{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password("securePass123"),
            role=role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        token = create_access_token(user.id)
        return user, token
    finally:
        db.close()


def test_create_property_requires_valid_coordinates():
    _, token = create_user("owner")

    # Missing coordinates -> 422
    res_missing = client.post(
        "/properties",
        json={
            "title": "No Coords Property",
            "property_type": "pg",
            "address": "MG Road",
            "city": "Bengaluru",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_missing.status_code == 422

    # Latitude out of range (> 90)
    res_invalid_lat = client.post(
        "/properties",
        json={
            "title": "Invalid Lat Property",
            "property_type": "pg",
            "address": "MG Road",
            "city": "Bengaluru",
            "latitude": 91.5,
            "longitude": 77.59,
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_invalid_lat.status_code == 422

    # Longitude out of range (< -180)
    res_invalid_lon = client.post(
        "/properties",
        json={
            "title": "Invalid Lon Property",
            "property_type": "pg",
            "address": "MG Road",
            "city": "Bengaluru",
            "latitude": 12.97,
            "longitude": -185.0,
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_invalid_lon.status_code == 422

    # Valid coordinates saved and returned correctly
    res_valid = client.post(
        "/properties",
        json={
            "title": "Valid Location Stay",
            "description": "Close to tech park",
            "property_type": "pg",
            "address": "Indiranagar 100ft Rd",
            "city": "Bengaluru",
            "latitude": 12.9716,
            "longitude": 77.5946,
            "security_deposit": "6000.00",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_valid.status_code == 201
    created_data = res_valid.json()
    assert created_data["latitude"] == 12.9716
    assert created_data["longitude"] == 77.5946


def test_update_property_coordinates():
    owner, token = create_user("owner")

    # Create property with initial coordinates
    res_create = client.post(
        "/properties",
        json={
            "title": "Updatable Coords Stay",
            "property_type": "flat",
            "address": "Koramangala 4th Block",
            "city": "Bengaluru",
            "latitude": 12.9352,
            "longitude": 77.6245,
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_create.status_code == 201
    prop_id = res_create.json()["id"]

    # Update coordinates
    res_update = client.patch(
        f"/properties/{prop_id}",
        json={
            "latitude": 12.9360,
            "longitude": 77.6250,
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_update.status_code == 200
    updated_data = res_update.json()
    assert updated_data["latitude"] == 12.9360
    assert updated_data["longitude"] == 77.6250


def test_compatibility_with_properties_without_coordinates():
    owner, _ = create_user("owner")
    db = SessionLocal()
    try:
        # Simulate legacy property directly in DB with null coordinates
        legacy_prop = Property(
            owner_id=owner.id,
            title=f"Legacy Property {uuid.uuid4().hex[:6]}",
            property_type="pg",
            address="Old Town",
            city="Pune",
            latitude=None,
            longitude=None,
            is_verified=True,
            is_available=True,
        )
        db.add(legacy_prop)
        db.commit()
        db.refresh(legacy_prop)
        legacy_id = legacy_prop.id
    finally:
        db.close()

    # Detail API must return successfully without error and latitude/longitude as None
    res_detail = client.get(f"/properties/{legacy_id}")
    assert res_detail.status_code == 200
    data = res_detail.json()
    assert data["latitude"] is None
    assert data["longitude"] is None


def test_nearby_property_filtering_and_distance_calculation():
    owner, _ = create_user("owner")
    tag = uuid.uuid4().hex[:6]
    db = SessionLocal()
    try:
        # Point of reference: Pune Shaniwar Wada (~18.5196, 73.8553)
        # 1. Very close (~1 km away): Pune Station (~18.5284, 73.8739) -> ~2.2 km
        p_close = Property(
            owner_id=owner.id,
            title=f"Close Station Stay {tag}",
            property_type="pg",
            address="Station Rd",
            city=f"Pune_{tag}",
            latitude=18.5284,
            longitude=73.8739,
            is_verified=True,
            is_available=True,
        )
        # 2. Medium distance (~10 km away): Hinjewadi (~18.5913, 73.7389) -> ~14.6 km
        p_med = Property(
            owner_id=owner.id,
            title=f"Medium Hinjewadi Stay {tag}",
            property_type="pg",
            address="Phase 1",
            city=f"Pune_{tag}",
            latitude=18.5913,
            longitude=73.7389,
            is_verified=True,
            is_available=True,
        )
        # 3. Far distance (~120 km away): Mumbai (~19.0760, 72.8777)
        p_far = Property(
            owner_id=owner.id,
            title=f"Far Mumbai Stay {tag}",
            property_type="pg",
            address="Bandra",
            city=f"Mumbai_{tag}",
            latitude=19.0760,
            longitude=72.8777,
            is_verified=True,
            is_available=True,
        )
        # 4. Property with null coordinates
        p_null_coords = Property(
            owner_id=owner.id,
            title=f"No Coords Stay {tag}",
            property_type="pg",
            address="Camp",
            city=f"Pune_{tag}",
            latitude=None,
            longitude=None,
            is_verified=True,
            is_available=True,
        )
        # 5. Unverified property nearby
        p_unverified = Property(
            owner_id=owner.id,
            title=f"Unverified Close Stay {tag}",
            property_type="pg",
            address="Near Station",
            city=f"Pune_{tag}",
            latitude=18.5280,
            longitude=73.8740,
            is_verified=False,
            is_available=True,
        )
        db.add_all([p_close, p_med, p_far, p_null_coords, p_unverified])
        db.commit()
        close_id, med_id, far_id = p_close.id, p_med.id, p_far.id
    finally:
        db.close()

    # Query nearby with radius_km = 5 km from Shaniwar Wada (18.5196, 73.8553)
    res_5km = client.get(
        f"/properties?latitude=18.5196&longitude=73.8553&radius_km=5.0&city=Pune_{tag}"
    )
    assert res_5km.status_code == 200
    data_5km = res_5km.json()
    assert data_5km["total"] == 1
    items_5km = data_5km["items"]
    assert len(items_5km) == 1
    assert items_5km[0]["id"] == close_id
    assert items_5km[0]["distance_km"] is not None
    assert 1.5 <= items_5km[0]["distance_km"] <= 3.0

    # Query with radius_km = 20 km -> includes both close and medium, but excludes far, null coords, and unverified
    res_20km = client.get(
        f"/properties?latitude=18.5196&longitude=73.8553&radius_km=20.0&sort_by=distance&city=Pune_{tag}"
    )
    assert res_20km.status_code == 200
    data_20km = res_20km.json()
    assert data_20km["total"] == 2
    item_ids = [item["id"] for item in data_20km["items"]]
    assert item_ids == [close_id, med_id]
    # Check that distance is ascending
    assert data_20km["items"][0]["distance_km"] < data_20km["items"][1]["distance_km"]


def test_nearby_validation_errors():
    # radius_km provided without coordinates
    res1 = client.get("/properties?radius_km=10")
    assert res1.status_code == 422
    assert "latitude and longitude are required" in res1.json()["detail"]

    # latitude provided without longitude
    res2 = client.get("/properties?latitude=18.52")
    assert res2.status_code == 422
    assert "latitude and longitude must both be provided" in res2.json()["detail"]

    # longitude provided without latitude
    res3 = client.get("/properties?longitude=73.85")
    assert res3.status_code == 422
    assert "latitude and longitude must both be provided" in res3.json()["detail"]

    # radius_km <= 0
    res4 = client.get("/properties?latitude=18.52&longitude=73.85&radius_km=0")
    assert res4.status_code == 422

    # sort_by=distance without coordinates
    res5 = client.get("/properties?sort_by=distance")
    assert res5.status_code == 422
    assert "latitude and longitude are required when sorting by distance" in res5.json()["detail"]
