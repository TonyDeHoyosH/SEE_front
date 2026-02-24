import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
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
                              ? Image.network(
                                  user!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(user.nombrePreferido),
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
                        Navigator.pop(ctx);
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
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
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    Navigator.pop(context);

    final reportsService = context.read<ReportsApiService>();

    // Show loading
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Generando reporte...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final url = await reportsService.getClinicalReportUrl();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No se puede abrir la URL');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener reporte: $e'),
          backgroundColor: AppTheme.errorRed,
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
