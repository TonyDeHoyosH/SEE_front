import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio authDio;
  late Dio coreDio;
  late Dio reportsDio;

  ApiClient() {
    final authBaseUrl =
        dotenv.env['AUTH_BASE_URL'] ?? 'https://auth.kikisait0.me';
    final coreBaseUrl =
        dotenv.env['CORE_BASE_URL'] ?? 'https://apisee.kikisait0.me';
    final reportsBaseUrl =
        dotenv.env['REPORTS_BASE_URL'] ?? 'https://see-awos-report.onrender.com';

    // Dio instance for Auth (login/register) - No token required
    authDio = Dio(BaseOptions(
      baseUrl: authBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

    // Dio instance for Core Operations - Token injected automatically
    coreDio = Dio(BaseOptions(
      baseUrl: coreBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    // Dio instance for Report Service - Token injected automatically
    reportsDio = Dio(BaseOptions(
      baseUrl: reportsBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 15),
    ));

    // Shared auth interceptor for coreDio and reportsDio
    final authInterceptor = InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    );

    coreDio.interceptors.add(authInterceptor);
    reportsDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ));
  }
}
