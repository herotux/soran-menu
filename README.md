# SoranSib

SaaS platform for multiple restaurant owners, where **one installation serves many independent tenants** and each tenant can manage multiple restaurants.

## Architecture

```text
                    SoranSib SaaS
                         │
          ┌──────────────┼──────────────┐
          │              │              │
       Tenant A        Tenant B       Tenant C
          │              │              │
       R1  R2          R3  R4            R5
          │              │              │
          └──────────────┴──────────────┘
                         │
                 FastAPI + PostgreSQL
                         │
                Flutter Admin / Customer
                         │
                    Astro Website
```

The database is the source of truth. GitHub is used for source control and CI/CD, not as the production menu database.

## Tenant isolation

A tenant represents one restaurant business/account. A tenant can own multiple restaurants. Users are connected to tenants through `tenant_memberships` and to individual restaurants through `memberships`.

Every restaurant belongs to exactly one tenant. Authenticated restaurant-management requests are scoped to the selected tenant using the `X-Tenant-ID` header. If a user belongs to exactly one tenant, the header may be omitted. Users belonging to multiple tenants must explicitly select one.

This prevents a user from using a valid restaurant membership to access a restaurant belonging to another tenant.

## Repository layout

- `backend/` — FastAPI, SQLAlchemy, Alembic, PostgreSQL integration
- `website/` — Astro public menu
- `admin_app/` — Flutter RTL admin application (`soransib` package)
- `docker-compose.yml` — complete local/server stack
- `.github/workflows/` — backend tests, Flutter APK, and website deployment

## Backend API

Public:

- `GET /api/public/restaurants/{slug}/menu`
- `GET /health`

Authentication:

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/auth/me/restaurants`

Tenant management:

- `GET /api/tenants`

Authenticated restaurant management:

- `GET|POST /api/restaurants`
- `GET|PATCH|DELETE /api/restaurants/{restaurant_id}`
- `GET|POST /api/restaurants/{restaurant_id}/categories`
- `PATCH|DELETE /api/restaurants/{restaurant_id}/categories/{category_id}`
- `GET|POST /api/restaurants/{restaurant_id}/categories/{category_id}/products`
- `PATCH|DELETE /api/restaurants/{restaurant_id}/categories/{category_id}/products/{product_id}`
- `GET|PATCH /api/restaurants/{restaurant_id}/settings`
- `POST /api/uploads/image`

Restaurant access is enforced through both tenant membership and restaurant membership. Owner/admin roles can manage menu content.

## Database migrations

`0001_initial` through `0006_platform_extensions` build the existing restaurant and customer platform.

`0007_multi_tenant_saas` introduces tenants, tenant memberships, tenant-scoped restaurants, and a data backfill that groups existing restaurants owned by the same user into one tenant.

Run:

```bash
docker compose run --rm api alembic upgrade head
```

## Tests

Backend tests live under `backend/tests` and run in CI:

```bash
cd backend
pip install -r requirements.txt
pytest -q
```

## Full stack with Docker

Create `backend/.env` with at least `DATABASE_URL` and `JWT_SECRET`, then configure `RESTAURANT_SLUG` for the website build.

```bash
docker compose up -d --build
```

The API is exposed on port `8000` and the website on port `8080` by default.

## Website API build

Set:

```bash
API_URL=https://your-api.example.com \
RESTAURANT_SLUG=your-restaurant-slug \
npm run build
```

If the API is unavailable during a build, the bundled menu remains available as a fallback while the backend integration is being deployed.

## Flutter

The Flutter package is named `soransib` and is configured to use the restaurant logo as its launcher icon. Production work remains to make all admin and customer screens consume the authenticated multi-tenant API consistently.
