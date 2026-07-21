"""MED AGENT Diagnosis Knowledge Base.

A curated dataset of 200+ medical conditions organized by body system.
Each entry contains: id, name, icd10, symptoms, specialties, prevalence,
risk_factors, demographics, red_flags, urgency, and description.

This data is used by the RAG retriever to enhance Agent 3's clinical analysis
with evidence-based differential diagnosis candidates.

Sources: ICD-10-CM, WHO classification, Harrison's Principles of Internal Medicine.
NOTE: This is for decision-support only — NOT a substitute for clinical judgment.
"""

from medagent.rag.diagnoses.cardiology import CARDIOLOGY_DIAGNOSES
from medagent.rag.diagnoses.neurology import NEUROLOGY_DIAGNOSES
from medagent.rag.diagnoses.pulmonology import PULMONOLOGY_DIAGNOSES
from medagent.rag.diagnoses.gastroenterology import GASTRO_DIAGNOSES
from medagent.rag.diagnoses.endocrinology import ENDOCRINOLOGY_DIAGNOSES
from medagent.rag.diagnoses.nephrology import NEPHROLOGY_DIAGNOSES
from medagent.rag.diagnoses.infectious import INFECTIOUS_DIAGNOSES
from medagent.rag.diagnoses.oncology import ONCOLOGY_DIAGNOSES
from medagent.rag.diagnoses.emergency import EMERGENCY_DIAGNOSES
from medagent.rag.diagnoses.other import OTHER_DIAGNOSES

DIAGNOSIS_DATABASE: list[dict] = (
    CARDIOLOGY_DIAGNOSES
    + NEUROLOGY_DIAGNOSES
    + PULMONOLOGY_DIAGNOSES
    + GASTRO_DIAGNOSES
    + ENDOCRINOLOGY_DIAGNOSES
    + NEPHROLOGY_DIAGNOSES
    + INFECTIOUS_DIAGNOSES
    + ONCOLOGY_DIAGNOSES
    + EMERGENCY_DIAGNOSES
    + OTHER_DIAGNOSES
)

__all__ = ["DIAGNOSIS_DATABASE"]
