import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api/api_client.dart';
import '../app_theme.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen>
    with TickerProviderStateMixin {
  final _text = TextEditingController();
  double _severity = 5;
  bool _beta = true;
  bool _streaming = false;

  // Live pipeline state
  final List<_StageState> _stages = [];
  StreamSubscription? _sub;
  bool _pipelineDone = false;
  bool _pipelineHalted = false;
  String _haltReason = '';
  String _currentAgent = '';
  int _currentAttempt = 1;

  // Animations
  late AnimationController _pulseCtrl;

  static const _agentMeta = {
    'agent_1': ('History Extractor', '🔬', AppColors.gradBlue),
    'agent_2': ('Clinical Summarizer', '📋', AppColors.gradGreen),
    'agent_3': ('Clinical Analyst', '🩺', AppColors.gradPurple),
    'agent_4': ('Action & Treatment', '💊', AppColors.gradRed),
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _text.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _streaming = true;
      _stages.clear();
      _pipelineDone = false;
      _pipelineHalted = false;
      _haltReason = '';
      _currentAgent = '';
    });

    final full = '$text\nSeverity: ${_severity.toInt()}/10.';

    _sub?.cancel();
    _sub = ApiClient.instance.analyzeStream(full, beta: _beta).listen(
      (event) {
        if (!mounted) return;
        final type = event['type'] as String?;

        switch (type) {
          case 'stage_start':
            final agent = event['agent'] as String;
            final name = event['name'] as String;
            final icon = event['icon'] as String;
            setState(() {
              _currentAgent = agent;
              _currentAttempt = 1;
              if (!_stages.any((s) => s.agent == agent)) {
                _stages.add(_StageState(agent: agent, name: name, icon: icon));
              }
            });
            break;

          case 'stage_output':
            final agent = event['agent'] as String;
            final output = event['output'] as String;
            final attempt = event['attempt'] as int? ?? 1;
            setState(() {
              _currentAttempt = attempt;
              final stage = _stages.firstWhere((s) => s.agent == agent);
              stage.output = output;
              stage.attempts = attempt;
              stage.status = 'processing';
            });
            break;

          case 'stage_validated':
            final agent = event['agent'] as String;
            final status = event['status'] as String;
            final score = event['score'] as int;
            final issues = (event['issues'] as List).cast<String>();
            setState(() {
              final stage = _stages.firstWhere((s) => s.agent == agent);
              stage.status = status;
              stage.score = score;
              stage.issues = issues;
            });
            break;

          case 'beta_fallback':
            final agent = event['agent'] as String;
            setState(() {
              final stage = _stages.firstWhere((s) => s.agent == agent);
              stage.status = 'BETA';
              stage.score = 3;
              stage.issues = ['Limited accuracy — weak local model'];
            });
            break;

          case 'pipeline_halted':
            setState(() {
              _pipelineHalted = true;
              _haltReason = event['reason'] as String? ?? 'Pipeline halted.';
            });
            break;

          case 'pipeline_done':
            setState(() {
              _pipelineDone = true;
              _streaming = false;
            });
            break;

          case 'error':
            setState(() {
              _streaming = false;
              _haltReason = event['message'] as String? ?? 'Unknown error';
              _pipelineHalted = true;
            });
            break;
        }
      },
      onDone: () {
        if (mounted && !_pipelineDone) {
          setState(() => _streaming = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _streaming = false;
            _haltReason = e.toString();
            _pipelineHalted = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('AI Diagnosis', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (_streaming)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
        ],
      ),
      body: _streaming || _stages.isNotEmpty
          ? _buildStreamingView()
          : _buildInputView(),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  INPUT VIEW — before diagnosis starts
  // ═══════════════════════════════════════════════════════
  Widget _buildInputView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Neon header card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: Card3D.glass(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            borderOpacity: 0.15,
          ),
          child: Column(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.psychology_rounded, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Describe Your Symptoms',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                '4-agent neural pipeline with live results',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Neon input card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: Card3D.glass(backgroundColor: isDark ? AppColors.darkSurface : Colors.white, borderOpacity: 0.15),
          child: Column(
            children: [
              TextField(
                controller: _text,
                maxLines: 5,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. 58yo male, 3 weeks lower abdominal pain, fatigue, weight loss, blood in stool...',
                  hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceVariant.withValues(alpha: 0.5) : AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Severity slider
              Row(
                children: [
                  const Icon(Icons.speed, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Severity: ${_severity.toInt()}/10',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.15),
                  inactiveTrackColor: AppColors.border,
                ),
                child: Slider(
                  value: _severity, min: 1, max: 10, divisions: 9,
                  label: _severity.toInt().toString(),
                  onChanged: (v) => setState(() => _severity = v),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Beta mode', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                subtitle: const Text('Continue past validation issues', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                value: _beta,
                onChanged: (v) => setState(() => _beta = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Analyze button
        GestureDetector(
          onTap: _analyze,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text('🧠  Start AI Diagnosis', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Not a confirmed diagnosis. Always consult a licensed physician.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STREAMING VIEW — live diagnosis in progress
  // ═══════════════════════════════════════════════════════
  Widget _buildStreamingView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pipeline progress bar
        _buildProgressHeader(),
        const SizedBox(height: 16),

        // Agent cards — live updating
        ..._stages.map((stage) => _buildAgentCard(stage)),

        // Halt message
        if (_pipelineHalted && _haltReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: Card3D.glass(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              borderOpacity: 0.15,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                    SizedBox(width: 8),
                    Text('Pipeline Halted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_haltReason, style: GoogleFonts.poppins(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.danger, AppColors.warning]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/emergency'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Text('Go to Emergency', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Done — new diagnosis button
        if (_pipelineDone) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() {
              _stages.clear();
              _pipelineDone = false;
              _pipelineHalted = false;
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Text('New Diagnosis', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],

        // Streaming pulse indicator
        if (_streaming) ...[
          const SizedBox(height: 16),
          Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final opacity = (0.4 + _pulseCtrl.value * 0.6);
                return Opacity(
                  opacity: opacity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processing $_currentAgent... attempt $_currentAttempt',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProgressHeader() {
    const total = 4;
    final completed = _stages.where((s) => s.status == 'PASS' || s.status == 'BETA').length;
    final progress = completed / total;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Diagnosis Progress', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('$completed / $total', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              final agent = 'agent_${i + 1}';
              final stage = _stages.where((s) => s.agent == agent).firstOrNull;
              final color = stage == null
                  ? AppColors.textMuted
                  : stage.status == 'PASS'
                      ? AppColors.success
                      : stage.status == 'BETA'
                          ? AppColors.warning
                          : stage.status == 'FAIL'
                              ? AppColors.danger
                              : AppColors.primary;
              return Icon(
                stage == null
                    ? Icons.radio_button_unchecked
                    : stage.status == 'PASS'
                        ? Icons.check_circle
                        : stage.status == 'BETA'
                            ? Icons.science
                            : stage.status == 'FAIL'
                                ? Icons.cancel
                                : Icons.autorenew,
                color: color,
                size: 20,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(_StageState stage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = _agentMeta[stage.agent] ?? ('Unknown', '❓', AppColors.gradCyan);
    final isActive = stage.status == 'processing' || (stage.status.isEmpty && _streaming && _currentAgent == stage.agent);
    final isDone = stage.status == 'PASS';
    final isFail = stage.status == 'FAIL';
    final borderColor = isDone ? AppColors.success : isFail ? AppColors.danger : isActive ? AppColors.primary : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: Card3D.glass(borderColor: borderColor, borderOpacity: isActive ? 0.3 : 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor.withValues(alpha: 0.25)),
                ),
                child: Center(child: Text(meta.$2, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta.$1, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (stage.attempts > 1)
                      Text('Attempt ${stage.attempts}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning)),
                  ],
                ),
              ),
              _statusBadge(stage),
            ],
          ),
          if (stage.output.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariant.withValues(alpha: 0.4) : AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                stage.output,
                style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
              ),
            ),
          ],
          if (stage.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...stage.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(issue, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.danger))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(_StageState stage) {
    if (stage.status == 'PASS') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
            const SizedBox(width: 4),
            Text('${stage.score}/10', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
          ],
        ),
      );
    }
    if (stage.status == 'BETA') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text('BETA', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
          ],
        ),
      );
    }
    if (stage.status == 'FAIL') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel, size: 14, color: AppColors.danger),
            const SizedBox(width: 4),
            Text('${stage.score}/10', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
          ],
        ),
      );
    }
    if (stage.status == 'processing') {
      return const SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
      );
    }
    // waiting
    return Icon(Icons.hourglass_empty, size: 18, color: AppColors.textMuted);
  }
}

/// Mutable state for a single agent stage in the streaming view.
class _StageState {
  final String agent;
  final String name;
  final String icon;
  String output = '';
  String status = '';
  int score = 0;
  int attempts = 1;
  List<String> issues = [];

  _StageState({required this.agent, required this.name, required this.icon});
}
