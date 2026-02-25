from __future__ import annotations

import hashlib
import json
import os
import secrets
import sqlite3
import smtplib
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, Response
from fastapi.middleware.cors import CORSMiddleware
import bcrypt
from pydantic import BaseModel, Field


ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "cattle_backend.db"


app = FastAPI(title="Cattle Disease Backend", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

OTP_EXPIRY_MINUTES = 5
OTP_RESEND_COOLDOWN_SECONDS = 60
OTP_MAX_VERIFY_ATTEMPTS = 5
OTP_LOCK_MINUTES = 15
OTP_MAX_REQUESTS_PER_HOUR = 6
OTP_MAX_RESENDS_PER_CHALLENGE = 5
ACCESS_TOKEN_TTL_MINUTES = 30
REFRESH_TOKEN_TTL_DAYS = 30

SMTP_HOST = os.getenv("SMTP_HOST", "").strip()
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "").strip()
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "").strip()
SMTP_FROM = os.getenv("SMTP_FROM", "").strip()
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "true").strip().lower() == "true"
SMTP_USE_SSL = os.getenv("SMTP_USE_SSL", "false").strip().lower() == "true"
INFERENCE_API_URL = os.getenv("INFERENCE_API_URL", "").strip()
INFERENCE_TIMEOUT_SECONDS = int(os.getenv("INFERENCE_TIMEOUT_SECONDS", "8"))
INFERENCE_STRICT_MODE = os.getenv("INFERENCE_STRICT_MODE", "false").strip().lower() == "true"
INFERENCE_ALLOW_RULES_FALLBACK = (
    os.getenv("INFERENCE_ALLOW_RULES_FALLBACK", "false").strip().lower() == "true"
)

_job_worker_thread: threading.Thread | None = None
_job_worker_stop = threading.Event()
_job_worker_lock = threading.Lock()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _bcrypt_input(password: str) -> bytes:
    # Pre-hash to fixed length to avoid bcrypt's 72-byte password limit.
    digest = hashlib.sha256(password.encode("utf-8")).hexdigest()
    return digest.encode("ascii")


