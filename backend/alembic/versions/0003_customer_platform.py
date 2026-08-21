"""customer accounts, announcements, orders and loyalty tiers

Revision ID: 0003_customer_platform
Revises: 0002_menu_schema
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0003_customer_platform"
down_revision = "0002_menu_schema"
branch_labels = None
depends_on = None


def upgrade() -> None:
    tables = set(inspect(op.get_bind()).get_table_names())

    if "customers" not in tables:
        op.create_table(
            "customers",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.UniqueConstraint("user_id", "restaurant_id", name="uq_customer_restaurant"),
        )
        op.create_index("ix_customers_user_id", "customers", ["user_id"])
        op.create_index("ix_customers_restaurant_id", "customers", ["restaurant_id"])

    if "loyalty_tiers" not in tables:
        op.create_table(
            "loyalty_tiers",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("name", sa.String(100), nullable=False),
            sa.Column("min_spend", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("discount_percent", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        )
        op.create_index("ix_loyalty_tiers_restaurant_id", "loyalty_tiers", ["restaurant_id"])

    if "announcements" not in tables:
        op.create_table(
            "announcements",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("image", sa.String(500), nullable=True),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("starts_at", sa.DateTime(), nullable=True),
            sa.Column("ends_at", sa.DateTime(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_announcements_restaurant_id", "announcements", ["restaurant_id"])

    if "orders" not in tables:
        op.create_table(
            "orders",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("subtotal", sa.Integer(), nullable=False),
            sa.Column("discount_amount", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("total_amount", sa.Integer(), nullable=False),
            sa.Column("status", sa.String(20), nullable=False, server_default="completed"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_orders_user_id", "orders", ["user_id"])
        op.create_index("ix_orders_restaurant_id", "orders", ["restaurant_id"])

    if "order_items" not in tables:
        op.create_table(
            "order_items",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
            sa.Column("product_id", sa.Integer(), sa.ForeignKey("products.id", ondelete="SET NULL"), nullable=True),
            sa.Column("product_name", sa.String(255), nullable=False),
            sa.Column("unit_price", sa.Integer(), nullable=False),
            sa.Column("quantity", sa.Integer(), nullable=False, server_default="1"),
        )
        op.create_index("ix_order_items_order_id", "order_items", ["order_id"])


def downgrade() -> None:
    for table in ("order_items", "orders", "announcements", "loyalty_tiers", "customers"):
        if table in inspect(op.get_bind()).get_table_names():
            op.drop_table(table)
