# Cattle Backend (FastAPI + SQLite)

## Run

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API

- Health: `GET /health`
- Prediction:
  - `POST /predict` (direct prediction contract endpoint; used by case sync pipeline too)
- Auth:
  - `POST /auth/register` (also `/auth/signup`, `/register`, `/signup`) -> issues OTP challenge
  - `POST /auth/signup/verify` (also `/signup/verify`) -> verifies OTP and creates account
  - `POST /auth/signup/resend` (also `/signup/resend`) -> resend OTP
  - `POST /auth/forgot-password` (also `/forgot-password`) -> issues reset OTP challenge
  - `POST /auth/reset-password` (also `/reset-password`) -> verifies reset OTP and updates password
  - `POST /auth/login` (also `/login`)
  - `POST /auth/refresh` (also `/refresh`) -> rotates refresh token and issues new access token
- Animals:
  - `GET /animals`
  - `GET /animals/{animal_id}`
  - `POST /animals`
- Cases:
  - `GET /cases`
  - `GET /cases/{case_id}/export`
  - `GET /cases/{case_id}/gradcam`
  - `GET /cases/{case_id}`
  - `POST /cases`
  - `POST /cases/{case_id}/sync` (`?asyncMode=true` to enqueue background sync job)
  - `POST /cases/sync-pending` (`?asyncMode=true` to enqueue all pending sync jobs)
  - `PATCH /cases/{case_id}/follow-up`
  - `PATCH /cases/{case_id}/notes`
  - `DELETE /cases/{case_id}`
  - `GET /cases/pending-count`
- Jobs:
  - `GET /jobs/{job_id}` (returns background job status for the authenticated user)

All `/animals` and `/cases` routes require `Authorization: Bearer <token>`.

For local development, OTP codes are printed in backend terminal logs.

## SMTP Configuration (Real OTP Emails)

Set these environment variables before starting backend:

- `SMTP_HOST` (example: `smtp.gmail.com`)
- `SMTP_PORT` (example: `587`)
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_FROM` (sender email)
- `SMTP_USE_TLS` (`true`/`false`, default `true`)
- `SMTP_USE_SSL` (`true`/`false`, default `false`)

If SMTP is not configured, OTP is printed to backend logs for local development.

## OTP Security Controls

- OTP expiry: 5 minutes
- Resend cooldown: 60 seconds
- Max resend per signup challenge: 5
- Max verify attempts before lock: 5
- Lock duration after too many failures: 15 minutes
- Max OTP requests per email per hour (register + resend): 6

## Token Security

- Access token TTL: 30 minutes
- Refresh token TTL: 30 days
- Refresh token rotation enabled on `/auth/refresh`

## External Inference Integration

Optional environment variables:

- `INFERENCE_API_URL`: external model endpoint URL
- `INFERENCE_TIMEOUT_SECONDS`: timeout for model call (default `8`)
- `INFERENCE_STRICT_MODE`: `true`/`false`; if `true`, fail when model is unavailable instead of fallback
- `INFERENCE_ALLOW_RULES_FALLBACK`: `true`/`false` (default `false`)

Recommended for real model use:

- Set `INFERENCE_API_URL` to your deployed model endpoint.
- Keep `INFERENCE_ALLOW_RULES_FALLBACK=false` to avoid mock/rules predictions.
- Optionally set `INFERENCE_STRICT_MODE=true` for strict failure behavior.
