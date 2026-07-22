"""
URL routing configuration for med-agent backend.
Includes auth, profile, medical history, and pipeline endpoints.
"""
from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework.authtoken.views import obtain_auth_token

# Import views
from accounts.views import (
    UserRegisterView,
    UserLoginView,
    UserProfileView,
    UserLogoutView,
    MedicalHistoryViewSet,
    AnalysisRecordViewSet,
    NearbyHospitalsView,
)
from pipeline.views import (
    PipelineAnalyzeView,
    PipelineHistoryView,
)

# Create router for ViewSets
router = DefaultRouter()
router.register(r'medical-history', MedicalHistoryViewSet, basename='medical-history')
router.register(r'analysis-records', AnalysisRecordViewSet, basename='analysis-records')

# Auth URLs
auth_urls = [
    path('register/', UserRegisterView.as_view(), name='register'),
    path('login/', UserLoginView.as_view(), name='login'),
    path('logout/', UserLogoutView.as_view(), name='logout'),
    path('me/', UserProfileView.as_view(), name='profile'),
    path('nearby/', NearbyHospitalsView.as_view(), name='nearby-hospitals'),
    path('token/', obtain_auth_token, name='token-auth'),  # Standard token auth
]

# Pipeline URLs
pipeline_urls = [
    path('analyze/', PipelineAnalyzeView.as_view(), name='pipeline-analyze'),
    path('history/', PipelineHistoryView.as_view(), name='pipeline-history'),
]

# Main URL patterns
urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),
    
    # API v1
    path('api/auth/', include(auth_urls)),
    path('api/', include(router.urls)),
    path('api/pipeline/', include(pipeline_urls)),
]

# Optional: Include default auth login (for browsable API)
urlpatterns += [
    path('api-auth/', include('rest_framework.urls')),
]
