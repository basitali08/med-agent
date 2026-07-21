"""Medical record model — content is stored encrypted at rest."""

from django.contrib.auth import get_user_model
from django.db import models
from .crypto import decrypt, encrypt

User = get_user_model()


class MedicalRecord(models.Model):
    RECORD_TYPES = [
        ("lab", "Lab report"),
        ("imaging", "Imaging"),
        ("prescription", "Prescription"),
        ("note", "Clinical note"),
        ("other", "Other"),
    ]
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="records")
    title = models.CharField(max_length=200)
    record_type = models.CharField(max_length=20, choices=RECORD_TYPES, default="other")
    # Ciphertext only — plaintext is never persisted.
    encrypted_content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.title} ({self.record_type})"

    # Convenience accessors (decrypt on read).
    @property
    def content(self) -> str:
        try:
            return decrypt(self.encrypted_content)
        except Exception:
            return ""

    def set_content(self, plaintext: str) -> None:
        self.encrypted_content = encrypt(plaintext)
