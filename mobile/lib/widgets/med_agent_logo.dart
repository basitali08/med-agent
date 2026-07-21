import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Medical cross + pulse logo — clean healthcare style.
class MedAgentLogo extends StatefulWidget {
  final double size;
  const MedAgentLogo({super.key, this.size = 72});

  @override
  State<MedAgentLogo> createState() => _MedAgentLogoState();
}

class _MedAgentLogoState extends State<MedAgentLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _LogoPainter(progress: _ctrl.value),
        );
      },
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double progress;
  _LogoPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    // ── Outer ring ──
    final ringPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r + 4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(cx, cy), r + 4, ringPaint);

    // ── Inner fill ──
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.surface, AppColors.surfaceVariant],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // ── ECG/Pulse line ──
    final pulsePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.12, cy);
    path.lineTo(size.width * 0.28, cy);
    path.lineTo(size.width * 0.33, cy - size.height * 0.12);
    path.lineTo(size.width * 0.40, cy + size.height * 0.10);
    path.lineTo(size.width * 0.50, cy - size.height * 0.18);
    path.lineTo(size.width * 0.60, cy + size.height * 0.14);
    path.lineTo(size.width * 0.67, cy - size.height * 0.08);
    path.lineTo(size.width * 0.72, cy);
    path.lineTo(size.width * 0.88, cy);
    canvas.drawPath(path, pulsePaint);

    // ── DNA helix particles ──
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final t = progress * 2 * pi;

    for (int i = 0; i < 10; i++) {
      final phase = t + i * 0.65;
      final dx = sin(phase) * r * 0.35;
      final dy = -r * 0.55 + i * (r * 1.1 / 9);

      dotPaint.color = AppColors.primary.withValues(alpha: 0.5 + sin(phase) * 0.4);
      canvas.drawCircle(Offset(cx + dx, cy + dy), 2.5, dotPaint);

      dotPaint.color = AppColors.secondary.withValues(alpha: 0.5 + cos(phase) * 0.4);
      canvas.drawCircle(Offset(cx - dx, cy + dy), 2.5, dotPaint);
    }

    // ── Center medical cross ──
    final crossPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final cs = r * 0.18;
    canvas.drawLine(Offset(cx, cy - cs), Offset(cx, cy + cs), crossPaint);
    canvas.drawLine(Offset(cx - cs, cy), Offset(cx + cs, cy), crossPaint);

    // Cross glow
    final crossGlow = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(Offset(cx, cy - cs), Offset(cx, cy + cs), crossGlow);
    canvas.drawLine(Offset(cx - cs, cy), Offset(cx + cs, cy), crossGlow);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progress != progress;
}
