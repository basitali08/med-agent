import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Persistent, unmissable disclaimer banner shown on diagnosis/recommendation screens.
class DisclaimerBanner extends StatelessWidget {
  final String message;
  final bool danger;

  const DisclaimerBanner({
    super.key,
    this.message =
        'Not a confirmed diagnosis — this is AI decision-support. Consult a licensed physician.',
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: danger ? AppColors.danger.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
        border: Border(
          left: BorderSide(
            color: danger ? AppColors.danger : AppColors.warning,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(danger ? Icons.warning_amber_rounded : Icons.info_outline,
              color: danger ? AppColors.danger : AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppText.caption,
                color: danger ? AppColors.danger : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
