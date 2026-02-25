# SudVet Web Dashboards

Standalone web dashboards for high-volume vet operations and system management.

This folder is independent from your Flutter mobile app.

## Access Control

- The dashboard now requires sign-in before data is shown.
- Login uses backend auth endpoints:
  - `POST /auth/login` (fallback `POST /login`)
  - refresh via `POST /auth/refresh` (fallback `POST /refresh`)
- Allowed dashboard roles are `vet` and `admin` (selected at sign-in screen).
- Session is stored in browser localStorage and automatically refreshed when access token expires.

## Included Views

- Vet Dashboard
  - Priority queue
  - High urgency count
  - Unassigned case count
  - Worker/CHW workload summary
- System Management Dashboard
  - Total cases, animals, pending sync, failed cases
  - Disease distribution
  - Platform status summary

## Backend APIs Used

- `GET /vet/inbox?limit=200`
- `GET /cases?limit=500`
- `GET /animals`
- `GET /cases/pending-count`

## Run Locally

From project root:

```powershell
cd dashboard_web
python -m http.server 8081
```

Then open:

- `http://127.0.0.1:8081`

## Notes

- Save connection settings from the sidebar.
- Default API URL is `http://127.0.0.1:8000`.
- This is an MVP web dashboard and can be expanded with server-side role claims, pagination, and RBAC policies.
