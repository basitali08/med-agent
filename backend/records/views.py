"""Records CRUD views — owner-scoped, with OCR/voice service stubs."""

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, JSONParser
from django.core.files.storage import default_storage
from pipeline.services import extract_lab_text
from .models import MedicalRecord
from .serializers import RecordSerializer, RecordDetailSerializer


class RecordListCreateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser]

    def get(self, request):
        qs = MedicalRecord.objects.filter(owner=request.user)
        return Response(RecordDetailSerializer(qs, many=True).data)

    def post(self, request):
        ser = RecordSerializer(data=request.data, context={"request": request})
        ser.is_valid(raise_exception=True)
        ser.save(owner=request.user)
        return Response(RecordDetailSerializer(ser.instance).data, status=status.HTTP_201_CREATED)


class RecordDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get(self, request, pk):
        return MedicalRecord.objects.filter(owner=request.user, pk=pk).first()

    def get(self, request, pk):
        rec = self._get(request, pk)
        if not rec:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(RecordDetailSerializer(rec).data)

    def put(self, request, pk):
        rec = self._get(request, pk)
        if not rec:
            return Response(status=status.HTTP_404_NOT_FOUND)
        ser = RecordSerializer(rec, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(RecordDetailSerializer(rec).data)

    def delete(self, request, pk):
        rec = self._get(request, pk)
        if not rec:
            return Response(status=status.HTTP_404_NOT_FOUND)
        rec.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class LabUploadView(APIView):
    """STUB: accept a lab PDF/image, run OCR, then feed text to Agent 1.

    Wire in Tesseract/another OCR engine in phase 2; for now we just store the file and
    return a placeholder message so the endpoint contract is stable.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):
        f = request.FILES.get("file")
        if not f:
            return Response({"detail": "file required"}, status=status.HTTP_400_BAD_REQUEST)
        path = default_storage.save(f"labs/{request.user.id}_{f.name}", f)
        return Response({
            "stored_as": path,
            "status": "received",
            "note": "OCR + Agent 1 routing is a phase-2 integration. Text extraction not performed yet.",
        })


class LabAnalyzeTextView(APIView):
    """Accept already-extracted lab text, run Agent 1 (de-identifying extractor), return
    structured JSON + Supervisor rating. OCR is a phase-2 step that feeds text here."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        text = (request.data.get("text") or "").strip()
        if not text:
            return Response({"detail": "'text' is required."}, status=status.HTTP_400_BAD_REQUEST)
        return Response(extract_lab_text(text, model=request.data.get("model")))


class VoiceTranscribeView(APIView):
    """STUB: accept an audio file, transcribe via Whisper, then feed text to Agent 1.

    Phase-2 integration; returns a placeholder until Whisper is wired in.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):
        f = request.FILES.get("file")
        if not f:
            return Response({"detail": "file required"}, status=status.HTTP_400_BAD_REQUEST)
        path = default_storage.save(f"voice/{request.user.id}_{f.name}", f)
        return Response({
            "stored_as": path,
            "status": "received",
            "note": "Whisper transcription + Agent 1 routing is a phase-2 integration.",
        })
