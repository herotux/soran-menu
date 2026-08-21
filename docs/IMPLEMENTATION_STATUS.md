# Implementation status

## Completed in `feature/complete-system`

- [x] One installation supports one owner with multiple restaurants.
- [x] Restaurant membership roles are enforced by the backend dependency layer.
- [x] Restaurant profile/theme fields.
- [x] Category and product persistence models.
- [x] Safe menu migration for both clean and already-populated installations.
- [x] Restaurant CRUD.
- [x] Category CRUD.
- [x] Product CRUD.
- [x] Restaurant settings API.
- [x] Public menu API.
- [x] Authenticated image upload.
- [x] CORS and media serving.
- [x] API-backed Astro build with JSON fallback.
- [x] Full-stack Docker Compose.
- [x] Backend unit tests and CI workflow.
- [x] Architecture and deployment documentation.
- [x] Flutter package name `soransib` and launcher icon configuration.

## Remaining before production merge

- [ ] Add Flutter login/session/token storage.
- [ ] Add restaurant switcher and owner restaurant management UI.
- [ ] Replace Flutter legacy `/api/v1/menu` repository with authenticated category/product/settings APIs.
- [ ] Add Flutter API integration tests/widget tests.
- [ ] Add API integration tests against PostgreSQL.
- [ ] Add production reverse proxy/HTTPS configuration.
- [ ] Add database backup/restore procedure.
- [ ] Remove or disable GitHub menu repository mode after server mode is validated.
- [ ] Decide whether GitHub Pages remains a supported static deployment or is documentation-only once per-installation Docker deployment is adopted.

The remaining items are intentionally explicit rather than being represented as completed work without verification.
