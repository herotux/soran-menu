"""add restaurant menu schema

Revision ID: 0002_menu_schema
Revises: 0001_initial
"""

from alembic import op
import sqlalchemy as sa

revision = "0002_menu_schema"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("restaurants", sa.Column("description", sa.String(2000), nullable=True))
    op.add_column("restaurants", sa.Column("logo", sa.String(500), nullable=True))
    op.add_column("restaurants", sa.Column("phone", sa.String(50), nullable=True))
    op.add_column("restaurants", sa.Column("mobile", sa.String(50), nullable=True))
    op.add_column("restaurants", sa.Column("address", sa.String(1000), nullable=True))
    op.add_column("restaurants", sa.Column("instagram", sa.String(255), nullable=True))
    op.add_column("restaurants", sa.Column("telegram", sa.String(255), nullable=True))
    op.add_column("restaurants", sa.Column("theme_background", sa.String(20), nullable=True))
    op.add_column("restaurants", sa.Column("theme_accent", sa.String(20), nullable=True))
    op.add_column("restaurants", sa.Column("theme_secondary", sa.String(20), nullable=True))

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
    op.drop_index("ix_products_category_id", table_name="products")
    op.drop_table("products")
    op.drop_index("ix_categories_restaurant_id", table_name="categories")
    op.drop_table("categories")
    for column in ["theme_secondary", "theme_accent", "theme_background", "telegram", "instagram", "address", "mobile", "phone", "logo", "description"]:
        op.drop_column("restaurants", column)
