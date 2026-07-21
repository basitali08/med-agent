"""URL routing for the MED AGENT backend."""

from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("accounts.urls")),
    path("api/pipeline/", include("pipeline.urls")),
    path("api/records/", include("records.urls")),
    path("api/reports/", include("reports.urls")),
]
