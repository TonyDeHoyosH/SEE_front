import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/emotion.dart';
import '../../providers/data_provider.dart';
import '../../models/capsule.dart';
import '../../services/base_api_service.dart';
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
                                capsule: capsule, emotions: emotions);
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

  const _CapsuleCard({required this.capsule, required this.emotions});

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

  Color get _iconColor => widget.capsule.type == 'audio'
      ? AppTheme.accentPrimary
      : const Color(0xFFC4A8E8);

  @override
  Widget build(BuildContext context) {
    final emotionName = widget.emotions
            .where((e) => e.id == widget.capsule.emotionId)
            .map((e) => e.name)
            .firstOrNull ??
        'Emoción ${widget.capsule.emotionId}';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CapsuleDetailScreen(
              capsule: widget.capsule,
              emotionName: emotionName,
            ),
          ),
        );
      },
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
                  widget.capsule.type == 'audio'
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
          if (widget.capsule.type == 'texto') ...[
            const SizedBox(height: 16),
            Text(
              widget.capsule.content,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Grabación de voz guardada',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
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
              emotionName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
