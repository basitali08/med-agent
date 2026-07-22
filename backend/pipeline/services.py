"""Wraps the medagent ai_pipeline so Django can call the 4-agent + Supervisor flow."""

from medagent.ollama_client import OllamaClient
from medagent.supervisor import Supervisor
from medagent.pipeline import run_pipeline, extract_history
from django.conf import settings


def analyze_text(text, *, model=None, analyzer_model=None, host=None, beta=False, use_rag=True):
    """Run the full pipeline and return a JSON-serializable report.

    `score` from the Supervisor is the 1-10 rating (<5 FAIL, >=5 PASS).
    `beta=True` enables lenient mode (continues past validation failures, flagging the
    output as limited-accuracy) instead of the strict Supervisor halt.
    `use_rag=True` enables RAG (diagnosis knowledge base lookup) to enhance Agent 3.
    """
    model = model or settings.DEFAULT_EXTRACT_MODEL
    analyzer_model = analyzer_model or settings.DEFAULT_ANALYZER_MODEL
    host = host or settings.OLLAMA_BASE_URL

    client = OllamaClient(base_url=host)
    supervisor = Supervisor(client=client, model=model)

    if not client.is_model_available(model):
        return {
            "error": f"Model '{model}' not available at {host}. Run: ollama pull {model}",
            "stages": [],
            "halted": True,
            "beta": False,
            "halt_reason": "Model unavailable.",
        }

    result = run_pipeline(
        client, supervisor, text,
        extract_model=model, analyzer_model=analyzer_model,
        verbose=False, lenient=beta, use_rag=use_rag,
    )
    return {
        "halted": result.halted,
        "beta": result.beta,
        "halt_reason": result.halt_reason,
        "stages": [
            {
                "agent": s.agent,
                "attempts": s.attempts,
                "supervisor": s.supervisor,
                "output": s.output,
            }
            for s in result.stages
        ],
    }


def extract_lab_text(text, *, model=None, host=None):
    """Run Agent 1 (de-identifying extractor) on OCR'd/raw lab text.

    The OCR step is a phase-2 integration; this accepts already-extracted text and returns
    the de-identified structured history.
    """
    model = model or settings.DEFAULT_EXTRACT_MODEL
    host = host or settings.OLLAMA_BASE_URL
    client = OllamaClient(base_url=host)
    supervisor = Supervisor(client=client, model=model)
    if not client.is_model_available(model):
        return {"error": f"Model '{model}' not available at {host}."}
    return extract_history(client, supervisor, text, extract_model=model)

# Keep existing analyze_text, extract_lab_text functions...

from datetime import datetime
from accounts.models import MedicalHistory, AnalysisRecord, UserProfile


def format_medical_history_for_pipeline(user_profile):
    """
    Get patient's medical history and format for AI pipeline (Feature #1).
    """
    histories = MedicalHistory.objects.filter(
        user_profile=user_profile,
        is_active=True
    )
    
    if not histories:
        return "No significant past medical history."
    
    text = "PAST MEDICAL HISTORY:\n"
    for h in histories:
        text += f"\n- {h.condition_name}"
        if h.date_diagnosed:
            text += f" (diagnosed {h.date_diagnosed})"
        if h.duration_text:
            text += f", duration: {h.duration_text}"
        if h.treatment_received:
            text += f"\n  Treatment: {h.treatment_received}"
        if h.status:
            text += f", Status: {h.status}"
        if h.recurrence_risk and h.recurrence_risk != 'unknown':
            text += f", Risk: {h.recurrence_risk}"
        if h.notes:
            text += f"\n  Notes: {h.notes}"
    
    return text


def run_analysis_with_history(
    user_profile,
    current_complaint,
    medical_history_ids=None,
    save_analysis=False,
    **pipeline_kwargs
):
    """
    Run full pipeline with split past/current sections (Features #1 & #2).
    
    Args:
        user_profile: UserProfile instance
        current_complaint: Current symptoms (string)
        medical_history_ids: Optional list of MedicalHistory IDs to include
        save_analysis: Whether to save result to AnalysisRecord
        **pipeline_kwargs: Passed to analyze_text()
    
    Returns:
        Dictionary with analysis results + analysis_id if saved
    """
    # Get medical history
    if medical_history_ids:
        histories = MedicalHistory.objects.filter(
            user_profile=user_profile,
            id__in=medical_history_ids,
            is_active=True
        )
    else:
        histories = MedicalHistory.objects.filter(
            user_profile=user_profile,
            is_active=True
        )
    
    # Format past + current
    past_text = format_medical_history_for_pipeline(user_profile)
    current_text = f"CURRENT COMPLAINT:\n{current_complaint}"
    full_report = f"{past_text}\n\n{current_text}"
    
    # Run pipeline
    result = analyze_text(full_report, **pipeline_kwargs)
    
    # Extract outputs
    agent1 = None
    agent2 = None
    agent3 = None
    agent4 = None
    urgent = False
    
    for stage in result.get('stages', []):
        if stage['agent'] == 1:
            agent1 = stage['output']
        elif stage['agent'] == 2:
            agent2 = stage['output']
        elif stage['agent'] == 3:
            agent3 = stage['output']
            urgent = _detect_urgent(agent3)
        elif stage['agent'] == 4:
            agent4 = stage['output']
    
    # Save if requested
    analysis_id = None
    if save_analysis:
        run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        analysis_id = f"Analysis_{run_id}"
        
        past_conditions_data = [
            {
                'id': h.id,
                'condition_name': h.condition_name,
                'status': h.status,
            }
            for h in histories
        ]
        
        AnalysisRecord.objects.create(
            user_profile=user_profile,
            analysis_id=analysis_id,
            past_conditions=past_conditions_data,
            current_complaint=current_complaint,
            agent1_output=agent1 or {},
            agent2_output=agent2 or '',
            agent3_output=agent3 or '',
            agent4_output=agent4 or '',
            urgent_flag=urgent,
            specialty_persona=_extract_specialty(agent4 or ''),
        )
    
    return {
        'halted': result.get('halted'),
        'urgent': urgent,
        'analysis_id': analysis_id,
        'agent1': agent1,
        'agent2': agent2,
        'agent3': agent3,
        'agent4': agent4,
        'specialty_persona': _extract_specialty(agent4 or ''),
    }


def _detect_urgent(agent3_text):
    """Check if Agent 3 output contains urgent keywords."""
    keywords = [
        'emergency', 'urgent', 'immediate', 'er referral',
        'chest pain', 'stroke', 'severe bleeding'
    ]
    return any(kw in agent3_text.lower() for kw in keywords)


def _extract_specialty(agent4_text):
    """Try to extract medical specialty from Agent 4 output."""
    specialties = [
        'cardiology', 'neurology', 'dermatology', 'orthopedics',
        'gastroenterology', 'pulmonology', 'oncology', 'psychiatry'
    ]
    text_lower = agent4_text.lower()
    for spec in specialties:
        if spec in text_lower:
            return spec.title()
    return 'General Medicine'
