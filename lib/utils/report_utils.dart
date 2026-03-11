import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/base_api_service.dart';

class ReportUtils {
  static Future<void> openClinicalReport(BuildContext context) async {
    int elapsedSeconds = 0;
    Timer? timer;
    StateSetter? dialogSetState;
    BuildContext? dialogCtx;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        return StatefulBuilder(
          builder: (_, setState) {
            dialogSetState = setState;
            timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              dialogSetState?.call(() => elapsedSeconds++);
            });
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Generando reporte clínico…',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${elapsedSeconds}s — esto puede tardar hasta 1 minuto',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final reportsService = context.read<ReportsApiService>();

    try {
      final result = await reportsService.getClinicalReportUrl();

      timer?.cancel();
      final activeCtx = dialogCtx;
      if (activeCtx == null || !activeCtx.mounted) return;
      Navigator.pop(activeCtx);

      final isLocalFile =
          !result.startsWith('http://') && !result.startsWith('https://');

      showModalBottomSheet<void>(
        context: activeCtx,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFF22C55E),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporte Clínico Listo',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Tu reporte ha sido generado',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isLocalFile
                                ? Icons.folder_outlined
                                : Icons.cloud_done_outlined,
                            size: 18,
                            color: const Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLocalFile
                                ? '📂 Guardado en Descargas'
                                : '☁️ Disponible en el servidor',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      if (isLocalFile) ...[
                        const SizedBox(height: 6),
                        Text(
                          result.split('/').last,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ábrelo desde "Mis Archivos" → Descargas',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isLocalFile)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Mis Archivos'),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final uri = Uri.parse(
                                'content://com.android.externalstorage.documents/root/primary');
                            try {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } catch (_) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Busca "Mis Archivos" en tu dispositivo → Descargas'),
                                    duration: Duration(seconds: 6),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (isLocalFile) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Abrir'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final Uri uri;
                            final LaunchMode mode;
                            if (isLocalFile) {
                              uri = Uri.file(result);
                              mode = LaunchMode.platformDefault;
                            } else {
                              uri = Uri.parse(result);
                              mode = LaunchMode.externalApplication;
                            }
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: mode);
                            } else {
                              throw Exception('No se pudo abrir');
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isLocalFile
                                        ? 'El PDF está en: $result\n'
                                            'Busca la app "Archivos" o "Mis Archivos" en tu dispositivo.'
                                        : 'No se pudo abrir el enlace: $result',
                                  ),
                                  duration: const Duration(seconds: 8),
                                  backgroundColor: const Color(0xFF475569),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      timer?.cancel();
      final activeCtx = dialogCtx;
      if (activeCtx == null || !activeCtx.mounted) return;
      Navigator.pop(activeCtx);

      final msg = e.toString().replaceFirst('Exception: ', '');

      showDialog<void>(
        context: activeCtx,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Error en el Reporte'),
            ],
          ),
          content: Text(
            msg.startsWith('TIMEOUT')
                ? '⏱ El servidor tardó demasiado.\n\nIntenta de nuevo.'
                : msg.startsWith('AUTH_ERROR')
                    ? '🔒 Sesión expirada. Cierra sesión e inicia de nuevo.'
                    : msg.startsWith('NOT_FOUND')
                        ? '🚫 El servicio de reportes no está disponible.'
                        : '❌ Error: $msg',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }
}
