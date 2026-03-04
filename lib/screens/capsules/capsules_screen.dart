import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/emotion.dart';
import '../../providers/data_provider.dart';
import '../../models/capsule.dart';
import '../../services/base_api_service.dart';
import '../../services/local_database_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/glass_card.dart';
import 'capsule_detail_screen.dart';
import 'create_capsule_screen.dart';

class CapsulesScreen extends StatefulWidget {
  const CapsulesScreen({super.key});

  @override
  State<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends State<CapsulesScreen> {
  List<Capsule> _capsules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCapsules();
  }

  Future<void> _loadCapsules() async {
    setState(() => _isLoading = true);

    try {
      final capsules = await context.read<CoreApiService>().getCapsules();
      setState(() {
        _capsules = capsules;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cápsulas: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCapsuleScreen()),
    );

    if (result == true) {
      _loadCapsules();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Uses global background
      floatingActionButton: Padding(
        padding:
            const EdgeInsets.only(bottom: 90.0), // Above the floating navbar
        child: FloatingActionButton(
          onPressed: _navigateToCreate,
          elevation: 4,
          backgroundColor: AppTheme.accentButton,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis Cápsulas',
                    style: AppTheme.lightTheme.textTheme.headlineMedium,
                  ),
                  const AppDrawerButton(),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _capsules.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 64,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No tienes cápsulas aún',
                                  style: AppTheme
                                      .lightTheme.textTheme.headlineMedium
                                      ?.copyWith(
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea una cápsula personalizada con el botón +',
                                  style:
                                      AppTheme.lightTheme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 180),
                          itemCount: _capsules.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final capsule = _capsules[index];
                            final emotions =
                                context.read<DataProvider>().emotions;
                            return _CapsuleCard(
                              capsule: capsule,
                              emotions: emotions,
                              onChanged: _loadCapsules,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleCard extends StatefulWidget {
  final Capsule capsule;
  final List<Emotion> emotions;
  final VoidCallback onChanged;

  const _CapsuleCard({
    required this.capsule,
    required this.emotions,
    required this.onChanged,
  });

  @override
  State<_CapsuleCard> createState() => _CapsuleCardState();
}

class _CapsuleCardState extends State<_CapsuleCard> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = widget.capsule.isActive;
  }

  Color get _iconColor => widget.capsule.type.toUpperCase() == 'AUDIO'
      ? AppTheme.accentPrimary
      : const Color(0xFFC4A8E8);

  void _showOptionsSheet(BuildContext context, Capsule capsule) {
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
                capsule.title,
                style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.edit_rounded, color: AppTheme.accentPrimary),
              title: const Text('Editar cápsula'),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToEdit(capsule);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_rounded, color: AppTheme.errorRed),
              title: const Text('Eliminar cápsula'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(capsule);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToEdit(Capsule capsule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCapsuleScreen(capsule: capsule),
      ),
    );
    if (result == true) {
      widget.onChanged();
    }
  }

  void _confirmDelete(Capsule capsule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        content: Text(
            'Esto eliminará la cápsula \'${capsule.title}\'. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await context.read<CoreApiService>().deleteCapsule(capsule.id);
              } catch (e) {
                // Si falla en backend, continua de todas formas para no dejar colgada la app
              }
              await LocalDatabaseService.deleteCapsule(capsule.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                widget.onChanged();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emotionNames = widget.capsule.emotionIds.isEmpty
        ? 'Sin emoción'
        : widget.capsule.emotionIds.map((id) {
            return widget.emotions
                    .where((e) => e.id == id)
                    .map((e) => e.name)
                    .firstOrNull ??
                'Emoción $id';
          }).join(', ');

    return GlassCard(
      padding: const EdgeInsets.all(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CapsuleDetailScreen(
              capsule: widget.capsule,
              emotionName: emotionNames,
            ),
          ),
        );
      },
      onLongPress: () => _showOptionsSheet(context, widget.capsule),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.capsule.type.toUpperCase() == 'AUDIO'
                      ? Icons.mic_rounded
                      : Icons.text_fields_rounded,
                  size: 24,
                  color: _iconColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.capsule.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isActive
                          ? 'Cápsula activada'
                          : 'Cápsula desactivada'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          if (widget.capsule.type.toUpperCase() == 'TEXT' &&
              widget.capsule.content.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              widget.capsule.content,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (widget.capsule.type.toUpperCase() == 'AUDIO') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.play_circle_outline,
                    size: 18, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Grabación de voz',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentLight.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              emotionNames,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
