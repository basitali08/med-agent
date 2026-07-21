/// Models for the pipeline API response. Mirrors the Django /api/pipeline/analyze/ JSON.
library;

class SupervisorResult {
  final String status; // PASS | FAIL
  final int score; // 1-10 rating (>=5 PASS, <5 FAIL)
  final int ruleScore;
  final int? llmScore;
  final List<String> issues;

  const SupervisorResult({
    required this.status,
    required this.score,
    required this.ruleScore,
    this.llmScore,
    required this.issues,
  });

  factory SupervisorResult.fromJson(Map<String, dynamic> j) => SupervisorResult(
        status: j['status'] as String? ?? 'FAIL',
        score: (j['score'] as num? ?? 0).toInt(),
        ruleScore: (j['rule_score'] as num? ?? 0).toInt(),
        llmScore: (j['llm_score'] as num?)?.toInt(),
        issues: (j['issues'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

class StageResult {
  final String agent; // agent_1 .. agent_4
  final int attempts;
  final SupervisorResult supervisor;
  final String output;

  const StageResult({
    required this.agent,
    required this.attempts,
    required this.supervisor,
    required this.output,
  });

  factory StageResult.fromJson(Map<String, dynamic> j) => StageResult(
        agent: j['agent'] as String? ?? '',
        attempts: (j['attempts'] as num? ?? 1).toInt(),
        supervisor: SupervisorResult.fromJson(j['supervisor'] as Map<String, dynamic>? ?? {}),
        output: j['output'] as String? ?? '',
      );
}

class PipelineResult {
  final bool halted;
  final bool beta;
  final String haltReason;
  final List<StageResult> stages;

  const PipelineResult({
    required this.halted,
    required this.beta,
    required this.haltReason,
    required this.stages,
  });

  factory PipelineResult.fromJson(Map<String, dynamic> j) => PipelineResult(
        halted: j['halted'] as bool? ?? false,
        beta: j['beta'] as bool? ?? false,
        haltReason: j['halt_reason'] as String? ?? '',
        stages: (j['stages'] as List? ?? [])
            .map((e) => StageResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
