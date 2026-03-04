import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio authDio;
  late Dio coreDio;
  late Dio reportsDio;

  ApiClient() {
    final authBaseUrl =
        dotenv.env['AUTH_BASE_URL'] ?? 'http://10.0.2.2:3001/api';
    final coreBaseUrl =
        dotenv.env['CORE_BASE_URL'] ?? 'http://10.0.2.2:3002/api';
    final reportsBaseUrl =
        dotenv.env['REPORTS_BASE_URL'] ?? 'http://10.0.2.2:3003/api';

    // Dio instance for Auth (login/register) - No token required
    authDio = Dio(BaseOptions(
      baseUrl: authBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Dio instance for Core Operations - Token injected automatically
    coreDio = Dio(BaseOptions(
      baseUrl: coreBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Dio instance for Report Service - Token injected automatically
    reportsDio = Dio(BaseOptions(
      baseUrl: reportsBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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
