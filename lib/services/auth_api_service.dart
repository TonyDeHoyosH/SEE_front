import '../config/api_config.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'base_api_service.dart';

class HttpAuthApiService implements AuthApiService {
  final ApiClient _client = ApiClient(baseUrl: ApiConfig.authUrl);

  @override
  Future<User> login(String email, String password) async {
    final data = await _client.post(
      '/login',
      {'email': email, 'password': password},
      requiresAuth: false,
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<User> register(
    String email,
    String password,
    String nombrePreferido,
  ) async {
    final data = await _client.post(
      '/register',
      {
        'email': email,
        'password': password,
        'nombre_preferido': nombrePreferido,
      },
      requiresAuth: false,
    );
    return User.fromJson(data as Map<String, dynamic>);
  }
}
