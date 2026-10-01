# Gas Cylinder Distribution Management Platform — Project Handoff

**Audience:** another LLM/agent continuing work on this repo.
**Status:** MVP complete and verified (backend tests, dashboard build, Flutter analyze, health check all green).

---

## 1. What this project is

A multi-tenant **gas cylinder distribution management platform** covering the full operations loop:

> Catalog & pricing → outlets (geo-fenced) → route planning → shift start (pre-trip checklist) → en-route check-in → geofenced delivery → safety incidents → offline-capable field app → cash/credit reconciliation → audit trail.

**Three apps, one API:**

| Layer | Stack | Location |
|-------|-------|----------|
| Backend | Python 3.13 / FastAPI modular monolith, SQLAlchemy, Alembic, PostGIS, JWT+OTP | `backend/` |
| Dashboard | Next.js 16 (App Router), TypeScript, static maps | `dashboard/` |
| Field app | Flutter 3.41 Android-first (OTP login, geofencing, offline outbox) | `mobile/` |
| DB | PostgreSQL 18 + PostGIS 3.6.1, DB name `gaz` | local |

Original spec file: `C:\Users\ULTRA PC\Downloads\Gas Cylinder Distribution Managemen.txt`

---

## 2. Architecture decisions (do not reverse casually)

- **Real PostGIS from day 1** — outlet locations are `geometry(Point,4326)`; manual GiST indexes (`GeoAlchemy2` with `spatial_index=False`).
- **Repo-layer `tenant_id` filter** on all tenant-scoped queries.
- **Auth:** OTP request/verify → short-lived access JWT (15m) + refresh (7d). Dev SMS stub returns `dev_code` in response.
- **Idempotency:** `Idempotency-Key` header on mutating endpoints + `client_event_id` (UUID4) on field events.
- **Inventory is append-only** via `inventory_movements` (no in-place quantity edits as source of truth).
- **Dev stubs:** SMS=console/dev_code, media=local file store, alerts=print, Redis=in-memory revocation set.
- **CNDP/consent:** location + data-processing consent captured in mobile permissions screen before operations.
- **Geofences:** own implementation in `mobile/lib/services/geofence_service.dart` (haversine; config enter 60m / exit 50m / interval 25s) — do **not** re-add the pub package `geofence_service` (it does not exist at the version we tried).
- Backend mounts everything under `/api/v1` in `backend/app/main.py`.
- Safety endpoint is `POST /api/v1/safety-incidents` (not `/safety/incidents`).
- Severity enum: `LOW | HIGH | CRITICAL` only.
- Closeout: `POST /api/v1/shifts/{shift_id}/closeout-unload` with body `{unloaded_lines:[{cylinder_type_id, state, quantity}], declared_cash_mad, cashier_user_id, variance_reason?}`.
- Mobile must send `client_event_id` as **UUID string** (`Uuid().v4()`).
- Delivery: `POST /api/v1/route-stops/{stop_id}/deliveries` (signature/photo media tokens optional/nullable).

---

## 3. What was built (by phase)

### Phase 0–1 — Foundation
- Monorepo: `backend/`, `dashboard/`, `mobile/`, `scripts/`, root README + `.gitignore` + `.env.example`.
- PostgreSQL 18 + PostGIS installed; `pg_hba.conf` set to **trust** for 127.0.0.1/::1 (backup: `pg_hba.conf.bak`). Password not known — keep trust for local dev or ask user.
- DB `gaz` with extensions `postgis`, `uuid-ossp`. DSN: `postgresql+psycopg://postgres@127.0.0.1:5432/gaz`.
- Flask-free venv at `backend/.venv` (Python 3.13).

### Phase 2 — Schema & domain
- Alembic migration `fa3c37b283d7_initial_schema.py` (applied).
- Entities include: tenants, users/roles, cylinder types, cylinders (states: full/empty/defective…), vehicles, outlets (+ geofence polygons/points), depots/stock, shifts, routes/stops, check-ins, deliveries, inventory_movements, payments/cash, credit, safety incidents, audit log.
- Seed (`scripts/seed.py`): 1 tenant, 6 users, 3 cylinder types, 2 vehicles, 20 outlets, depot stock.

### Phase 3 — API (48 endpoints)
Router map (prefixes before `/api/v1`):

| Module | Prefix | Notes |
|--------|--------|-------|
| auth | `/auth` | OTP request/verify, refresh, me; rate limit 3 OTP / 10 min |
| catalog | `/…` (no extra) | cylinders, outlets, vehicles, types |
| shifts | `/shifts` | start (pre-trip checklist required), check-in, closeout-unload |
| routes | `/routes` | plan, stops, mine (for agent) |
| field | (no prefix) | deliveries under `/route-stops/{id}/deliveries` |
| ops | (no prefix) | ops/dashboard aggregates |
| inventory | `/inventory` | movements, stock |
| credit | `/credit` | credit accounts/limits |
| safety | `/safety-incidents` | create incident |

- Services: `pricing`, `geofence`, `inventory_journal`, `credit`, `cash`, `audit`, `media`.
- Core: config, database, deps, exceptions, idempotency, security.

### Phase 4 — Dashboard (Next.js)
- 9 routes + login: `/`, `/login`, `/outlets`, `/routes`, `/dispatch`, `/stock`, `/cash`, `/safety`, `/audit`.
- Components: `Shell`, `OutletMap`, `DispatchMap`, `types`; API client `src/lib/api.ts`.
- `npm run build` → **success** (12 static pages).

