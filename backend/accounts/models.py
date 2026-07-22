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

# Keep existing User and UserProfile models...

class MedicalHistory(models.Model):
    """Structured past medical conditions (Feature #1)."""
    STATUS_CHOICES = [
        ('resolved', 'Resolved'),
        ('ongoing', 'Ongoing'),
        ('chronic', 'Chronic'),
        ('remission', 'Remission'),
        ('unknown', 'Unknown'),
    ]
    
    SEVERITY_CHOICES = [
        ('mild', 'Mild'),
        ('moderate', 'Moderate'),
        ('severe', 'Severe'),
        ('unknown', 'Unknown'),
    ]
    
    RISK_CHOICES = [
        ('high', 'High'),
        ('moderate', 'Moderate'),
        ('low', 'Low'),
        ('none', 'None'),
        ('unknown', 'Unknown'),
    ]
    
    user_profile = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name='medical_history_entries'
    )
    
    condition_name = models.CharField(max_length=255)
    date_diagnosed = models.DateField(null=True, blank=True)
    date_resolved = models.DateField(null=True, blank=True)
    duration_text = models.CharField(max_length=255, blank=True, null=True)
    treatment_received = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='unknown')
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES, default='unknown', blank=True)
    recurrence_risk = models.CharField(max_length=20, choices=RISK_CHOICES, default='unknown', blank=True)
    notes = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-date_diagnosed', '-created_at']
        unique_together = ('user_profile', 'condition_name', 'date_diagnosed')
    
    def __str__(self):
        return f"{self.user_profile.user.email} - {self.condition_name}"


class AnalysisRecord(models.Model):
    """Saved AI analysis results (Feature #5)."""
    user_profile = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name='analysis_records'
    )
    
    analysis_id = models.CharField(max_length=50, unique=True)
    past_conditions = models.JSONField(default=list)
    current_complaint = models.TextField()
    
    agent1_output = models.JSONField()
    agent2_output = models.TextField()
    agent3_output = models.TextField()
    agent4_output = models.TextField()
    
    urgent_flag = models.BooleanField(default=False)
    specialty_persona = models.CharField(max_length=100, blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.analysis_id}"


class AnalysisFeedback(models.Model):
    """Feedback on analysis (Feature #4)."""
    ACCURACY_CHOICES = [
        ('accurate', 'Accurate'),
        ('partially_correct', 'Partially Correct'),
        ('inaccurate', 'Inaccurate'),
        ('helpful_but_uncertain', 'Helpful but Uncertain'),
    ]
    
    analysis = models.ForeignKey(
        AnalysisRecord,
        on_delete=models.CASCADE,
        related_name='feedback'
    )
    
    accuracy = models.CharField(max_length=30, choices=ACCURACY_CHOICES)
    comments = models.TextField(blank=True, null=True)
    corrected_diagnosis = models.CharField(max_length=255, blank=True, null=True)
    submitted_by = models.CharField(
        max_length=20,
        choices=[
            ('patient', 'Patient'),
            ('doctor', 'Doctor'),
            ('clinician', 'Clinician'),
        ],
        default='patient'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Feedback on {self.analysis.analysis_id}"
