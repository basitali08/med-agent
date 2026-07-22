"""
Django REST Framework views for accounts app.
Includes user registration, login, profile management, and medical history CRUD.
"""
from rest_framework import viewsets, status, generics, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate, get_user_model
from django.shortcuts import get_object_or_404

from .models import UserProfile, MedicalHistory, AnalysisRecord, AnalysisFeedback
from .serializers import (
    UserSerializer,
    UserRegisterSerializer,
    UserProfileSerializer,
    UserProfileUpdateSerializer,
    MedicalHistorySerializer,
    AnalysisRecordSerializer,
    AnalysisRecordListSerializer,
    AnalysisFeedbackSerializer,
)

User = get_user_model()


class UserRegisterView(generics.CreateAPIView):
    """
    POST /api/auth/register/
    Register a new user (4 fields: username, email, password, password_confirm).
    Auto-creates an associated UserProfile.
    """
    queryset = User.objects.all()
    serializer_class = UserRegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {
                'user': UserSerializer(user).data,
                'token': token.key,
                'message': 'User registered successfully'
            },
            status=status.HTTP_201_CREATED
        )


class UserLoginView(generics.GenericAPIView):
    """
    POST /api/auth/login/
    Login with username (or email) and password.
    Returns token for subsequent requests.
    """
    permission_classes = [permissions.AllowAny]
    serializer_class = UserSerializer

    def post(self, request, *args, **kwargs):
        username = request.data.get('username')
        email = request.data.get('email')
        password = request.data.get('password')

        if not password:
            return Response(
                {'error': 'Password is required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Try authenticate with username or email
        user = None
        if username:
            user = authenticate(username=username, password=password)
        elif email:
            try:
                user_obj = User.objects.get(email=email)
                user = authenticate(username=user_obj.username, password=password)
            except User.DoesNotExist:
                pass

        if not user:
            return Response(
                {'error': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {
                'user': UserSerializer(user).data,
                'token': token.key,
                'message': 'Login successful'
            },
            status=status.HTTP_200_OK
        )


class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    GET /api/auth/me/
    PUT /api/auth/me/
    Get or update the current user's profile.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserProfileSerializer

    def get_object(self):
        profile, created = UserProfile.objects.get_or_create(user=self.request.user)
        return profile

    def get_serializer_class(self):
        if self.request.method == 'PUT' or self.request.method == 'PATCH':
            return UserProfileUpdateSerializer
        return UserProfileSerializer


class UserLogoutView(generics.GenericAPIView):
    """
    POST /api/auth/logout/
    Delete user's auth token (logout).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        request.user.auth_token.delete()
        return Response(
            {'message': 'Logged out successfully'},
            status=status.HTTP_200_OK
        )


class MedicalHistoryViewSet(viewsets.ModelViewSet):
    """
    ViewSet for CRUD operations on medical history.
    
    Endpoints:
    - GET /api/medical-history/ — List all conditions for current user
    - POST /api/medical-history/ — Add a new condition
    - GET /api/medical-history/{id}/ — Get specific condition
    - PUT /api/medical-history/{id}/ — Update condition
    DELETE /api/medical-history/{id}/ — Delete condition
    """
    serializer_class = MedicalHistorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Return only the current user's medical history."""
        user_profile = UserProfile.objects.get(user=self.request.user)
        return MedicalHistory.objects.filter(user_profile=user_profile)

    def perform_create(self, serializer):
        """Auto-associate with current user's profile."""
        user_profile = UserProfile.objects.get(user=self.request.user)
        serializer.save(user_profile=user_profile)

    @action(detail=False, methods=['get'])
    def active(self, request):
        """GET /api/medical-history/active/ — Get only active conditions."""
        queryset = self.get_queryset().filter(is_active=True)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """
        GET /api/medical-history/summary/
        Get a summary of medical history (for use in AI pipeline).
        """
        queryset = self.get_queryset().filter(is_active=True)
        summary = {
            'total_conditions': queryset.count(),
            'conditions': [
                {
                    'id': h.id,
                    'condition_name': h.condition_name,
                    'date_diagnosed': h.date_diagnosed,
                    'duration_text': h.duration_text,
                    'treatment_received': h.treatment_received,
                    'status': h.status,
                    'recurrence_risk': h.recurrence_risk,
                    'notes': h.notes,
                }
                for h in queryset
            ]
        }
        return Response(summary)

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """POST /api/medical-history/{id}/toggle_active/ — Toggle is_active flag."""
        history = self.get_object()
        history.is_active = not history.is_active
        history.save()
        serializer = self.get_serializer(history)
        return Response(serializer.data)


class AnalysisRecordViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing analysis records (read-only).
    
    Endpoints:
    - GET /api/analysis-records/ — List all analyses
    - GET /api/analysis-records/{id}/ — Get specific analysis
    - GET /api/analysis-records/{id}/feedback/ — Get feedback on analysis
    """
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Return only the current user's analysis records."""
        user_profile = UserProfile.objects.get(user=self.request.user)
        return AnalysisRecord.objects.filter(user_profile=user_profile)

    def get_serializer_class(self):
        if self.action == 'list':
            return AnalysisRecordListSerializer
        return AnalysisRecordSerializer

    @action(detail=True, methods=['get'])
    def feedback(self, request, pk=None):
        """GET /api/analysis-records/{id}/feedback/ — Get feedback for this analysis."""
        analysis = self.get_object()
        feedback = analysis.feedback.all()
        serializer = AnalysisFeedbackSerializer(feedback, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def add_feedback(self, request, pk=None):
        """POST /api/analysis-records/{id}/add_feedback/ — Submit feedback on analysis."""
        analysis = self.get_object()
        serializer = AnalysisFeedbackSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(analysis=analysis)
            return Response(
                serializer.data,
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class NearbyHospitalsView(generics.GenericAPIView):
    """
    POST /api/auth/nearby/
    Find nearby hospitals using Overpass API (OpenStreetMap).
    Requires: latitude, longitude in request body or from user profile.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        import requests

        # Get coordinates from request or user profile
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')

        if not lat or not lng:
            user_profile = UserProfile.objects.get(user=request.user)
            lat = user_profile.latitude
            lng = user_profile.longitude

        if not lat or not lng:
            return Response(
                {'error': 'Latitude and longitude are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Overpass API query for hospitals
            radius = 5000  # 5km radius
            overpass_url = "https://overpass-api.de/api/interpreter"
            query = f"""
            [bbox:{lat - 0.045},-{lng + 0.045},{lat + 0.045},{lng - 0.045}];
            (node["amenity"="hospital"];way["amenity"="hospital"];relation["amenity"="hospital"];);
            out center;
            """

            response = requests.post(
                overpass_url,
                data={'data': query},
                timeout=10
            )

            if response.status_code == 200:
                # Parse and format results
                data = response.json()
                hospitals = []

                for element in data.get('elements', []):
                    hospital = {
                        'id': element.get('id'),
                        'name': element.get('tags', {}).get('name', 'Unnamed Hospital'),
                        'latitude': element.get('center', {}).get('lat') or element.get('lat'),
                        'longitude': element.get('center', {}).get('lon') or element.get('lon'),
                        'phone': element.get('tags', {}).get('phone'),
                        'website': element.get('tags', {}).get('website'),
                    }
                    if hospital['latitude'] and hospital['longitude']:
                        hospitals.append(hospital)

                return Response(
                    {
                        'count': len(hospitals),
                        'hospitals': hospitals,
                        'user_location': {'latitude': lat, 'longitude': lng}
                    },
                    status=status.HTTP_200_OK
                )
            else:
                return Response(
                    {'error': 'Failed to query hospitals from Overpass API'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

        except requests.exceptions.RequestException as e:
            return Response(
                {'error': f'Request error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
