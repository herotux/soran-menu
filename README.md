# SoranSib

Digital restaurant menu platform for a **single installation serving one owner with multiple restaurants**.

## Architecture

```text
SoranSib Flutter Admin ──┐
                         ├── HTTPS ── FastAPI ── PostgreSQL
Astro Website ───────────┘                 │
                                           └── media uploads
```

The database is the source of truth. GitHub is used for source control and CI/CD, not as the production menu database.

## Repository layout

- `backend/` — FastAPI, SQLAlchemy, Alembic, PostgreSQL integration
- `website/` — Astro public menu
- `admin_app/` — Flutter RTL admin application (`soransib` package)
- `docker-compose.yml` — complete local/server stack
- `.github/workflows/` — backend tests, Flutter APK, and website deployment

## Multi-tenant model

One installation supports:

- one owner account
- multiple restaurants per owner
- owner/admin/staff memberships per restaurant
- isolated categories/products/settings by restaurant

## Backend API

Public:

- `GET /api/public/restaurants/{slug}/menu`
- `GET /health`

Authenticated management:

- `GET|POST /api/restaurants`
- `GET|PATCH|DELETE /api/restaurants/{restaurant_id}`
- `GET|POST /api/restaurants/{restaurant_id}/categories`
- `PATCH|DELETE /api/restaurants/{restaurant_id}/categories/{category_id}`
- `GET|POST /api/restaurants/{restaurant_id}/categories/{category_id}/products`
- `PATCH|DELETE /api/restaurants/{restaurant_id}/categories/{category_id}/products/{product_id}`
- `GET|PATCH /api/restaurants/{restaurant_id}/settings`
- `POST /api/uploads/image`

Access is enforced through restaurant memberships; owner/admin roles can manage menu content.

## Database migrations

`0001_initial` creates the account/restaurant foundation.

`0002_menu_schema` adds restaurant profile/theme fields plus categories/products and is safe for installations where those objects already exist.

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

The Flutter package is already named `soransib` and is configured to use the restaurant logo as its launcher icon. The remaining production integration work is to make the server repository use the authenticated restaurant/category/product endpoints instead of the legacy `/api/v1/menu` blob contract.
