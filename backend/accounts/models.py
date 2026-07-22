"""
Django models for user authentication and medical profile.
Includes User, UserProfile, and MedicalHistory models.
"""
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator


class User(AbstractUser):
    """Custom user model extending Django's AbstractUser."""
    email = models.EmailField(unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.username} ({self.email})"


class UserProfile(models.Model):
    """Extended user profile with medical information."""
    BLOOD_TYPE_CHOICES = [
        ('O-', 'O Negative'),
        ('O+', 'O Positive'),
        ('A-', 'A Negative'),
        ('A+', 'A Positive'),
        ('B-', 'B Negative'),
        ('B+', 'B Positive'),
        ('AB-', 'AB Negative'),
        ('AB+', 'AB Positive'),
    ]

    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
        ('O', 'Other'),
        ('N', 'Prefer not to say'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    
    # Personal medical info
    blood_type = models.CharField(
        max_length=3, 
        choices=BLOOD_TYPE_CHOICES, 
        null=True, 
        blank=True
    )
    gender = models.CharField(
        max_length=1, 
        choices=GENDER_CHOICES, 
        null=True, 
        blank=True
    )
    date_of_birth = models.DateField(null=True, blank=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    
    # Allergies and medications (comma-separated or JSON)
    allergies = models.TextField(
        blank=True, 
        null=True, 
        help_text="Comma-separated list of known allergies"
    )
    current_medications = models.TextField(
        blank=True, 
        null=True, 
        help_text="Comma-separated list of current medications"
    )
    
    # Location for nearby hospitals feature
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    
    # Additional info
    emergency_contact_name = models.CharField(max_length=100, blank=True, null=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.user.username} Profile"


class MedicalHistory(models.Model):
    """
    Stores patient's past medical conditions.
    Each entry represents a single past condition/illness.
    """
    STATUS_CHOICES = [
        ('resolved', 'Resolved'),
        ('ongoing', 'Ongoing'),
        ('chronic', 'Chronic'),
        ('remission', 'Remission'),
        ('unknown', 'Unknown'),
    ]

    user_profile = models.ForeignKey(
        UserProfile, 
        on_delete=models.CASCADE, 
        related_name='medical_history'
    )
    
    # Condition details
    condition_name = models.CharField(
        max_length=255, 
        help_text="Name of the past medical condition (e.g., 'Type 2 Diabetes', 'Pneumonia')"
    )
    
    # Timing
    date_diagnosed = models.DateField(
        null=True, 
        blank=True, 
        help_text="When the condition was diagnosed"
    )
    date_resolved = models.DateField(
        null=True, 
        blank=True, 
        help_text="When the condition resolved (if applicable)"
    )
    
    # Duration/timeframe (text field for flexibility)
    duration_text = models.CharField(
        max_length=255, 
        blank=True, 
        null=True, 
        help_text="e.g., '2019-2020' or '6 months' if exact dates unavailable"
    )
    
    # Treatment & outcome
    treatment_received = models.TextField(
        blank=True, 
        null=True, 
        help_text="Description of treatment (medication, surgery, etc.)"
    )
    
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='unknown'
    )
    
    # Additional notes
    notes = models.TextField(
        blank=True, 
        null=True, 
        help_text="Additional clinical notes or important details"
    )
    
    # Severity (optional)
    severity = models.CharField(
        max_length=20,
        choices=[
            ('mild', 'Mild'),
            ('moderate', 'Moderate'),
            ('severe', 'Severe'),
            ('unknown', 'Unknown'),
        ],
        default='unknown',
        blank=True
    )
    
    # Risk of recurrence (yes/no/unknown)
    recurrence_risk = models.CharField(
        max_length=20,
        choices=[
            ('high', 'High'),
            ('moderate', 'Moderate'),
            ('low', 'Low'),
            ('none', 'None'),
            ('unknown', 'Unknown'),
        ],
        default='unknown',
        blank=True
    )
    
    # Metadata
    is_active = models.BooleanField(default=True, help_text="Whether to include in AI analysis")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-date_diagnosed', '-created_at']
        unique_together = ('user_profile', 'condition_name', 'date_diagnosed')
        verbose_name_plural = "Medical Histories"

    def __str__(self):
        return f"{self.user_profile.user.username} - {self.condition_name}"


class AnalysisRecord(models.Model):
    """
    Stores saved AI analysis results.
    Used for Feature #5 (Save & Organize Each Analysis).
    """
    user_profile = models.ForeignKey(
        UserProfile, 
        on_delete=models.CASCADE, 
        related_name='analysis_records'
    )
    
    # Unique identifier
    analysis_id = models.CharField(
        max_length=50, 
        unique=True, 
        help_text="Auto-generated unique ID (e.g., Analysis_2026-07-21_001)"
    )
    
    # Input data
    past_conditions = models.JSONField(
        help_text="List of past medical conditions used in analysis"
    )
    current_complaint = models.TextField(
        help_text="Current symptoms/complaint analyzed"
    )
    
    # Agent outputs (stored for audit trail)
    agent1_output = models.JSONField(help_text="Agent 1 extraction")
    agent2_output = models.TextField(help_text="Agent 2 summary")
    agent3_output = models.TextField(help_text="Agent 3 differential analysis")
    agent4_output = models.TextField(help_text="Agent 4 treatment plan")
    
    # Metadata
    urgent_flag = models.BooleanField(default=False, help_text="Whether red flags detected")
    specialty_persona = models.CharField(
        max_length=100, 
        blank=True, 
        null=True, 
        help_text="Medical specialty used in Agent 4 response"
    )
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.analysis_id} ({self.user_profile.user.username})"


class AnalysisFeedback(models.Model):
    """
    Stores feedback on analysis results.
    Used for Feature #4 (Feedback System) and Feature #6 (Continuous Learning).
    """
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
    
    # Accuracy rating
    accuracy = models.CharField(
        max_length=30, 
        choices=ACCURACY_CHOICES
    )
    
    # Free-text feedback
    comments = models.TextField(
        blank=True, 
        null=True, 
        help_text="Detailed feedback or corrections"
    )
    
    # Optional: specific corrections to agent outputs
    corrected_diagnosis = models.CharField(
        max_length=255, 
        blank=True, 
        null=True, 
        help_text="If analysis was inaccurate, what should it have been?"
    )
    
    # Who submitted feedback
    submitted_by = models.CharField(
        max_length=20,
        choices=[
            ('patient', 'Patient'),
            ('doctor', 'Doctor'),
            ('clinician', 'Clinician'),
            ('other', 'Other'),
        ],
        default='patient'
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Feedback on {self.analysis.analysis_id}"
