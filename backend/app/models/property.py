from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Numeric,
    String,
    Table,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.amenity import Amenity
    from app.models.room import Room
    from app.models.user import User

# Association table for Many-to-Many relationship between Property and Amenity
property_amenities = Table(
    "property_amenities",
    Base.metadata,
    Column(
        "property_id",
        ForeignKey("properties.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "amenity_id",
        ForeignKey("amenities.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class Property(Base):
    __tablename__ = "properties"
    __table_args__ = (
        CheckConstraint(
            "security_deposit IS NULL OR security_deposit >= 0",
            name="check_non_negative_security_deposit",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    property_type: Mapped[str] = mapped_column(String(50), nullable=False)
    address: Mapped[str] = mapped_column(String(255), nullable=False)
    city: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    security_deposit: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    ##yha owner python me associated User ko access karne ka tarika , naming hai bas and kuch alag se nhi 
    #hai like property.owner se hame Wo User milega jo is property ko own karta hoga 
    owner: Mapped["User"] = relationship(back_populates="properties")
    rooms: Mapped[list["Room"]] = relationship(
        back_populates="property", cascade="all, delete-orphan"
    )
    images: Mapped[list["PropertyImage"]] = relationship(
        back_populates="property", cascade="all, delete-orphan"
    )
    amenities: Mapped[list["Amenity"]] = relationship(
        secondary=property_amenities, back_populates="properties"
    )


class PropertyImage(Base):
    __tablename__ = "property_images"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True
    )
    image_url: Mapped[str] = mapped_column(String(500), nullable=False)
    storage_path: Mapped[str] = mapped_column(String(500), nullable=False, default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    property: Mapped["Property"] = relationship(back_populates="images")
