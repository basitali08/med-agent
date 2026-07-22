import uuid
from django.db import models
from .analysis import Analysis


class Feedback(models.Model):
    """User feedback on a specific analysis/diagnosis."""
    
    RATING_CHOICES = [
        ('accurate', 'Accurate'),
        ('inaccurate', 'Inaccurate'),
        ('partial', 'Partially Correct'),
    ]
    
    FEEDBACK_SOURCE_CHOICES = [
        ('patient', 'Patient'),
        ('clinician', 'Clinician'),
        ('doctor', 'Doctor'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    analysis = models.ForeignKey(Analysis, on_delete=models.CASCADE, related_name='feedback_comments')
    
    source = models.CharField(
        max_length=20,
        choices=FEEDBACK_SOURCE_CHOICES,
        default='patient',
        help_text="Who provided this feedback"
    )
    rating = models.CharField(
        max_length=20,
        choices=RATING_CHOICES,
        help_text="Was the diagnosis accurate?"
    )
    comment = models.TextField(
        blank=True,
        null=True,
        help_text="Free-text feedback/corrections"
    )
    
    # For future weighted learning
    weight = models.FloatField(
        default=1.0,
        help_text="Weight for learning (1.0 for patient, 3.0 for doctor)"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'feedbacks'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Feedback ({self.rating}) on {self.analysis.id}"
