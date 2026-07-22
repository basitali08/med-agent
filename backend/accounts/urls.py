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
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegisterView, LoginView, MeView, NearbyHospitalsView,
    MedicalHistoryViewSet, AnalysisRecordViewSet
)

router = DefaultRouter()
router.register(r'medical-history', MedicalHistoryViewSet, basename='medical-history')
router.register(r'analysis-records', AnalysisRecordViewSet, basename='analysis-records')

urlpatterns = [
    # Keep existing auth endpoints
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('me/', MeView.as_view(), name='me'),
    path('nearby/', NearbyHospitalsView.as_view(), name='nearby-hospitals'),
    
    # Add new medical history & analysis endpoints
    path('', include(router.urls)),
]
