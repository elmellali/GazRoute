from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import AuthDep, DbDep
from app.core.exceptions import Forbidden, Unauthorized, ValidationException
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_otp_code,
    hash_password,
    is_revoked,
    revoke_jti,
)
from app.models import OtpCode, User
from app.schemas import (
    OtpRequestIn,
    OtpRequestOut,
    OtpVerifyIn,
    RefreshIn,
    TokenOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _normalize_phone(phone: str) -> str:
    p = phone.strip().replace(" ", "").replace("-", "")
    if p.startswith("00"):
        p = "+" + p[2:]
    if p.startswith("0") and len(p) == 10:
        p = "+212" + p[1:]
    if p.startswith("212") and not p.startswith("+"):
        p = "+" + p
    return p


@router.post("/otp/request", response_model=OtpRequestOut)
def otp_request(body: OtpRequestIn, db: DbDep) -> OtpRequestOut:
    phone = _normalize_phone(body.phone)
    window_start = datetime.now(timezone.utc) - timedelta(seconds=settings.otp_rate_window_seconds)
    recent = db.execute(
        select(func.count(OtpCode.id)).where(OtpCode.phone == phone, OtpCode.created_at >= window_start)
    ).scalar_one()
    if recent >= settings.otp_rate_limit:
        raise ValidationException("OTP rate limit exceeded (3 per 10 minutes)")

    code = generate_otp_code()
    otp = OtpCode(
        phone=phone,
        code_hash=hash_password(code),
        expires_at=datetime.now(timezone.utc) + timedelta(seconds=settings.otp_ttl_seconds),
    )
    db.add(otp)
    db.commit()

    from app.services.sms import SmsGatewayService

    # Dispatch real SMS via configured provider (Twilio, Infobip, Orange, Custom, or Dev Stub)
    SmsGatewayService.send_otp(phone, code)

    return OtpRequestOut(
        message="OTP dispatched via SMS",
        expires_in_seconds=settings.otp_ttl_seconds,
        dev_code=code if settings.env == "dev" else None,
    )


@router.post("/otp/verify", response_model=TokenOut)
def otp_verify(body: OtpVerifyIn, db: DbDep) -> TokenOut:
    phone = _normalize_phone(body.phone)
    now = datetime.now(timezone.utc)
    otp = db.execute(
        select(OtpCode)
        .where(OtpCode.phone == phone, OtpCode.consumed_at.is_(None), OtpCode.expires_at > now)
        .order_by(OtpCode.created_at.desc())
    ).scalars().first()
    if otp is None:
        raise Unauthorized("OTP expired or not found")
    otp.attempts += 1
    if otp.attempts > 5:
        otp.consumed_at = now
        db.commit()
        raise Unauthorized("Too many attempts")
    from app.core.security import verify_password

    if not verify_password(otp.code_hash, body.otp_code):
        db.commit()
        raise Unauthorized("Invalid OTP")
    otp.consumed_at = now

    user = db.execute(
        select(User).where(User.phone == phone, User.is_active.is_(True))
    ).scalars().first()
    if user is None:
        db.commit()
        raise Unauthorized("No active account for this phone number")

    device_id = body.device_id
    access = create_access_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role, device_id=device_id
    )
    refresh = create_refresh_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role, device_id=device_id
    )
    db.commit()
    return TokenOut(
        access_token=access,
        refresh_token=refresh,
        role=user.role,
        tenant_id=user.tenant_id,
        user_id=user.id,
        expires_in_seconds=settings.access_token_expire_minutes * 60,
    )


@router.post("/refresh", response_model=TokenOut)
def refresh_token(body: RefreshIn, db: DbDep) -> TokenOut:
    try:
        payload = decode_token(body.refresh_token)
    except Exception:
        raise Unauthorized("Invalid refresh token")
    if payload.get("type") != "refresh":
        raise Unauthorized("Refresh token required")
    jti = payload.get("jti") or ""
    if jti and is_revoked(jti):
        raise Unauthorized("Refresh token revoked")
    sub = payload.get("sub")
    try:
        user_uuid = UUID(str(sub))
    except (ValueError, TypeError):
        raise Unauthorized("Invalid user ID in token")
    user = db.get(User, user_uuid)
    if user is None or not user.is_active:
        raise Unauthorized("User inactive")
    if str(user.tenant_id) != payload.get("tenant_id"):
        raise Forbidden("Tenant mismatch")
    # rotate: revoke old refresh jti
    if jti:
        revoke_jti(jti)
    access = create_access_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role, device_id=payload.get("device_id")
    )
    new_refresh = create_refresh_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role, device_id=payload.get("device_id")
    )
    return TokenOut(
        access_token=access,
        refresh_token=new_refresh,
        role=user.role,
        tenant_id=user.tenant_id,
        user_id=user.id,
        expires_in_seconds=settings.access_token_expire_minutes * 60,
    )


@router.post("/logout")
def logout(ctx: AuthDep) -> dict:
    if ctx.jti:
        revoke_jti(ctx.jti)
    return {"message": "logged out"}
