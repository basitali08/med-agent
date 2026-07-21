"""Records URL config."""

from django.urls import path
from .views import (
    RecordListCreateView, RecordDetailView, LabUploadView, VoiceTranscribeView,
    LabAnalyzeTextView,
)

app_name = "records"
urlpatterns = [
    path("", RecordListCreateView.as_view(), name="list-create"),
    path("<int:pk>/", RecordDetailView.as_view(), name="detail"),
    path("labs/upload/", LabUploadView.as_view(), name="lab-upload"),
    path("labs/analyze/", LabAnalyzeTextView.as_view(), name="lab-analyze"),
    path("voice/transcribe/", VoiceTranscribeView.as_view(), name="voice-transcribe"),
]
