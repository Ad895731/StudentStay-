from decimal import Decimal
from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_role
from app.models.property import Property, PropertyImage
from app.models.room import Room
from app.models.user import User
from app.schemas.property import (
    PropertyCreate,
    PropertyDetailResponse,
    PropertyImageResponse,
    PropertyListResponse,
    PropertyResponse,
    PropertyUpdate,
)
from app.services.storage import (
    delete_property_image,
    save_property_image_record,
    upload_property_image,
    validate_image_file,
)

router = APIRouter(prefix="/properties", tags=["Properties"])


@router.post("", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
def create_property(
    property_in: PropertyCreate,
    current_user: User = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    """Create a new property listing. Restricted to users with the 'owner' role."""
    new_property = Property(
        owner_id=current_user.id,
        title=property_in.title,
        description=property_in.description,
        property_type=property_in.property_type,
        address=property_in.address,
        city=property_in.city,
        latitude=property_in.latitude,
        longitude=property_in.longitude,
        security_deposit=property_in.security_deposit,
        is_verified=False,
        is_available=True,
    )
    db.add(new_property)
    db.commit()
    db.refresh(new_property)
    return new_property


def haversine_distance_expr(user_lat: float, user_lon: float):
    """PostgreSQL-compatible Haversine formula for calculating distance in km."""
    dlat = func.radians(Property.latitude - user_lat)
    dlon = func.radians(Property.longitude - user_lon)
    lat1_rad = func.radians(user_lat)
    lat2_rad = func.radians(Property.latitude)

    a = (
        func.pow(func.sin(dlat / 2.0), 2)
        + func.cos(lat1_rad) * func.cos(lat2_rad) * func.pow(func.sin(dlon / 2.0), 2)
    )
    a_clamped = func.least(1.0, func.greatest(0.0, a))
    return 6371.0 * 2.0 * func.asin(func.sqrt(a_clamped))


@router.get("", response_model=PropertyListResponse)
def list_properties(
    q: str | None = Query(None, description="Search query across title, description, city, and address"),
    city: str | None = Query(None, description="Filter by city"),
    property_type: str | None = Query(None, description="Filter by property type"),
    min_rent: Decimal | None = Query(None, ge=Decimal("0.00"), description="Minimum monthly rent"),
    max_rent: Decimal | None = Query(None, ge=Decimal("0.00"), description="Maximum monthly rent"),
    sharing_type: str | None = Query(None, description="Filter by room sharing type (e.g. single, double)"),
    latitude: float | None = Query(None, ge=-90.0, le=90.0, description="Latitude for nearby search"),
    longitude: float | None = Query(None, ge=-180.0, le=180.0, description="Longitude for nearby search"),
    radius_km: float | None = Query(None, gt=0.0, description="Radius in kilometers for nearby search"),
    sort_by: str = Query("newest", description="Sorting option: newest, rent_low_to_high, rent_high_to_low, distance"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=50, description="Items per page (max 50)"),
    db: Session = Depends(get_db),
):
    """Public endpoint to list verified and available properties with search, filters, sorting, and pagination."""
    if min_rent is not None and max_rent is not None and min_rent > max_rent:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="min_rent cannot exceed max_rent",
        )

    has_lat = latitude is not None
    has_lon = longitude is not None
    has_radius = radius_km is not None

    if has_radius and not (has_lat and has_lon):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="latitude and longitude are required when radius_km is specified",
        )

    if (has_lat and not has_lon) or (has_lon and not has_lat):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="latitude and longitude must both be provided",
        )

    allowed_sort_options = ("newest", "rent_low_to_high", "rent_high_to_low", "distance")
    if sort_by not in allowed_sort_options:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid sort_by option. Allowed values: {', '.join(allowed_sort_options)}",
        )

    if sort_by == "distance" and not (has_lat and has_lon):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="latitude and longitude are required when sorting by distance",
        )

    # 1. Base visibility filter: only verified and available properties
    base_query = select(Property).where(
        Property.is_available.is_(True),
        Property.is_verified.is_(True),
    )

    # 2. Text search across title, description, city, address
    if q and q.strip():
        search_term = f"%{q.strip()}%"
        base_query = base_query.where(
            or_(
                Property.title.ilike(search_term),
                Property.description.ilike(search_term),
                Property.city.ilike(search_term),
                Property.address.ilike(search_term),
            )
        )

    # 3. Direct property filters
    if city and city.strip():
        base_query = base_query.where(func.lower(Property.city) == city.strip().lower())
    if property_type and property_type.strip():
        base_query = base_query.where(func.lower(Property.property_type) == property_type.strip().lower())

    # 4. Room-based filters (rent range & sharing type applied to the SAME room)
    room_conditions = [Room.property_id == Property.id]
    if min_rent is not None:
        room_conditions.append(Room.monthly_rent >= min_rent)
    if max_rent is not None:
        room_conditions.append(Room.monthly_rent <= max_rent)
    if sharing_type and sharing_type.strip():
        room_conditions.append(func.lower(Room.sharing_type) == sharing_type.strip().lower())

    if len(room_conditions) > 1:
        base_query = base_query.where(
            select(Room.id).where(*room_conditions).exists()
        )

    # 5. Nearby / Location filtering
    dist_expr = None
    if has_lat and has_lon:
        dist_expr = haversine_distance_expr(latitude, longitude)
        if has_radius:
            # Exclude properties without valid coordinates and beyond radius_km
            base_query = base_query.where(
                Property.latitude.is_not(None),
                Property.longitude.is_not(None),
                dist_expr <= radius_km,
            )

    # 6. Total count calculation (after visibility, search, and filters, but before pagination)
    count_stmt = select(func.count()).select_from(base_query.subquery())
    total = db.scalar(count_stmt) or 0

    # 7. Sorting
    if sort_by == "distance":
        base_query = base_query.order_by(
            dist_expr.asc().nulls_last(),
            Property.id.desc(),
        )
    elif sort_by == "rent_low_to_high":
        min_rent_sub = (
            select(func.min(Room.monthly_rent))
            .where(Room.property_id == Property.id)
            .scalar_subquery()
        )
        base_query = base_query.order_by(
            min_rent_sub.asc().nulls_last(),
            Property.id.desc(),
        )
    elif sort_by == "rent_high_to_low":
        min_rent_sub = (
            select(func.min(Room.monthly_rent))
            .where(Room.property_id == Property.id)
            .scalar_subquery()
        )
        base_query = base_query.order_by(
            min_rent_sub.desc().nulls_last(),
            Property.id.desc(),
        )
    else:  # "newest"
        base_query = base_query.order_by(
            Property.created_at.desc(),
            Property.id.desc(),
        )

    # 8. Pagination and Fetching
    offset = (page - 1) * page_size
    if dist_expr is not None:
        items_stmt = (
            base_query.options(selectinload(Property.images))
            .add_columns(dist_expr.label("distance_km"))
            .offset(offset)
            .limit(page_size)
        )
        rows = db.execute(items_stmt).all()
        items = []
        for prop, dist in rows:
            prop.distance_km = round(dist, 2) if dist is not None else None
            items.append(prop)
    else:
        items_stmt = (
            base_query.options(selectinload(Property.images))
            .offset(offset)
            .limit(page_size)
        )
        items = db.scalars(items_stmt).all()

    return PropertyListResponse(
        items=items,
        page=page,
        page_size=page_size,
        total=total,
    )


