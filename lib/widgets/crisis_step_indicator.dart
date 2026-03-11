import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Indicador de progreso del flujo de crisis: 5 segmentos rectangulares
/// delgados y planos, sin texto ni bordes.
class CrisisStepIndicator extends StatelessWidget
    implements PreferredSizeWidget {
  final int currentStep; // 1-indexed, 1 to 5

  static const int _totalSteps = 5;

  const CrisisStepIndicator({super.key, required this.currentStep});

  @override
  Size get preferredSize => const Size.fromHeight(20);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final step = i + 1;
          final isDone = step < currentStep;
          final isActive = step == currentStep;

          Color color;
          if (isActive) {
            color = AppTheme.accentButton;
          } else if (isDone) {
            color = AppTheme.accentButton.withValues(alpha: 0.45);
          } else {
            color = AppTheme.textSecondary.withValues(alpha: 0.18);
          }

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
