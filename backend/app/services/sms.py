import base64
import logging
from typing import Any
import urllib.parse
import urllib.request
import json

from app.core.config import settings

logger = logging.getLogger("gaz.sms")


class SmsGatewayService:
    """Production Multi-Provider SMS Gateway for OTP dispatch and alerts.
    Supports Twilio, Infobip, Orange, Custom Telco Webhook, and Local Dev Stub.
    """

    @staticmethod
    def format_otp_message(code: str, lang: str = "fr") -> str:
        if lang == "ar":
            return f"رمز التحقق الخاص بك لتطبيق غاز روت هو: {code}. صالح لمدة 5 دقائق."
        return f"Votre code de vérification GazRoute est: {code}. Valable 5 minutes."

    @classmethod
    def send_otp(cls, phone: str, code: str, lang: str = "fr") -> bool:
        message = cls.format_otp_message(code, lang)
        return cls.send_sms(phone, message)

    @classmethod
    def send_sms(cls, phone: str, message: str) -> bool:
        provider = settings.sms_provider.lower().strip()

        if provider == "twilio":
            return cls._send_twilio(phone, message)
        elif provider == "infobip":
            return cls._send_infobip(phone, message)
        elif provider == "orange":
            return cls._send_orange(phone, message)
        elif provider == "custom":
            return cls._send_custom_webhook(phone, message)
        else:
            return cls._send_stub(phone, message)

    @classmethod
    def _send_stub(cls, phone: str, message: str) -> bool:
        print(f"\n========================================================")
        print(f" [SMS GATEWAY: DEV STUB]")
        print(f" To: {phone}")
        print(f" Body: {message}")
        print(f"========================================================\n")
        logger.info("[SMS STUB] Sent to %s: %s", phone, message)
        return True

    @classmethod
    def _send_twilio(cls, phone: str, message: str) -> bool:
        sid = settings.twilio_account_sid
        token = settings.twilio_auth_token
        from_num = settings.twilio_from_number

        if not sid or not token or not from_num:
            logger.warning("[SMS TWILIO] Missing credentials. Falling back to console log.")
            return cls._send_stub(phone, message)

        url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
        data = urllib.parse.urlencode({
            "To": phone,
            "From": from_num,
            "Body": message,
        }).encode("utf-8")

        auth_str = f"{sid}:{token}"
        b64_auth = base64.b64encode(auth_str.encode("utf-8")).decode("ascii")

        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Basic {b64_auth}",
                "Content-Type": "application/x-www-form-urlencoded",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
                body = resp.read().decode("utf-8")
                logger.info("[SMS TWILIO] Response status %d: %s", status, body)
                return 200 <= status < 300
        except Exception as e:
            logger.error("[SMS TWILIO] Dispatch failed: %s", e)
            return False

    @classmethod
    def _send_infobip(cls, phone: str, message: str) -> bool:
        api_key = settings.infobip_api_key
        base_url = settings.infobip_base_url.rstrip("/")

        if not api_key or not base_url:
            logger.warning("[SMS INFOBIP] Missing API key or base URL. Falling back to stub.")
            return cls._send_stub(phone, message)

        url = f"{base_url}/sms/2/text/advanced"
        payload = {
            "messages": [
                {
                    "from": settings.sms_sender_name,
                    "destinations": [{"to": phone}],
                    "text": message,
                }
            ]
        }
        data = json.dumps(payload).encode("utf-8")

        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"App {api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
                logger.info("[SMS INFOBIP] Dispatched with status %d", status)
                return 200 <= status < 300
        except Exception as e:
            logger.error("[SMS INFOBIP] Dispatch failed: %s", e)
            return False

    @classmethod
    def _send_orange(cls, phone: str, message: str) -> bool:
        client_id = settings.orange_client_id
        client_secret = settings.orange_client_secret
        sender_address = settings.orange_sender_address

        if not client_id or not client_secret:
            logger.warning("[SMS ORANGE] Missing credentials. Falling back to stub.")
            return cls._send_stub(phone, message)

        try:
            # 1. Obtain OAuth token
            token_url = "https://api.orange.com/oauth/v3/token"
            auth_str = f"{client_id}:{client_secret}"
            b64_auth = base64.b64encode(auth_str.encode("utf-8")).decode("ascii")
            token_data = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode("utf-8")

            token_req = urllib.request.Request(
                token_url,
                data=token_data,
                headers={"Authorization": f"Basic {b64_auth}", "Content-Type": "application/x-www-form-urlencoded"},
                method="POST",
            )

            with urllib.request.urlopen(token_req, timeout=10) as resp:
                token_json = json.loads(resp.read().decode("utf-8"))
                access_token = token_json.get("access_token")

            if not access_token:
                logger.error("[SMS ORANGE] Failed to retrieve access token")
                return False

            # 2. Send SMS
            clean_sender = urllib.parse.quote(sender_address or "tel:+212000000000")
            clean_recipient = urllib.parse.quote(f"tel:{phone}")
            sms_url = f"https://api.orange.com/smsmessaging/v1/outbound/{clean_sender}/requests"

            sms_payload = {
                "outboundSMSMessageRequest": {
                    "address": clean_recipient,
                    "senderAddress": clean_sender,
                    "outboundSMSTextMessage": {"message": message},
                }
            }

            sms_data = json.dumps(sms_payload).encode("utf-8")
            sms_req = urllib.request.Request(
                sms_url,
                data=sms_data,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )

            with urllib.request.urlopen(sms_req, timeout=10) as resp:
                return 200 <= resp.status < 300

        except Exception as e:
            logger.error("[SMS ORANGE] Dispatch failed: %s", e)
            return False

    @classmethod
    def _send_custom_webhook(cls, phone: str, message: str) -> bool:
        url = settings.custom_sms_url
        token = settings.custom_sms_bearer_token

        if not url:
            logger.warning("[SMS CUSTOM] Missing custom webhook URL.")
            return cls._send_stub(phone, message)

        payload = {"phone": phone, "message": message, "sender": settings.sms_sender_name}
        data = json.dumps(payload).encode("utf-8")

        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        req = urllib.request.Request(url, data=data, headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                return 200 <= resp.status < 300
        except Exception as e:
            logger.error("[SMS CUSTOM] Dispatch failed: %s", e)
            return False
