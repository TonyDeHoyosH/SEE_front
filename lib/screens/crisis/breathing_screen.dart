import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/crisis_provider.dart';
import 'crisis_capsules_selection_screen.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _currentPhase = 'Inhala profundamente';
  bool _completed = false;
  int _cyclesCompleted = 0; // Contador de ciclos completados

  @override
  void initState() {
    super.initState();

    // Total cycle: 19 seconds (4 + 7 + 8)
    _controller = AnimationController(
      duration: const Duration(seconds: 19),
      vsync: this,
    );

    // Animation sequence: grow (0-4s), hold (4-11s), shrink (11-19s)
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 7,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
    ]).animate(_controller);

    // Update phase text
    _controller.addListener(() {
      final progress = _controller.value;
      String newPhase;
      if (progress < 4 / 19) {
        newPhase = 'Inhala profundamente';
      } else if (progress < 11 / 19) {
        newPhase = 'Sostén el aire';
      } else {
        newPhase = 'Exhala lentamente';
      }
      if (newPhase != _currentPhase) {
        setState(() => _currentPhase = newPhase);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completed = true;
          _cyclesCompleted++;
        });

        // Notificar al backend que se completó un ciclo de respiración
        _reportBreathingCycle();

        // Loop the animation
        _controller.repeat();
      }
    });

    _controller.forward();
  }

  /// Informa al backend que se completó un ciclo de respiración.
  /// Se llama cada vez que el AnimationController completa un ciclo.
  void _reportBreathingCycle() {
    final crisisProvider = context.read<CrisisProvider>();
    final crisisId = crisisProvider.currentCrisis?.id;
    if (crisisId == null) return;

    // updateCrisisProgress acumula: breathingExerciseCompleted = true
    // El backend debería incrementar el contador; si no, al menos registra
    // que hay ejercicios completados.
    crisisProvider.markBreathingCycleCompleted(crisisId);
    debugPrint(
        '[Respiración] Ciclo $_cyclesCompleted completado → PATCH enviado');
  }

  Future<void> _navigateToNextStep() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CrisisCapsulesSelectionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Respiración Guiada'),
            Text(
              'Paso 2 de 3',
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Respira conmigo',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            if (_cyclesCompleted > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$_cyclesCompleted ${_cyclesCompleted == 1 ? 'ciclo completado' : 'ciclos completados'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                Color currentInnerColor;
                Color currentOuterColor;

                if (_currentPhase == 'Inhala profundamente') {
                  double phaseProgress = _controller.value / (4 / 19);
                  phaseProgress = phaseProgress.clamp(0.0, 1.0);
                  currentInnerColor = Color.lerp(
                    AppTheme.breathEmptyInner,
                    AppTheme.breathFullInner,
                    phaseProgress,
                  )!;
                  currentOuterColor = Color.lerp(
                    AppTheme.breathEmptyOuter,
                    AppTheme.breathFullOuter,
                    phaseProgress,
                  )!;
                } else if (_currentPhase == 'Sostén el aire') {
                  double phaseProgress =
                      (_controller.value - (4 / 19)) / (7 / 19);
                  phaseProgress = phaseProgress.clamp(0.0, 1.0);
                  currentInnerColor = Color.lerp(
                    AppTheme.breathFullInner,
                    AppTheme.breathReleaseInner,
                    phaseProgress,
                  )!;
                  currentOuterColor = Color.lerp(
                    AppTheme.breathFullOuter,
                    AppTheme.breathReleaseOuter,
                    phaseProgress,
                  )!;
                } else {
                  double phaseProgress =
                      (_controller.value - (11 / 19)) / (8 / 19);
                  phaseProgress = phaseProgress.clamp(0.0, 1.0);
                  currentInnerColor = Color.lerp(
                    AppTheme.breathReleaseInner,
                    AppTheme.breathEmptyInner,
                    phaseProgress,
                  )!;
                  currentOuterColor = Color.lerp(
                    AppTheme.breathReleaseOuter,
                    AppTheme.breathEmptyOuter,
                    phaseProgress,
                  )!;
                }

                final double currentSize = 80 + (180 * _animation.value);

                return Container(
                  width: currentSize,
                  height: currentSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentInnerColor.withValues(alpha: 0.5),
                    border: Border.all(
                      color: currentOuterColor,
                      width: 4,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            Text(
              _currentPhase,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
            if (_completed) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToNextStep,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text('Ya estoy más tranquilo'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 48),
            ],
          ],
        ),
      ),
    );
  }
}
