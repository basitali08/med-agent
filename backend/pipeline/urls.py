"""Pipeline URL config."""

from django.urls import path
from .views import AnalyzeView
from .streaming_views import StreamAnalyzeView

app_name = "pipeline"
urlpatterns = [
    path("analyze/", AnalyzeView.as_view(), name="analyze"),
    path("stream/", StreamAnalyzeView.as_view(), name="stream-analyze"),
]
