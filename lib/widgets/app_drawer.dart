import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/victory_provider.dart';
import '../screens/auth/login_screen.dart';
import 'privacy_policy_dialog.dart';
import 'terms_conditions_dialog.dart';
import '../screens/auth/setup_2fa_screen.dart';
import '../providers/connectivity_provider.dart';
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
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
                  onTap: () => _showAvatarOptions(context, authProvider),
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
                              ? (user!.avatarUrl!.startsWith('file://')
                                  ? Image.file(
                                      File(user!.avatarUrl!.replaceFirst('file://', '')),
                                      fit: BoxFit.cover,
                                      width: 64,
                                      height: 64,
                                      errorBuilder: (context, error, stackTrace) {
                                        debugPrint('==== ERROR LOADING LOCAL AVATAR ====');
                                        return _avatarFallback(user.nombrePreferido);
                                      },
                                    )
                                  : CachedNetworkImage(
                                      imageUrl:
                                          '${user!.avatarUrl!}?v=${DateTime.now().millisecondsSinceEpoch}',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: AppTheme.primaryGradient,
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) {
                                        debugPrint('==== ERROR LOADING AVATAR ====');
                                        return _avatarFallback(user.nombrePreferido);
                                      },
                                    ))
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.shield_outlined,
                color: AppTheme.accentPrimary),
            title: Text(
              'Aviso de Privacidad',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context); // Cierra el menú
              PrivacyPolicyDialog.show(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined,
                color: AppTheme.accentPrimary),
            title: Text(
              'Términos y Condiciones',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context); // Cierra el menú
              TermsAndConditionsDialog.show(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.security_rounded, color: AppTheme.accentPrimary),
            title: Text(
              'Configurar Seguridad (2FA)',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context); // Cierra el menú
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Setup2FAScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: connectivity.isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Badge(
                    isLabelVisible: connectivity.hasPendingSync,
                    label: const Text('1', style: TextStyle(fontSize: 10)),
                    backgroundColor: AppTheme.errorRed,
                    child: Icon(
                      Icons.sync_rounded,
                      color: connectivity.hasPendingSync
                          ? AppTheme.accentPrimary
                          : AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
            title: Text(
              connectivity.isSyncing
                  ? 'Sincronizando...'
                  : (connectivity.hasPendingSync ? 'Sincronizar datos pendientes' : 'Datos sincronizados'),
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: connectivity.hasPendingSync || connectivity.isSyncing
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            trailing: connectivity.isSyncing
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.errorRed),
                    onPressed: () {
                      connectivity.cancelSync();
                    },
                    tooltip: 'Cancelar sincronización',
                  )
                : null,
            onTap: (connectivity.hasPendingSync && !connectivity.isSyncing)
                ? () {
                    connectivity.syncAll();
                  }
                : null,
            enabled: connectivity.hasPendingSync || connectivity.isSyncing,
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
              final sm = ScaffoldMessenger.of(context);
              final victoryProvider = context.read<VictoryProvider>();
              final navigator = Navigator.of(context, rootNavigator: true);

              Navigator.pop(context); // Cierra el primer drawer
              
              showDialog(
                context: navigator.context,
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
                        Navigator.pop(ctx); // Cierra el dialog
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
    
    // Request permission explicitly to see the system prompt
    Map<Permission, PermissionStatus> statuses;
    if (Platform.isAndroid) {
      statuses = await [Permission.photos, Permission.storage].request();
    } else {
      statuses = await [Permission.photos].request();
    }

    final isPermanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);

    if (isPermanentlyDenied) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos denegados permanentemente, abre Ajustes para cambiar foto.')),
      );
      await openAppSettings();
      return;
    }

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
    } else {}
  }
}

class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final user = authProvider.user;

    Widget button = GestureDetector(
      onTap: () {
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
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.accentPrimary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: user?.avatarUrl != null
              ? (user!.avatarUrl!.startsWith('file://')
                  ? Image.file(
                      File(user!.avatarUrl!.replaceFirst('file://', '')),
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => _FallbackAvatar(name: user.nombrePreferido),
                    )
                  : CachedNetworkImage(
                      imageUrl:
                          '${user!.avatarUrl!}?v=${DateTime.now().millisecondsSinceEpoch}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(strokeWidth: 2),
                      errorWidget: (context, url, error) => _FallbackAvatar(
                        name: user.nombrePreferido,
                      ),
                    ))
              : _FallbackAvatar(
                  name: user?.nombrePreferido ?? 'U',
                ),
        ),
      ),
    );

    if (connectivity.hasPendingSync) {
      return Badge(
        label: const Text('1', style: TextStyle(fontSize: 10)),
        backgroundColor: AppTheme.errorRed,
        alignment: Alignment.topRight,
        offset: const Offset(-2, 2),
        child: button,
      );
    }
    
    return button;
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String name;

  const _FallbackAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
