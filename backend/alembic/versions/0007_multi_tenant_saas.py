"""introduce tenant isolation for multi-tenant SaaS

Revision ID: 0007_multi_tenant_saas
Revises: 0006_platform_extensions
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0007_multi_tenant_saas"
down_revision = "0006_platform_extensions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    tables = set(inspector.get_table_names())

    if "tenants" not in tables:
        op.create_table(
            "tenants",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("name", sa.String(255), nullable=False),
            sa.Column("slug", sa.String(255), nullable=False),
        )
        op.create_index("ix_tenants_id", "tenants", ["id"])
        op.create_index("ix_tenants_slug", "tenants", ["slug"], unique=True)

    if "tenant_memberships" not in tables:
        op.create_table(
            "tenant_memberships",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("tenant_id", sa.Integer(), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("role", sa.String(20), nullable=False, server_default="admin"),
            sa.UniqueConstraint("tenant_id", "user_id", name="uq_tenant_user"),
        )
        op.create_index("ix_tenant_memberships_tenant_id", "tenant_memberships", ["tenant_id"])
        op.create_index("ix_tenant_memberships_user_id", "tenant_memberships", ["user_id"])

    restaurant_columns = {c["name"] for c in inspector.get_columns("restaurants")}
    if "tenant_id" not in restaurant_columns:
        op.add_column("restaurants", sa.Column("tenant_id", sa.Integer(), nullable=True))
        op.create_index("ix_restaurants_tenant_id", "restaurants", ["tenant_id"])
        op.create_foreign_key(
            "fk_restaurants_tenant_id",
            "restaurants",
            "tenants",
            ["tenant_id"],
            ["id"],
            ondelete="CASCADE",
        )

    # Backfill existing data. Restaurants owned by the same user are grouped
    # into one tenant, preserving the intended "one owner -> many restaurants" model.
    rows = bind.execute(sa.text("""
        SELECT r.id, r.name, m.user_id
        FROM restaurants r
        LEFT JOIN memberships m
          ON m.restaurant_id = r.id AND m.role = 'owner'
        WHERE r.tenant_id IS NULL
        ORDER BY r.id
    """)).mappings().all()

    tenant_by_owner: dict[int, int] = {}
    for row in rows:
        owner_id = row["user_id"]
        tenant_id = tenant_by_owner.get(owner_id) if owner_id is not None else None
        if tenant_id is None and owner_id is not None:
            existing = bind.execute(
                sa.text("SELECT tm.tenant_id FROM tenant_memberships tm WHERE tm.user_id = :uid AND tm.role = 'owner' LIMIT 1"),
                {"uid": owner_id},
            ).scalar_one_or_none()
            tenant_id = existing

        if tenant_id is None:
            slug = f"tenant-{row['id']}"
            bind.execute(
                sa.text("INSERT INTO tenants (name, slug) VALUES (:name, :slug)"),
                {"name": row["name"], "slug": slug},
            )
            tenant_id = bind.execute(sa.text("SELECT id FROM tenants WHERE slug = :slug"), {"slug": slug}).scalar_one()

        if owner_id is not None:
            bind.execute(
                sa.text("""
                    INSERT INTO tenant_memberships (tenant_id, user_id, role)
                    VALUES (:tenant_id, :user_id, 'owner')
                    ON CONFLICT (tenant_id, user_id) DO NOTHING
                """),
                {"tenant_id": tenant_id, "user_id": owner_id},
            )
            tenant_by_owner[owner_id] = tenant_id

        bind.execute(
            sa.text("UPDATE restaurants SET tenant_id = :tenant_id WHERE id = :restaurant_id"),
            {"tenant_id": tenant_id, "restaurant_id": row["id"]},
        )

    # New schema invariant: every restaurant belongs to exactly one tenant.
    op.alter_column("restaurants", "tenant_id", nullable=False)


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if "restaurants" in inspector.get_table_names():
        op.drop_constraint("fk_restaurants_tenant_id", "restaurants", type_="foreignkey")
        op.drop_index("ix_restaurants_tenant_id", table_name="restaurants")
        op.drop_column("restaurants", "tenant_id")
    if "tenant_memberships" in inspector.get_table_names():
        op.drop_table("tenant_memberships")
    if "tenants" in inspector.get_table_names():
        op.drop_index("ix_tenants_slug", table_name="tenants")
        op.drop_index("ix_tenants_id", table_name="tenants")
        op.drop_table("tenants")
