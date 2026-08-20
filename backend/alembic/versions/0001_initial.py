"""initial database schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-20
"""

from alembic import op
import sqlalchemy as sa


revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "restaurants",
        sa.Column(
            "id",
            sa.Integer(),
            primary_key=True,
        ),
        sa.Column(
            "name",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "slug",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
    )

    op.create_index(
        "ix_restaurants_id",
        "restaurants",
        ["id"],
    )

    op.create_index(
        "ix_restaurants_slug",
        "restaurants",
        ["slug"],
        unique=True,
    )

    op.create_table(
        "users",
        sa.Column(
            "id",
            sa.Integer(),
            primary_key=True,
        ),
        sa.Column(
            "email",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
        ),
    )

    op.create_index(
        "ix_users_id",
        "users",
        ["id"],
    )

    op.create_index(
        "ix_users_email",
        "users",
        ["email"],
        unique=True,
    )

    op.create_table(
        "memberships",
        sa.Column(
            "id",
            sa.Integer(),
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "restaurant_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "role",
            sa.String(length=20),
            nullable=False,
            server_default="staff",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["restaurant_id"],
            ["restaurants.id"],
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "user_id",
            "restaurant_id",
            name="uq_user_restaurant",
        ),
    )




def downgrade() -> None:
    op.drop_table("memberships")

    op.drop_index(
        "ix_users_email",
        table_name="users",
    )

    op.drop_index(
        "ix_users_id",
        table_name="users",
    )

    op.drop_table("users")

    op.drop_index(
        "ix_restaurants_slug",
        table_name="restaurants",
    )

    op.drop_index(
        "ix_restaurants_id",
        table_name="restaurants",
    )

    op.drop_table("restaurants")
