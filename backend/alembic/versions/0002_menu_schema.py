"""add restaurant menu schema

Revision ID: 0002_menu_schema
Revises: 0001_initial
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0002_menu_schema"
down_revision = "0001_initial"
branch_labels = None
depends_on = None

RESTAURANT_COLUMNS = {
    "description": sa.String(2000),
    "logo": sa.String(500),
    "phone": sa.String(50),
    "mobile": sa.String(50),
    "address": sa.String(1000),
    "instagram": sa.String(255),
    "telegram": sa.String(255),
    "theme_background": sa.String(20),
    "theme_accent": sa.String(20),
    "theme_secondary": sa.String(20),
}


def upgrade() -> None:
    inspector = inspect(op.get_bind())

    restaurant_columns = {column["name"] for column in inspector.get_columns("restaurants")}
    for name, column_type in RESTAURANT_COLUMNS.items():
        if name not in restaurant_columns:
            op.add_column("restaurants", sa.Column(name, column_type, nullable=True))

    tables = set(inspector.get_table_names())
    if "categories" not in tables:
        op.create_table(
            "categories",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("external_id", sa.String(255), nullable=True),
            sa.Column("name", sa.String(255), nullable=False),
            sa.Column("image", sa.String(500), nullable=True),
            sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_categories_restaurant_id", "categories", ["restaurant_id"])

    if "products" not in tables:
        op.create_table(
            "products",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("category_id", sa.Integer(), sa.ForeignKey("categories.id", ondelete="CASCADE"), nullable=False),
            sa.Column("external_id", sa.String(255), nullable=True),
            sa.Column("name", sa.String(255), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            sa.Column("price", sa.Integer(), nullable=False),
            sa.Column("old_price", sa.Integer(), nullable=True),
            sa.Column("image", sa.String(500), nullable=True),
            sa.Column("available", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_products_category_id", "products", ["category_id"])


def downgrade() -> None:
    inspector = inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    if "products" in tables:
        op.drop_index("ix_products_category_id", table_name="products")
        op.drop_table("products")
    if "categories" in tables:
        op.drop_index("ix_categories_restaurant_id", table_name="categories")
        op.drop_table("categories")
    for column in reversed(list(RESTAURANT_COLUMNS)):
        current = {item["name"] for item in inspect(op.get_bind()).get_columns("restaurants")}
        if column in current:
            op.drop_column("restaurants", column)
