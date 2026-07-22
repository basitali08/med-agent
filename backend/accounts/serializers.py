"""
Django REST Framework serializers for accounts app.
Includes serializers for User, UserProfile, MedicalHistory, and AnalysisRecord.
"""
from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import UserProfile, MedicalHistory, AnalysisRecord, AnalysisFeedback

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model (registration and login)."""
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'created_at']
        read_only_fields = ['id', 'created_at']


class UserRegisterSerializer(serializers.ModelSerializer):
    """Serializer for user registration (with password)."""
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm']

    def validate(self, data):
        if data['password'] != data.pop('password_confirm'):
            raise serializers.ValidationError("Passwords do not match")
        return data

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User.objects.create_user(**validated_data)
        user.set_password(password)
        user.save()
        # Create associated UserProfile
        UserProfile.objects.create(user=user)
        return user


class MedicalHistorySerializer(serializers.ModelSerializer):
    """Serializer for MedicalHistory model (CRUD operations)."""
    class Meta:
        model = MedicalHistory
        fields = [
            'id',
            'condition_name',
            'date_diagnosed',
            'date_resolved',
            'duration_text',
            'treatment_received',
            'status',
            'severity',
            'recurrence_risk',
            'notes',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer for UserProfile with nested MedicalHistory."""
    medical_history = MedicalHistorySerializer(many=True, read_only=True)
    user = UserSerializer(read_only=True)

    class Meta:
        model = UserProfile
        fields = [
            'id',
            'user',
            'blood_type',
            'gender',
            'date_of_birth',
            'phone_number',
            'allergies',
            'current_medications',
            'latitude',
            'longitude',
            'emergency_contact_name',
            'emergency_contact_phone',
            'medical_history',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    """Serializer for updating UserProfile (without nested history)."""
    class Meta:
        model = UserProfile
        fields = [
            'blood_type',
            'gender',
            'date_of_birth',
            'phone_number',
            'allergies',
            'current_medications',
            'latitude',
            'longitude',
            'emergency_contact_name',
            'emergency_contact_phone',
        ]


class AnalysisFeedbackSerializer(serializers.ModelSerializer):
    """Serializer for AnalysisFeedback."""
    class Meta:
        model = AnalysisFeedback
        fields = [
            'id',
            'accuracy',
            'comments',
            'corrected_diagnosis',
            'submitted_by',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class AnalysisRecordSerializer(serializers.ModelSerializer):
    """Serializer for AnalysisRecord with feedback."""
    feedback = AnalysisFeedbackSerializer(many=True, read_only=True)

    class Meta:
        model = AnalysisRecord
        fields = [
            'id',
            'analysis_id',
            'past_conditions',
            'current_complaint',
            'agent1_output',
            'agent2_output',
            'agent3_output',
            'agent4_output',
            'urgent_flag',
            'specialty_persona',
            'feedback',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'analysis_id',
            'agent1_output',
            'agent2_output',
            'agent3_output',
            'agent4_output',
            'created_at',
            'updated_at',
        ]


class AnalysisRecordListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for listing analyses (without full agent outputs)."""
    feedback_count = serializers.SerializerMethodField()

    class Meta:
        model = AnalysisRecord
        fields = [
            'id',
            'analysis_id',
            'current_complaint',
            'urgent_flag',
            'specialty_persona',
            'feedback_count',
            'created_at',
        ]
        read_only_fields = fields

    def get_feedback_count(self, obj):
        return obj.feedback.count()


class PipelineInputSerializer(serializers.Serializer):
    """
    Serializer for AI pipeline input.
    Accepts both past conditions (from medical history) and current complaint.
    """
    # Past conditions from medical history
    past_medical_history = serializers.ListField(
        child=serializers.DictField(),
        required=False,
        help_text="List of past medical conditions (from UserProfile.medical_history)"
    )

    # Current complaint/symptoms
    current_complaint = serializers.CharField(
        max_length=2000,
        help_text="Current symptoms or reason for visit"
    )

    # Optional: include specific medical history IDs
    medical_history_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        help_text="IDs of specific MedicalHistory records to include"
    )

    # Optional: save the analysis result
    save_analysis = serializers.BooleanField(
        default=False,
        help_text="Whether to save this analysis to the user's record"
    )

    def validate_current_complaint(self, value):
        if len(value.strip()) < 10:
            raise serializers.ValidationError(
                "Current complaint must be at least 10 characters."
            )
        return value


class PipelineOutputSerializer(serializers.Serializer):
    """Serializer for AI pipeline output."""
    run_id = serializers.CharField()
    urgent = serializers.BooleanField()
    phi_count = serializers.IntegerField()
    agent1 = serializers.DictField()
    agent2 = serializers.CharField()
    agent3 = serializers.CharField()
    agent4 = serializers.CharField()
    specialty_persona = serializers.CharField(required=False)
    analysis_id = serializers.CharField(required=False)


class MedicalHistoryBulkSerializer(serializers.Serializer):
    """Serializer for bulk import/export of medical history."""
    conditions = serializers.ListField(
        child=MedicalHistorySerializer()
    )

    def create(self, validated_data):
        """Bulk create medical history records."""
        user_profile = self.context['user_profile']
        conditions = validated_data['conditions']
        
        created_records = []
        for cond_data in conditions:
            record = MedicalHistory.objects.create(
                user_profile=user_profile,
                **cond_data
            )
            created_records.append(record)
        
        return created_records
