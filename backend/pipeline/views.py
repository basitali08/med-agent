"""
Django REST Framework views for pipeline API.
Handles analysis requests and streams responses to frontend.
"""
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from django.http import StreamingHttpResponse
import json

from accounts.models import UserProfile, AnalysisRecord
from accounts.serializers import PipelineInputSerializer, PipelineOutputSerializer
from .services import run_analysis_pipeline, get_user_analysis_history, get_analysis_summary


class PipelineAnalyzeView(generics.GenericAPIView):
    """
    POST /api/pipeline/analyze/
    
    Main AI analysis endpoint. Accepts:
    - past_medical_history: List of past conditions (optional, auto-fetched if not provided)
    - medical_history_ids: Specific condition IDs to include (optional)
    - current_complaint: Current symptoms/reason for visit (required)
    - save_analysis: Whether to save result (default: False)
    - stream: Whether to stream response (default: True)
    
    Returns:
    - Agents 1-4 outputs
    - Specialty persona
    - Urgent flag
    - Analysis ID (if saved)
    
    Example request:
    {
        "current_complaint": "I've had a headache for 3 days...",
        "medical_history_ids": [1, 2, 3],
        "save_analysis": true,
        "stream": false
    }
    """
    serializer_class = PipelineInputSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Get user profile
        user_profile = UserProfile.objects.get(user=request.user)

        # Extract validated data
        current_complaint = serializer.validated_data['current_complaint']
        medical_history_ids = serializer.validated_data.get('medical_history_ids')
        save_analysis = serializer.validated_data.get('save_analysis', False)

        try:
            # Run the analysis pipeline
            result = run_analysis_pipeline(
                user_profile=user_profile,
                current_complaint=current_complaint,
                past_medical_history_ids=medical_history_ids,
                save_analysis=save_analysis,
            )

            # Return response
            return Response(result, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {'error': f'Pipeline error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class PipelineHistoryView(generics.GenericAPIView):
    """
    GET /api/pipeline/history/
    
    Fetch analysis history for the current user.
    
    Query parameters:
    - limit: Number of recent analyses (default: 10)
    - include_summary: Include summary stats (default: false)
    
    Returns:
    - List of recent AnalysisRecord objects
    - Optional: summary statistics
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user_profile = UserProfile.objects.get(user=request.user)
        limit = int(request.query_params.get('limit', 10))
        include_summary = request.query_params.get('include_summary', 'false').lower() == 'true'

        analyses = get_user_analysis_history(user_profile, limit=limit)

        # Serialize analyses
        from accounts.serializers import AnalysisRecordListSerializer
        serializer = AnalysisRecordListSerializer(analyses, many=True)

        response_data = {
            'count': len(analyses),
            'analyses': serializer.data,
        }

        if include_summary:
            summary = get_analysis_summary(user_profile)
            response_data['summary'] = summary

        return Response(response_data, status=status.HTTP_200_OK)


class PipelineStreamView(generics.GenericAPIView):
    """
    POST /api/pipeline/analyze-stream/
    
    Streaming analysis endpoint (SSE — Server-Sent Events).
    Sends live updates as each agent completes.
    
    Uses the same input as PipelineAnalyzeView but returns streamed chunks.
    """
    serializer_class = PipelineInputSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Get user profile
        user_profile = UserProfile.objects.get(user=request.user)

        # Extract validated data
        current_complaint = serializer.validated_data['current_complaint']
        medical_history_ids = serializer.validated_data.get('medical_history_ids')
        save_analysis = serializer.validated_data.get('save_analysis', False)

        def event_stream():
            """Generator function for streaming events."""
            try:
                # Import streaming pipeline
                from medagent.pipeline import run_pipeline_streaming
                from accounts.models import MedicalHistory

                # Fetch past medical history
                if medical_history_ids:
                    medical_histories = MedicalHistory.objects.filter(
                        user_profile=user_profile,
                        id__in=medical_history_ids,
                        is_active=True
                    )
                else:
                    medical_histories = MedicalHistory.objects.filter(
                        user_profile=user_profile,
                        is_active=True
                    )

                # Format for pipeline
                from .services import (
                    format_medical_history_for_pipeline,
                    format_current_complaint,
                    build_full_report,
                )

                past_history_text = format_medical_history_for_pipeline(medical_histories)
                current_complaint_text = format_current_complaint(current_complaint)
                full_report = build_full_report(past_history_text, current_complaint_text)

                # Yield start event
                yield f"data: {json.dumps({'event': 'start', 'message': 'Analysis starting...'})}\n\n"

                # Run streaming pipeline
                result = run_pipeline_streaming(full_report)

                # Yield agent 1
                yield f"data: {json.dumps({'event': 'agent1', 'data': result['agent1']})}\n\n"

                # Yield agent 2
                yield f"data: {json.dumps({'event': 'agent2', 'data': result['agent2']})}\n\n"

                # Yield agent 3
                yield f"data: {json.dumps({'event': 'agent3', 'data': result['agent3']})}\n\n"

                # Yield guardrail
                yield f"data: {json.dumps({'event': 'guardrail', 'urgent': result['urgent']})}\n\n"

                # Yield agent 4
                yield f"data: {json.dumps({'event': 'agent4', 'data': result['agent4']})}\n\n"

                # Save if requested
                analysis_id = None
                if save_analysis:
                    from .services import extract_specialty_from_agent4
                    
                    past_conditions_data = [
                        {
                            'condition_name': h.condition_name,
                            'date_diagnosed': str(h.date_diagnosed) if h.date_diagnosed else None,
                            'duration_text': h.duration_text,
                            'status': h.status,
                        }
                        for h in medical_histories
                    ]

                    analysis_id = f"Analysis_{result['run_id']}"
                    AnalysisRecord.objects.create(
                        user_profile=user_profile,
                        analysis_id=analysis_id,
                        past_conditions=past_conditions_data,
                        current_complaint=current_complaint,
                        agent1_output=result.get('agent1', {}),
                        agent2_output=result.get('agent2', ''),
                        agent3_output=result.get('agent3', ''),
                        agent4_output=result.get('agent4', ''),
                        urgent_flag=result.get('urgent', False),
                        specialty_persona=extract_specialty_from_agent4(result.get('agent4', '')),
                    )

                # Yield completion event
                yield f"data: {json.dumps({'event': 'complete', 'analysis_id': analysis_id, 'run_id': result['run_id']})}\n\n"

            except Exception as e:
                yield f"data: {json.dumps({'event': 'error', 'message': str(e)})}\n\n"

        # Return StreamingHttpResponse with SSE
        response = StreamingHttpResponse(event_stream(), content_type='text/event-stream')
        response['Cache-Control'] = 'no-cache'
        response['X-Accel-Buffering'] = 'no'
        return response


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def pipeline_status(request):
    """
    GET /api/pipeline/status/
    Check if Ollama/LLM service is available.
    """
    try:
        from medagent.ollama_client import _client
        import config
        
        # Try a simple ping
        response = _client.models.list()
        
        return Response({
            'status': 'healthy',
            'model': config.MODEL,
            'endpoint': config.BASE_URL,
            'message': 'AI service is available'
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({
            'status': 'error',
            'message': f'AI service error: {str(e)}'
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
