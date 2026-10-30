from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.inquiry import Inquiry
from app.models.property import Property
from app.models.user import User
from app.schemas.inquiry import InquiryCreate, InquiryResponse, InquiryStatusUpdate

router = APIRouter(prefix="/inquiries", tags=["Inquiries"])


def mask_phone_number(phone: str) -> str:
    """Masks middle digits of phone number for privacy (e.g. +91 98******10)."""
    clean = phone.strip()
    if len(clean) <= 4:
        return "****"
    # Show first 2 and last 2 characters, mask middle
    visible_prefix = clean[:2]
    visible_suffix = clean[-2:]
    masked_middle = "*" * max(4, len(clean) - 4)
    return f"{visible_prefix}{masked_middle}{visible_suffix}"


def serialize_inquiry_for_user(inquiry: Inquiry, current_user_id: int) -> dict:
    """
    Serializes inquiry with phone privacy enforcement:
    - If current user is the student, show full phone.
    - If current user is the owner AND status is 'confirmed' or 'completed', show full phone.
    - If current user is the owner AND status is 'pending' or 'rejected', MASK phone number.
    """
    is_student = inquiry.student_id == current_user_id
    is_confirmed_or_done = inquiry.status in ("confirmed", "completed")

    phone_to_show = inquiry.contact_phone
    if not is_student and not is_confirmed_or_done:
        phone_to_show = mask_phone_number(inquiry.contact_phone)

    return {
        "id": inquiry.id,
        "property_id": inquiry.property_id,
        "student_id": inquiry.student_id,
        "owner_id": inquiry.owner_id,
        "visit_date": inquiry.visit_date,
        "sharing_preference": inquiry.sharing_preference,
        "contact_phone": phone_to_show,
        "message": inquiry.message,
        "status": inquiry.status,
        "created_at": inquiry.created_at,
        "updated_at": inquiry.updated_at,
        "property": inquiry.property,
        "student": inquiry.student,
    }


@router.post("", response_model=InquiryResponse, status_code=status.HTTP_201_CREATED)
def create_inquiry(
    payload: InquiryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Student submits an inquiry / visit schedule request."""
    # 1. Fetch property
    prop = db.scalar(select(Property).where(Property.id == payload.property_id))
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    if prop.owner_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot submit an inquiry for your own property",
        )

    # 2. Create inquiry
    new_inquiry = Inquiry(
        property_id=prop.id,
        student_id=current_user.id,
        owner_id=prop.owner_id,
        visit_date=payload.visit_date,
        sharing_preference=payload.sharing_preference,
        contact_phone=payload.contact_phone,
        message=payload.message,
        status="pending",
    )
    db.add(new_inquiry)
    db.commit()
    db.refresh(new_inquiry)

    # Eager load relationships for response
    stmt = (
        select(Inquiry)
        .options(
            selectinload(Inquiry.property).selectinload(Property.images),
            selectinload(Inquiry.student),
        )
        .where(Inquiry.id == new_inquiry.id)
    )
    loaded = db.scalar(stmt)
    return serialize_inquiry_for_user(loaded, current_user.id)


@router.get("/my-sent", response_model=list[InquiryResponse])
def get_my_sent_inquiries(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Student fetches inquiries they sent."""
    stmt = (
        select(Inquiry)
        .options(
            selectinload(Inquiry.property).selectinload(Property.images),
            selectinload(Inquiry.student),
        )
        .where(Inquiry.student_id == current_user.id)
        .order_by(Inquiry.created_at.desc())
    )
    inquiries = db.scalars(stmt).all()
    return [serialize_inquiry_for_user(inq, current_user.id) for inq in inquiries]


@router.get("/my-received", response_model=list[InquiryResponse])
def get_my_received_inquiries(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Owner fetches inquiries received for their properties."""
    stmt = (
        select(Inquiry)
        .options(
            selectinload(Inquiry.property).selectinload(Property.images),
            selectinload(Inquiry.student),
        )
        .where(Inquiry.owner_id == current_user.id)
        .order_by(Inquiry.created_at.desc())
    )
    inquiries = db.scalars(stmt).all()
    return [serialize_inquiry_for_user(inq, current_user.id) for inq in inquiries]


@router.patch("/{inquiry_id}/status", response_model=InquiryResponse)
def update_inquiry_status(
    inquiry_id: int,
    payload: InquiryStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Owner accepts/confirms, rejects, or marks inquiry completed."""
    stmt = (
        select(Inquiry)
        .options(
            selectinload(Inquiry.property).selectinload(Property.images),
            selectinload(Inquiry.student),
        )
        .where(Inquiry.id == inquiry_id)
    )
    inquiry = db.scalar(stmt)
    if not inquiry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inquiry not found")

    if inquiry.owner_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the property owner can update inquiry status",
        )

    inquiry.status = payload.status
    db.commit()
    db.refresh(inquiry)
    return serialize_inquiry_for_user(inquiry, current_user.id)

