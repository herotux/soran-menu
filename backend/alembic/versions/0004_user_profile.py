"""add customer profile fields

Revision ID: 0004_user_profile
Revises: 0003_customer_platform
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0004_user_profile"
down_revision = "0003_customer_platform"
branch_labels = None
depends_on = None


def upgrade() -> None:
    columns = {c["name"] for c in inspect(op.get_bind()).get_columns("users")}
    if "name" not in columns:
        op.add_column("users", sa.Column("name", sa.String(255), nullable=True))
    if "phone" not in columns:
        op.add_column("users", sa.Column("phone", sa.String(50), nullable=True))
        op.create_index("ix_users_phone", "users", ["phone"])


def downgrade() -> None:
    columns = {c["name"] for c in inspect(op.get_bind()).get_columns("users")}
    if "phone" in columns:
        op.drop_index("ix_users_phone", table_name="users")
        op.drop_column("users", "phone")
    if "name" in columns:
        op.drop_column("users", "name")
