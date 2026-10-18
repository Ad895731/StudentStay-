from decimal import Decimal
import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.amenity import Amenity
from app.models.property import Property, PropertyImage
from app.models.room import Room
from app.models.user import User


def test_property_creation_and_relationships():
    db = SessionLocal()
    try:
        # 1. Create an owner user
        owner_email = f"owner_{uuid.uuid4().hex[:8]}@example.com"
        owner = User(
            name="Property Owner",
            email=owner_email,
            password_hash=hash_password("ownerPassword123"),
            role="owner",
        )
        db.add(owner)
        db.commit()
        db.refresh(owner)

        # 2. Create amenities
        wifi = Amenity(name=f"WiFi_{uuid.uuid4().hex[:6]}")
        ac = Amenity(name=f"AC_{uuid.uuid4().hex[:6]}")
        db.add_all([wifi, ac])
        db.commit()

        # 3. Create property with amenities, rooms, and images
        prop = Property(
            owner_id=owner.id,
            title="Sunrise Student Hostel",
            description="Affordable and secure PG for college students.",
            property_type="hostel",
            address="123 University Road",
            city="Pune",
            latitude=18.5204,
            longitude=73.8567,
            security_deposit=Decimal("5000.00"),
            is_verified=False,
            is_available=True,
            amenities=[wifi, ac],
        )
        db.add(prop)
        db.commit()
        db.refresh(prop)

        room1 = Room(
            property_id=prop.id,
            sharing_type="single",
            monthly_rent=Decimal("8000.00"),
            available_beds=1,
        )
        room2 = Room(
            property_id=prop.id,
            sharing_type="double",
            monthly_rent=Decimal("5000.00"),
            available_beds=2,
        )
        img = PropertyImage(
            property_id=prop.id,
            image_url="https://example.com/images/room1.jpg",
        )
        db.add_all([room1, room2, img])
        db.commit()

        # 4. Verify relationships from Property
        db.refresh(prop)
        assert prop.owner.id == owner.id
        assert len(prop.rooms) == 2
        assert len(prop.images) == 1
        assert len(prop.amenities) == 2

        # Verify relationship back from Amenity
        assert any(p.id == prop.id for p in wifi.properties)

        # Verify relationship from User
        db.refresh(owner)
        assert any(p.id == prop.id for p in owner.properties)

        # 5. Verify Cascade Delete
        property_id = prop.id
        db.delete(prop)
        db.commit()

        # Rooms and images should be automatically deleted via cascade
        rooms = db.scalars(select(Room).where(Room.property_id == property_id)).all()
        assert len(rooms) == 0

        images = db.scalars(select(PropertyImage).where(PropertyImage.property_id == property_id)).all()
        assert len(images) == 0

        # Amenities and Owner should still exist
        assert db.scalar(select(User).where(User.id == owner.id)) is not None
        assert db.scalar(select(Amenity).where(Amenity.id == wifi.id)) is not None

    finally:
        db.close()


def test_room_negative_beds_constraint():
    db = SessionLocal()
    try:
        owner = User(
            name="Owner Test",
            email=f"owner_{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password("password"),
            role="owner",
        )
        db.add(owner)
        db.commit()

        prop = Property(
            owner_id=owner.id,
            title="Test PG",
            property_type="pg",
            address="Test Street",
            city="Mumbai",
        )
        db.add(prop)
        db.commit()

        # Violate available_beds >= 0 constraint
        invalid_room = Room(
            property_id=prop.id,
            sharing_type="single",
            monthly_rent=Decimal("5000.00"),
            available_beds=-1,
        )
        db.add(invalid_room)
        with pytest.raises(IntegrityError):
            db.commit()

    finally:
        db.rollback()
        db.close()
