"""Accounts URL config."""

from django.urls import path
from .views import RegisterView, LoginView, MeView, NearbyHospitalsView

app_name = "accounts"
urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", LoginView.as_view(), name="login"),
    path("me/", MeView.as_view(), name="me"),
    path("nearby/", NearbyHospitalsView.as_view(), name="nearby"),
]
