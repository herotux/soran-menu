"""multi-tenant customer platform

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
    bind = op.get_bind()
    tables = set(inspect(bind).get_table_names())
    users = {c["name"] for c in inspect(bind).get_columns("users")}
    if "name" not in users:
        op.add_column("users", sa.Column("name", sa.String(255), nullable=True))
    if "phone" not in users:
        op.add_column("users", sa.Column("phone", sa.String(50), nullable=True))

    if "customer_restaurants" not in tables:
        op.create_table("customer_restaurants",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("points", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("total_spent", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("visit_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("tier", sa.String(20), nullable=False, server_default="bronze"),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.UniqueConstraint("user_id", "restaurant_id", name="uq_customer_restaurant"))
        op.create_index("ix_customer_restaurants_user_id", "customer_restaurants", ["user_id"])
        op.create_index("ix_customer_restaurants_restaurant_id", "customer_restaurants", ["restaurant_id"])

    if "orders" not in tables:
        op.create_table("orders",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("customer_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
            sa.Column("subtotal", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("discount_amount", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("total", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("note", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("completed_at", sa.DateTime(), nullable=True))
        op.create_index("ix_orders_restaurant_id", "orders", ["restaurant_id"])
        op.create_index("ix_orders_customer_id", "orders", ["customer_id"])
        op.create_index("ix_orders_status", "orders", ["status"])
        op.create_index("ix_orders_created_at", "orders", ["created_at"])

    if "order_items" not in tables:
        op.create_table("order_items",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
            sa.Column("product_id", sa.Integer(), sa.ForeignKey("products.id", ondelete="RESTRICT"), nullable=False),
            sa.Column("name", sa.String(255), nullable=False),
            sa.Column("unit_price", sa.Integer(), nullable=False),
            sa.Column("quantity", sa.Integer(), nullable=False),
            sa.Column("line_total", sa.Integer(), nullable=False))
        op.create_index("ix_order_items_order_id", "order_items", ["order_id"])

    if "discount_codes" not in tables:
        op.create_table("discount_codes",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("code", sa.String(50), nullable=False),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("discount_type", sa.String(20), nullable=False),
            sa.Column("amount", sa.Integer(), nullable=False),
            sa.Column("min_purchase", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("max_discount", sa.Integer(), nullable=True),
            sa.Column("min_visits", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("min_spent", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("usage_limit", sa.Integer(), nullable=True),
            sa.Column("used_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("expires_at", sa.DateTime(), nullable=True))
        op.create_index("ix_discount_codes_restaurant_id", "discount_codes", ["restaurant_id"])
        op.create_index("ix_discount_codes_code", "discount_codes", ["code"])

    if "notifications" not in tables:
        op.create_table("notifications",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("body", sa.Text(), nullable=False),
            sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_at", sa.DateTime(), nullable=False))
        op.create_index("ix_notifications_restaurant_id", "notifications", ["restaurant_id"])

    if "loyalty_transactions" not in tables:
        op.create_table("loyalty_transactions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("customer_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("points", sa.Integer(), nullable=False),
            sa.Column("reason", sa.String(255), nullable=False),
            sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="SET NULL"), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False))
        op.create_index("ix_loyalty_transactions_restaurant_id", "loyalty_transactions", ["restaurant_id"])
        op.create_index("ix_loyalty_transactions_customer_id", "loyalty_transactions", ["customer_id"])

    if "wallets" not in tables:
        op.create_table("wallets",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("balance", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.UniqueConstraint("user_id", "restaurant_id", name="uq_wallet_customer_restaurant"))

    if "wallet_transactions" not in tables:
        op.create_table("wallet_transactions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("wallet_id", sa.Integer(), sa.ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False),
            sa.Column("amount", sa.Integer(), nullable=False),
            sa.Column("kind", sa.String(30), nullable=False),
            sa.Column("description", sa.String(255), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False))
        op.create_index("ix_wallet_transactions_wallet_id", "wallet_transactions", ["wallet_id"])


def downgrade() -> None:
    for table in ["wallet_transactions", "wallets", "loyalty_transactions", "notifications", "discount_codes", "order_items", "orders", "customer_restaurants"]:
        if table in inspect(op.get_bind()).get_table_names():
            op.drop_table(table)
    users = {c["name"] for c in inspect(op.get_bind()).get_columns("users")}
    if "phone" in users:
        op.drop_column("users", "phone")
    if "name" in users:
        op.drop_column("users", "name")
