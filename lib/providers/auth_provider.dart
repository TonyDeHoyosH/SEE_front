import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/base_api_service.dart';

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

  Future<void> updateAvatar(File imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _coreService.updateProfile(avatarImage: imageFile);
      _user = _user?.copyWith(avatarUrl: updated.avatarUrl);
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

      // Limpiar sesión local independientemente del resultado si el servidor falla por alguna razón
      _user = null;
      await _clearSession();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', user.token);
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_nombre', user.nombrePreferido);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_nombre');
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

      if (token != null && email != null && nombre != null && id != null) {
        _user = User(
          id: id,
          email: email,
          nombrePreferido: nombre,
          token: token,
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
