"""
Pipeline service: orchestrates the AI analysis workflow.
Handles splitting of past medical history and current complaint.
Integrates with medagent.pipeline for the 4-agent chain.
"""
import json
from datetime import datetime
from typing import Dict, List, Any, Optional

from accounts.models import AnalysisRecord, MedicalHistory, UserProfile


def format_medical_history_for_pipeline(medical_histories: List[MedicalHistory]) -> str:
    """
    Convert MedicalHistory objects into a formatted string for the pipeline.
    This will be passed to Agent 1 as context about the patient's past.
    """
    if not medical_histories:
        return "No significant past medical history."

    history_text = "PAST MEDICAL HISTORY:\n"
    for h in medical_histories:
        history_text += f"\n- {h.condition_name}"
        if h.date_diagnosed:
            history_text += f" (diagnosed {h.date_diagnosed})"
        if h.duration_text:
            history_text += f", duration: {h.duration_text}"
        if h.treatment_received:
            history_text += f"\n  Treatment: {h.treatment_received}"
        if h.status:
            history_text += f", Status: {h.status}"
        if h.recurrence_risk and h.recurrence_risk != 'unknown':
            history_text += f", Recurrence risk: {h.recurrence_risk}"
        if h.notes:
            history_text += f"\n  Notes: {h.notes}"

    return history_text


def format_current_complaint(complaint: str) -> str:
    """Format current complaint for the pipeline."""
    return f"CURRENT COMPLAINT:\n{complaint}"


def build_full_report(
    past_medical_history: str,
    current_complaint: str
) -> str:
    """
    Combine past medical history and current complaint into a single report
    to be sent to the AI pipeline.
    """
    return f"{past_medical_history}\n\n{current_complaint}"


def build_structured_context(
    past_conditions: List[Dict],
    current_complaint: str
) -> Dict[str, Any]:
    """
    Build a structured context object with both past and current data.
    This is used to track what inputs were sent to the pipeline.
    """
    return {
        'past_conditions': past_conditions,
        'current_complaint': current_complaint,
        'timestamp': datetime.now().isoformat(),
    }


def run_analysis_pipeline(
    user_profile: UserProfile,
    current_complaint: str,
    past_medical_history_ids: Optional[List[int]] = None,
    save_analysis: bool = False,
    stream_callback=None,
) -> Dict[str, Any]:
    """
    Main pipeline orchestration function.
    
    Args:
        user_profile: UserProfile object for the patient
        current_complaint: Current symptoms/complaint text
        past_medical_history_ids: Specific medical history IDs to include (None = all active)
        save_analysis: Whether to save the result to AnalysisRecord
        stream_callback: Optional callback for streaming output
    
    Returns:
        Dictionary with analysis results and metadata
    """
    from medagent.pipeline import run_pipeline

    # 1. Fetch past medical history from user profile
    if past_medical_history_ids:
        medical_histories = MedicalHistory.objects.filter(
            user_profile=user_profile,
            id__in=past_medical_history_ids,
            is_active=True
        )
    else:
        medical_histories = MedicalHistory.objects.filter(
            user_profile=user_profile,
            is_active=True
        )

    # 2. Format data for pipeline
    past_history_text = format_medical_history_for_pipeline(medical_histories)
    current_complaint_text = format_current_complaint(current_complaint)
    full_report = build_full_report(past_history_text, current_complaint_text)

    # 3. Prepare structured context
    past_conditions_data = [
        {
            'id': h.id,
            'condition_name': h.condition_name,
            'date_diagnosed': str(h.date_diagnosed) if h.date_diagnosed else None,
            'duration_text': h.duration_text,
            'treatment_received': h.treatment_received,
            'status': h.status,
            'severity': h.severity,
            'recurrence_risk': h.recurrence_risk,
            'notes': h.notes,
        }
        for h in medical_histories
    ]

    context = build_structured_context(past_conditions_data, current_complaint)

    # 4. Run the AI pipeline
    if stream_callback:
        # For streaming responses (handled by views)
        result = run_pipeline(full_report)
    else:
        # For silent execution
        result = run_pipeline(full_report)

    # 5. Save to AnalysisRecord if requested
    analysis_id = None
    if save_analysis:
        analysis_id = f"Analysis_{result['run_id']}"
        
        analysis_record = AnalysisRecord.objects.create(
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

    # 6. Return structured response
    return {
        'run_id': result['run_id'],
        'urgent': result.get('urgent', False),
        'phi_count': result.get('phi_count', 0),
        'analysis_id': analysis_id,
        'specialist_persona': extract_specialty_from_agent4(result.get('agent4', '')),
        'context': context,
        'outputs': {
            'agent1': result.get('agent1'),
            'agent2': result.get('agent2'),
            'agent3': result.get('agent3'),
            'agent4': result.get('agent4'),
        },
        'supervisor_statuses': result.get('supervisor_statuses', {}),
        'log_dir': result.get('log_dir'),
    }


def extract_specialty_from_agent4(agent4_output: str) -> str:
    """
    Try to extract the medical specialty from Agent 4's output.
    This is a simple heuristic; can be improved.
    """
    specialties = [
        'cardiology', 'neurology', 'dermatology', 'orthopedics',
        'gastroenterology', 'pulmonology', 'nephrology', 'endocrinology',
        'psychiatry', 'oncology', 'rheumatology', 'immunology',
        'infectious disease', 'emergency medicine', 'general practice',
    ]

    output_lower = agent4_output.lower()
    for specialty in specialties:
        if specialty in output_lower:
            return specialty.title()

    return 'General Medicine'


def get_user_analysis_history(user_profile: UserProfile, limit: int = 10) -> List[AnalysisRecord]:
    """Fetch recent analyses for a user."""
    return AnalysisRecord.objects.filter(
        user_profile=user_profile
    ).order_by('-created_at')[:limit]


def get_analysis_summary(user_profile: UserProfile) -> Dict[str, Any]:
    """Get summary statistics about user's analyses."""
    analyses = AnalysisRecord.objects.filter(user_profile=user_profile)
    urgent_count = analyses.filter(urgent_flag=True).count()
    
    return {
        'total_analyses': analyses.count(),
        'urgent_analyses': urgent_count,
        'recent_analysis': analyses.first(),
        'common_complaints': get_common_complaints(user_profile),
    }


def get_common_complaints(user_profile: UserProfile, limit: int = 5) -> List[str]:
    """Get the most frequent complaints for a user."""
    from django.db.models import Count
    
    complaints = AnalysisRecord.objects.filter(
        user_profile=user_profile
    ).values('current_complaint').annotate(
        count=Count('id')
    ).order_by('-count')[:limit]
    
    return [c['current_complaint'] for c in complaints]
