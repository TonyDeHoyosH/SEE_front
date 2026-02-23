import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({required this.baseUrl});

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  void _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message']?.toString() ?? message;
    } catch (_) {}

    throw Exception(message);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = await _buildHeaders(requiresAuth: requiresAuth);
    final response = await http.get(uri, headers: headers);
    _handleResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _buildHeaders(requiresAuth: requiresAuth);
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    _handleResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _buildHeaders(requiresAuth: requiresAuth);
    final response = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );
    _handleResponse(response);
    return jsonDecode(response.body);
  }
}
