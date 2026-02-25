# Cattle Disease AI (Flutter)

Field-ready cattle disease screening app with Material 3 UI, auth flow, backend API integration, sync workflow, education module, and analytics.

## Run

```bash
flutter pub get
flutter run
```

## Backend URL Defaults (User Builds)

CHW/Vet users do **not** configure API URLs in the app.

The app resolves the backend URL in this order:

1. Saved developer override (if present)
2. Build-time URL via `--dart-define=SUDVET_API_BASE_URL=...`
3. Platform local fallback for development:
   - Web/Desktop/iOS: `http://127.0.0.1:8000`
   - Android emulator: `http://10.0.2.2:8000`

### Developer-only server settings

To expose the in-app server configuration screen for development/debugging:

```bash
flutter run --dart-define=ENABLE_DEV_SERVER_SETTINGS=true
```

### Recommended builds

- Local web/dev:
  ```bash
  flutter run -d chrome
  ```
- Staging/prod:
  ```bash
  flutter build web --dart-define=SUDVET_API_BASE_URL=https://your-sudvet-api.example.com
  ```

## Backend Required

This app now uses a real backend for auth, animals, and cases.

Start backend first:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Auth API

The app tries these endpoints in order:

- Login: `POST /auth/login`, fallback `POST /login`
- Signup (step 1): `POST /auth/register`, fallback `POST /auth/signup`, `POST /register`, `POST /signup`
- OTP verify (step 2): `POST /auth/signup/verify`, fallback `POST /signup/verify`
- OTP resend: `POST /auth/signup/resend`, fallback `POST /signup/resend`
- Forgot password: `POST /auth/forgot-password`, fallback `POST /forgot-password`
- Reset password: `POST /auth/reset-password`, fallback `POST /reset-password`
- Refresh access token: `POST /auth/refresh`, fallback `POST /refresh`
- Direct prediction endpoint: `POST /predict` (also used internally by case sync pipeline)

Accepted response fields are flexible:

- Token: `token` or `access_token`
- User payload: `user.{id,name,email}` (or top-level equivalents)

## Signup Security

- Signup now requires OTP verification before account activation.
- Passwords are hashed with bcrypt on backend.
- Backend enforces OTP cooldown, retry lockout, and request rate limits.
- In local backend dev environment (without SMTP config), OTP is printed in backend console logs.
