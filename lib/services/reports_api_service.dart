import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_api_service.dart';
import 'api_client.dart';

// Escribe bytes en isolate para no bloquear el UI thread
Future<void> _writeBytesIsolate(List<dynamic> args) async {
  final path = args[0] as String;
  final bytes = args[1] as List<int>;
  await File(path).writeAsBytes(bytes, flush: true);
}

class HttpReportsApiService implements ReportsApiService {
  @override
  Future<String> getReportUrl() async {
    // 1. Obtener el token directamente (no pasar por el interceptor async
    //    de ApiClient que puede colgarse en SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    // 2. Construir URL base desde el ApiClient pero crear un Dio limpio
    final client = ApiClient();
    final baseUrl = client.reportsDio.options.baseUrl;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final fullUrl = '${cleanBase}clinical';

    debugPrint('[Report] ▶ Iniciando request a: $fullUrl');
    debugPrint('[Report]   Token presente: ${token.isNotEmpty}');

    // 3. Dio limpio sin interceptores async (evita el cuelgue)
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 90),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json, application/pdf, */*',
      },
    ));

    final cancelToken = CancelToken();

    debugPrint('[Report]   Lanzando GET...');

    try {
      final response = await dio
          .get(
        fullUrl,
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.bytes),
      )
          .timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          cancelToken.cancel('timeout');
          debugPrint('[ClinicalReport] ⏱ TIMEOUT disparado');
          throw Exception('TIMEOUT');
        },
      );

      final contentType = response.headers.value('content-type') ?? '';
      final bytes = response.data as List<int>;

      debugPrint('[Report] ✅ status=${response.statusCode} '
          'content-type=$contentType bytes=${bytes.length}');

      // Caso 1: JSON con URL
      if (contentType.contains('application/json')) {
        final jsonStr = utf8.decode(bytes);
        debugPrint('[Report] JSON: $jsonStr');
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final url = data['url'] ??
            data['reportUrl'] ??
            data['pdfUrl'] ??
            data['link'] ??
            data['downloadUrl'];
        if (url != null) return url as String;
        throw Exception('JSON sin campo URL:\n$jsonStr');
      }

      // Caso 2: PDF en bytes → guardar en SEE_reports con nombre único por fecha
      if (bytes.isNotEmpty) {
        final now = DateTime.now();
        final stamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
            '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
        final savePath = await _getSeeReportsPath('SEE_Reporte_$stamp.pdf');
        await compute(_writeBytesIsolate, [savePath, bytes]);
        debugPrint('[Report] 📄 PDF en: $savePath');
        return savePath;
      }

      throw Exception('Respuesta vacía del servidor');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw Exception('TIMEOUT');
      final statusCode = e.response?.statusCode;
      debugPrint('[Report] ❌ DioError $statusCode: ${e.message}');
      if (statusCode == 401) throw Exception('AUTH_ERROR');
      if (statusCode == 404) throw Exception('NOT_FOUND');

      String body = '';
      if (e.response?.data is List<int>) {
        try {
          body = utf8.decode(e.response!.data as List<int>);
        } catch (_) {}
      }
      throw Exception('HTTP_$statusCode: $body');
    } on TimeoutException {
      cancelToken.cancel();
      throw Exception('TIMEOUT');
    }
  }

  /// Devuelve la ruta completa dentro de la carpeta interna SEE_reports de la app.
  Future<String> _getSeeReportsPath(String filename) async {
    final docs = await getApplicationDocumentsDirectory();
    final seeDir = Directory('${docs.path}/SEE_reports');
    if (!seeDir.existsSync()) {
      await seeDir.create(recursive: true);
    }
    return '${seeDir.path}/$filename';
  }
}
