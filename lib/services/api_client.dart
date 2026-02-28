import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late Dio authDio;
  late Dio coreDio;

  ApiClient() {
    final authBaseUrl =
        dotenv.env['AUTH_BASE_URL'] ?? 'http://10.0.2.2:3001/api/auth';
    final coreBaseUrl =
        dotenv.env['CORE_BASE_URL'] ?? 'http://10.0.2.2:3002/api';

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

    // Interceptor for Authentication
    coreDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Here you could handle 401 globally to log the user out
        return handler.next(e);
      },
    ));
  }
}