@router.get("/my", response_model=list[PropertyResponse])
def get_my_properties(
    current_user: User = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    """Owner endpoint to view all properties they own with verification and availability status."""
    stmt = (
        select(Property)
        .options(
            selectinload(Property.rooms),
            selectinload(Property.amenities),
            selectinload(Property.images),
        )
        .where(Property.owner_id == current_user.id)
        .order_by(Property.created_at.desc())
    )
    return db.scalars(stmt).all()


@router.get("/{property_id}", response_model=PropertyDetailResponse)
def get_property_detail(
    property_id: int,
    db: Session = Depends(get_db),
):
    """Public endpoint to view property details including rooms, amenities, and images."""
    stmt = (
        select(Property)
        .options(
            selectinload(Property.rooms),
            selectinload(Property.amenities),
            selectinload(Property.images),
        )
        .where(
            Property.id == property_id,
            Property.is_available.is_(True),
            Property.is_verified.is_(True),
        )
    )
    property_obj = db.scalar(stmt)
    if not property_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found",
        )
    return property_obj


@router.patch("/{property_id}", response_model=PropertyResponse)
def update_property(
    property_id: int,
    property_in: PropertyUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update a property. Allowed for the owning user or platform administrators."""
    if current_user.role not in ["owner", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operation not permitted",
        )

    property_obj = db.scalar(select(Property).where(Property.id == property_id))
    if not property_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found",
        )

    if current_user.role == "owner" and property_obj.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this property",
        )

    update_data = property_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(property_obj, field, value)

    db.commit()
    db.refresh(property_obj)
    return property_obj


@router.delete("/{property_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_property(
    property_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a property. Allowed for the owning user or platform administrators."""
    if current_user.role not in ["owner", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operation not permitted",
        )

    property_obj = db.scalar(select(Property).where(Property.id == property_id))
    if not property_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found",
        )

    if current_user.role == "owner" and property_obj.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this property",
        )

    db.delete(property_obj)
    db.commit()
    return None


