import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/victory_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_card.dart';
import '../../utils/sanitizer_utils.dart';

class VictoriesScreen extends StatefulWidget {
  const VictoriesScreen({super.key});

  @override
  State<VictoriesScreen> createState() => _VictoriesScreenState();
}

class _VictoriesScreenState extends State<VictoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VictoryProvider>().loadAll();
    });
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Victoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'Ej: Leí 10 páginas',
            labelText: '¿Qué logro quieres registrar?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = SanitizerUtils.sanitizeHtml(controller.text.trim());
              if (name.isNotEmpty) {
                context.read<VictoryProvider>().addDefinition(name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Victoria añadida'),
                    backgroundColor: AppTheme.successGreen,
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(VictoryDefinition def) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                def.name,
                style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.edit_rounded, color: AppTheme.accentPrimary),
              title: const Text('Cambiar nombre'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(def);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_rounded, color: AppTheme.errorRed),
              title: const Text('Eliminar'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(def);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(VictoryDefinition def) {
    final controller = TextEditingController(text: def.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Victoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = SanitizerUtils.sanitizeHtml(controller.text.trim());
              if (name.isNotEmpty) {
                context.read<VictoryProvider>().updateDefinition(def.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(VictoryDefinition def) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Victoria'),
        content: Text('¿Eliminar "${def.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            onPressed: () {
              context.read<VictoryProvider>().deleteDefinition(def.id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VictoryProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent, // Global gradient shows through
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis Victorias',
                    style: AppTheme.lightTheme.textTheme.headlineMedium,
                  ),
                  const AppDrawerButton(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Registra al menos una victoria al día para recordar tus logros personales, por más pequeños que sean.',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              if (provider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Text(
                  'Registra una victoria hoy',
                  style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Marca las acciones positivas que completaste',
                  style: AppTheme.lightTheme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ...provider.definitions.asMap().entries.map((entry) {
                        final def = entry.value;
                        final isChecked =
                            provider.todayChecked.contains(def.id);
                        return GestureDetector(
                          onLongPress: () => _showOptionsSheet(def),
                          onTap: () {
                            final wasChecked = isChecked;
                            provider.toggleCheck(def.id);
                            if (!wasChecked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('¡Bien hecho! 🎉'),
                                  backgroundColor: AppTheme.successGreen,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border:
                                  entry.key < provider.definitions.length - 1
                                      ? Border(
                                          bottom: BorderSide(
                                            color: AppTheme.textSecondary
                                                .withValues(alpha: 0.1),
                                          ),
                                        )
                                      : null,
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                def.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isChecked
                                      ? AppTheme.textSecondary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              trailing: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isChecked
                                      ? AppTheme.accentPrimary
                                      : Colors.transparent,
                                  border: isChecked
                                      ? null
                                      : Border.all(
                                          color: AppTheme.accentLight,
                                          width: 2,
                                        ),
                                ),
                                child: isChecked
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (provider.definitions.isNotEmpty)
                        Divider(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.1)),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentButton,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Añadir nueva victoria',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Historial',
                  style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 16),
                if (provider.history.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay victorias registradas aún',
                            style: AppTheme.lightTheme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.history.take(5).length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = provider.history.take(5).toList()[index];
                      return _VictoryCard(log: log);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VictoryCard extends StatelessWidget {
  final VictoryLog log;

  const _VictoryCard({required this.log});

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(logDate).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 7) return 'Hace $diff días';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: AppTheme.accentPrimary,
            size: 24,
          ),
        ),
        title: Text(
          log.name,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          _formatDate(log.loggedDate),
          style: AppTheme.lightTheme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
