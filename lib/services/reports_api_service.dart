import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'base_api_service.dart';
import 'api_client.dart';

class HttpReportsApiService implements ReportsApiService {
  final ApiClient _apiClient = ApiClient();

  /// Fetches the clinical PDF report from the backend.
  ///
  /// The backend `GET /api/reports/clinical` can return:
  ///   - A JSON body with a `{ "url": "..." }` field (presigned S3 URL), OR
  ///   - Raw PDF bytes (application/pdf).
  ///
  /// This method returns the URL string. If the backend returns raw bytes,
  /// we save them locally and return the file path (not yet implemented).
  @override
  Future<String> getClinicalReportUrl() async {
    try {
      final response = await _apiClient.reportsDio.get(
        '/reports/clinical',
        options: Options(
          headers: {'Accept': 'application/json, application/pdf'},
          responseType: ResponseType.json,
        ),
      );

      final data = response.data;

      // Case 1: Backend returns { url: "https://..." }
      if (data is Map<String, dynamic> && data.containsKey('url')) {
        return data['url'] as String;
      }

      // Case 2: Backend returns { reportUrl: "https://..." }
      if (data is Map<String, dynamic> && data.containsKey('reportUrl')) {
        return data['reportUrl'] as String;
      }

      throw Exception(
          'Formato de respuesta desconocido del servicio de reportes.');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorMsg = e.response?.data?['error'] ?? e.message;
      debugPrint('Error obteniendo reporte clínico ($statusCode): $errorMsg');
      throw Exception('Error al obtener el reporte clínico: $errorMsg');
    }
  }
}
