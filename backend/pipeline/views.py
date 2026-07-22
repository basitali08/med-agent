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
        # Keep existing AnalyzeView...

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .services import run_analysis_with_history
from accounts.serializers import PipelineInputSerializer, PipelineOutputSerializer
from accounts.models import AnalysisRecord


class AnalyzeView(APIView):
    """
    POST /api/pipeline/analyze-split/
    
    Run analysis with split past/current sections (Features #1 & #2).
    
    Input:
    {
        "current_complaint": "I've had a headache for 3 days...",
        "medical_history_ids": [1, 2, 3],  // Optional: specific conditions
        "save_analysis": true
    }
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        serializer = PipelineInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user_profile = request.user.profile
        
        try:
            result = run_analysis_with_history(
                user_profile=user_profile,
                current_complaint=serializer.validated_data['current_complaint'],
                medical_history_ids=serializer.validated_data.get('medical_history_ids'),
                save_analysis=serializer.validated_data.get('save_analysis', False),
            )
            
            output_serializer = PipelineOutputSerializer(result)
            return Response(output_serializer.data, status=status.HTTP_200_OK)
        
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class PipelineHistoryView(APIView):
    """GET /api/pipeline/history/ — List past analyses."""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user_profile = request.user.profile
        analyses = AnalysisRecord.objects.filter(
            user_profile=user_profile
        ).order_by('-created_at')[:10]
        
        data = [
            {
                'analysis_id': a.analysis_id,
                'current_complaint': a.current_complaint,
                'urgent_flag': a.urgent_flag,
                'specialty_persona': a.specialty_persona,
                'created_at': a.created_at,
                'feedback_count': a.feedback.count(),
            }
            for a in analyses
        ]
        
        return Response({'analyses': data})
