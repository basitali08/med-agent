"""Reports views: generate a downloadable clinical report from the pipeline output."""

import os
import tempfile
from django.http import FileResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from pipeline.services import analyze_text

DISCLAIMER = (
    "AI-GENERATED DECISION SUPPORT. Not a diagnosis or prescription. "
    "All outputs must be reviewed and approved by a licensed physician."
)


def build_report_text(text: str, report: dict) -> str:
    lines = ["MED AGENT — CLINICAL REPORT", "=" * 40, ""]
    lines.append(f"Input (truncated): {text[:300]}")
    lines.append("")
    if report.get("halted"):
        lines.append("STATUS: Pipeline halted — direct human clinical review required.")
        lines.append(report.get("halt_reason", ""))
        lines.append("")
        lines.append(DISCLAIMER)
        return "\n".join(lines)

    for stage in report.get("stages", []):
        sup = stage["supervisor"]
        lines.append(f"--- {stage['agent'].upper()} (rating {sup.get('score')}/10, {sup['status']}) ---")
        if sup.get("issues"):
            lines.append("Supervisor notes: " + "; ".join(sup["issues"]))
        lines.append(stage["output"])
        lines.append("")
    lines.append(DISCLAIMER)
    return "\n".join(lines)


class GenerateReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        text = (request.data.get("text") or "").strip()
        if not text:
            return Response({"detail": "'text' is required."}, status=400)

        report = analyze_text(text, model=request.data.get("model"),
                              analyzer_model=request.data.get("analyzer_model"))
        body = build_report_text(text, report)

        fd, path = tempfile.mkstemp(suffix=".txt", prefix="medagent_report_")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(body)

        resp = FileResponse(open(path, "rb"), as_attachment=True, filename=os.path.basename(path))
        return resp
