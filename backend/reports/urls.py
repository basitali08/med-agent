"""Reports URL config."""

from django.urls import path
from .views import GenerateReportView

app_name = "reports"
urlpatterns = [
    path("generate/", GenerateReportView.as_view(), name="generate"),
]
