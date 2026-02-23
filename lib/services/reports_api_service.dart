import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'base_api_service.dart';

class HttpReportsApiService implements ReportsApiService {
  @override
  Future<String> getClinicalReportUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final uri = Uri.parse('${ApiConfig.reportsUrl}/api/reports/clinical');

    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Error al obtener reporte: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['url'] as String;
  }
}
