import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/data_provider.dart';
import '../../providers/reflections_provider.dart';
import '../../widgets/glass_card.dart';
import '../crisis/post_crisis_reflection_screen.dart';

class ReflectionsScreen extends StatefulWidget {
  const ReflectionsScreen({super.key});

  @override
  State<ReflectionsScreen> createState() => _ReflectionsScreenState();
}

class _ReflectionsScreenState extends State<ReflectionsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh count when viewing this tab just in case
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReflectionsProvider>().loadPending();
    });
  }

  void _navigateToReflection(Map<String, dynamic> crisis) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostCrisisReflectionScreen(
          existingCrisisId: crisis['id'],
          existingEmotion: crisis['emotion'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Uses global background
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Reflexiones',
                    style: AppTheme.lightTheme.textTheme.displaySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Completar estas reflexiones nos ayuda a entender mejor qué detona tus crisis y cómo ayudarte.',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Consumer<ReflectionsProvider>(
                builder: (context, provider, child) {
                  final pending = provider.pendingReflections;

                  if (pending.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    itemCount: pending.length,
                    itemBuilder: (context, index) {
                      final item = pending[index];
                      final date = DateTime.tryParse(item['started_at']) ?? DateTime.now();
                      final dateStr = DateFormat("d 'de' MMMM 'a las' HH:mm", 'es').format(date);
                      
                      String emotionText = item['emotion'] ?? 'Desconocida';
                      final String? emotionIdsStr = item['emotion_ids'];
                      if (emotionIdsStr != null && emotionIdsStr.isNotEmpty) {
                        try {
                          final dataProvider = context.read<DataProvider>();
                          final ids = emotionIdsStr.split(',').where((e) => e.trim().isNotEmpty).map(int.parse);
                          final names = ids.map((id) => dataProvider.getEmotionById(id)?.name).where((n) => n != null).toList();
                          if (names.isNotEmpty) {
                            emotionText = names.join(', ');
                          }
                        } catch (_) {
                          // Fallback to string if parsing fails
                        }
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: InkWell(
                            onTap: () => _navigateToReflection(item),
                            borderRadius: BorderRadius.circular(24),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Emociones: $emotionText',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '¡Todo al día!',
              style: AppTheme.lightTheme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes reflexiones pendientes.',
              textAlign: TextAlign.center,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48), // Spacing for navbar
          ],
        ),
      ),
    );
  }
}
