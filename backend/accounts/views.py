"""Accounts views: register, login (token), current user, profile update, nearby hospitals."""

import json
import urllib.request
import urllib.parse
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import UserProfile
from .serializers import RegisterSerializer, UserSerializer, UserProfileSerializer

User = get_user_model()


class RegisterView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        ser = RegisterSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        user = ser.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {"user": UserSerializer(user).data, "token": token.key},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        email = request.data.get("email")
        password = request.data.get("password")
        user = User.objects.filter(email=email).first()
        if not user or not user.check_password(password):
            return Response({"detail": "Invalid credentials."}, status=status.HTTP_401_UNAUTHORIZED)
        token, _ = Token.objects.get_or_create(user=user)
        return Response({"user": UserSerializer(user).data, "token": token.key})


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def put(self, request):
        """Update profile fields."""
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        ser = UserProfileSerializer(profile, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response({"user": UserSerializer(request.user).data})


class NearbyHospitalsView(APIView):
    """Query Overpass API (OpenStreetMap) for nearby hospitals/clinics/emergency centers."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        lat = request.data.get("latitude")
        lng = request.data.get("longitude")
        radius = request.data.get("radius", 10000)  # meters, default 10km
        category = request.data.get("category", "hospital")  # hospital, blood_bank, pharmacy

        if lat is None or lng is None:
            return Response({"detail": "latitude and longitude required."}, status=400)

        lat, lng = float(lat), float(lng)

        # Map category to Overpass tags (must include square brackets)
        tag_map = {
            "hospital": '["amenity"="hospital"]',
            "clinic": '["amenity"="clinic"]',
            "blood_bank": '["healthcare"="blood_bank"]',
            "pharmacy": '["amenity"="pharmacy"]',
            "emergency": '["amenity"="hospital"]["emergency"="yes"]',
            "all_hospital": '["amenity"~"hospital|clinic|doctors"]',
        }
        tag = tag_map.get(category, tag_map["hospital"])

        # Overpass QL query – generous timeout so rural/large-radius queries don't fail
        query = f"""
        [out:json][timeout:25];
        (
          node{tag}(around:{radius},{lat},{lng});
          way{tag}(around:{radius},{lat},{lng});
        );
        out center tags;
        """

        url = "https://overpass-api.de/api/interpreter"
        data = urllib.parse.urlencode({"data": query}).encode("utf-8")

        # Try primary Overpass server, fallback to mirror if timeout
        overpass_urls = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter",
        ]
        result = None
        last_error = None
        for overpass_url in overpass_urls:
            try:
                req = urllib.request.Request(overpass_url, data=data, headers={
                    "User-Agent": "MedAgent/0.1.0 (medical-assistant-app)",
                    "Accept": "application/json",
                })
                with urllib.request.urlopen(req, timeout=30) as resp:
                    result = json.loads(resp.read().decode("utf-8"))
                    break
            except Exception as e:
                last_error = e
                continue
        if result is None:
            # Return 200 with empty results so the client's auto-expanding radius loop
            # can gracefully continue instead of treating this as a hard error.
            return Response({"results": [], "count": 0, "warning": f"Overpass API error: {str(last_error)}"})

        hospitals = []
        for element in result.get("elements", []):
            tags = element.get("tags", {})
            el_lat = element.get("lat") or element.get("center", {}).get("lat")
            el_lng = element.get("lon") or element.get("center", {}).get("lon")
            if el_lat is None or el_lng is None:
                continue

            # Calculate rough distance (Haversine)
            import math
            R = 6371000  # Earth radius in meters
            phi1, phi2 = math.radians(lat), math.radians(el_lat)
            dphi = math.radians(el_lat - lat)
            dlambda = math.radians(el_lng - lng)
            a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
            distance = R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

            name = tags.get("name", tags.get("name:en", "Unnamed"))
            phone = tags.get("phone", tags.get("contact:phone", ""))
            address_parts = [
                tags.get("addr:housenumber", ""),
                tags.get("addr:street", ""),
                tags.get("addr:city", ""),
            ]
            address = ", ".join(p for p in address_parts if p)

            hospitals.append({
                "name": name,
                "latitude": el_lat,
                "longitude": el_lng,
                "distance_m": round(distance),
                "phone": phone,
                "address": address,
                "type": tags.get("amenity", tags.get("healthcare", "unknown")),
                "website": tags.get("website", ""),
                "opening_hours": tags.get("opening_hours", ""),
                "emergency": tags.get("emergency", ""),
            })




        # Keep existing RegisterView, LoginView, MeView, NearbyHospitalsView...

from rest_framework import viewsets, permissions
from .models import MedicalHistory, AnalysisRecord, AnalysisFeedback
from .serializers import (
    MedicalHistorySerializer, AnalysisRecordSerializer, 
    AnalysisFeedbackSerializer
)


class MedicalHistoryViewSet(viewsets.ModelViewSet):
    """CRUD for medical history conditions."""
    serializer_class = MedicalHistorySerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Return only current user's medical history."""
        return MedicalHistory.objects.filter(
            user_profile__user=self.request.user
        )
    
    def perform_create(self, serializer):
        """Auto-associate with current user's profile."""
        user_profile = self.request.user.profile
        serializer.save(user_profile=user_profile)
    
    @action(detail=False, methods=['get'])
    def summary(self, request):
        """Get summary for AI pipeline (used in Feature #2)."""
        queryset = self.get_queryset().filter(is_active=True)
        summary = {
            'total_conditions': queryset.count(),
            'conditions': [
                {
                    'id': h.id,
                    'condition_name': h.condition_name,
                    'date_diagnosed': h.date_diagnosed,
                    'treatment_received': h.treatment_received,
                    'status': h.status,
                    'recurrence_risk': h.recurrence_risk,
                }
                for h in queryset
            ]
        }
        return Response(summary)


class AnalysisRecordViewSet(viewsets.ReadOnlyModelViewSet):
    """View saved analysis records (Feature #5)."""
    serializer_class = AnalysisRecordSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Return only current user's analyses."""
        return AnalysisRecord.objects.filter(
            user_profile__user=self.request.user
        )
    
    @action(detail=True, methods=['post'])
    def add_feedback(self, request, pk=None):
        """Add feedback to an analysis."""
        analysis = self.get_object()
        serializer = AnalysisFeedbackSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(analysis=analysis)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # Sort by distance
        hospitals.sort(key=lambda h: h["distance_m"])

        return Response({"results": hospitals, "count": len(hospitals)})
