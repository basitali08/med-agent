"""Accounts app: email-based user registration & token auth."""

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Email-based user (username kept but email is the login identifier)."""

    email = models.EmailField(unique=True)
    REQUIRED_FIELDS = ["email"]

    def __str__(self):
        return self.email


class UserProfile(models.Model):
    """Extended profile for each user — medical & personal data."""

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")

    # Personal
    full_name = models.CharField(max_length=200, blank=True, default="")
    phone = models.CharField(max_length=20, blank=True, default="")
    date_of_birth = models.DateField(null=True, blank=True)
    address = models.TextField(blank=True, default="")

    # Medical
    BLOOD_TYPES = [
        ("A+", "A+"), ("A-", "A-"),
        ("B+", "B+"), ("B-", "B-"),
        ("AB+", "AB+"), ("AB-", "AB-"),
        ("O+", "O+"), ("O-", "O-"),
        ("", "Unknown"),
    ]
    blood_type = models.CharField(max_length=5, choices=BLOOD_TYPES, blank=True, default="")
    height_cm = models.FloatField(null=True, blank=True)
    weight_kg = models.FloatField(null=True, blank=True)
    known_allergies = models.TextField(blank=True, default="")
    medical_conditions = models.TextField(blank=True, default="")
    medications = models.TextField(blank=True, default="")

    # Location (populated when user grants permission)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile({self.user.email})"
