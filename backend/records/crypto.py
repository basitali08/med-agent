"""Encryption helpers for at-rest medical records.

Uses Fernet (from the `cryptography` package). If the package is unavailable we fall back
to a clear-text warning mode so the app still imports — but DO NOT rely on that for real
patient data; install `cryptography` and set RECORD_ENCRYPTION_KEY properly.
"""

from django.conf import settings

try:
    from cryptography.fernet import Fernet, InvalidToken

    _fernet = Fernet(settings.RECORD_ENCRYPTION_KEY)
    FERNET_AVAILABLE = True
except Exception:  # pragma: no cover - fallback only
    FERNET_AVAILABLE = False

    class InvalidToken(Exception):
        pass


def encrypt(plaintext: str) -> str:
    if not FERNET_AVAILABLE:
        # Fallback (INSECURE): keep plaintext but mark it.
        return "PLAINTEXT:" + plaintext
    return _fernet.encrypt(plaintext.encode("utf-8")).decode("utf-8")


def decrypt(token: str) -> str:
    if token.startswith("PLAINTEXT:"):
        return token[len("PLAINTEXT:"):]
    if not FERNET_AVAILABLE:
        raise InvalidToken("cryptography not installed")
    return _fernet.decrypt(token.encode("utf-8")).decode("utf-8")
