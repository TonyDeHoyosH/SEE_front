import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/crisis_provider.dart';
import '../../providers/data_provider.dart';
import '../../widgets/crisis_step_indicator.dart';
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
      onPopInvokedWithResult: (didPop, result) async {
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
          automaticallyImplyLeading: false,
          bottom: const CrisisStepIndicator(currentStep: 1),
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

                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1, // ligeramente más ancho que alto
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
    if (lower.contains('vergüenza') || lower.contains('verguenza')) return '😳';
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

  String _getImagePath(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ansiedad')) return 'assets/images/emojis/ansiedad.png';
    if (lower.contains('depresi') || lower.contains('vacío') || lower.contains('vacio')) return 'assets/images/emojis/depresión.png';
    if (lower.contains('estr') || lower.contains('vergüenza') || lower.contains('verguenza')) return 'assets/images/emojis/estrés.png';
    if (lower.contains('ira') || lower.contains('enojo')) return 'assets/images/emojis/enojo.png';
    if (lower.contains('p') && lower.contains('nico') || lower.contains('miedo')) return 'assets/images/emojis/pánico.png';
    if (lower.contains('tristeza')) return 'assets/images/emojis/tristeza.png';
    return 'assets/images/emojis/ansiedad.png';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: AppTheme.accentPrimary, width: 2),
              color: AppTheme.accentPrimary.withValues(alpha: 0.1),
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.transparent, width: 2),
            ),
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        borderRadius: 20.0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji PNG ocupa la mayor parte
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, left: 12, right: 12),
                  child: Image.asset(
                    _getImagePath(emotion),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        Text(emoji, style: const TextStyle(fontSize: 44)),
                  ),
                ),
              ),
              // Nombre emoción
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    emotion,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isSelected
                          ? AppTheme.accentPrimary
                          : AppTheme.textPrimary,
                    ),
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