@router.post(
    "/{property_id}/images",
    response_model=PropertyImageResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_property_image_endpoint(
    property_id: int,
    file: UploadFile = File(..., description="Property image file (JPEG, PNG, WebP up to 5 MB)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Upload an image for a property. Restricted to the property owner or admin."""
    # 1. Require authentication & authorization
    if current_user.role not in ["owner", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operation not permitted",
        )

    # 2. Check property existence
    property_obj = db.scalar(select(Property).where(Property.id == property_id))
    if not property_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found",
        )

    # 3. Verify owner permissions
    if current_user.role == "owner" and property_obj.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to upload images for this property",
        )

    # 4. Read file content
    file_bytes = await file.read()

    # 5. Validate file content and size
    try:
        content_type = file.content_type or "image/jpeg"
        verified_mime = validate_image_file(file_bytes, content_type)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    # 6. Upload via Supabase storage utility
    try:
        upload_result = upload_property_image(
            property_id=property_id,
            file_bytes=file_bytes,
            content_type=verified_mime,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Storage upload failed: {str(e)}",
        )

    storage_path = upload_result["storage_path"]
    public_url = upload_result["public_url"]

    # 7. Persist to PostgreSQL database (prevent orphan storage files if DB fails)
    try:
        image_record = save_property_image_record(
            db=db,
            property_id=property_id,
            image_url=public_url,
            storage_path=storage_path,
        )
        return image_record
    except Exception as e:
        # Clean up uploaded storage object if database save fails
        try:
            delete_property_image(storage_path)
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database persistence failed: {str(e)}",
        )


@router.delete(
    "/{property_id}/images/{image_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_property_image_endpoint(
    property_id: int,
    image_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a property image. Restricted to the property owner or admin."""
    # 1. Require authentication & authorization
    if current_user.role not in ["owner", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operation not permitted",
        )

    # 2. Check property existence
    property_obj = db.scalar(select(Property).where(Property.id == property_id))
    if not property_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found",
        )

    # 3. Verify owner permissions
    if current_user.role == "owner" and property_obj.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete images for this property",
        )

    # 4. Find image record
    image_record = db.scalar(
        select(PropertyImage).where(PropertyImage.id == image_id)
    )
    if not image_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Image not found",
        )

    # 5. Verify image belongs to property
    if image_record.property_id != property_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Image does not belong to the specified property",
        )

    # 6. Delete from Supabase Storage using storage_path
    if image_record.storage_path:
        try:
            delete_property_image(image_record.storage_path)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to delete image from storage: {str(e)}",
            )

    # 7. Delete record from PostgreSQL
    try:
        db.delete(image_record)
        db.commit()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete image record from database: {str(e)}",
        )

    return None