def hash_password(password: str) -> str:
    hashed = bcrypt.hashpw(_bcrypt_input(password), bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        stored = password_hash.encode("utf-8")
        # Preferred path for newly hashed passwords.
        if bcrypt.checkpw(_bcrypt_input(password), stored):
            return True
        # Backward compatibility with previously stored raw-bcrypt entries.
        return bcrypt.checkpw(password.encode("utf-8"), stored)
    except Exception:
        return False


@contextmanager
def db_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with db_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users(
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS auth_tokens(
              token TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              expires_at TEXT,
              FOREIGN KEY(user_id) REFERENCES users(id)
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS auth_refresh_tokens(
              token TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              expires_at TEXT NOT NULL,
              revoked_at TEXT,
              FOREIGN KEY(user_id) REFERENCES users(id)
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS signup_otps(
              signup_token TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              otp_code TEXT NOT NULL,
              expires_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              resend_count INTEGER NOT NULL DEFAULT 0,
              last_sent_at TEXT NOT NULL,
              locked_until TEXT
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS otp_rate_limits(
              email TEXT PRIMARY KEY,
              window_start TEXT NOT NULL,
              request_count INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS password_reset_otps(
              reset_token TEXT PRIMARY KEY,
              email TEXT NOT NULL UNIQUE,
              otp_code TEXT NOT NULL,
              expires_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              resend_count INTEGER NOT NULL DEFAULT 0,
              last_sent_at TEXT NOT NULL,
              locked_until TEXT
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS animals(
              id TEXT PRIMARY KEY,
              userId TEXT,
              tag TEXT NOT NULL UNIQUE,
              name TEXT,
              dob TEXT,
              location TEXT,
              notes TEXT,
              createdAt TEXT NOT NULL
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS cases(
              id TEXT PRIMARY KEY,
              userId TEXT,
              animalId TEXT,
              animalName TEXT,
              animalTag TEXT,
              createdAt TEXT NOT NULL,
              imagePath TEXT,
              symptomsJson TEXT NOT NULL,
              status TEXT NOT NULL,
              predictionJson TEXT,
              followUpStatus TEXT NOT NULL,
              followUpDate TEXT,
              notes TEXT,
              syncedAt TEXT,
              temperature REAL,
              severity REAL,
              attachmentsJson TEXT,
              FOREIGN KEY(animalId) REFERENCES animals(id)
            );
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS background_jobs(
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              status TEXT NOT NULL,
              error_message TEXT,
              created_at TEXT NOT NULL,
              started_at TEXT,
              finished_at TEXT
            );
            """
        )
        _ensure_column(conn, "signup_otps", "attempt_count", "INTEGER NOT NULL DEFAULT 0")
        _ensure_column(conn, "signup_otps", "resend_count", "INTEGER NOT NULL DEFAULT 0")
        _ensure_column(conn, "signup_otps", "last_sent_at", "TEXT")
        _ensure_column(conn, "signup_otps", "locked_until", "TEXT")
        conn.execute("UPDATE signup_otps SET last_sent_at = created_at WHERE last_sent_at IS NULL")
        _ensure_column(conn, "animals", "userId", "TEXT")
        _ensure_column(conn, "cases", "userId", "TEXT")
        _ensure_column(
            conn,
            "password_reset_otps",
            "attempt_count",
            "INTEGER NOT NULL DEFAULT 0",
        )
        _ensure_column(
            conn,
            "password_reset_otps",
            "resend_count",
            "INTEGER NOT NULL DEFAULT 0",
        )
        _ensure_column(conn, "password_reset_otps", "last_sent_at", "TEXT")
        _ensure_column(conn, "password_reset_otps", "locked_until", "TEXT")
        conn.execute(
            "UPDATE password_reset_otps SET last_sent_at = created_at WHERE last_sent_at IS NULL"
        )
        _ensure_column(conn, "auth_tokens", "expires_at", "TEXT")


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
    info = conn.execute(f"PRAGMA table_info({table})").fetchall()
    columns = {row["name"] for row in info}
    if column in columns:
        return
    conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}")


@app.on_event("startup")
def startup() -> None:
    init_db()
    _start_job_worker()


@app.on_event("shutdown")
def shutdown() -> None:
    _stop_job_worker()


def _token_from_header(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header.")
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Invalid Authorization scheme.")
    return authorization[7:].strip()


def get_current_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    token = _token_from_header(authorization)
    with db_conn() as conn:
        token_row = conn.execute(
            "SELECT user_id, expires_at FROM auth_tokens WHERE token = ?",
            (token,),
        ).fetchone()
        if token_row is None:
            raise HTTPException(status_code=401, detail="Invalid or expired token.")
        expires_at_raw = token_row["expires_at"]
        if expires_at_raw:
            expires_at = _parse_iso(expires_at_raw)
            if _now_utc() >= expires_at:
                conn.execute("DELETE FROM auth_tokens WHERE token = ?", (token,))
                raise HTTPException(status_code=401, detail="Invalid or expired token.")
        user_row = conn.execute(
            "SELECT id, name, email FROM users WHERE id = ?",
            (token_row["user_id"],),
        ).fetchone()
        if user_row is None:
            raise HTTPException(status_code=401, detail="User not found.")
        return {"id": user_row["id"], "name": user_row["name"], "email": user_row["email"]}


class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str = Field(min_length=8)


class LoginRequest(BaseModel):
    email: str
    password: str


class RefreshTokenRequest(BaseModel):
    refreshToken: str


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    resetToken: str
    otp: str
    newPassword: str = Field(min_length=8)


class VerifySignupOtpRequest(BaseModel):
    signupToken: str
    otp: str


class ResendSignupOtpRequest(BaseModel):
    signupToken: str


class AnimalCreateRequest(BaseModel):
    name: str | None = None
    dob: str | None = None
    location: str | None = None
    notes: str | None = None


class CaseCreateRequest(BaseModel):
    animalId: str | None = None
    symptoms: dict[str, bool]
    temperature: float | None = None
    severity: float | None = None
    imagePath: str | None = None
    attachments: list[str] = Field(default_factory=list)
    notes: str | None = None
    shouldAttemptSync: bool = True


class FollowUpUpdateRequest(BaseModel):
    followUpStatus: str


class NotesUpdateRequest(BaseModel):
    notes: str


class PredictRequest(BaseModel):
    symptoms: dict[str, bool]
    temperature: float | None = None
    imagePath: str | None = None
    animalId: str | None = None


class AsyncCaseSyncRequest(BaseModel):
    caseId: str


class JobStatusResponse(BaseModel):
    id: str
    type: str
    status: str
    errorMessage: str | None = None
    createdAt: str
    startedAt: str | None = None
    finishedAt: str | None = None


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _new_token() -> str:
    return secrets.token_urlsafe(32)


def _new_signup_token() -> str:
    return secrets.token_urlsafe(36)


def _new_reset_token() -> str:
    return secrets.token_urlsafe(36)


def _new_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _new_job_id() -> str:
    return f"job-{uuid.uuid4()}"


def _new_tag() -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ123456789"
    value = "".join(secrets.choice(alphabet) for _ in range(6))
    return f"COW-{value}"


def _disease_from_prediction(prediction_json: dict[str, Any] | None) -> str:
    if not prediction_json:
        return "unknown"
    prediction = str(prediction_json.get("prediction", "")).strip().lower()
    if "normal" in prediction:
        return "normal"
    if "lsd" in prediction:
        return "lsd"
    if "fmd" in prediction:
        return "fmd"
    if "ecf" in prediction:
        return "ecf"
    if "cbpp" in prediction:
        return "cbpp"
    return "unknown"


def _predict(symptoms: dict[str, bool], temperature: float | None) -> dict[str, Any]:
    fever = symptoms.get("fever", False) or ((temperature or 0) >= 39.0)
    nodules = symptoms.get("skin_nodules", False)
    mouth_lesions = symptoms.get("mouth_lesions", False)
    breathing = symptoms.get("difficulty_breathing", False)
    lameness = symptoms.get("lameness", False)
    nasal = symptoms.get("nasal_discharge", False)

    if nodules and fever:
        disease = "LSD"
    elif mouth_lesions and lameness:
        disease = "FMD"
    elif fever and breathing:
        disease = "CBPP"
    elif fever and nasal:
        disease = "ECF"
    elif not any(symptoms.values()) and not fever:
        disease = "Normal"
    else:
        disease = "Unknown"

    symptom_count = sum(1 for value in symptoms.values() if value)
    base = 0.75 if disease == "Normal" else 0.7
    confidence = min(0.97, base + symptom_count * 0.04)

    rec_map = {
        "LSD": [
            "Isolate affected cattle from the herd immediately.",
            "Disinfect shared feed and water points.",
            "Consult a veterinarian for confirmatory diagnosis.",
        ],
        "FMD": [
            "Restrict animal movement and herd contact.",
            "Disinfect housing and feeding zones daily.",
            "Call veterinary services to manage spread.",
        ],
        "ECF": [
            "Improve tick control around barns and fields.",
            "Monitor body temperature twice daily.",
            "Consult a veterinarian for targeted treatment.",
        ],
        "CBPP": [
            "Separate suspected animals and improve ventilation.",
            "Avoid transport until veterinary review.",
            "Seek urgent diagnosis and treatment guidance.",
        ],
    }
    recommendations = rec_map.get(
        disease,
        [
            "Continue routine observation and preventive care.",
            "Retake photos if symptoms change.",
            "Maintain vaccination and treatment records.",
        ],
    )

    return {
        "prediction": disease,
        "confidence": confidence,
        "method": "Backend Rules Engine",
        "gradcamPath": None,
        "recommendations": recommendations,
    }


def _predict_with_external_service(
    *,
    symptoms: dict[str, bool],
    temperature: float | None,
    image_path: str | None,
    animal_id: str | None,
) -> dict[str, Any]:
    if not INFERENCE_API_URL:
        if INFERENCE_ALLOW_RULES_FALLBACK:
            fallback = _predict(symptoms, temperature)
            fallback["method"] = "Backend Rules Engine (no external model URL)"
            return fallback
        raise HTTPException(
            status_code=503,
            detail="External model URL is not configured. Set INFERENCE_API_URL.",
        )

    try:
        decoded = _call_external_inference(
            symptoms=symptoms,
            temperature=temperature,
            image_path=image_path,
            animal_id=animal_id,
        )
        prediction = (
            decoded.get("prediction")
            or decoded.get("disease")
            or decoded.get("label")
            or "Unknown"
        )
        normalized_prediction = _normalize_model_prediction(str(prediction))
        if normalized_prediction is None:
            raise ValueError("Unsupported model class. Expected Normal/LSD/FMD.")

        confidence_raw = (
            decoded.get("confidence")
            or decoded.get("probability")
            or decoded.get("score")
            or decoded.get("conf")
        )
        confidence: float | None
        if isinstance(confidence_raw, (int, float)):
            confidence = float(confidence_raw)
        elif confidence_raw is not None:
            try:
                confidence = float(str(confidence_raw))
            except Exception:
                confidence = None
        else:
            confidence = None

        recommendations = decoded.get("recommendations") or decoded.get("next_steps") or []
        if not isinstance(recommendations, list):
            recommendations = []
        recommendations = [str(item) for item in recommendations]
        if not recommendations:
            recommendations = _default_recommendations_for_class(normalized_prediction)

        return {
            "prediction": normalized_prediction,
            "confidence": confidence,
            "method": str(decoded.get("method") or "External Inference API"),
            "modelVersion": decoded.get("modelVersion") or decoded.get("model_version"),
            "gradcamPath": decoded.get("gradcamPath")
            or decoded.get("gradcam_path")
            or decoded.get("gradcam")
            or decoded.get("cam"),
            "recommendations": recommendations,
        }
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError, json.JSONDecodeError):
        if INFERENCE_STRICT_MODE or not INFERENCE_ALLOW_RULES_FALLBACK:
            raise HTTPException(
                status_code=502,
                detail="External inference service unavailable or returned invalid output.",
            )
        fallback = _predict(symptoms, temperature)
        fallback["method"] = "Backend Rules Engine (fallback)"
        return fallback


def _call_external_inference(
    *,
    symptoms: dict[str, bool],
    temperature: float | None,
    image_path: str | None,
    animal_id: str | None,
) -> dict[str, Any]:
    # Try JSON first for APIs that accept structured payloads.
    json_payload = {
        "symptoms": symptoms,
        "temperature": temperature,
        "imagePath": image_path,
        "animalId": animal_id,
    }
    json_request = urllib.request.Request(
        INFERENCE_API_URL,
        data=json.dumps(json_payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(json_request, timeout=INFERENCE_TIMEOUT_SECONDS) as response:
            body = response.read().decode("utf-8")
            decoded = json.loads(body) if body else {}
            if isinstance(decoded, dict):
                return decoded
    except Exception:
        # Fall through to form payload style.
        pass

    form_payload: dict[str, str] = {}
    for key, value in symptoms.items():
        form_payload[key] = "1" if value else "0"
    if temperature is not None:
        form_payload["temperature"] = str(temperature)
    if animal_id:
        form_payload["animal_id"] = animal_id
    form_payload["imagePath"] = image_path or ""

    form_request = urllib.request.Request(
        INFERENCE_API_URL,
        data=urllib.parse.urlencode(form_payload).encode("utf-8"),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urllib.request.urlopen(form_request, timeout=INFERENCE_TIMEOUT_SECONDS) as response:
        body = response.read().decode("utf-8")
        decoded = json.loads(body) if body else {}
        if not isinstance(decoded, dict):
            raise ValueError("Invalid inference payload shape.")
        return decoded


def _normalize_model_prediction(raw: str) -> str | None:
    value = raw.strip().lower()
    if not value:
        return None
    if value in {"normal", "healthy"}:
        return "Normal"
    if "lsd" in value or "lumpy" in value:
        return "LSD"
    if "fmd" in value or "foot" in value or "mouth" in value:
        return "FMD"
    return None


def _default_recommendations_for_class(prediction: str) -> list[str]:
    if prediction == "LSD":
        return [
            "Isolate affected cattle from the herd immediately.",
            "Disinfect shared feed and water points.",
            "Consult a veterinarian for confirmatory diagnosis.",
        ]
    if prediction == "FMD":
        return [
            "Restrict animal movement and herd contact.",
            "Disinfect housing and feeding zones daily.",
            "Call veterinary services to manage spread.",
        ]
    return [
        "Continue routine observation and preventive care.",
        "Retake photos if symptoms change.",
        "Maintain vaccination and treatment records.",
    ]


def _case_from_row(row: sqlite3.Row) -> dict[str, Any]:
    symptoms_json = row["symptomsJson"] or "{}"
    prediction_json_raw = row["predictionJson"]
    attachments_json = row["attachmentsJson"] or "[]"
    return {
        "id": row["id"],
        "animalId": row["animalId"],
        "animalName": row["animalName"],
        "animalTag": row["animalTag"],
        "createdAt": row["createdAt"],
        "imagePath": row["imagePath"],
        "symptomsJson": json.loads(symptoms_json),
        "status": row["status"],
        "predictionJson": json.loads(prediction_json_raw) if prediction_json_raw else None,
        "followUpStatus": row["followUpStatus"],
        "followUpDate": row["followUpDate"],
        "notes": row["notes"],
        "syncedAt": row["syncedAt"],
        "temperature": row["temperature"],
        "severity": row["severity"],
        "attachmentsJson": json.loads(attachments_json),
    }


def _case_export_payload(row: sqlite3.Row) -> dict[str, Any]:
    case_data = _case_from_row(row)
    prediction_json = case_data.get("predictionJson") or {}
    symptoms = case_data.get("symptomsJson") or {}
    active_symptoms = [key for key, value in symptoms.items() if value]

    summary_lines = [
        f"Case ID: {case_data['id']}",
        f"Animal: {case_data.get('animalName') or 'Quick Case'} ({case_data.get('animalTag') or '-'})",
        f"Created At: {case_data.get('createdAt')}",
        f"Status: {case_data.get('status')}",
        f"Prediction: {prediction_json.get('prediction', 'Pending')}",
        f"Confidence: {prediction_json.get('confidence', 'N/A')}",
        f"Method: {prediction_json.get('method', 'N/A')}",
        f"Temperature: {case_data.get('temperature') if case_data.get('temperature') is not None else 'N/A'}",
        f"Severity: {case_data.get('severity') if case_data.get('severity') is not None else 'N/A'}",
        f"Symptoms: {', '.join(active_symptoms) if active_symptoms else 'None flagged'}",
    ]
    notes = case_data.get("notes")
    if notes:
        summary_lines.append(f"Notes: {notes}")

    recommendations = prediction_json.get("recommendations") or []
    if isinstance(recommendations, list) and recommendations:
        summary_lines.append("Recommendations:")
        for item in recommendations:
            summary_lines.append(f"- {item}")

    return {
        "caseId": case_data["id"],
        "generatedAt": now_iso(),
        "summaryText": "\n".join(summary_lines),
        "data": case_data,
    }


def _gradcam_svg_for_case(row: sqlite3.Row) -> str:
    symptoms = json.loads(row["symptomsJson"] or "{}")
    score = sum(1 for value in symptoms.values() if value)
    intensity = min(1.0, 0.25 + (score * 0.12))
    alpha = max(0.20, min(0.85, intensity))

    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 320">
  <defs>
    <radialGradient id="hotspot" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="rgba(255,0,0,{alpha:.2f})" />
      <stop offset="60%" stop-color="rgba(255,153,0,{alpha * 0.8:.2f})" />
      <stop offset="100%" stop-color="rgba(0,0,0,0.0)" />
    </radialGradient>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#e8f2ec" />
      <stop offset="100%" stop-color="#d8e6df" />
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="600" height="320" rx="16" fill="url(#bg)" />
  <ellipse cx="200" cy="145" rx="145" ry="92" fill="url(#hotspot)" />
  <ellipse cx="360" cy="162" rx="125" ry="88" fill="url(#hotspot)" />
  <ellipse cx="285" cy="220" rx="110" ry="64" fill="url(#hotspot)" />
  <text x="20" y="298" font-size="18" font-family="Arial, sans-serif" fill="#1f3d2f">
    Explainability Map (synthetic Grad-CAM)
  </text>
</svg>"""


def _parse_iso(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value)


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _issue_tokens(conn: sqlite3.Connection, user_id: str) -> tuple[str, str]:
    now = _now_utc()
    access_token = _new_token()
    refresh_token = _new_token()
    access_expires = (now + timedelta(minutes=ACCESS_TOKEN_TTL_MINUTES)).isoformat()
    refresh_expires = (now + timedelta(days=REFRESH_TOKEN_TTL_DAYS)).isoformat()

    conn.execute(
        """
        INSERT INTO auth_tokens(token, user_id, created_at, expires_at)
        VALUES(?,?,?,?)
        """,
        (access_token, user_id, now.isoformat(), access_expires),
    )
    conn.execute(
        """
        INSERT INTO auth_refresh_tokens(token, user_id, created_at, expires_at, revoked_at)
        VALUES(?,?,?,?,NULL)
        """,
        (refresh_token, user_id, now.isoformat(), refresh_expires),
    )
    return access_token, refresh_token


def _seconds_until(moment: datetime, now: datetime) -> int:
    return max(0, int((moment - now).total_seconds()))


def _deliver_otp(email: str, otp: str, purpose: str = "signup") -> None:
    purpose_label = "signup verification" if purpose == "signup" else "password reset"
    if not SMTP_HOST or not SMTP_FROM:
        print(
            f"[OTP] {purpose} email={email} code={otp} (SMTP not configured; using console delivery)"
        )
        return

    message = EmailMessage()
    message["Subject"] = f"Your Cattle Disease App {purpose_label} OTP"
    message["From"] = SMTP_FROM
    message["To"] = email
    message.set_content(
        (
            f"Your {purpose_label} OTP code is: {otp}\n\n"
            f"It expires in {OTP_EXPIRY_MINUTES} minutes.\n"
            "If you did not request this code, please ignore this email."
        )
    )

    try:
        if SMTP_USE_SSL:
            with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=15) as smtp:
                if SMTP_USERNAME:
                    smtp.login(SMTP_USERNAME, SMTP_PASSWORD)
                smtp.send_message(message)
            return

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as smtp:
            if SMTP_USE_TLS:
                smtp.starttls()
            if SMTP_USERNAME:
                smtp.login(SMTP_USERNAME, SMTP_PASSWORD)
            smtp.send_message(message)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send OTP email: {exc}",
        ) from exc


def _enqueue_job(conn: sqlite3.Connection, job_type: str, payload: dict[str, Any]) -> str:
    job_id = _new_job_id()
    conn.execute(
        """
        INSERT INTO background_jobs(id, type, payload_json, status, error_message, created_at, started_at, finished_at)
        VALUES(?,?,?,?,?,?,?,?)
        """,
        (job_id, job_type, json.dumps(payload), "pending", None, now_iso(), None, None),
    )
    return job_id


def _job_status_payload(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "type": row["type"],
        "status": row["status"],
        "errorMessage": row["error_message"],
        "createdAt": row["created_at"],
        "startedAt": row["started_at"],
        "finishedAt": row["finished_at"],
    }


def _job_owned_by_user(row: sqlite3.Row, user_id: str) -> bool:
    payload_raw = row["payload_json"]
    if not payload_raw:
        return False
    try:
        payload = json.loads(payload_raw)
    except json.JSONDecodeError:
        return False
    if not isinstance(payload, dict):
        return False
    return str(payload.get("userId", "")).strip() == user_id


def _next_pending_job(conn: sqlite3.Connection) -> sqlite3.Row | None:
    return conn.execute(
        """
        SELECT id, type, payload_json
        FROM background_jobs
        WHERE status = 'pending'
        ORDER BY created_at ASC
        LIMIT 1
        """
    ).fetchone()


def _process_background_job(job_type: str, payload: dict[str, Any]) -> None:
    if job_type == "send_otp_email":
        _deliver_otp(
            email=str(payload.get("email", "")),
            otp=str(payload.get("otp", "")),
            purpose=str(payload.get("purpose", "signup")),
        )
        return

    if job_type == "sync_case":
        case_id = str(payload.get("caseId", ""))
        user_id = str(payload.get("userId", ""))
        base_url = str(payload.get("baseUrl", "")).rstrip("/")
        if not case_id or not user_id:
            raise ValueError("sync_case payload missing caseId/userId")
        with db_conn() as conn:
            row = conn.execute(
                "SELECT * FROM cases WHERE id = ? AND userId = ?",
                (case_id, user_id),
            ).fetchone()
            if row is None:
                raise ValueError("Case not found for async sync.")
            symptoms = json.loads(row["symptomsJson"] or "{}")
            prediction_json = _predict_with_external_service(
                symptoms=symptoms,
                temperature=row["temperature"],
                image_path=row["imagePath"],
                animal_id=row["animalId"],
            )
            if not prediction_json.get("gradcamPath"):
                if base_url:
                    prediction_json["gradcamPath"] = f"{base_url}/cases/{case_id}/gradcam"
                else:
                    prediction_json["gradcamPath"] = f"/cases/{case_id}/gradcam"
            conn.execute(
                """
                UPDATE cases
                SET predictionJson = ?, status = 'synced', syncedAt = ?
                WHERE id = ? AND userId = ?
                """,
                (json.dumps(prediction_json), now_iso(), case_id, user_id),
            )
        return

    raise ValueError(f"Unsupported job type: {job_type}")


def _job_worker_loop() -> None:
    while not _job_worker_stop.is_set():
        claimed_job: sqlite3.Row | None = None
        try:
            with db_conn() as conn:
                job = _next_pending_job(conn)
                if job is None:
                    pass
                else:
                    conn.execute(
                        "UPDATE background_jobs SET status = 'running', started_at = ? WHERE id = ?",
                        (now_iso(), job["id"]),
                    )
                    claimed_job = job
        except Exception:
            # Keep worker alive even if one cycle fails.
            pass
        if claimed_job is not None:
            try:
                payload = json.loads(claimed_job["payload_json"] or "{}")
                if not isinstance(payload, dict):
                    payload = {}
                _process_background_job(claimed_job["type"], payload)
                with db_conn() as conn:
                    conn.execute(
                        """
                        UPDATE background_jobs
                        SET status = 'completed', finished_at = ?, error_message = NULL
                        WHERE id = ?
                        """,
                        (now_iso(), claimed_job["id"]),
                    )
            except Exception as exc:
                with db_conn() as conn:
                    conn.execute(
                        """
                        UPDATE background_jobs
                        SET status = 'failed', finished_at = ?, error_message = ?
                        WHERE id = ?
                        """,
                        (now_iso(), str(exc), claimed_job["id"]),
                    )
        _job_worker_stop.wait(0.8)


def _start_job_worker() -> None:
    global _job_worker_thread
    with _job_worker_lock:
        if _job_worker_thread is not None and _job_worker_thread.is_alive():
            return
        _job_worker_stop.clear()
        _job_worker_thread = threading.Thread(
            target=_job_worker_loop,
            name="background-job-worker",
            daemon=True,
        )
        _job_worker_thread.start()


def _stop_job_worker() -> None:
    _job_worker_stop.set()


def _enforce_otp_request_rate_limit(conn: sqlite3.Connection, email: str) -> None:
    now = _now_utc()
    row = conn.execute(
        "SELECT window_start, request_count FROM otp_rate_limits WHERE email = ?",
        (email,),
    ).fetchone()

    if row is None:
        conn.execute(
            "INSERT INTO otp_rate_limits(email, window_start, request_count) VALUES(?,?,?)",
            (email, now.isoformat(), 1),
        )
        return

    window_start = _parse_iso(row["window_start"])
    if now - window_start >= timedelta(hours=1):
        conn.execute(
            "UPDATE otp_rate_limits SET window_start = ?, request_count = 1 WHERE email = ?",
            (now.isoformat(), email),
        )
        return

    request_count = int(row["request_count"] or 0)
    if request_count >= OTP_MAX_REQUESTS_PER_HOUR:
        raise HTTPException(
            status_code=429,
            detail="Too many OTP requests. Please try again later.",
        )
    conn.execute(
        "UPDATE otp_rate_limits SET request_count = request_count + 1 WHERE email = ?",
        (email,),
    )


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "service": "cattle-backend", "time": now_iso()}


@app.post("/predict")
def predict(payload: PredictRequest) -> dict[str, Any]:
    return _predict_with_external_service(
        symptoms=payload.symptoms,
        temperature=payload.temperature,
        image_path=payload.imagePath,
        animal_id=payload.animalId,
    )


@app.post("/auth/register")
@app.post("/auth/signup")
@app.post("/register")
@app.post("/signup")
def register(payload: RegisterRequest) -> dict[str, Any]:
    email = _normalize_email(payload.email)
    now = _now_utc()
    with db_conn() as conn:
        existing = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if existing is not None:
            raise HTTPException(status_code=409, detail="Email already registered.")
        _enforce_otp_request_rate_limit(conn, email)
        signup_token = _new_signup_token()
        otp = _new_otp()
        expires_at = (now + timedelta(minutes=OTP_EXPIRY_MINUTES)).isoformat()
        conn.execute("DELETE FROM signup_otps WHERE email = ?", (email,))
        conn.execute(
            """
            INSERT INTO signup_otps(
              signup_token, name, email, password_hash, otp_code, expires_at, created_at,
              attempt_count, resend_count, last_sent_at, locked_until
            )
            VALUES(?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                signup_token,
                payload.name.strip(),
                email,
                hash_password(payload.password),
                otp,
                expires_at,
                now_iso(),
                0,
                0,
                now.isoformat(),
                None,
            ),
        )
        delivery_job_id = _enqueue_job(
            conn,
            "send_otp_email",
            {"email": email, "otp": otp, "purpose": "signup"},
        )
    return {
        "otpRequired": True,
        "signupToken": signup_token,
        "email": email,
        "expiresInSeconds": OTP_EXPIRY_MINUTES * 60,
        "message": "OTP sent to your email.",
        "deliveryJobId": delivery_job_id,
    }


@app.post("/auth/signup/resend")
@app.post("/signup/resend")
def resend_signup_otp(payload: ResendSignupOtpRequest) -> dict[str, Any]:
    signup_token = payload.signupToken.strip()
    if not signup_token:
        raise HTTPException(status_code=400, detail="Invalid signup token.")
    now = _now_utc()

    with db_conn() as conn:
        row = conn.execute(
            """
            SELECT email, resend_count, last_sent_at, locked_until
            FROM signup_otps
            WHERE signup_token = ?
            """,
            (signup_token,),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Signup session not found.")

        _enforce_otp_request_rate_limit(conn, row["email"])

        locked_until_raw = row["locked_until"]
        if locked_until_raw:
            locked_until = _parse_iso(locked_until_raw)
            if now < locked_until:
                wait_seconds = _seconds_until(locked_until, now)
                raise HTTPException(
                    status_code=429,
                    detail=f"OTP verification temporarily locked. Try again in {wait_seconds} seconds.",
                )

        resend_count = int(row["resend_count"] or 0)
        if resend_count >= OTP_MAX_RESENDS_PER_CHALLENGE:
            raise HTTPException(
                status_code=429,
                detail="Resend limit reached. Start signup again.",
            )

        last_sent_raw = row["last_sent_at"]
        if last_sent_raw:
            last_sent_at = _parse_iso(last_sent_raw)
            next_allowed = last_sent_at + timedelta(seconds=OTP_RESEND_COOLDOWN_SECONDS)
            if now < next_allowed:
                wait_seconds = _seconds_until(next_allowed, now)
                raise HTTPException(
                    status_code=429,
                    detail=f"Please wait {wait_seconds} seconds before requesting another OTP.",
                )

        otp = _new_otp()
        expires_at = (now + timedelta(minutes=OTP_EXPIRY_MINUTES)).isoformat()
        conn.execute(
            """
            UPDATE signup_otps
            SET otp_code = ?, expires_at = ?, resend_count = resend_count + 1,
                attempt_count = 0, last_sent_at = ?, locked_until = NULL
            WHERE signup_token = ?
            """,
            (otp, expires_at, now.isoformat(), signup_token),
        )
        delivery_job_id = _enqueue_job(
            conn,
            "send_otp_email",
            {"email": row["email"], "otp": otp, "purpose": "signup"},
        )
    return {
        "message": "A new OTP has been sent.",
        "expiresInSeconds": OTP_EXPIRY_MINUTES * 60,
        "deliveryJobId": delivery_job_id,
    }


@app.post("/auth/signup/verify")
@app.post("/signup/verify")
def verify_signup_otp(payload: VerifySignupOtpRequest) -> dict[str, Any]:
    signup_token = payload.signupToken.strip()
    otp = payload.otp.strip()
    if not signup_token:
        raise HTTPException(status_code=400, detail="Invalid signup token.")
    if not otp:
        raise HTTPException(status_code=400, detail="OTP is required.")

    with db_conn() as conn:
        pending = conn.execute(
            """
            SELECT signup_token, name, email, password_hash, otp_code, expires_at, attempt_count, locked_until
            FROM signup_otps
            WHERE signup_token = ?
            """,
            (signup_token,),
        ).fetchone()
        if pending is None:
            raise HTTPException(status_code=404, detail="Signup session not found.")

        now = _now_utc()
        locked_until_raw = pending["locked_until"]
        if locked_until_raw:
            locked_until = _parse_iso(locked_until_raw)
            if now < locked_until:
                wait_seconds = _seconds_until(locked_until, now)
                raise HTTPException(
                    status_code=429,
                    detail=f"OTP verification temporarily locked. Try again in {wait_seconds} seconds.",
                )

        expires_at = _parse_iso(pending["expires_at"])
        if now > expires_at:
            conn.execute("DELETE FROM signup_otps WHERE signup_token = ?", (signup_token,))
            raise HTTPException(status_code=400, detail="OTP expired. Request a new OTP.")

        if pending["otp_code"] != otp:
            attempt_count = int(pending["attempt_count"] or 0) + 1
            if attempt_count >= OTP_MAX_VERIFY_ATTEMPTS:
                lock_until = (now + timedelta(minutes=OTP_LOCK_MINUTES)).isoformat()
                conn.execute(
                    "UPDATE signup_otps SET attempt_count = ?, locked_until = ? WHERE signup_token = ?",
                    (attempt_count, lock_until, signup_token),
                )
                raise HTTPException(
                    status_code=429,
                    detail=f"Too many invalid OTP attempts. Try again in {OTP_LOCK_MINUTES} minutes.",
                )
            conn.execute(
                "UPDATE signup_otps SET attempt_count = ? WHERE signup_token = ?",
                (attempt_count, signup_token),
            )
            raise HTTPException(status_code=400, detail="Invalid OTP code.")

        existing = conn.execute("SELECT id FROM users WHERE email = ?", (pending["email"],)).fetchone()
        if existing is not None:
            conn.execute("DELETE FROM signup_otps WHERE signup_token = ?", (signup_token,))
            raise HTTPException(status_code=409, detail="Email already registered.")

        user_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO users(id, name, email, password_hash, created_at) VALUES(?,?,?,?,?)",
            (user_id, pending["name"], pending["email"], pending["password_hash"], now_iso()),
        )
        conn.execute("DELETE FROM signup_otps WHERE signup_token = ?", (signup_token,))

        token, refresh_token = _issue_tokens(conn, user_id)

    return {
        "token": token,
        "refreshToken": refresh_token,
        "accessTokenExpiresInSeconds": ACCESS_TOKEN_TTL_MINUTES * 60,
        "user": {"id": user_id, "name": pending["name"], "email": pending["email"]},
    }


@app.post("/auth/forgot-password")
@app.post("/forgot-password")
def forgot_password(payload: ForgotPasswordRequest) -> dict[str, Any]:
    email = _normalize_email(payload.email)
    now = _now_utc()

    with db_conn() as conn:
        user = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if user is None:
            raise HTTPException(status_code=404, detail="Email not registered.")

        _enforce_otp_request_rate_limit(conn, email)

        existing = conn.execute(
            """
            SELECT reset_token, resend_count, last_sent_at, locked_until
            FROM password_reset_otps
            WHERE email = ?
            """,
            (email,),
        ).fetchone()

        if existing is not None:
            locked_until_raw = existing["locked_until"]
            if locked_until_raw:
                locked_until = _parse_iso(locked_until_raw)
                if now < locked_until:
                    wait_seconds = _seconds_until(locked_until, now)
                    raise HTTPException(
                        status_code=429,
                        detail=f"Reset verification temporarily locked. Try again in {wait_seconds} seconds.",
                    )

            last_sent_raw = existing["last_sent_at"]
            if last_sent_raw:
                last_sent_at = _parse_iso(last_sent_raw)
                next_allowed = last_sent_at + timedelta(seconds=OTP_RESEND_COOLDOWN_SECONDS)
                if now < next_allowed:
                    wait_seconds = _seconds_until(next_allowed, now)
                    raise HTTPException(
                        status_code=429,
                        detail=f"Please wait {wait_seconds} seconds before requesting another OTP.",
                    )

            resend_count = int(existing["resend_count"] or 0)
            if resend_count >= OTP_MAX_RESENDS_PER_CHALLENGE:
                raise HTTPException(
                    status_code=429,
                    detail="Reset request limit reached. Please try again later.",
                )

            reset_token = existing["reset_token"]
            otp = _new_otp()
            expires_at = (now + timedelta(minutes=OTP_EXPIRY_MINUTES)).isoformat()
            conn.execute(
                """
                UPDATE password_reset_otps
                SET otp_code = ?, expires_at = ?, resend_count = resend_count + 1,
                    attempt_count = 0, last_sent_at = ?, locked_until = NULL
                WHERE reset_token = ?
                """,
                (otp, expires_at, now.isoformat(), reset_token),
            )
        else:
            reset_token = _new_reset_token()
            otp = _new_otp()
            expires_at = (now + timedelta(minutes=OTP_EXPIRY_MINUTES)).isoformat()
            conn.execute(
                """
                INSERT INTO password_reset_otps(
                  reset_token, email, otp_code, expires_at, created_at, attempt_count,
                  resend_count, last_sent_at, locked_until
                )
                VALUES(?,?,?,?,?,?,?,?,?)
                """,
                (
                    reset_token,
                    email,
                    otp,
                    expires_at,
                    now_iso(),
                    0,
                    0,
                    now.isoformat(),
                    None,
                ),
            )
        delivery_job_id = _enqueue_job(
            conn,
            "send_otp_email",
            {"email": email, "otp": otp, "purpose": "reset"},
        )
    return {
        "resetToken": reset_token,
        "email": email,
        "expiresInSeconds": OTP_EXPIRY_MINUTES * 60,
        "message": "Password reset OTP sent.",
        "deliveryJobId": delivery_job_id,
    }


@app.post("/auth/reset-password")
@app.post("/reset-password")
def reset_password(payload: ResetPasswordRequest) -> dict[str, Any]:
    reset_token = payload.resetToken.strip()
    otp = payload.otp.strip()
    if not reset_token:
        raise HTTPException(status_code=400, detail="Invalid reset token.")
    if not otp:
        raise HTTPException(status_code=400, detail="OTP is required.")

    with db_conn() as conn:
        pending = conn.execute(
            """
            SELECT reset_token, email, otp_code, expires_at, attempt_count, locked_until
            FROM password_reset_otps
            WHERE reset_token = ?
            """,
            (reset_token,),
        ).fetchone()
        if pending is None:
            raise HTTPException(status_code=404, detail="Reset session not found.")

        now = _now_utc()
        locked_until_raw = pending["locked_until"]
        if locked_until_raw:
            locked_until = _parse_iso(locked_until_raw)
            if now < locked_until:
                wait_seconds = _seconds_until(locked_until, now)
                raise HTTPException(
                    status_code=429,
                    detail=f"Reset verification temporarily locked. Try again in {wait_seconds} seconds.",
                )

        expires_at = _parse_iso(pending["expires_at"])
        if now > expires_at:
            conn.execute("DELETE FROM password_reset_otps WHERE reset_token = ?", (reset_token,))
            raise HTTPException(status_code=400, detail="OTP expired. Request a new reset OTP.")

        if pending["otp_code"] != otp:
            attempt_count = int(pending["attempt_count"] or 0) + 1
            if attempt_count >= OTP_MAX_VERIFY_ATTEMPTS:
                lock_until = (now + timedelta(minutes=OTP_LOCK_MINUTES)).isoformat()
                conn.execute(
                    """
                    UPDATE password_reset_otps
                    SET attempt_count = ?, locked_until = ?
                    WHERE reset_token = ?
                    """,
                    (attempt_count, lock_until, reset_token),
                )
                raise HTTPException(
                    status_code=429,
                    detail=f"Too many invalid OTP attempts. Try again in {OTP_LOCK_MINUTES} minutes.",
                )
            conn.execute(
                "UPDATE password_reset_otps SET attempt_count = ? WHERE reset_token = ?",
                (attempt_count, reset_token),
            )
            raise HTTPException(status_code=400, detail="Invalid OTP code.")

        user = conn.execute("SELECT id FROM users WHERE email = ?", (pending["email"],)).fetchone()
        if user is None:
            conn.execute("DELETE FROM password_reset_otps WHERE reset_token = ?", (reset_token,))
            raise HTTPException(status_code=404, detail="User not found.")

        conn.execute(
            "UPDATE users SET password_hash = ? WHERE id = ?",
            (hash_password(payload.newPassword), user["id"]),
        )
        conn.execute("DELETE FROM password_reset_otps WHERE reset_token = ?", (reset_token,))
        conn.execute("DELETE FROM auth_tokens WHERE user_id = ?", (user["id"],))
        conn.execute("DELETE FROM auth_refresh_tokens WHERE user_id = ?", (user["id"],))

    return {"message": "Password reset successful."}


@app.post("/auth/login")
@app.post("/login")
def login(payload: LoginRequest) -> dict[str, Any]:
    email = _normalize_email(payload.email)
    with db_conn() as conn:
        row = conn.execute(
            "SELECT id, name, email, password_hash FROM users WHERE email = ?",
            (email,),
        ).fetchone()
        if row is None or not verify_password(payload.password, row["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials.")

        token, refresh_token = _issue_tokens(conn, row["id"])

    return {
        "token": token,
        "refreshToken": refresh_token,
        "accessTokenExpiresInSeconds": ACCESS_TOKEN_TTL_MINUTES * 60,
        "user": {"id": row["id"], "name": row["name"], "email": row["email"]},
    }


@app.post("/auth/refresh")
@app.post("/refresh")
def refresh_access_token(payload: RefreshTokenRequest) -> dict[str, Any]:
    refresh_token = payload.refreshToken.strip()
    if not refresh_token:
        raise HTTPException(status_code=400, detail="Refresh token is required.")

    with db_conn() as conn:
        row = conn.execute(
            """
            SELECT token, user_id, expires_at, revoked_at
            FROM auth_refresh_tokens
            WHERE token = ?
            """,
            (refresh_token,),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=401, detail="Invalid refresh token.")

        if row["revoked_at"] is not None:
            raise HTTPException(status_code=401, detail="Refresh token revoked.")

        expires_at = _parse_iso(row["expires_at"])
        if _now_utc() >= expires_at:
            conn.execute("DELETE FROM auth_refresh_tokens WHERE token = ?", (refresh_token,))
            raise HTTPException(status_code=401, detail="Refresh token expired.")

        user = conn.execute(
            "SELECT id, name, email FROM users WHERE id = ?",
            (row["user_id"],),
        ).fetchone()
        if user is None:
            conn.execute(
                "DELETE FROM auth_refresh_tokens WHERE token = ?",
                (refresh_token,),
            )
            raise HTTPException(status_code=401, detail="User not found.")

        conn.execute(
            "UPDATE auth_refresh_tokens SET revoked_at = ? WHERE token = ?",
            (now_iso(), refresh_token),
        )
        token, new_refresh_token = _issue_tokens(conn, user["id"])

    return {
        "token": token,
        "refreshToken": new_refresh_token,
        "accessTokenExpiresInSeconds": ACCESS_TOKEN_TTL_MINUTES * 60,
        "user": {"id": user["id"], "name": user["name"], "email": user["email"]},
    }


@app.get("/animals")
def list_animals(
    query: str = Query(default=""),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[dict[str, Any]]:
    normalized = query.strip().lower()
    user_id = current_user["id"]
    with db_conn() as conn:
        if normalized:
            rows = conn.execute(
                """
                SELECT id, tag, name, dob, location, notes, createdAt
                FROM animals
                WHERE userId = ?
                  AND (
                    LOWER(COALESCE(name, '')) LIKE ?
                    OR LOWER(tag) LIKE ?
                    OR LOWER(COALESCE(location, '')) LIKE ?
                  )
                ORDER BY createdAt DESC
                """,
                (user_id, f"%{normalized}%", f"%{normalized}%", f"%{normalized}%"),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT id, tag, name, dob, location, notes, createdAt
                FROM animals
                WHERE userId = ?
                ORDER BY createdAt DESC
                """,
                (user_id,),
            ).fetchall()
    return [dict(row) for row in rows]


@app.get("/animals/{animal_id}")
def get_animal(
    animal_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        row = conn.execute(
            """
            SELECT id, tag, name, dob, location, notes, createdAt
            FROM animals
            WHERE id = ? AND userId = ?
            """,
            (animal_id, user_id),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Animal not found.")
    return dict(row)


@app.post("/animals")
def create_animal(
    payload: AnimalCreateRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        animal_id = str(uuid.uuid4())
        tag = _new_tag()
        while conn.execute("SELECT id FROM animals WHERE tag = ?", (tag,)).fetchone() is not None:
            tag = _new_tag()

        created_at = now_iso()
        conn.execute(
            """
            INSERT INTO animals(id, userId, tag, name, dob, location, notes, createdAt)
            VALUES(?,?,?,?,?,?,?,?)
            """,
            (
                animal_id,
                user_id,
                tag,
                payload.name.strip() if payload.name else None,
                payload.dob,
                payload.location.strip() if payload.location else None,
                payload.notes.strip() if payload.notes else None,
                created_at,
            ),
        )
    return {
        "id": animal_id,
        "tag": tag,
        "name": payload.name.strip() if payload.name else None,
        "dob": payload.dob,
        "location": payload.location.strip() if payload.location else None,
        "notes": payload.notes.strip() if payload.notes else None,
        "createdAt": created_at,
    }


@app.get("/cases")
def list_cases(
    query: str = Query(default=""),
    animalId: str | None = Query(default=None),
    status: str | None = Query(default=None),
    disease: str | None = Query(default=None),
    limit: int | None = Query(default=None),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> list[dict[str, Any]]:
    user_id = current_user["id"]
    clauses: list[str] = []
    args: list[Any] = [user_id]

    clauses.append("userId = ?")

    if animalId:
        clauses.append("animalId = ?")
        args.append(animalId)
    if status:
        clauses.append("status = ?")
        args.append(status)
    if query.strip():
        normalized = f"%{query.strip().lower()}%"
        clauses.append(
            "(LOWER(id) LIKE ? OR LOWER(COALESCE(animalName,'')) LIKE ? OR LOWER(COALESCE(animalTag,'')) LIKE ? OR LOWER(COALESCE(predictionJson,'')) LIKE ?)"
        )
        args.extend([normalized, normalized, normalized, normalized])

    where_clause = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    limit_clause = f"LIMIT {limit}" if limit and limit > 0 else ""

    with db_conn() as conn:
        rows = conn.execute(
            f"""
            SELECT *
            FROM cases
            {where_clause}
            ORDER BY createdAt DESC
            {limit_clause}
            """,
            tuple(args),
        ).fetchall()

    mapped = [_case_from_row(row) for row in rows]
    if disease and disease != "all":
        mapped = [item for item in mapped if _disease_from_prediction(item.get("predictionJson")) == disease]
    return mapped


@app.get("/cases/pending-count")
def pending_count(current_user: dict[str, Any] = Depends(get_current_user)) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        row = conn.execute(
            "SELECT COUNT(*) AS count FROM cases WHERE status = 'pending' AND userId = ?",
            (user_id,),
        ).fetchone()
    return {"count": int(row["count"]) if row is not None else 0}


@app.get("/jobs/{job_id}")
def get_job_status(
    job_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        row = conn.execute(
            """
            SELECT id, type, payload_json, status, error_message, created_at, started_at, finished_at
            FROM background_jobs
            WHERE id = ?
            """,
            (job_id,),
        ).fetchone()
        if row is None or not _job_owned_by_user(row, user_id):
            raise HTTPException(status_code=404, detail="Job not found.")
    return _job_status_payload(row)


@app.get("/cases/{case_id}/export")
def export_case_summary(
    case_id: str,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        row = conn.execute(
            "SELECT * FROM cases WHERE id = ? AND userId = ?",
            (case_id, user_id),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Case not found.")
    return _case_export_payload(row)


@app.get("/cases/{case_id}/gradcam")
def case_gradcam(case_id: str, current_user: dict[str, Any] = Depends(get_current_user)) -> Response:
    user_id = current_user["id"]
    with db_conn() as conn:
        row = conn.execute(
            "SELECT id, userId, symptomsJson FROM cases WHERE id = ? AND userId = ?",
            (case_id, user_id),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Case not found.")
    svg = _gradcam_svg_for_case(row)
    return Response(content=svg, media_type="image/svg+xml")


@app.get("/cases/{case_id}")
def get_case(case_id: str, _: dict[str, Any] = Depends(get_current_user)) -> dict[str, Any]:
    user_id = _["id"]
    with db_conn() as conn:
        row = conn.execute(
            "SELECT * FROM cases WHERE id = ? AND userId = ?",
            (case_id, user_id),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Case not found.")
    return _case_from_row(row)


@app.post("/cases")
def create_case(
    payload: CaseCreateRequest,
    request: Request,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    case_id = str(uuid.uuid4())
    created_at = now_iso()
    user_id = current_user["id"]

    animal_name: str | None = None
    animal_tag: str | None = None
    with db_conn() as conn:
        if payload.animalId:
            animal = conn.execute(
                "SELECT name, tag FROM animals WHERE id = ? AND userId = ?",
                (payload.animalId, user_id),
            ).fetchone()
            if animal is None:
                raise HTTPException(status_code=404, detail="Animal not found.")
            animal_name = animal["name"]
            animal_tag = animal["tag"]

        prediction_json: dict[str, Any] | None = None
        status = "pending"
        synced_at: str | None = None

        if payload.shouldAttemptSync:
            prediction_json = _predict_with_external_service(
                symptoms=payload.symptoms,
                temperature=payload.temperature,
                image_path=payload.imagePath,
                animal_id=payload.animalId,
            )
            if not prediction_json.get("gradcamPath"):
                prediction_json["gradcamPath"] = (
                    f"{str(request.base_url).rstrip('/')}/cases/{case_id}/gradcam"
                )
            status = "synced"
            synced_at = now_iso()

        conn.execute(
            """
            INSERT INTO cases(
              id, userId, animalId, animalName, animalTag, createdAt, imagePath, symptomsJson, status,
              predictionJson, followUpStatus, followUpDate, notes, syncedAt, temperature, severity, attachmentsJson
            )
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                case_id,
                user_id,
                payload.animalId,
                animal_name,
                animal_tag,
                created_at,
                payload.imagePath,
                json.dumps(payload.symptoms),
                status,
                json.dumps(prediction_json) if prediction_json else None,
                "open",
                None,
                payload.notes.strip() if payload.notes else None,
                synced_at,
                payload.temperature,
                payload.severity,
                json.dumps(payload.attachments),
            ),
        )

        row = conn.execute(
            "SELECT * FROM cases WHERE id = ? AND userId = ?",
            (case_id, user_id),
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=500, detail="Failed to create case.")

    return {
        "case": _case_from_row(row),
        "syncedImmediately": payload.shouldAttemptSync,
        "warningMessage": None,
    }


@app.post("/cases/{case_id}/sync")
def sync_case(
    case_id: str,
    request: Request,
    asyncMode: bool = Query(default=False),
    _: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = _["id"]
    gradcam_path = f"{str(request.base_url).rstrip('/')}/cases/{case_id}/gradcam"
    with db_conn() as conn:
        row = conn.execute(
            "SELECT * FROM cases WHERE id = ? AND userId = ?",
            (case_id, user_id),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Case not found.")
        if asyncMode:
            job_id = _enqueue_job(
                conn,
                "sync_case",
                {
                    "caseId": case_id,
                    "userId": user_id,
                    "baseUrl": str(request.base_url).rstrip("/"),
                },
            )
            return {
                "queued": True,
                "jobId": job_id,
                "syncedCount": 0,
                "failedCount": 0,
                "errorMessage": None,
            }
        symptoms = json.loads(row["symptomsJson"] or "{}")
        prediction_json = _predict_with_external_service(
            symptoms=symptoms,
            temperature=row["temperature"],
            image_path=row["imagePath"],
            animal_id=row["animalId"],
        )
        if not prediction_json.get("gradcamPath"):
            prediction_json["gradcamPath"] = gradcam_path
        conn.execute(
            """
            UPDATE cases
            SET predictionJson = ?, status = 'synced', syncedAt = ?
            WHERE id = ? AND userId = ?
            """,
            (json.dumps(prediction_json), now_iso(), case_id, user_id),
        )
    return {"syncedCount": 1, "failedCount": 0, "errorMessage": None}


@app.post("/cases/sync-pending")
def sync_pending(
    request: Request,
    asyncMode: bool = Query(default=False),
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    synced_count = 0
    queued_job_ids: list[str] = []
    with db_conn() as conn:
        rows = conn.execute(
            "SELECT id, symptomsJson, temperature, imagePath, animalId FROM cases WHERE status = 'pending' AND userId = ?",
            (user_id,),
        ).fetchall()
        if asyncMode:
            for row in rows:
                job_id = _enqueue_job(
                    conn,
                    "sync_case",
                    {
                        "caseId": row["id"],
                        "userId": user_id,
                        "baseUrl": str(request.base_url).rstrip("/"),
                    },
                )
                queued_job_ids.append(job_id)
            return {
                "queued": True,
                "queuedCount": len(queued_job_ids),
                "jobIds": queued_job_ids,
                "syncedCount": 0,
                "failedCount": 0,
                "errorMessage": None,
            }
        for row in rows:
            symptoms = json.loads(row["symptomsJson"] or "{}")
            prediction_json = _predict_with_external_service(
                symptoms=symptoms,
                temperature=row["temperature"],
                image_path=row["imagePath"],
                animal_id=row["animalId"],
            )
            if not prediction_json.get("gradcamPath"):
                prediction_json["gradcamPath"] = (
                    f"{str(request.base_url).rstrip('/')}/cases/{row['id']}/gradcam"
                )
            conn.execute(
                """
                UPDATE cases
                SET predictionJson = ?, status = 'synced', syncedAt = ?
                WHERE id = ? AND userId = ?
                """,
                (json.dumps(prediction_json), now_iso(), row["id"], user_id),
            )
            synced_count += 1

    return {"syncedCount": synced_count, "failedCount": 0, "errorMessage": None}


@app.patch("/cases/{case_id}/follow-up")
def update_follow_up(
    case_id: str,
    payload: FollowUpUpdateRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        result = conn.execute(
            "UPDATE cases SET followUpStatus = ? WHERE id = ? AND userId = ?",
            (payload.followUpStatus, case_id, user_id),
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Case not found.")
    return {"ok": True}


@app.patch("/cases/{case_id}/notes")
def update_notes(
    case_id: str,
    payload: NotesUpdateRequest,
    current_user: dict[str, Any] = Depends(get_current_user),
) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        result = conn.execute(
            "UPDATE cases SET notes = ? WHERE id = ? AND userId = ?",
            (payload.notes.strip(), case_id, user_id),
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Case not found.")
    return {"ok": True}


@app.delete("/cases/{case_id}")
def delete_case(case_id: str, current_user: dict[str, Any] = Depends(get_current_user)) -> dict[str, Any]:
    user_id = current_user["id"]
    with db_conn() as conn:
        result = conn.execute("DELETE FROM cases WHERE id = ? AND userId = ?", (case_id, user_id))
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Case not found.")
    return {"ok": True}
