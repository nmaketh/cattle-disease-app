# Cattle Disease AI Monorepo

This repository contains five collaborating systems:

- Flutter mobile app for field workers (CAHW)
- Mobile API for the Flutter app (FastAPI + SQLite)
- Vet/Admin web dashboard (Next.js)
- Ops API for the dashboard (FastAPI + PostgreSQL)
- ML service for hybrid inference and explainability (FastAPI + TensorFlow / scikit-learn)

## Canonical Component Names

- `mobile_api` (formerly `backend`): Flutter field app backend
- `ops_api` (formerly `api`): Vet/admin dashboard backend
- `dashboard`: Next.js web dashboard for vets/admins
- `cattle_disease_ml`: ML training + inference service (separate nested repo / gitlink)

## Repo Layout

```text
cattle_disease_app/
  android/ ios/ lib/ web/ windows/ ...   # Flutter mobile app (field work)
  mobile_api/                            # Flutter backend (FastAPI + SQLite)
  ops_api/                               # Web dashboard backend (FastAPI + Postgres)
  dashboard/                             # Next.js vet/admin dashboard
  cattle_disease_ml/                     # ML service + training pipeline (nested repo)
  docs/                                  # Architecture / runbooks / ports / naming
  deploy/                                # Production deployment templates (Nginx/systemd/prod compose)
  scripts/                               # Local developer launcher aliases
  docker-compose.yml                     # Vet/admin + ML stack compose
```

## Ports (Standardized)

- `3000` -> `dashboard` (Next.js UI)
- `8000` -> `mobile_api` (Flutter backend)
- `8001` -> `cattle_disease_ml` (ML service)
- `8002` -> `ops_api` (dashboard backend)
- `5432` -> PostgreSQL (ops stack DB)

See `docs/PORTS.md` for details.

## Quick Start

### Vet/Admin Web Stack (Docker)

From repo root:

```bash
docker compose up --build
```

Endpoints:

- Mobile API (Flutter backend): `http://localhost:8000/health`
- Dashboard: `http://localhost:3000`
- Ops API docs: `http://localhost:8002/docs`
- ML health (direct): `http://localhost:8001/health`

### Flutter Field App + Mobile API (Local)

1. Start `mobile_api` on port `8000`
2. Run Flutter app (`flutter run`)

See `docs/RUNNING.md` for exact commands.

## Documentation

- `docs/ARCHITECTURE.md`
- `docs/PORTS.md`
- `docs/RUNNING.md`
- `docs/NAMING_ALIASES.md`
- `deploy/README.md` (production templates and deployment notes)

## Developer Shortcuts (PowerShell)

- `scripts/run-mobile-api.ps1`
- `scripts/run-ops-api.ps1`
- `scripts/run-dashboard.ps1`
- `scripts/run-ml-service.ps1`

## Notes

- Temporary compatibility shim: `backend/` may still exist on your machine with local `.venv`, `env`, and `cattle_backend.db` files while the canonical mobile API source lives in `mobile_api/`.
- `cattle_disease_ml/` is currently tracked as a nested gitlink (no `.gitmodules` present). Treat it as a separate codebase and do not delete its `.git` directory without an explicit migration plan.
- The Flutter app should point to `mobile_api` (`http://127.0.0.1:8000` for web/desktop local dev), not `ops_api`.
- `ops_api` now supports startup flags (`RUN_MIGRATIONS_ON_START`, `RUN_SEED_ON_START`) so production deployments can disable seeding.

