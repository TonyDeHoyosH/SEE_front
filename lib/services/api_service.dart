import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base_api_service.dart';
import 'api_client.dart';
import 'reports_api_service.dart';

import '../models/user.dart';
import '../models/emotion.dart';
import '../models/victory_type.dart';
import '../models/evaluation.dart';
import '../models/capsule.dart';
import '../models/crisis.dart';
import '../models/victory.dart';
import '../models/dashboard_data.dart';

/// Real API implementation utilizing Dio ApiClient connecting to SEE_AWOS backend.
class ApiServiceImpl
    implements AuthApiService, CoreApiService, ReportsApiService {
  final ApiClient _apiClient = ApiClient();

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------
  @override
  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.authDio.post('/login', data: {
        'email': email,
        'password': password,
      });

      // 🐛 DEBUG: ver exactamente qué devuelve el backend
      debugPrint('==== RESPUESTA LOGIN BACKEND ====');
      debugPrint('Type: ${response.data.runtimeType}');
      debugPrint('Data: ${response.data}');
      debugPrint('=================================');

      final data = response.data;

      // Handle both flat response { token, user } and nested formats
      String token = '';
      Map<String, dynamic> userData = {};

      if (data is Map<String, dynamic>) {
        token = data['token'] ?? data['accessToken'] ?? '';
        final rawUser = data['user'] ?? data['userData'] ?? data;
        if (rawUser is Map<String, dynamic>) {
          userData = rawUser;
        }
      } else {
        throw Exception(
            'Formato de respuesta inesperado del servidor: ${data.runtimeType}');
      }

      final user = User(
        id: (userData['id'] ?? userData['userId'] ?? '').toString(),
        email: userData['email'] ?? email,
        nombrePreferido:
            userData['name'] ?? userData['preferredName'] ?? 'Usuario',
        token: token,
      );

      // Save to local storage automatically
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_nombre', user.nombrePreferido);

      return user;
    } on DioException catch (e) {
      debugPrint('==== ERROR LOGIN ====');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Data: ${e.response?.data}');
      debugPrint('====================');
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['error'] ?? errorData['message'] ?? e.message)
          : e.message;
      throw Exception('Error en login: $errorMsg');
    }
  }

  @override
  Future<User> register(
    String email,
    String password,
    String nombrePreferido,
  ) async {
    try {
      final response = await _apiClient.authDio.post('/register', data: {
        'email': email,
        'password': password,
        'preferredName': nombrePreferido,
      });

      // Backend returns: { token, userId }  (no "user" object)
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userId = (data['userId'] ?? '').toString();

      final user = User(
        id: userId,
        email: email,
        nombrePreferido: nombrePreferido,
        token: token,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_nombre', user.nombrePreferido);

      return user;
    } on DioException catch (e) {
      debugPrint('==== ERROR REGISTER ====');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Data: ${e.response?.data}');
      debugPrint('=======================');
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['error'] ?? errorData['message'] ?? e.message)
          : e.message;
      throw Exception('Error en registro: $errorMsg');
    }
  }

  @override
  Future<User> googleLogin(
    String email,
    String nombrePreferido,
    String? googleAccessToken,
  ) async {
    try {
      final response = await _apiClient.authDio.post('/googleLogin', data: {
        'email': email,
        'preferredName': nombrePreferido,
        'googleToken': googleAccessToken,
      });

      final data = response.data;
      final token = data['token'];
      final userResponse = data['user'];

      final appUser = User(
        id: userResponse['id'],
        email: userResponse['email'],
        nombrePreferido: userResponse['name'],
        token: token,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_email', appUser.email);
      await prefs.setString('user_nombre', appUser.nombrePreferido);

      return appUser;
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ??
          'Error de red durante Google Login: ${e.message}');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _apiClient.coreDio.delete('/users/profile');
    } catch (e) {
      debugPrint('Error en deleteAccount: $e');
      rethrow; // Lanzar para que el Frontend lo sepa y de todas formas cierre sesión
    }
  }

  // ---------------------------------------------------------------------------
  // CORE - DASHBOARD & METRICS
  // ---------------------------------------------------------------------------
  @override
  Future<DashboardData> getDashboard() async {
    try {
      final response = await _apiClient.coreDio.get('/dashboard/summary');
      final metrics = response.data['metrics'];

      // Mapeamos temporalmente según el DashboardData mock hasta que haya endpoint idéntico.
      return DashboardData.fromJson({
        'weekly_victories_count': metrics['totalVictories'] ?? 0,
        // El backend de summary no entrega "last_crisis" por ahora enviaremos null o un mock para que no rompa la UI
        // 'last_crisis': ...
      });
    } on DioException {
      print('Dashboard error: \$e');
      // Fallback a un mock vacío si falla o no coinciden tipos para evitar Pantalla Roja
      return DashboardData.fromJson({'weekly_victories_count': 0});
    }
  }

  // ---------------------------------------------------------------------------
  // CORE - CATALOGS (Mocked temporalmente ya que backend no provee endpoints GET /catalogs)
  // ---------------------------------------------------------------------------
  @override
  Future<Map<String, dynamic>> getCatalogs() async {
    final emotions = await getEmotions();
    final victoryTypes = await getVictoryTypes();
    final evaluations = await getEvaluations();

    return {
      'emotions': emotions.map((e) => e.toJson()).toList(),
      'victory_types': victoryTypes.map((v) => v.toJson()).toList(),
      'evaluations': evaluations.map((e) => e.toJson()).toList(),
    };
  }

  @override
  Future<List<Emotion>> getEmotions() async {
    try {
      final response = await _apiClient.coreDio.get('/catalogs/emotions');
      if (response.data is List) {
        return (response.data as List).map((e) => Emotion.fromJson(e)).toList();
      }
      return _mockEmotions();
    } catch (_) {
      return _mockEmotions();
    }
  }

  List<Emotion> _mockEmotions() => [
        Emotion(id: 1, name: "Miedo"),
        Emotion(id: 2, name: "Tristeza"),
        Emotion(id: 3, name: "Ira"),
        Emotion(id: 4, name: "Ansiedad"),
        Emotion(id: 5, name: "Vacío"),
      ];

  @override
  Future<List<VictoryType>> getVictoryTypes() async {
    try {
      final response = await _apiClient.coreDio.get('/victories/types');
      if (response.data is List) {
        return (response.data as List)
            .map((v) => VictoryType.fromJson(v))
            .toList();
      }
      return _mockVictoryTypes();
    } catch (_) {
      return _mockVictoryTypes();
    }
  }

  List<VictoryType> _mockVictoryTypes() => [
        VictoryType(id: 1, name: "Higiene"),
        VictoryType(id: 2, name: "No Consumo"),
        VictoryType(id: 3, name: "Ejercicio"),
        VictoryType(id: 4, name: "Alimentación"),
      ];

  @override
  Future<List<Evaluation>> getEvaluations() async {
    // MOCK: Backend aún no lo implementa.
    return [
      Evaluation(id: 1, description: "Mejor"),
      Evaluation(id: 2, description: "Igual"),
      Evaluation(id: 3, description: "Peor"),
    ];
  }

  // ---------------------------------------------------------------------------
  // CORE - CAPSULES
  // ---------------------------------------------------------------------------
  @override
  Future<List<Capsule>> getCapsules({int? emotionId}) async {
    try {
      final response = await _apiClient.coreDio.get('/capsules');
      final data = response.data['capsules'] as List;

      var capsules = data.map((json) {
        // Transform incoming Prisma JSON to match what Capsule.fromJson expects
        return Capsule.fromJson({
          ...json,
          'is_active': json['isActive'] ?? true,
          'content': json['contentText'] ?? '',
        });
      }).toList();

      if (emotionId != null) {
        capsules =
            capsules.where((c) => c.emotionIds.contains(emotionId)).toList();
      }

      return capsules;
    } on DioException catch (e) {
      throw Exception('Error al obtener cápsulas: ${e.message}');
    }
  }

  @override
  Future<Capsule> getCapsuleById(String id) async {
    // No hay GET /capsules/:id aún, buscamos de la lista
    final capsules = await getCapsules();
    return capsules.firstWhere((c) => c.id == id,
        orElse: () => throw Exception('Cápsula no encontrada'));
  }

  @override
  Future<Capsule> createCapsule({
    required String title,
    required String type, // 'TEXT' or 'AUDIO'
    String? contentText,
    File? audioFile,
    required List<int> emotionIds,
  }) async {
    try {
      String? s3Key;

      if (type == 'AUDIO' && audioFile != null) {
        // PASO 1: Obtener URL pre-firmada desde el backend
        final fileName = audioFile.path.split('/').last;
        final presignRes =
            await _apiClient.coreDio.get('/s3/presigned-url', queryParameters: {
          'filename': fileName,
          'fileType': 'audio/mp4',
        });

        debugPrint('==== PRESIGNED URL RESPONSE ====');
        debugPrint('Type: ${presignRes.data.runtimeType}');
        debugPrint('Data: ${presignRes.data}');
        debugPrint('================================');

        final presignData = presignRes.data as Map<String, dynamic>;
        final uploadUrl = presignData['uploadUrl'] ?? presignData['url'];
        // Jaitovich devuelve fileUrl (URL limpia) y uploadUrl (pre-signed S3)
        s3Key = presignData['fileUrl'] ??
            presignData['key'] ??
            presignData['s3Key'];

        // PASO 2: Subir directamente a S3 con PUT (no POST)
        final fileBytes = await audioFile.readAsBytes();
        await Dio().put(
          uploadUrl,
          data: fileBytes,
          options: Options(
            headers: {
              // Content-Type DEBE coincidir con el que se pidió arriba
              Headers.contentTypeHeader: 'audio/mp4',
            },
          ),
        );
      }

      // 3. Crear la cápsula en el Backend
      final Map<String, dynamic> body = {
        'title': title,
        'contentType': type,
        'emotionIds': emotionIds,
      };

      if (type == 'TEXT') {
        body['contentText'] = contentText;
      } else if (type == 'AUDIO') {
        body['s3Key'] = s3Key;
      }

      debugPrint('==== ENVIANDO PETICIÓN CREATE CAPSULE ====');
      debugPrint('Body: $body');
      debugPrint('==========================================');

      final response = await _apiClient.coreDio.post('/capsules', data: body);

      final json = response.data;
      return Capsule.fromJson({
        ...json,
        'is_active': json['isActive'] ?? true,
        'content': json['contentText'] ?? '',
      });
    } on DioException catch (e) {
      final rawData = e.response?.data;
      String errorMsg;
      String details;

      if (rawData is Map<String, dynamic>) {
        errorMsg = rawData['error'] ??
            rawData['message'] ??
            e.message ??
            'Error desconocido';
        details = rawData['details']?.toString() ?? 'Sin detalles adicionales';
      } else {
        errorMsg = e.message ?? 'Error desconocido';
        details = rawData?.toString() ?? 'Sin detalles adicionales';
      }

      debugPrint('==== ERROR EN CREATE CAPSULE ====');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Error Backend: $errorMsg');
      debugPrint('Detalles: $details');
      debugPrint('=================================');

      throw Exception('Error al crear cápsula: $errorMsg\nDetalles: $details');
    }
  }

  @override
  Future<Capsule> updateCapsule(
    String id, {
    String? title,
    List<int>? emotionIds,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (emotionIds != null) body['emotionIds'] = emotionIds;

      final response =
          await _apiClient.coreDio.patch('/capsules/$id', data: body);
      final json = response.data;
      return Capsule.fromJson({
        ...json,
        'is_active': json['isActive'] ?? true,
        'content': json['contentText'] ?? '',
      });
    } on DioException catch (e) {
      final errorMsg = e.response?.data['error'] ?? e.message;
      throw Exception('Error al actualizar cápsula: $errorMsg');
    }
  }

  @override
  Future<void> deleteCapsule(String id) async {
    try {
      await _apiClient.coreDio.delete('/capsules/$id');
    } on DioException catch (e) {
      final errorMsg = e.response?.data['error'] ?? e.message;
      throw Exception('Error al eliminar cápsula: $errorMsg');
    }
  }

  // ---------------------------------------------------------------------------
  // CORE - CRISIS
  // ---------------------------------------------------------------------------
  @override
  Future<Map<String, dynamic>> createCrisis(
      List<int> emotionIds, int intensityLevel) async {
    try {
      final response = await _apiClient.coreDio.post('/crisis', data: {
        'emotionIds': emotionIds,
        'intensity': intensityLevel,
      });

      final crisisId = response.data['crisisId'];
      final sessionJson = response.data['session'];

      // Construct locally matching models
      final crisis = Crisis(
        id: crisisId,
        startedAt:
            DateTime.tryParse(sessionJson['startedAt']) ?? DateTime.now(),
        emotion: 'Varias emociones',
        emotionIds: emotionIds,
        intensity: intensityLevel,
        evaluation: '',
        breathingCompleted: false,
      );

      // Find a capsule to recommend
      Capsule? recommendedCapsule;
      try {
        final allCapsules = await getCapsules();
        if (allCapsules.isNotEmpty && emotionIds.isNotEmpty) {
          for (final eid in emotionIds) {
            final matches =
                allCapsules.where((c) => c.emotionIds.contains(eid)).toList();
            if (matches.isNotEmpty) {
              recommendedCapsule = matches.first;
              break;
            }
          }
          recommendedCapsule ??= allCapsules.first;
        }
      } catch (_) {}

      return {
        'crisis': crisis,
        'capsule': recommendedCapsule,
      };
    } on DioException catch (e) {
      final errorMsg = e.response?.data['error'] ?? e.message;
      throw Exception('Error al iniciar crisis: $errorMsg');
    }
  }

  @override
  Future<Crisis> updateCrisisProgress(
    String id, {
    bool? breathingExerciseCompleted,
    String? usedCapsuleId,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (breathingExerciseCompleted != null) {
        body['breathingExerciseCompleted'] = breathingExerciseCompleted;
      }
      if (usedCapsuleId != null) body['usedCapsuleId'] = usedCapsuleId;

      await _apiClient.coreDio.patch('/crisis/$id/progress', data: body);

      return Crisis(
        id: id,
        startedAt: DateTime.now(),
        emotion: 'En progreso',
        evaluation: '',
        breathingCompleted: breathingExerciseCompleted ?? false,
      );
    } on DioException catch (e) {
      print('Error actualizando progreso de crisis: ${e.response?.data}');
      throw Exception('Error al actualizar el progreso de la crisis.');
    }
  }

  @override
  Future<Crisis> saveCrisisReflection(
    String id, {
    String? triggerDesc,
    String? location,
    String? companion,
    String? substanceUse,
    String? notes,
    int? finalEvaluationId,
  }) async {
    try {
      final response = await _apiClient.coreDio.put(
        '/crisis/$id/reflection',
        data: {
          if (triggerDesc != null) 'triggerDesc': triggerDesc,
          if (location != null) 'location': location,
          if (companion != null) 'companion': companion,
          if (substanceUse != null) 'substanceUse': substanceUse,
          if (notes != null) 'notes': notes,
          if (finalEvaluationId != null) 'finalEvaluationId': finalEvaluationId,
        },
      );

      final data = response.data['crisis'] ?? response.data;
      return Crisis(
        id: data['crisisId'] ?? id,
        startedAt: DateTime.tryParse(data['startedAt'] ?? '') ?? DateTime.now(),
        emotion: 'Completada',
        evaluation: notes ?? '',
        breathingCompleted: data['breathingExerciseCompleted'] ?? false,
      );
    } on DioException catch (e) {
      print('Error guardando reflexión: ${e.response?.data}');
      throw Exception('Error al guardar la reflexión de la crisis.');
    }
  }

  @override
  Future<List<Crisis>> getMyCrises() async {
    // MOCKED: Backend missing GET /api/crisis mapping
    try {
      // Si no existe, usamos mock temporal
      return [
        Crisis(
            id: 'mock-1',
            startedAt: DateTime.now().subtract(const Duration(days: 1)),
            emotion: 'Ansiedad',
            evaluation: 'Mejor',
            breathingCompleted: true),
      ];
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // CORE - VICTORIES
  // ---------------------------------------------------------------------------
  @override
  Future<Victory> createVictory(String name, DateTime occurredAt) async {
    try {
      final response = await _apiClient.coreDio.post('/victories', data: {
        'newCustomVictoryName': name,
      });
      return Victory(
        id: response.data['insertedIds']?.first?.toString() ?? 'temp',
        name: name,
        occurredAt: occurredAt,
      );
    } catch (_) {
      // Fallback
      return Victory(id: 'mock-v-1', name: name, occurredAt: occurredAt);
    }
  }

  @override
  Future<List<Victory>> getMyVictories() async {
    // Backend missing simple GET /victories right now.
    return [];
  }

  @override
  Future<void> deleteVictoryType(int id) async {
    try {
      await _apiClient.coreDio.delete('/victories/$id');
    } catch (e) {
      debugPrint('Error eliminando victoria en backend: $e');
      // No rethrow para no romper la app si el backend falla o no existe el endpoint aún
    }
  }

  // ---------------------------------------------------------------------------
  // PROFILE & REPORTS
  // ---------------------------------------------------------------------------
  @override
  Future<User> updateProfile({String? preferredName, File? avatarImage}) async {
    try {
      String? avatarKey;

      // 1. If there's an avatar image, upload it to S3 first
      if (avatarImage != null) {
        final fileName = avatarImage.path.split('/').last;
        final presignRes =
            await _apiClient.coreDio.get('/s3/presigned-url', queryParameters: {
          'filename': fileName,
          'fileType': 'image/jpeg',
        });

        final uploadUrl = presignRes.data['uploadUrl'];
        avatarKey = presignRes.data['key'];

        final fileBytes = await avatarImage.readAsBytes();
        await Dio().put(
          uploadUrl,
          data: fileBytes,
          options: Options(
            headers: {Headers.contentTypeHeader: 'image/jpeg'},
          ),
        );
      }

      // 2. Call PUT /users/profile with updated data
      final Map<String, dynamic> body = {};
      if (preferredName != null) body['preferredName'] = preferredName;
      if (avatarKey != null) body['avatarKey'] = avatarKey;

      final response =
          await _apiClient.coreDio.put('/users/profile', data: body);

      final data = response.data['user'] ?? response.data;
      final prefs = await SharedPreferences.getInstance();
      final updatedName = data['preferredName'] ??
          data['name'] ??
          preferredName ??
          prefs.getString('user_nombre') ??
          'Usuario';

      await prefs.setString('user_nombre', updatedName);

      return User(
        id: data['id'] ?? prefs.getString('user_id') ?? '',
        email: data['email'] ?? prefs.getString('user_email') ?? '',
        nombrePreferido: updatedName,
        token: prefs.getString('auth_token') ?? '',
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ?? e.message;
      throw Exception('Error al actualizar perfil: $errorMsg');
    }
  }

  @override
  Future<String> getClinicalReportUrl() async {
    final reportsService = HttpReportsApiService();
    return await reportsService.getClinicalReportUrl();
  }

  @override
  Future<void> sendTelemetrySnapshot(String googleAccessToken) async {
    try {
      await _apiClient.coreDio.post('/telemetry/snapshot', data: {
        'googleAccessToken': googleAccessToken,
      });
    } on DioException catch (e) {
      final errorMsg = e.response?.data['error'] ?? e.message;
      throw Exception('Error enviando snapshot de telemetría: $errorMsg');
    }
  }
}
