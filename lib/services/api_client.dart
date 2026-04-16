import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  late Dio authDio;
  late Dio coreDio;
  late Dio reportsDio;
  
  static VoidCallback? onUnauthorized;

  ApiClient() {
    final authBaseUrl =
        dotenv.env['AUTH_BASE_URL'] ?? 'https://apisee.kikisait0.me/api/auth';
    final coreBaseUrl =
        dotenv.env['CORE_BASE_URL'] ?? 'https://apisee.kikisait0.me/api';
    final reportsBaseUrl = dotenv.env['REPORTS_BASE_URL'] ??
        'https://apisee.kikisait0.me/api/reports';

    authDio = Dio(BaseOptions(
      baseUrl: authBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    coreDio = Dio(BaseOptions(
      baseUrl: coreBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    reportsDio = Dio(BaseOptions(
      baseUrl: reportsBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    // Shared interactors for checking token and evaluating unauth
    final authInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) async {
        const storage = FlutterSecureStorage();
        // Prefer secure storage for access token
        final token = await storage.read(key: 'auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          debugPrint('==== SESIÓN EXPIRADA O NO AUTORIZADA ====');
          const storage = FlutterSecureStorage();
          await storage.delete(key: 'auth_token');
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
          
          ApiClient.onUnauthorized?.call();
        }
        return handler.next(e);
      },
    );

    authDio.interceptors.add(authInterceptor);
    coreDio.interceptors.add(authInterceptor);
    reportsDio.interceptors.add(authInterceptor);
  }
}
