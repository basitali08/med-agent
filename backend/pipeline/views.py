"""Pipeline API views."""

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from .services import analyze_text


class AnalyzeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        text = (request.data.get("text") or "").strip()
        if not text:
            return Response({"detail": "'text' is required."}, status=status.HTTP_400_BAD_REQUEST)

        model = request.data.get("model")
        analyzer_model = request.data.get("analyzer_model")
        beta = bool(request.data.get("beta", False))
        use_rag = bool(request.data.get("use_rag", True))
        report = analyze_text(text, model=model, analyzer_model=analyzer_model, beta=beta, use_rag=use_rag)

        if report.get("halted") and report.get("error"):
            return Response(report, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        code = status.HTTP_422_UNPROCESSABLE_ENTITY if report.get("halted") else status.HTTP_200_OK
        return Response(report, status=code)
