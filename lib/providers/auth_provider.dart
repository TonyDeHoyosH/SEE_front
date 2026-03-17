import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/base_api_service.dart';
import '../services/local_database_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authService;
  final CoreApiService _coreService;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authService, this._coreService);

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      await _saveSession(_user!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String email,
    String password,
    String nombrePreferido,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.register(email, password, nombrePreferido);
      await _saveSession(_user!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '406957271307-3d97h1iouperfm2p9g0hrf4pp4bt6n3h.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInClientAuthorization authDetails =
          await googleUser.authorizationClient.authorizeScopes([
        'email',
        'https://www.googleapis.com/auth/bigquery',
      ]);

      final String accessToken = authDetails.accessToken;

      if (accessToken.isEmpty) {
        throw Exception('No se pudo obtener el token de acceso de Google.');
      }

      // Enviar snapshot de telemetría a nuestro backend
      await _coreService.sendTelemetrySnapshot(accessToken);

      // Enviar credenciales a Node.js para que genere sesión en BD y devuelva su Token Oficial
      _user = await _authService.googleLogin(
        googleUser.email,
        googleUser.displayName ?? 'Usuario de Google',
        accessToken,
      );

      // Guardar también la sesión global
      await _saveSession(_user!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('canceled') ||
          e.toString().contains('sign_in_canceled') ||
          e.toString().contains('GoogleSignInException')) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      _errorMessage = 'Error en inicio de sesión con Google: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAvatar(File imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _coreService.updateProfile(avatarImage: imageFile);
      _user = _user?.copyWith(avatarUrl: updated.avatarUrl);
      final prefs = await SharedPreferences.getInstance();
      if (updated.avatarUrl != null) {
        await prefs.setString('user_avatar', updated.avatarUrl!);
      }
      // Clean any pending offline cache for this user
      if (_user?.id != null) {
        await LocalDatabaseService.clearProfileCache(_user!.id);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Offline: save image locally for later sync
      debugPrint('Sin internet para subir avatar, guardando offline.');
      try {
        final userId = _user?.id ?? 'guest';
        final appDir = await getApplicationDocumentsDirectory();
        final localPath = '${appDir.path}/avatar_$userId.jpg';
        await imageFile.copy(localPath);
        await LocalDatabaseService.saveProfileCache(
          userId: userId,
          localPath: localPath,
          isSynced: false,
        );
        // Show local file as current avatar in UI
        _user = _user?.copyWith(avatarUrl: 'file://$localPath');
      } catch (cacheError) {
        _errorMessage = e.toString();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called after connectivity sync to refresh the avatar URL from SharedPrefs.
  /// This updates the UI to show the newly uploaded remote photo.
  Future<void> refreshAvatarFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUrl = prefs.getString('user_avatar');
      if (remoteUrl != null && _user != null) {
        _user = _user!.copyWith(avatarUrl: remoteUrl);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> deleteAvatar() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _coreService.updateProfile(clearAvatar: true);
      _user = _user?.copyWith(avatarUrl: updated.avatarUrl, clearAvatar: true);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    await _clearSession();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.deleteAccount();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      // Limpiar sesión local independientemente del resultado si el servidor falla por alguna razón
      _user = null;
      await _clearSession();

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', user.token);
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_nombre', user.nombrePreferido);
    if (user.avatarUrl != null) {
      await prefs.setString('user_avatar', user.avatarUrl!);
    } else {
      await prefs.remove('user_avatar');
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_nombre');
    await prefs.remove('user_avatar');
    await LocalDatabaseService.clearAllData();
  }

  Future<void> loadSavedUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final email = prefs.getString('user_email');
      final nombre = prefs.getString('user_nombre');
      final id = prefs.getString('user_id');
      final avatarUrl = prefs.getString('user_avatar');

      if (token != null && email != null && nombre != null && id != null) {
        // Check for locally cached (offline) avatar
        String? resolvedAvatar = avatarUrl;
        try {
          final cache = await LocalDatabaseService.getProfileCache(id);
          if (cache != null && (cache['is_synced'] as int? ?? 1) == 0) {
            final localPath = cache['local_path'] as String?;
            if (localPath != null && await File(localPath).exists()) {
              resolvedAvatar = 'file://$localPath';
            }
          }
        } catch (_) {}

        _user = User(
          id: id,
          email: email,
          nombrePreferido: nombre,
          token: token,
          avatarUrl: resolvedAvatar,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }
}
