# SoranSib multi-tenant platform

SoranSib now uses a central-server multi-tenant architecture.

## Tenancy model

- One deployment serves many restaurants.
- A `User` can own/manage multiple restaurants through `memberships`.
- A customer can be associated with many restaurants through `customer_restaurants`.
- Orders, loyalty points, discounts, notifications, wallets and reports are always scoped by `restaurant_id`.
- Public menus are selected by restaurant slug.

## Main roles

- `owner`: full control of a restaurant.
- `admin`: operational management without ownership transfer.
- `staff`: menu/operational access according to endpoint permissions.
- customer: can register, browse restaurants and menus, receive announcements, place orders, earn loyalty points and use eligible discounts.

## Customer lifecycle

1. Register/login.
2. Discover restaurants.
3. Select a restaurant and view its menu.
4. Receive restaurant announcements.
5. Place an order.
6. Completed orders update spend, visit count, loyalty points and tier.
7. Purchase history unlocks targeted discounts.
8. Customer can view wallet and loyalty history.

## Loyalty tiers

The initial rules are deterministic and server-side:

- bronze: default
- silver: 5 visits or 500,000 spend
- gold: 10 visits or 2,000,000 spend
- platinum: 20 visits or 5,000,000 spend

The thresholds can later be moved to restaurant settings without changing the API contract.

## Deployment

The central deployment consists of PostgreSQL and one FastAPI service. PostgreSQL and uploaded media use persistent Docker volumes. The API container runs Alembic migrations before starting Uvicorn.

Recommended production topology:

`Internet -> reverse proxy/TLS -> API -> PostgreSQL`

The mobile customer app and owner/admin app use the same API and select a restaurant by ID/slug.
