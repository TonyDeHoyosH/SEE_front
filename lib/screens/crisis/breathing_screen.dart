import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/crisis_provider.dart';
import '../../widgets/crisis_step_indicator.dart';
import 'crisis_capsules_selection_screen.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rippleController;
  late Animation<double> _animation;
  String _currentPhase = 'Inhala profundamente';
  bool _completed = false;
  int _cyclesCompleted = 0;

  @override
  void initState() {
    super.initState();

    // Main cycle controller: 19 seconds (4 inhale + 7 hold + 8 exhale)
    _controller = AnimationController(
      duration: const Duration(seconds: 19),
      vsync: this,
    );

    // Ripple controller: loops every 2 seconds, drives the wave animations
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Size sequence: grow → hold → shrink
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

    // Phase tracking + haptic on transition
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
        HapticFeedback.mediumImpact();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completed = true;
          _cyclesCompleted++;
        });
        _reportBreathingCycle();
        HapticFeedback.lightImpact();
        _controller.forward(from: 0.0);
      }
    });

    _controller.forward();
  }

  void _reportBreathingCycle() {
    final crisisProvider = context.read<CrisisProvider>();
    final crisisId = crisisProvider.currentCrisis?.id;
    if (crisisId == null) return;
    crisisProvider.markBreathingCycleCompleted(crisisId);
    debugPrint(
        '[Respiración] Ciclo $_cyclesCompleted completado → PATCH enviado');
  }

  Future<void> _navigateToNextStep() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CrisisCapsulesSelectionScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  // Compute current colors based on phase progress
  (Color inner, Color outer) _resolveColors() {
    final val = _controller.value;
    if (_currentPhase == 'Inhala profundamente') {
      final t = (val / (4 / 19)).clamp(0.0, 1.0);
      return (
        Color.lerp(AppTheme.breathEmptyInner, AppTheme.breathFullInner, t)!,
        Color.lerp(AppTheme.breathEmptyOuter, AppTheme.breathFullOuter, t)!,
      );
    } else if (_currentPhase == 'Sostén el aire') {
      final t = ((val - (4 / 19)) / (7 / 19)).clamp(0.0, 1.0);
      return (
        Color.lerp(AppTheme.breathFullInner, AppTheme.breathReleaseInner, t)!,
        Color.lerp(AppTheme.breathFullOuter, AppTheme.breathReleaseOuter, t)!,
      );
    } else {
      final t = ((val - (11 / 19)) / (8 / 19)).clamp(0.0, 1.0);
      return (
        Color.lerp(AppTheme.breathReleaseInner, AppTheme.breathEmptyInner, t)!,
        Color.lerp(AppTheme.breathReleaseOuter, AppTheme.breathEmptyOuter, t)!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: const CrisisStepIndicator(currentStep: 2),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              'Respira conmigo',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _cyclesCompleted == 0
                    ? 'Sigue el ritmo del círculo'
                    : '$_cyclesCompleted ${_cyclesCompleted == 1 ? 'ciclo completado ✓' : 'ciclos completados ✓'}',
                key: ValueKey(_cyclesCompleted),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _cyclesCompleted == 0
                          ? AppTheme.textSecondary
                          : AppTheme.accentButton,
                      fontWeight: _cyclesCompleted > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // Breathing circle with ripple waves — centered
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_animation, _rippleController]),
                  builder: (context, _) {
                    final (innerColor, outerColor) = _resolveColors();
                    final mainRadius = 40.0 + (90.0 * _animation.value);

                    return CustomPaint(
                      size: const Size(260, 260),
                      painter: _BreathingPainter(
                        phase: _currentPhase,
                        mainRadius: mainRadius,
                        rippleProgress: _rippleController.value,
                        innerColor: innerColor,
                        outerColor: outerColor,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Phase label with crossfade
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _currentPhase,
                key: ValueKey(_currentPhase),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (_completed)
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class _BreathingPainter extends CustomPainter {
  final String phase;
  final double mainRadius; // current circle radius in px (40–130)
  final double rippleProgress; // 0.0–1.0, loops
  final Color innerColor;
  final Color outerColor;

  static const int _numWaves = 3;
  static const double _minRadius = 40.0;
  static const double _maxRadius = 130.0;

  const _BreathingPainter({
    required this.phase,
    required this.mainRadius,
    required this.rippleProgress,
    required this.innerColor,
    required this.outerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── Draw ripple waves first (behind main circle) ──────────────────────
    for (int i = 0; i < _numWaves; i++) {
      final stagger = i / _numWaves;
      final t = ((rippleProgress + stagger) % 1.0);

      double waveRadius;
      double opacity;

      if (phase == 'Inhala profundamente') {
        // Waves born at center, expand outward to mainRadius
        waveRadius = _minRadius * 0.3 + t * mainRadius;
        opacity = (1.0 - t) * 0.45;
      } else if (phase == 'Sostén el aire') {
        // Waves fixed near mainRadius, pulse in opacity (sine wave)
        final offset = i / _numWaves;
        waveRadius = mainRadius * (0.6 + 0.13 * i);
        opacity = 0.15 + 0.25 * sin((rippleProgress + offset) * 2 * pi);
      } else {
        // Waves born at mainRadius, shrink inward toward center
        waveRadius = mainRadius - t * (mainRadius - _minRadius * 0.3);
        opacity = (1.0 - t) * 0.45;
      }

      final wavePaint = Paint()
        ..color = outerColor.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(
          center, waveRadius.clamp(0.0, _maxRadius + 20), wavePaint);
    }

    // ── Draw main filled circle ───────────────────────────────────────────
    final fillPaint = Paint()
      ..color = innerColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, mainRadius, fillPaint);

    final borderPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, mainRadius, borderPaint);
  }

  @override
  bool shouldRepaint(_BreathingPainter old) =>
      old.mainRadius != mainRadius ||
      old.rippleProgress != rippleProgress ||
      old.phase != phase ||
      old.innerColor != innerColor ||
      old.outerColor != outerColor;
}
