import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../services/base_api_service.dart';
import '../services/local_database_service.dart';

String _friendlyError(dynamic e) {
  final raw = e.toString().toLowerCase();
  if (raw.contains('socketexception') ||
      raw.contains('connection refused') ||
      raw.contains('network is unreachable') ||
      raw.contains('failed host lookup')) {
    return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
  }
  if (raw.contains('connection timed out') ||
      raw.contains('timeout') ||
      raw.contains('timedout')) {
    return 'El servidor tardó demasiado en responder. Intenta en unos segundos.';
  }
  if (raw.contains('código 2fa') ||
      raw.contains('2fa inválido') ||
      raw.contains('invalid totp') ||
      raw.contains('invalid token')) {
    return 'Código 2FA incorrecto. Verifica tu app de autenticación e intenta de nuevo.';
  }
  if (raw.contains('401') ||
      raw.contains('credenciales') ||
      raw.contains('invalid credentials') ||
      raw.contains('incorrect password') ||
      raw.contains('contraseña')) {
    return 'Correo o contraseña incorrectos. Verifica tus datos.';
  }
  if (raw.contains('409') ||
      raw.contains('already exists') ||
      raw.contains('ya existe') ||
      raw.contains('duplicate') ||
      raw.contains('email already')) {
    return 'Este correo ya está registrado. Intenta iniciar sesión.';
  }
  if (raw.contains('400')) {
    return 'Los datos ingresados no son válidos. Verifica el formulario.';
  }
  if (raw.contains('500') ||
      raw.contains('server error') ||
      raw.contains('internal')) {
    return 'Error en el servidor. Por favor intenta más tarde.';
  }
  if (raw.contains('403')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (raw.contains('404')) {
    return 'No encontramos tu cuenta. Verifica el correo ingresado.';
  }
  return e
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException: ', '')
      .replaceFirst('[connection error]: ', '');
}

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authService;
  final CoreApiService _coreService;
  final _storage = const FlutterSecureStorage();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Estado Temporal 2FA ---
  String? _tempToken;        // Token provisional recibido cuando requires2FA=true
  bool _requires2FA = false; // Flag para iniciar pantalla 2FA desde la UI

  AuthProvider(this._authService, this._coreService);

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  /// true cuando el backend solicitó 2FA — la UI debe navegar a Verify2FAScreen
  bool get requires2FA => _requires2FA;

  // ---------------------------------------------------------------------------
  // LOGIN — Paso A del flujo 2FA
  // ---------------------------------------------------------------------------
  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _requires2FA = false;
    _tempToken = null;
    notifyListeners();

    try {
      final (user, tempToken) = await _authService.login(email, password);

      if (tempToken != null) {
        // Backend requiere 2FA → guardamos temp y señalamos a la UI
        _tempToken = tempToken;
        _requires2FA = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Login normal sin 2FA
      _user = user!;
      await _saveSession(_user!);

      try {
        final fullProfile = await _coreService.getMyProfile();
        _user = fullProfile;
        await _saveSession(_user!);
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // VERIFY 2FA — Paso B del flujo 2FA
  // ---------------------------------------------------------------------------
  Future<void> verify2fa(String code6digits) async {
    if (_tempToken == null) {
      _errorMessage = 'Sesión 2FA expirada. Inicia sesión nuevamente.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.verify2fa(_tempToken!, code6digits);
      _tempToken = null;
      _requires2FA = false;
      await _saveSession(_user!);

      try {
        final fullProfile = await _coreService.getMyProfile();
        _user = fullProfile;
        await _saveSession(_user!);
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // SETUP 2FA - Configuración
  // ---------------------------------------------------------------------------
  Future<Map<String, String>?> setup2FAWorkflow() async {
    if (_user == null) return null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _authService.generate2fa(_user!.id);
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmEnable2FA(String code6digits) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.enable2fa(_user!.id, code6digits);
      if (success) {
        // Enforce state change if needed, but normally authProvider user doesn't track is2FAEnabled, 
        // however we could update local user object if backend supports it.
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancela el flujo 2FA y regresa al estado inicial del login
  void cancel2FA() {
    _tempToken = null;
    _requires2FA = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // REGISTER
  // ---------------------------------------------------------------------------
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

      try {
        final fullProfile = await _coreService.getMyProfile();
        _user = fullProfile;
        await _saveSession(_user!);
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // GOOGLE LOGIN
  // ---------------------------------------------------------------------------
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

      await _coreService.sendTelemetrySnapshot(accessToken);

      _user = await _authService.googleLogin(
        googleUser.email,
        googleUser.displayName ?? 'Usuario de Google',
        accessToken,
      );
      await _saveSession(_user!);

      try {
        final fullProfile = await _coreService.getMyProfile();
        _user = fullProfile;
        await _saveSession(_user!);
      } catch (_) {}

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
      _errorMessage = 'Error en inicio de sesión con Google: ${_friendlyError(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // AVATAR
  // ---------------------------------------------------------------------------
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
      if (_user?.id != null) {
        await LocalDatabaseService.clearProfileCache(_user!.id);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
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
        _user = _user?.copyWith(avatarUrl: 'file://$localPath');
      } catch (_) {
        _errorMessage = e.toString();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refrescamos la URL del avatar desde SharedPreferences tras sync.
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

  // ---------------------------------------------------------------------------
  // LOGOUT & SESSION
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    _user = null;
    _tempToken = null;
    _requires2FA = false;
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
      _user = null;
      _tempToken = null;
      _requires2FA = false;
      await _clearSession();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------
  Future<void> _saveSession(User user, {bool clearAvatar = false}) async {
    // Guardar en SecureStorage (fuente de verdad para el token)
    await _storage.write(key: 'auth_token', value: user.token);
    // Mantener en SharedPreferences para compatibilidad con otros providers
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', user.token);
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_nombre', user.nombrePreferido);
    if (user.avatarUrl != null) {
      await prefs.setString('user_avatar', user.avatarUrl!);
    } else if (clearAvatar) {
      await prefs.remove('user_avatar');
    }
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: 'auth_token');
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
      // Preferir SecureStorage, fallback a SharedPreferences
      final token = await _storage.read(key: 'auth_token')
          ?? prefs.getString('auth_token');
      final email = prefs.getString('user_email');
      final nombre = prefs.getString('user_nombre');
      final id = prefs.getString('user_id');
      final avatarUrl = prefs.getString('user_avatar');

      if (token != null && email != null && nombre != null && id != null) {
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
