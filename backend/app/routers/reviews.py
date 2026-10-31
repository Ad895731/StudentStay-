from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.inquiry import Inquiry
from app.models.property import Property
from app.models.review import Review
from app.models.user import User
from app.schemas.review import PropertyRatingSummary, ReviewCreate, ReviewResponse

router = APIRouter(prefix="/properties", tags=["Reviews"])


@router.get("/{property_id}/can-review")
def check_can_review(
    property_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Check if the current student is verified/eligible to review this stay.
    To prevent fake reviews, only students who have a confirmed or completed visit
    can leave a rating/review.
    """
    prop = db.scalar(select(Property).where(Property.id == property_id))
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    if prop.owner_id == current_user.id:
        return {
            "can_review": False,
            "reason": "Property owners cannot review their own stay.",
        }

    # Verify if student has a confirmed or completed inquiry/visit
    verified_visit = db.scalar(
        select(Inquiry).where(
            Inquiry.property_id == property_id,
            Inquiry.student_id == current_user.id,
            Inquiry.status.in_(["confirmed", "completed"]),
        )
    )
    if not verified_visit:
        return {
            "can_review": False,
            "reason": "Only verified students with a confirmed visit or stay can write a review.",
        }

    return {
        "can_review": True,
        "reason": "Eligible to write a review.",
    }


@router.post("/{property_id}/reviews", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
def submit_or_update_review(
    property_id: int,
    payload: ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Student submits or updates their rating and review for a stay.
    Enforces verified resident integrity: student must have a confirmed/completed visit.
    """
    prop = db.scalar(select(Property).where(Property.id == property_id))
    if not prop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Property not found")

    if prop.owner_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Owners cannot review their own property",
        )

    # Fake review prevention: ensure student actually visited or stayed at this property
    verified_visit = db.scalar(
        select(Inquiry).where(
            Inquiry.property_id == property_id,
            Inquiry.student_id == current_user.id,
            Inquiry.status.in_(["confirmed", "completed"]),
        )
    )
    if not verified_visit:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only verified students with a confirmed visit or booking can review this stay.",
        )

    # Check if student already reviewed this property (Upsert / Update if exists)
    stmt = select(Review).where(
        Review.property_id == property_id,
        Review.student_id == current_user.id,
    )
    existing_review = db.scalar(stmt)

    if existing_review:
        existing_review.rating = payload.rating
        existing_review.comment = payload.comment
        db.commit()
        db.refresh(existing_review)
        review = existing_review
    else:
        new_review = Review(
            property_id=property_id,
            student_id=current_user.id,
            rating=payload.rating,
            comment=payload.comment,
        )
        db.add(new_review)
        db.commit()
        db.refresh(new_review)
        review = new_review

    # Eager load student for response
    loaded_review = db.scalar(
        select(Review)
        .options(selectinload(Review.student))
        .where(Review.id == review.id)
    )
    return loaded_review


@router.get("/{property_id}/reviews", response_model=list[ReviewResponse])
def get_property_reviews(
    property_id: int,
    db: Session = Depends(get_db),
):
    """Fetch all reviews for a property ordered by newest first."""
    stmt = (
        select(Review)
        .options(selectinload(Review.student))
        .where(Review.property_id == property_id)
        .order_by(Review.created_at.desc())
    )
    return db.scalars(stmt).all()


@router.get("/{property_id}/rating-summary", response_model=PropertyRatingSummary)
def get_property_rating_summary(
    property_id: int,
    db: Session = Depends(get_db),
):
    """Compute average star rating and total review count for a stay."""
    stmt = select(
        func.avg(Review.rating),
        func.count(Review.id)
    ).where(Review.property_id == property_id)
    
    avg_rating, count = db.execute(stmt).one()
    return PropertyRatingSummary(
        average_rating=round(float(avg_rating), 1) if avg_rating is not None else 0.0,
        total_reviews=count or 0,
    )
