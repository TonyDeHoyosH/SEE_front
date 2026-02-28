import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/crisis_provider.dart';
import '../../providers/data_provider.dart';
import '../../widgets/glass_card.dart';
import '../../config/theme.dart';
import 'breathing_screen.dart';

class CrisisEmotionScreen extends StatefulWidget {
  const CrisisEmotionScreen({super.key});

  @override
  State<CrisisEmotionScreen> createState() => _CrisisEmotionScreenState();
}

class _CrisisEmotionScreenState extends State<CrisisEmotionScreen> {
  final Set<int> _selectedEmotionIds = {};
  double _intensity = 5.0;

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final emotions = dataProvider.emotions;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Salir del flujo?'),
            content: const Text(
              '¿Estás seguro que quieres salir? No se guardará tu progreso.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Salir'),
              ),
            ],
          ),
        );

        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent, // Global background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Qué sientes?'),
              Text(
                'Paso 1 de 3',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        body: emotions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identifica tu emoción',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona lo que más se acerca a cómo te sientes ahora',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: emotions.length,
                        itemBuilder: (context, index) {
                          final emotion = emotions[index];
                          final isSelected =
                              _selectedEmotionIds.contains(emotion.id);
                          return _EmotionCard(
                            emotion: emotion.name,
                            emoji: _getEmotionEmoji(emotion.name),
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedEmotionIds.remove(emotion.id);
                                } else {
                                  _selectedEmotionIds.add(emotion.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Intensidad de la crisis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('1',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        Expanded(
                          child: Slider(
                            value: _intensity,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _intensity.round().toString(),
                            activeColor: AppTheme.accentPrimary,
                            inactiveColor:
                                AppTheme.accentPrimary.withValues(alpha: 0.2),
                            onChanged: (value) {
                              setState(() {
                                _intensity = value;
                              });
                            },
                          ),
                        ),
                        const Text('10',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedEmotionIds.isNotEmpty
                            ? () => _handleContinuar(context)
                            : null,
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text('Continuar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ), // Close PopScope child (Scaffold)
    ); // Close PopScope
  }

  String _getEmotionEmoji(String emotionName) {
    final lower = emotionName.toLowerCase();
    if (lower.contains('ansiedad')) return '😰';
    if (lower.contains('miedo')) return '😨';
    if (lower.contains('tristeza')) return '😢';
    if (lower.contains('ira')) return '😠';
    if (lower.contains('vacío') || lower.contains('vacio')) return '😶';
    return '😐';
  }

  Future<void> _handleContinuar(BuildContext context) async {
    final crisisProvider = context.read<CrisisProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await crisisProvider.startCrisis(
      _selectedEmotionIds.toList(),
      _intensity.round(),
    );

    if (!context.mounted) return;

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

    // Default flow continues to BreathingScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BreathingScreen(),
      ),
    );
  }
}

class _EmotionCard extends StatelessWidget {
  final String emotion;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmotionCard({
    required this.emotion,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: AppTheme.accentPrimary, width: 2),
              color: AppTheme.accentPrimary.withValues(alpha: 0.1),
            )
          : null,
      child: GlassCard(
        padding: const EdgeInsets.all(8.0),
        borderRadius: 16.0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(
                emotion,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
