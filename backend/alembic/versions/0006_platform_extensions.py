"""extend customer platform for discounts, loyalty ledger and wallets

Revision ID: 0006_platform_extensions
Revises: 0005_announcement_reads
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0006_platform_extensions"
down_revision = "0005_announcement_reads"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    tables = set(inspector.get_table_names())

    customer_columns = {c["name"] for c in inspector.get_columns("customers")}
    if "points" not in customer_columns:
        op.add_column("customers", sa.Column("points", sa.Integer(), nullable=False, server_default="0"))
    if "total_spent" not in customer_columns:
        op.add_column("customers", sa.Column("total_spent", sa.Integer(), nullable=False, server_default="0"))
    if "visit_count" not in customer_columns:
        op.add_column("customers", sa.Column("visit_count", sa.Integer(), nullable=False, server_default="0"))
    if "tier" not in customer_columns:
        op.add_column("customers", sa.Column("tier", sa.String(20), nullable=False, server_default="bronze"))

    order_columns = {c["name"] for c in inspector.get_columns("orders")}
    if "note" not in order_columns:
        op.add_column("orders", sa.Column("note", sa.Text(), nullable=True))
    if "completed_at" not in order_columns:
        op.add_column("orders", sa.Column("completed_at", sa.DateTime(), nullable=True))

    if "discount_codes" not in tables:
        op.create_table(
            "discount_codes",
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
            sa.Column("expires_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("restaurant_id", "code", name="uq_discount_restaurant_code"),
        )
        op.create_index("ix_discount_codes_restaurant_id", "discount_codes", ["restaurant_id"])

    if "loyalty_transactions" not in tables:
        op.create_table(
            "loyalty_transactions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("restaurant_id", sa.Integer(), sa.ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("customer_id", sa.Integer(), sa.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False),
            sa.Column("points", sa.Integer(), nullable=False),
            sa.Column("reason", sa.String(255), nullable=False),
            sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="SET NULL"), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_loyalty_transactions_customer_id", "loyalty_transactions", ["customer_id"])
        op.create_index("ix_loyalty_transactions_restaurant_id", "loyalty_transactions", ["restaurant_id"])

    if "wallets" not in tables:
        op.create_table(
            "wallets",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("customer_id", sa.Integer(), sa.ForeignKey("customers.id", ondelete="CASCADE"), nullable=False),
            sa.Column("balance", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.UniqueConstraint("customer_id", name="uq_wallet_customer"),
        )

    if "wallet_transactions" not in tables:
        op.create_table(
            "wallet_transactions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("wallet_id", sa.Integer(), sa.ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False),
            sa.Column("amount", sa.Integer(), nullable=False),
            sa.Column("kind", sa.String(30), nullable=False),
            sa.Column("description", sa.String(255), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
        )
        op.create_index("ix_wallet_transactions_wallet_id", "wallet_transactions", ["wallet_id"])


def downgrade() -> None:
    bind = op.get_bind()
    tables = set(inspect(bind).get_table_names())
    for table in ("wallet_transactions", "wallets", "loyalty_transactions", "discount_codes"):
        if table in tables:
            op.drop_table(table)
    order_columns = {c["name"] for c in inspect(bind).get_columns("orders")}
    if "completed_at" in order_columns:
        op.drop_column("orders", "completed_at")
    if "note" in order_columns:
        op.drop_column("orders", "note")
    customer_columns = {c["name"] for c in inspect(bind).get_columns("customers")}
    for column in ("tier", "visit_count", "total_spent", "points"):
        if column in customer_columns:
            op.drop_column("customers", column)
