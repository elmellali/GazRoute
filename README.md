# Gas Cylinder Distribution Management Platform

Multi-tenant B2B LPG distributor → retailer delivery platform (MVP).

| Layer | Stack |
|-------|--------|
| API | FastAPI (Python 3.12+) modular monolith, PostgreSQL 16+PostGIS, Alembic |
| Dashboard | Next.js (React) dispatcher / owner / accountant views |
| Field app | Flutter (Android-first) delivery agent with offline outbox |

## Repository layout

```
backend/    FastAPI service, migrations, tests
dashboard/  Next.js admin/dispatch UI
mobile/     Flutter field agent app
scripts/    Seed / demo utilities
```

## Quick start

### 1. Database

PostgreSQL 16+ with PostGIS. Example (local):

```sql
CREATE DATABASE gaz;
\c gaz
CREATE EXTENSION postgis;
CREATE EXTENSION "uuid-ossp";
```

Set `DATABASE_URL` in `backend/.env` (see `.env.example`).

### 2. Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -e ".[dev]"
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

Health: `GET http://127.0.0.1:8000/health`  
OpenAPI: `http://127.0.0.1:8000/docs`

Seed demo tenant (users, outlets, vehicles, stock):

```bash
# from backend/ with venv active and PYTHONPATH=.
python ../scripts/seed.py
```

Demo users (password `Passw0rd!`):

| Role | Phone |
|------|-------|
| owner | +212600000001 |
| dispatcher | +212600000002 |
| warehouse | +212600000003 |
| agent | +212600000004 |
| accountant | +212600000005 |
| auditor | +212600000006 |

OTP in `ENV=dev` is returned in the API response (`dev_code`).

Tests:

```bash
pytest
```

### 3. Dashboard

```bash
cd dashboard
npm install
echo "NEXT_PUBLIC_API_URL=http://127.0.0.1:8000" > .env.local
npm run dev
```

Open `http://localhost:3000`.

### 4. Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run                 # Android emulator: API uses http://10.0.2.2:8000
```

Flow: OTP login → permissions → vehicle pre-trip → route stops → geofence check-in → delivery/returns/payment → safety report → closeout.

Offline: events queue in `local_outbox` (SQLite) and sync with `Idempotency-Key` + `client_event_id` when connectivity returns.

## Core domain rules (MVP)

- **RBAC**: owner, dispatcher, warehouse, agent, accountant, auditor.
- **Geofence**: default 60 m radius, GPS accuracy gate ≤ 50 m, dwell 25 s; manual override requires reason.
- **Stop state machine**: PENDING → EN_ROUTE → NEARBY → ARRIVED → IN_SERVICE → COMPLETED | EXCEPTION.
- **Inventory**: append-only `inventory_movements` journal; balances derived, never edited in place.
- **Credit**: soft warning near limit; hard lock over limit / overdue; manager override code with TTL.
- **Idempotency**: mutating field endpoints require `Idempotency-Key`; replays return stored response.
- **Location minimization**: GPS only between shift start and closeout.

## CNDP / compliance checklist (pilot)

- [ ] Data processing agreement / legal basis documented
- [ ] Location purpose + retention disclosed to agents (in-app consent screen)
- [ ] Retention: GPS 90 days, commercial records 10 years, audit logs 3 years
- [ ] Access logging on all tenant-scoped reads/writes (`audit_logs`)
- [ ] Secrets via environment only (never committed)
- [ ] Right-to-erasure procedure for outlet contacts (soft-delete + retention clock)

## Spec §14 KPI targets (track post-pilot)

| KPI | Target |
|-----|--------|
| On-time stop arrival | ≥ 90% |
| First-time delivery success | ≥ 95% |
| Cash variance at closeout | ≤ 0.5% of collected |
| Stock loss (unexplained) | ≤ 0.2% of cylinders moved |
| Offline sync failure rate | < 1% of outbox events |
| Average stop service time | < 12 min |

## Environment

Copy `.env.example` → `backend/.env` and `dashboard/.env.local`.

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | SQLAlchemy DSN (PostGIS) |
| `SECRET_KEY` | JWT signing |
| `ENV` | `dev` reveals OTP in response |
| `CORS_ORIGINS` | Dashboard origin(s) |
| `NEXT_PUBLIC_API_URL` | Dashboard → API base |

## Dev stubs (replace before production)

- SMS/OTP → console + `dev_code` in response when `ENV=dev`
- Push alerts → print to server log
- Media → local filesystem under `MEDIA_ROOT`
- Redis token revocation → in-memory set
