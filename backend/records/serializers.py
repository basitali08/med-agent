"""Records serializers — plaintext in/out, ciphertext at rest."""

from rest_framework import serializers
from .models import MedicalRecord


class RecordSerializer(serializers.ModelSerializer):
    content = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = MedicalRecord
        fields = ["id", "title", "record_type", "content", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]

    def create(self, validated):
        content = validated.pop("content", "")
        record = MedicalRecord(**validated)
        record.set_content(content)
        record.save()
        return record

    def update(self, instance, validated):
        content = validated.pop("content", None)
        for k, v in validated.items():
            setattr(instance, k, v)
        if content is not None:
            instance.set_content(content)
        instance.save()
        return instance


class RecordDetailSerializer(serializers.ModelSerializer):
    """Read serializer that decrypts content for the owner."""

    content = serializers.SerializerMethodField()

    class Meta:
        model = MedicalRecord
        fields = ["id", "title", "record_type", "content", "created_at", "updated_at"]

    def get_content(self, obj):
        return obj.content
