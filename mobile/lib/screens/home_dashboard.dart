import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../widgets/med_agent_logo.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.background;
    final textColor = isDark ? AppColors.textOnPrimary : AppColors.textDark;
    final mutedColor = isDark ? AppColors.textLight : AppColors.textMuted;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Header with green gradient ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
              ),
              child: Row(
                children: [
                  const MedAgentLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MED AGENT', style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Smart Health Intelligence', style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  // Notification bell
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Health Score Card ──
            _buildHealthScore(context, textColor, mutedColor, cardColor, borderColor),
            const SizedBox(height: 16),

            // ── Primary CTA — AI Diagnosis ──
            _actionCard(
              context,
              icon: Icons.psychology_rounded,
              title: 'AI Diagnosis',
              subtitle: '4-agent clinical pipeline • live analysis',
              color: AppColors.primary,
              route: '/symptom-checker',
              cardColor: cardColor,
              textColor: textColor,
              mutedColor: mutedColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 16),

            // ── Quick Actions ──
            Text('Quick Actions', style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _quickTile(context, Icons.emergency_rounded, 'Emergency', AppColors.danger, '/emergency', cardColor, textColor, borderColor)),
                const SizedBox(width: 12),
                Expanded(child: _quickTile(context, Icons.person_rounded, 'Profile', AppColors.secondary, '/profile', cardColor, textColor, borderColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _quickTile(context, Icons.settings_rounded, 'Settings', AppColors.info, '/settings', cardColor, textColor, borderColor)),
                const SizedBox(width: 12),
                Expanded(child: _quickTile(context, Icons.shield_rounded, 'Privacy', AppColors.primary, '/settings', cardColor, textColor, borderColor)),
              ],
            ),
            const SizedBox(height: 24),

            // ── Pipeline Steps ──
            Text('How It Works', style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 12),
            _pipelineStep('01', 'Extract', 'De-identify & structure patient data', AppColors.primary, cardColor, textColor, mutedColor, borderColor),
            _pipelineStep('02', 'Summarize', 'Clinical narrative generation', AppColors.secondary, cardColor, textColor, mutedColor, borderColor),
            _pipelineStep('03', 'Analyze', 'Multi-specialty differential diagnosis', AppColors.accent, cardColor, textColor, mutedColor, borderColor),
            _pipelineStep('04', 'Recommend', 'Physician-reviewed action plan', AppColors.success, cardColor, textColor, mutedColor, borderColor),
            const SizedBox(height: 24),

            // ── Footer ──
            Center(
              child: Text('NOT A MEDICAL DEVICE • DECISION SUPPORT ONLY',
                  style: GoogleFonts.poppins(fontSize: 10, color: mutedColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScore(BuildContext context, Color textColor, Color mutedColor, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _ScoreRingPainter(score: 82),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('82', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Text('SCORE', style: TextStyle(fontSize: 8, color: AppColors.textMuted, letterSpacing: 2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HEALTH INDEX', style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 4),
                Text('Good condition • 4 screenings pending', style: GoogleFonts.poppins(
                  fontSize: 12, color: mutedColor)),
                const SizedBox(height: 8),
                _miniStat('Cardiac', 0.82, AppColors.primary),
                const SizedBox(height: 4),
                _miniStat('Neural', 0.74, AppColors.secondary),
                const SizedBox(height: 4),
                _miniStat('Immune', 0.68, AppColors.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 28, child: Text('${(value * 100).toInt()}%', style: GoogleFonts.poppins(
          fontSize: 10, color: color, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _actionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
    required Color cardColor,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.08), cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(
                    fontSize: 12, color: mutedColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: mutedColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _quickTile(BuildContext context, IconData icon, String label, Color color, String route,
      Color cardColor, Color textColor, Color borderColor) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _pipelineStep(String num, String title, String desc, Color color,
      Color cardColor, Color textColor, Color mutedColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(num, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                Text(desc, style: GoogleFonts.poppins(
                  fontSize: 11, color: mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final int score;
  _ScoreRingPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.surfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    // Score arc
    final scorePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      scorePaint,
    );

    // Glow
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      glowPaint,
    );
  }
  ElevatedButton(
  onPressed: () => context.pushNamed('medical-history', extra: userProfile),
  child: const Text('📋 Medical History'),
),
ElevatedButton(
  onPressed: () => context.pushNamed('symptom-checker', extra: userProfile),
  child: const Text('🩺 AI Analysis'),
),

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.score != score;
}
