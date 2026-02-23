import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/victory_provider.dart';
import '../../widgets/app_drawer.dart';

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
              final name = controller.text.trim();
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                def.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
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
            const SizedBox(height: 8),
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
              final name = controller.text.trim();
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
      endDrawer: const AppDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9F7AEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mis Victorias',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const AppDrawerButton(),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registra una victoria hoy',
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Marca las acciones positivas que completaste',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [AppTheme.cardShadow],
                                ),
                                child: Column(
                                  children: [
                                    ...provider.definitions
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final def = entry.value;
                                      final isChecked = provider.todayChecked
                                          .contains(def.id);
                                      return GestureDetector(
                                        onLongPress: () =>
                                            _showOptionsSheet(def),
                                        onTap: () {
                                          final wasChecked = isChecked;
                                          provider.toggleCheck(def.id);
                                          if (!wasChecked) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('¡Bien hecho! 🎉'),
                                                backgroundColor:
                                                    AppTheme.successGreen,
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: entry.key <
                                                    provider.definitions
                                                            .length -
                                                        1
                                                ? Border(
                                                    bottom: BorderSide(
                                                      color: AppTheme.textLight
                                                          .withValues(
                                                              alpha: 0.1),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          child: ListTile(
                                            title: Text(
                                              def.name,
                                              style: GoogleFonts.nunito(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                decoration: isChecked
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: isChecked
                                                    ? AppTheme.textLight
                                                    : AppTheme.textDark,
                                              ),
                                            ),
                                            trailing: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 250),
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: isChecked
                                                    ? AppTheme.mintGradient
                                                    : null,
                                                border: isChecked
                                                    ? null
                                                    : Border.all(
                                                        color: Colors
                                                            .grey.shade300,
                                                        width: 2,
                                                      ),
                                              ),
                                              child: isChecked
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      color: Colors.white,
                                                      size: 16,
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    Divider(
                                      height: 1,
                                      color: AppTheme.textLight
                                          .withValues(alpha: 0.1),
                                    ),
                                    TextButton.icon(
                                      onPressed: _showAddDialog,
                                      icon: const Icon(Icons.add_rounded),
                                      label:
                                          const Text('Añadir nueva victoria'),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Historial',
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 16),
                              provider.history.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.emoji_events_outlined,
                                              size: 48,
                                              color: AppTheme.textLight
                                                  .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No hay victorias registradas aún',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount:
                                          provider.history.take(7).length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final log = provider.history
                                            .take(7)
                                            .toList()[index];
                                        return _VictoryCard(log: log);
                                      },
                                    ),
                            ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          log.name,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _formatDate(log.loggedDate),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