### Phase 5 — Field app (Flutter)
- SDK installed at `C:\tools\flutter` (3.41.9 stable, Dart 3.11.5).
- `flutter create` scaffolded `android/` with package `com.gaz`, label **Gaz Field Agent**.
- **Manifest permissions:** INTERNET, FINE/COARSE/BACKGROUND location, CAMERA, READ_MEDIA_IMAGES, POST_NOTIFICATIONS.
- **Screens & flow:**
  1. `login_screen.dart` — phone → OTP → store `access_token`, `refresh_token`, `role`, `tenant_id` (raw `package:http`).
  2. `permissions_screen.dart` — location + CNDP consent → vehicle check.
  3. `vehicle_check_screen.dart` — pre-trip checklist → `POST /shifts/start` → start geofence monitoring → route map.
  4. `route_map_screen.dart` — stops from `/routes/mine`, check-in with `Uuid().v4()`, opens delivery.
  5. `delivery_flow_screen.dart` — cylinder matrix (full/empty/defective), totals, POST delivery; offline → outbox entity `DELIVERY`.
  6. `safety_report_screen.dart` — `POST /safety-incidents`, severity LOW/HIGH/CRITICAL, types LEAK/FIRE/CYLINDER_DAMAGE/VEHICLE_INCIDENT/NEAR_MISS/OTHER.
  7. `reconciliation_screen.dart` — closeout-unload payload, stops geofence monitoring, offline enqueue `CLOSEOUT`.
- **Services:**
  - `api_client.dart` — Bearer, `Idempotency-Key`, default base `http://10.0.2.2:8000` (emulator), overridable via SharedPreferences key `api_base`.
  - `outbox_service.dart` — sqflite queue; `markFailed` uses `rawUpdate` (not broken `SqfliteExpression.raw`).
  - `sync_service.dart` — prefers `path` embedded in outbox payload; known paths `/payments`, `/safety-incidents`; CHECK_IN/DELIVERY/EXCEPTION/CLOSEOUT use embedded path.
  - `geofence_service.dart` — clean rewrite, no pub geofence package.
- Flutter deps notes: `intl` must be `^0.20.2` (flutter_localizations pin); `DropdownButtonFormField` uses `initialValue` not `value` on this SDK.
- Translations assets: `assets/translations/{ar,fr}.arb`.
- `flutter analyze` → **No issues found**.

### Phase 6 — Docs / ops
- Root `README.md` (setup, demo users, domain rules, CNDP checklist, KPI table, env vars, stubs).
- Root `.gitignore`, `.env.example`.
- Not committed to git yet (repo is untracked/no commits unless user asks).

---

## 4. Demo credentials

Password for all: `Passw0rd!`

| Role | Phone |
|------|-------|
| owner | +212600000001 |
| dispatcher | +212600000002 |
| warehouse | +212600000003 |
| agent | +212600000004 |
| accountant | +212600000005 |
| auditor | +212600000006 |

**Note:** Seed does not create a shift/route — create a shift+route from dashboard or API before running the mobile agent flow.

---

## 5. How to run / verify

```powershell
# Backend (from backend/)
& .\.venv\Scripts\uvicorn.exe app.main:app --reload --host 127.0.0.1 --port 8000
# Health
Invoke-RestMethod http://127.0.0.1:8000/health
# Tests (13 expected)
& .\.venv\Scripts\python.exe -m pytest tests -q

# Dashboard (from dashboard/)
npm run dev    # or npm run build

# Mobile (from mobile/)
& C:\tools\flutter\bin\flutter.bat analyze
& C:\tools\flutter\bin\flutter.bat run   # Android emulator hits 10.0.2.2:8000
```

**Last verification results:**
- pytest: **13 passed** (warnings only: Starlette deprecation of `HTTP_422_UNPROCESSABLE_ENTITY` → prefer `HTTP_422_UNPROCESSABLE_CONTENT` if touching those lines).
- next build: **✓** all routes static.
- flutter analyze: **0 issues**.
- `/health`: `{"status":"ok","database":true}`.

---

## 6. Gotchas for the next agent

1. **Edit tool** requires `oldString` / `newString` keys.
2. Do not reinstall `geofence_service` from pub.dev; use local `services/geofence_service.dart`.
3. `main.dart` awaits `OutboxService.instance.db` — there is no separate `init()`.
4. Safety body requires `shift_id`, `incident_type`, `severity`, `description` (+ optional lat/lng).
5. Closeout state values must match backend cylinder-state enum used in inventory journal (full/empty/defective…).
6. Dashboard env in `dashboard/.env.local` points at local API.
7. `pg_hba` is trust-auth on localhost — fine for dev; do not ship that config.
8. Flutter SDK path: `C:\tools\flutter\bin` (not on default PATH necessarily — call full path).
9. Mobile API base override: SharedPreferences `api_base`.
10. No git commit unless user explicitly asks.

---

## 7. Suggested next steps (post-MVP)

- E2E test: seed shift → agent login → check-in → delivery → closeout against live API.
- Replace stub SMS/media/alerts with real providers when available.
- CI: pytest + `next build` + `flutter analyze`.
- Harden auth refresh rotation, rate limits, and production `pg_hba`.
- Optional: OpenTelemetry/structured logs, Docker Compose for Postgres.
- Git initial commit (user request only).
