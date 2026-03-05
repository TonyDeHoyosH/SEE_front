import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/capsule.dart';
import '../../providers/crisis_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/base_api_service.dart';
import '../../widgets/glass_card.dart';
import '../capsules/capsule_detail_screen.dart';
import 'crisis_evaluation_screen.dart';

class CrisisCapsulesSelectionScreen extends StatefulWidget {
  const CrisisCapsulesSelectionScreen({super.key});

  @override
  State<CrisisCapsulesSelectionScreen> createState() =>
      _CrisisCapsulesSelectionScreenState();
}

class _CrisisCapsulesSelectionScreenState
    extends State<CrisisCapsulesSelectionScreen> {
  List<Capsule> _capsules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendedCapsules();
  }

  Future<void> _loadRecommendedCapsules() async {
    try {
      final crisisProvider = context.read<CrisisProvider>();
      final currentCrisis = crisisProvider.currentCrisis;

      final allCapsules = await context.read<CoreApiService>().getCapsules();
      // Nunca mostrar cápsulas inactivas en el flujo de crisis
      final activeCapsules = allCapsules.where((c) => c.isActive).toList();

      if (currentCrisis != null &&
          currentCrisis.emotionIds.isNotEmpty &&
          mounted) {
        setState(() {
          _capsules = activeCapsules.where((c) {
            return c.emotionIds
                .any((id) => currentCrisis.emotionIds.contains(id));
          }).toList();
          // Si ninguna cápsula activa coincide con las emociones, mostrar todas las activas
          if (_capsules.isEmpty) _capsules = activeCapsules;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _capsules = activeCapsules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEvaluation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CrisisEvaluationScreen(breathingCompleted: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cápsulas recomendadas'),
            Text(
              'Paso 3 de 4',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tómate un momento',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona una cápsula de contención que te ayude a procesar lo que sientes en este momento.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _capsules.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay cápsulas recomendadas. Puedes continuar.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _capsules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final capsule = _capsules[index];
                              return GlassCard(
                                onTap: () async {
                                  final emotionNames =
                                      capsule.emotionIds.isEmpty
                                          ? 'General'
                                          : capsule.emotionIds
                                              .map((id) =>
                                                  context
                                                      .read<DataProvider>()
                                                      .getEmotionById(id)
                                                      ?.name ??
                                                  'Desconocida')
                                              .join(', ');
                                  // Esperar a que el usuario regrese de la cápsula
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CapsuleDetailScreen(
                                        capsule: capsule,
                                        emotionName: emotionNames,
                                      ),
                                    ),
                                  );
                                  // Al regresar, registrar que esta cápsula fue usada
                                  if (!context.mounted) return;
                                  final crisisId = context
                                      .read<CrisisProvider>()
                                      .currentCrisis
                                      ?.id;
                                  if (crisisId != null) {
                                    debugPrint(
                                        '[Crisis] Marcando cápsula usada: ${capsule.id}');
                                    await context
                                        .read<CrisisProvider>()
                                        .markCapsuleUsed(crisisId, capsule.id);
                                  }
                                },
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentPrimary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        capsule.type.toUpperCase() == 'AUDIO'
                                            ? Icons.mic_rounded
                                            : Icons.text_snippet_rounded,
                                        color: AppTheme.accentPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            capsule.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            capsule.type.toUpperCase() ==
                                                    'AUDIO'
                                                ? 'Nota de voz'
                                                : 'Texto',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: AppTheme.textSecondary),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToEvaluation,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text('Continuar a evaluación'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
