import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/reflections_provider.dart';
import '../../utils/report_utils.dart';
import '../../widgets/glass_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<FileSystemEntity> _reports = [];
  bool _loadingList = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<Directory> _getSeeReportsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/SEE_reports');
  }

  Future<void> _loadReports() async {
    setState(() => _loadingList = true);
    try {
      final dir = await _getSeeReportsDir();
      if (dir.existsSync()) {
        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.pdf'))
            .toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        setState(() {
          _reports = files;
          _loadingList = false;
        });
      } else {
        setState(() {
          _reports = [];
          _loadingList = false;
        });
      }
    } catch (_) {
      setState(() {
        _reports = [];
        _loadingList = false;
      });
    }
  }

  Future<void> _openFile(File file) async {
    try {
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        throw Exception('${result.type.toString()}: ${result.message}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir: $e\nRuta: ${file.path}',
          ),
          duration: const Duration(seconds: 8),
          backgroundColor: const Color(0xFF475569),
        ),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text(
            '¿Deseas eliminar "${file.path.split('/').last}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await file.delete();
      _loadReports();
    }
  }

  Future<void> _onGeneratePressed() async {
    final pendingCount = context.read<ReflectionsProvider>().pendingCount;

    if (pendingCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Completar Reflexiones'),
          content: Text(
            'Tienes $pendingCount reflexión(es) pendiente(s). Por favor, complétalas navegando a la pestaña "Reflexiones" antes de generar tu reporte para que tu información esté completa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    await ReportUtils.openReport(context);
    // Refresh the list after generating
    _loadReports();
  }

  String _formatDate(DateTime dt) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportes',
                      style: AppTheme.lightTheme.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Genera y consulta tus reportes de bienestar',
                      style:
                          AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Botón Generar ──────────────────────────────
                    GestureDetector(
                      onTap: _onGeneratePressed,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.add_chart_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Generar Reporte',
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Descarga tu reporte de bienestar en PDF',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: Colors.white, size: 24),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Sección historial ──────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mis reportes',
                          style: AppTheme.lightTheme.textTheme.headlineMedium
                              ?.copyWith(fontSize: 18),
                        ),
                        if (!_loadingList)
                          GestureDetector(
                            onTap: _loadReports,
                            child: Icon(Icons.refresh_rounded,
                                color: AppTheme.textSecondary, size: 22),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Lista de reportes ────────────────────────────────────
            if (_loadingList)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_reports.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _EmptyReports(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final file = _reports[i] as File;
                      final filename = file.path.split('/').last;
                      final modified = file.statSync().modified;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      filename,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(modified),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 20),
                                color: AppTheme.accentPrimary,
                                tooltip: 'Abrir',
                                onPressed: () => _openFile(file),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 20),
                                color: const Color(0xFFEF4444),
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteFile(file),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _reports.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            size: 52,
            color: Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Aún no tienes reportes',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Genera tu primer reporte con el\nbotón de arriba.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
