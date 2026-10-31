"""create favorites inquiries reviews tables

Revision ID: 8de5b77941b2
Revises: 4182ce66c462
Create Date: 2026-10-31 16:16:36.866267

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8de5b77941b2'
down_revision: Union[str, Sequence[str], None] = '4182ce66c462'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # 1. Favorites table
    op.create_table(
        'favorites',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('property_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['property_id'], ['properties.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'property_id', name='uq_user_property_favorite'),
        if_not_exists=True,
    )
    op.create_index(op.f('ix_favorites_property_id'), 'favorites', ['property_id'], unique=False, if_not_exists=True)
    op.create_index(op.f('ix_favorites_user_id'), 'favorites', ['user_id'], unique=False, if_not_exists=True)

    # 2. Inquiries table
    op.create_table(
        'inquiries',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('property_id', sa.Integer(), nullable=False),
        sa.Column('student_id', sa.Integer(), nullable=False),
        sa.Column('owner_id', sa.Integer(), nullable=False),
        sa.Column('visit_date', sa.DateTime(timezone=True), nullable=False),
        sa.Column('sharing_preference', sa.String(length=50), nullable=False),
        sa.Column('contact_phone', sa.String(length=20), nullable=False),
        sa.Column('message', sa.Text(), nullable=True),
        sa.Column('status', sa.String(length=30), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['property_id'], ['properties.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        if_not_exists=True,
    )
    op.create_index(op.f('ix_inquiries_owner_id'), 'inquiries', ['owner_id'], unique=False, if_not_exists=True)
    op.create_index(op.f('ix_inquiries_property_id'), 'inquiries', ['property_id'], unique=False, if_not_exists=True)
    op.create_index(op.f('ix_inquiries_student_id'), 'inquiries', ['student_id'], unique=False, if_not_exists=True)

    # 3. Reviews table
    op.create_table(
        'reviews',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('property_id', sa.Integer(), nullable=False),
        sa.Column('student_id', sa.Integer(), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('comment', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('rating >= 1 AND rating <= 5', name='check_rating_range_1_to_5'),
        sa.ForeignKeyConstraint(['property_id'], ['properties.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('property_id', 'student_id', name='uq_property_student_review'),
        if_not_exists=True,
    )
    op.create_index(op.f('ix_reviews_property_id'), 'reviews', ['property_id'], unique=False, if_not_exists=True)
    op.create_index(op.f('ix_reviews_student_id'), 'reviews', ['student_id'], unique=False, if_not_exists=True)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_reviews_student_id'), table_name='reviews', if_exists=True)
    op.drop_index(op.f('ix_reviews_property_id'), table_name='reviews', if_exists=True)
    op.drop_table('reviews', if_exists=True)

    op.drop_index(op.f('ix_inquiries_student_id'), table_name='inquiries', if_exists=True)
    op.drop_index(op.f('ix_inquiries_property_id'), table_name='inquiries', if_exists=True)
    op.drop_index(op.f('ix_inquiries_owner_id'), table_name='inquiries', if_exists=True)
    op.drop_table('inquiries', if_exists=True)

    op.drop_index(op.f('ix_favorites_user_id'), table_name='favorites', if_exists=True)
    op.drop_index(op.f('ix_favorites_property_id'), table_name='favorites', if_exists=True)
    op.drop_table('favorites', if_exists=True)
