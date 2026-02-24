import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'crisis_evaluation_screen.dart';

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
      // Grow: 0.0 to 1.0 over 4 seconds
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
      // Hold: stay at 1.0 for 7 seconds
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 7,
      ),
      // Shrink: 1.0 to 0.5 over 8 seconds
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 8,
      ),
    ]).animate(_controller);

    // Update phase text based on progress
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
        setState(() {
          _currentPhase = newPhase;
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completed = true;
        });
        // Loop the animation
        _controller.repeat();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToEvaluation({required bool completed}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrisisEvaluationScreen(breathingCompleted: completed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Global background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Respiración Guiada'),
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
            const SizedBox(height: 48),
            // Breathing circle animation
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 200 + (100 * _animation.value),
                  height: 200 + (100 * _animation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF86EFAC).withValues(alpha: 0.3),
                    border: Border.all(
                      color: const Color(0xFF86EFAC),
                      width: 3,
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
                  onPressed: () => _navigateToEvaluation(completed: true),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text('Ya estoy más tranquilo'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _navigateToEvaluation(completed: false),
                child: const Text('Omitir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
