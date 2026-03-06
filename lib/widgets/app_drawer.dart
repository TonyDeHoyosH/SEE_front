import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/victory_provider.dart';
import '../services/base_api_service.dart';
import '../screens/auth/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC), // Opaque background
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showAvatarOptions(context, authProvider),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: user?.avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl:
                                      '${user!.avatarUrl!}?v=${DateTime.now().millisecondsSinceEpoch}',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => DecoratedBox(
                                    decoration: const BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    debugPrint(
                                        '==== ERROR LOADING AVATAR ====');
                                    debugPrint('URL: $url');
                                    debugPrint('Error: $error');
                                    debugPrint(
                                        '==============================');
                                    return _avatarFallback(
                                        user.nombrePreferido);
                                  },
                                )
                              : DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                  ),
                                  child: Center(
                                    child: _avatarFallback(
                                        user?.nombrePreferido ?? 'U'),
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 12,
                          color: AppTheme.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.nombrePreferido ?? 'Usuario',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mantén presionado para cambiar foto',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.55),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Clinical report
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined,
                color: AppTheme.accentPrimary),
            title: Text(
              'Mi Reporte Clínico',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _openClinicalReport(context),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined,
                color: AppTheme.accentPrimary),
            title: Text(
              'Política de Privacidad',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined,
                color: AppTheme.accentPrimary),
            title: Text(
              'Términos y condiciones',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded,
                color: AppTheme.errorRed),
            title: Text(
              'Eliminar cuenta',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorRed,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar cuenta'),
                  content: const Text(
                    '¿Estás seguro? Esta acción no se puede deshacer.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                      ),
                      onPressed: () async {
                        final sm = ScaffoldMessenger.of(context);
                        final victoryProvider = context.read<VictoryProvider>();
                        final navigator =
                            Navigator.of(context, rootNavigator: true);

                        Navigator.pop(ctx);
                        try {
                          await authProvider.deleteAccount();
                          sm.showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Cuenta eliminada permanentemente.'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        } catch (e) {
                          sm.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Intentamos eliminarla pero el servidor falló: $e. Cerrando sesión local...'),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        } finally {
                          victoryProvider.clear();
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            title: Text(
              'Cerrar sesión',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              final victoryProvider = context.read<VictoryProvider>();
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context);

              victoryProvider.clear();
              await authProvider.logout();

              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Text(
      name[0].toUpperCase(),
      style: GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  Future<void> _showAvatarOptions(
      BuildContext context, AuthProvider authProvider) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Foto de perfil',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Cambiar foto desde galería'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUploadAvatar(context, authProvider);
              },
            ),
            if (authProvider.user?.avatarUrl != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                title: const Text(
                  'Eliminar foto',
                  style: TextStyle(
                      color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteAvatar(context, authProvider);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAvatar(
      BuildContext context, AuthProvider authProvider) async {
    await authProvider.deleteAvatar();

    if (!context.mounted) return;
    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar foto: ${authProvider.errorMessage}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto eliminada'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }
  }

  Future<void> _pickAndUploadAvatar(
      BuildContext context, AuthProvider authProvider) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (picked == null || !context.mounted) return;

    await authProvider.updateAvatar(File(picked.path));

    if (!context.mounted) return;
    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sin conexión: no se pudo subir la foto. ${authProvider.errorMessage}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto actualizada'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }
  }

  Future<void> _openClinicalReport(BuildContext context) async {
    Navigator.pop(context); // cerrar drawer

    int _elapsedSeconds = 0;
    Timer? _timer;
    StateSetter? _dialogSetState;
    // dialogCtx: contexto del propio diálogo, permanece montado mientras
    // el diálogo está visible, independientemente del contexto del drawer.
    BuildContext? _dialogCtx;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _dialogCtx = ctx; // capturar aquí: ctx vive mientras el diálogo exista
        return StatefulBuilder(
          builder: (_, setState) {
            _dialogSetState = setState;
            _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              _dialogSetState?.call(() => _elapsedSeconds++);
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
                    '${_elapsedSeconds}s — esto puede tardar hasta 1 minuto',
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

      _timer?.cancel();
      // Usar dialogCtx (siempre montado) en lugar de context (ya desmontado)
      final activeCtx = _dialogCtx;
      if (activeCtx == null || !activeCtx.mounted) return;
      Navigator.pop(activeCtx); // cerrar loading dialog

      final isLocalFile =
          !result.startsWith('http://') && !result.startsWith('https://');

      // Mostrar bottom sheet con el resultado
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
                // Header
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

                // Ubicación
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

                // Botones
                Row(
                  children: [
                    if (isLocalFile)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Mis Archivos'),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            // Abrir el gestor de archivos de Android
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
      _timer?.cancel();
      final activeCtx = _dialogCtx;
      if (activeCtx == null || !activeCtx.mounted) return;
      Navigator.pop(activeCtx); // cerrar loading dialog

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

class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      onPressed: () {
        ScaffoldState? targetScaffold;
        context.visitAncestorElements((element) {
          if (element.widget is Scaffold) {
            final state = (element as StatefulElement).state as ScaffoldState;
            if (state.hasEndDrawer) {
              targetScaffold = state;
              return false; // Stop visiting
            }
          }
          return true;
        });

        if (targetScaffold != null) {
          targetScaffold!.openEndDrawer();
        } else {
          Scaffold.of(context).openEndDrawer();
        }
      },
    );
  }
}
