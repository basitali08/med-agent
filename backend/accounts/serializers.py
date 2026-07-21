"""Accounts serializers."""

from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import UserProfile

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    # Profile fields (all optional at registration)
    full_name = serializers.CharField(required=False, default="")
    phone = serializers.CharField(required=False, default="")
    date_of_birth = serializers.DateField(required=False, default=None, allow_null=True)
    blood_type = serializers.CharField(required=False, default="")
    height_cm = serializers.FloatField(required=False, default=None, allow_null=True)
    weight_kg = serializers.FloatField(required=False, default=None, allow_null=True)
    known_allergies = serializers.CharField(required=False, default="")
    address = serializers.CharField(required=False, default="")

    class Meta:
        model = User
        fields = [
            "id", "username", "email", "password",
            "full_name", "phone", "date_of_birth",
            "blood_type", "height_cm", "weight_kg",
            "known_allergies", "address",
        ]

    def create(self, validated):
        profile_data = {}
        profile_fields = [
            "full_name", "phone", "date_of_birth",
            "blood_type", "height_cm", "weight_kg",
            "known_allergies", "address",
        ]
        for f in profile_fields:
            if f in validated:
                profile_data[f] = validated.pop(f)

        user = User.objects.create_user(
            username=validated["username"],
            email=validated["email"],
            password=validated["password"],
        )
        UserProfile.objects.create(user=user, **profile_data)
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            "full_name", "phone", "date_of_birth",
            "blood_type", "height_cm", "weight_kg",
            "known_allergies", "medical_conditions", "medications",
            "address", "latitude", "longitude",
        ]


class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ["id", "username", "email", "profile"]
