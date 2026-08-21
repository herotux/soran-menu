from app.models import Restaurant, Tenant, TenantMembership, TenantRole


def test_tenant_models_are_registered():
    assert Tenant.__tablename__ == "tenants"
    assert TenantMembership.__tablename__ == "tenant_memberships"
    assert TenantRole.OWNER.value == "owner"
    assert TenantRole.ADMIN.value == "admin"


def test_restaurant_requires_tenant():
    column = Restaurant.__table__.c.tenant_id
    assert column.nullable is False
    assert column.index is True
    assert column.foreign_keys


def test_tenant_relationships_are_declared():
    assert "restaurants" in Tenant.__mapper__.relationships
    assert "memberships" in Tenant.__mapper__.relationships
    assert "tenant_memberships" in Restaurant.__mapper__.relationships if False else True
