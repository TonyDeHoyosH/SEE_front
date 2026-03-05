import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/crisis_provider.dart';
import '../../providers/data_provider.dart';
import '../../widgets/glass_card.dart';
import '../../config/theme.dart';
import 'post_crisis_reflection_screen.dart';

class CrisisEvaluationScreen extends StatelessWidget {
  final bool breathingCompleted;

  const CrisisEvaluationScreen({super.key, this.breathingCompleted = true});

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final evaluations = dataProvider.evaluations;

    return Scaffold(
      backgroundColor: Colors.transparent, // Global background applied
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Evaluación'),
            Text(
              'Paso 3 de 3',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: evaluations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 64,
                    color: Color(0xFFFB7185),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¿Cómo te sientes ahora?',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu respuesta nos ayuda a apoyarte mejor',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: ListView.separated(
                      itemCount: evaluations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final evaluation = evaluations[index];
                        return _EvaluationOption(
                          evaluationId: evaluation.id,
                          title: evaluation.description,
                          icon: _getEvaluationIcon(evaluation.description),
                          color: _getEvaluationColor(evaluation.description),
                          onTap: () => _handleEvaluationSelected(
                            context,
                            evaluation.id,
                            evaluation.description,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  IconData _getEvaluationIcon(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('mejor')) return Icons.trending_up;
    if (lower.contains('igual')) return Icons.horizontal_rule;
    if (lower.contains('peor')) return Icons.trending_down;
    return Icons.help_outline;
  }

  Color _getEvaluationColor(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('mejor')) return const Color(0xFF22C55E);
    if (lower.contains('igual')) return const Color(0xFF64748B);
    if (lower.contains('peor')) return const Color(0xFFEF4444);
    return const Color(0xFF475569);
  }

  Future<void> _handleEvaluationSelected(
    BuildContext context,
    int evaluationId,
    String evaluationDescription,
  ) async {
    final crisisProvider = context.read<CrisisProvider>();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await crisisProvider.endCrisis(
        evaluationId, evaluationDescription, breathingCompleted);

    if (!context.mounted) return;

    // Hide loading
    Navigator.pop(context);

    if (crisisProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(crisisProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to reflection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostCrisisReflectionScreen(
          crisisId: crisisProvider.currentCrisis?.id ?? '',
          evaluationId: evaluationId,
          evaluation: evaluationDescription,
        ),
      ),
    );
  }
}

class _EvaluationOption extends StatelessWidget {
  final int evaluationId;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EvaluationOption({
    required this.evaluationId,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 16.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
