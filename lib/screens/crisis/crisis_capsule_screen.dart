import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/crisis_provider.dart';
import '../../widgets/glass_card.dart';
import '../../config/theme.dart';
import 'breathing_screen.dart';

class CrisisCapsuleScreen extends StatelessWidget {
  const CrisisCapsuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final crisisProvider = context.watch<CrisisProvider>();
    final capsule = crisisProvider.recommendedCapsule;

    return Scaffold(
      backgroundColor: Colors.transparent, // Global background applied
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cápsula para ti'),
            Text(
              'Paso 2 de 4',
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
      body: capsule == null
          ? const Center(child: Text('No hay cápsula disponible'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb,
                    size: 64,
                    color: Color(0xFF5EEAD4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    capsule.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      capsule.content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BreathingScreen(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Text('Continuar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
