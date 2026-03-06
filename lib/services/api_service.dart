import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base_api_service.dart';
import 'api_client.dart';
import 'local_database_service.dart';
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
        avatarUrl: userData['avatarUrl'] ??
            (userData['avatarKey'] != null
                ? 'https://awos-see.s3.us-east-1.amazonaws.com/${userData['avatarKey']}'
                : null),
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
        avatarUrl: data['avatarUrl'] ??
            (data['avatarKey'] != null
                ? 'https://awos-see.s3.us-east-1.amazonaws.com/${data['avatarKey']}'
                : null),
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
        avatarUrl: userResponse['avatarUrl'] ??
            (userResponse['avatarKey'] != null
                ? 'https://awos-see.s3.us-east-1.amazonaws.com/${userResponse['avatarKey']}'
                : null),
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

      // Response is { capsules: [...] } or directly a list
      List rawList;
      final d = response.data;
      if (d is List) {
        rawList = d;
      } else if (d is Map && d['capsules'] is List) {
        rawList = d['capsules'] as List;
      } else {
        rawList = [];
      }

      // Build capsules, merging local DB content when backend has null
      final List<Capsule> capsules = [];
      for (final json in rawList) {
        // Parse targetEmotions -> List<int>
        final rawEmotions = json['targetEmotions'] as List? ?? [];
        final emotionIds = rawEmotions.map<int>((e) {
          return ((e['emotionId'] ?? e['id']) as num).toInt();
        }).toList();

        // DEBUG: ver todos los campos que devuelve el backend para capsulas de audio
        final contentType = (json['contentType'] ?? 'TEXT').toString();
        if (contentType.toUpperCase() == 'AUDIO') {
          debugPrint('==== CAPSULE AUDIO JSON ====');
          debugPrint('Keys: ${json.keys.toList()}');
          debugPrint('s3Key:       ${json["s3Key"]}');
          debugPrint('audioUrl:    ${json["audioUrl"]}');
          debugPrint('downloadUrl: ${json["downloadUrl"]}');
          debugPrint('signedUrl:   ${json["signedUrl"]}');
          debugPrint('fileUrl:     ${json["fileUrl"]}');
          debugPrint('============================');
        }

        // Prioridad para la URL de audio:
        // 1. Campo con URL firmada que el backend devuelve directamente (si existe)
        // 2. Construir desde s3Key (URL sin firma -> 403 si bucket es privado)
        final rawSignedUrl = json['audioUrl']?.toString() ??
            json['downloadUrl']?.toString() ??
            json['signedUrl']?.toString() ??
            json['fileUrl']?.toString();

        final s3Key = json['s3Key']?.toString();
        String? audioUrl = rawSignedUrl;

        if (audioUrl == null && s3Key != null && s3Key.isNotEmpty) {
          audioUrl =
              (s3Key.startsWith('http://') || s3Key.startsWith('https://'))
                  ? s3Key
                  : 'https://awos-see.s3.us-east-1.amazonaws.com/' + s3Key;
        }

        final backendContent = json['contentText']?.toString();
        final capsuleId = (json['capsuleId'] ?? json['id'] ?? '').toString();

        // Fallback: contenido/audio desde DB local
        String localContent = backendContent ?? '';
        String? localAudio = audioUrl;

        final localRow = await LocalDatabaseService.getCapsuleById(capsuleId);
        if (localRow != null) {
          localContent =
              backendContent ?? (localRow['content'] as String? ?? '');
          final localFilePath = localRow['audio_path'] as String?;

          // Si la URL remota NO tiene firma, preferir el archivo local si existe
          final hasSignedUrl =
              audioUrl != null && audioUrl.contains('X-Amz-Signature');
          if (!hasSignedUrl &&
              localFilePath != null &&
              File(localFilePath).existsSync()) {
            localAudio = localFilePath;
          } else {
            localAudio = audioUrl ?? localFilePath;
          }
        }

        // Construir el mapa de la cápsula para el upsert local
        final capsuleMap = {
          'id': capsuleId,
          'title': json['title'] ?? '',
          'type': contentType,
          'content': localContent,
          'audio_path': localAudio,
          'is_active': (json['isActive'] as bool? ?? true) ? 1 : 0,
          'emotion_ids': emotionIds.join(','),
          'created_at': json['createdAt'] ?? DateTime.now().toIso8601String(),
        };

        // Upsert en local DB (INSERT IGNORE + UPDATE sin tocar is_active)
        // Esto garantiza que updateCapsuleActiveState siempre tenga una fila.
        await LocalDatabaseService.upsertCapsuleFromBackend(capsuleMap);

        // Leer is_active DESDE la DB local (fuente de verdad para el usuario)
        final freshLocalRow =
            await LocalDatabaseService.getCapsuleById(capsuleId);
        final resolvedIsActive = freshLocalRow != null
            ? (freshLocalRow['is_active'] as int? ?? 1) == 1
            : (json['isActive'] as bool? ?? true);

        debugPrint(
            '[getCapsules] $capsuleId → backend=${json["isActive"]} local=$resolvedIsActive');

        capsules.add(Capsule.fromJson({
          'id': capsuleId,
          'title': json['title'] ?? '',
          'type': contentType,
          'content': localContent,
          'audio_path': localAudio,
          'is_active': resolvedIsActive,
          'emotion_ids': emotionIds.join(','),
          'created_at': json['createdAt'],
          'is_synced': true,
        }));
      }

      if (emotionId != null) {
        return capsules.where((c) => c.emotionIds.contains(emotionId)).toList();
      }
      return capsules;
    } on DioException catch (e) {
      debugPrint(
          'ERROR getCapsules: ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('Error al obtener capsulas: ${e.message}');
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
        try {
          await Dio().put(
            uploadUrl,
            data: fileBytes,
            options: Options(
              headers: {
                Headers.contentTypeHeader: 'audio/mp4',
              },
            ),
          );
        } on DioException catch (s3Error) {
          // Detectar el error específico de token expirado en S3
          final rawBody = s3Error.response?.data?.toString() ?? '';
          debugPrint('==== ERROR SUBIDA S3 ====');
          debugPrint('Status: ${s3Error.response?.statusCode}');
          debugPrint('Body: $rawBody');
          debugPrint('=========================');

          if (rawBody.contains('ExpiredToken') || rawBody.contains('expired')) {
            throw Exception(
              'S3_EXPIRED_TOKEN: Las credenciales del servidor para subir '
              'archivos han expirado. Por favor contacta al administrador '
              'para renovarlas e intenta de nuevo.',
            );
          }
          throw Exception(
            'S3_UPLOAD_ERROR: No se pudo subir el audio '
            '(código ${s3Error.response?.statusCode}). '
            'Verifica tu conexión e intenta de nuevo.',
          );
        }
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

      final json = response.data as Map<String, dynamic>;

      // Build audio URL from the s3Key returned by the backend
      final createdS3Key = json['s3Key']?.toString();
      String? createdAudioUrl;
      if (createdS3Key != null && createdS3Key.isNotEmpty) {
        createdAudioUrl = (createdS3Key.startsWith('http://') ||
                createdS3Key.startsWith('https://'))
            ? createdS3Key
            : 'https://awos-see.s3.us-east-1.amazonaws.com/$createdS3Key';
      }

      // Parse emotion ids from targetEmotions if present
      final rawEmotions = json['targetEmotions'] as List? ?? [];
      final parsedIds = rawEmotions.map<int>((e) {
        return ((e['emotionId'] ?? e['id']) as num).toInt();
      }).toList();

      return Capsule.fromJson({
        'id': (json['capsuleId'] ?? json['id'] ?? '').toString(),
        'title': json['title'] ?? '',
        'type': (json['contentType'] ?? type).toString(),
        'content': json['contentText'] ?? '',
        'audio_path': createdAudioUrl,
        'is_active': json['isActive'] ?? true,
        'emotion_ids':
            parsedIds.isNotEmpty ? parsedIds.join(',') : emotionIds.join(','),
        'created_at': json['createdAt'],
        'is_synced': true,
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
    String? contentText,
    List<int>? emotionIds,
    bool? isActive,
    File? audioFile,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (contentText != null) body['contentText'] = contentText;
      if (emotionIds != null) body['emotionIds'] = emotionIds;
      if (isActive != null) body['isActive'] = isActive;

      // Si hay un nuevo archivo de audio, subirlo a S3 primero
      if (audioFile != null) {
        final fileName = audioFile.path.split('/').last;
        final presignRes =
            await _apiClient.coreDio.get('/s3/presigned-url', queryParameters: {
          'filename': fileName,
          'fileType': 'audio/mp4',
        });
        final presignData = presignRes.data as Map<String, dynamic>;
        final uploadUrl = presignData['uploadUrl'] ?? presignData['url'];
        final newS3Key = presignData['s3Key'] ??
            presignData['key'] ??
            presignData['fileUrl'];

        final fileBytes = await audioFile.readAsBytes();
        try {
          await Dio().put(
            uploadUrl,
            data: fileBytes,
            options: Options(
              headers: {Headers.contentTypeHeader: 'audio/mp4'},
            ),
          );
          body['s3Key'] = newS3Key;
          debugPrint('==== AUDIO ACTUALIZADO EN S3: $newS3Key ====');
        } on DioException catch (s3Error) {
          final rawBody = s3Error.response?.data?.toString() ?? '';
          if (rawBody.contains('ExpiredToken') || rawBody.contains('expired')) {
            throw Exception(
              'S3_EXPIRED_TOKEN: Las credenciales del servidor para subir '
              'archivos han expirado.',
            );
          }
          throw Exception(
            'S3_UPLOAD_ERROR: No se pudo subir el audio '
            '(código ${s3Error.response?.statusCode}).',
          );
        }
      }

      final response =
          await _apiClient.coreDio.patch('/capsules/$id', data: body);
      final json = response.data as Map<String, dynamic>;

      // DEBUG: ver qué devuelve el backend en el PATCH
      debugPrint('==== UPDATE CAPSULE RESPONSE ====');
      debugPrint('Keys: ${json.keys.toList()}');
      debugPrint('contentText: ${json["contentText"]}');
      debugPrint('title: ${json["title"]}');
      debugPrint('=================================');

      // Parse targetEmotions
      final rawEmotions = json['targetEmotions'] as List? ?? [];
      final parsedIds = rawEmotions.map<int>((e) {
        return ((e['emotionId'] ?? e['id']) as num).toInt();
      }).toList();

      final s3Key = json['s3Key']?.toString();
      final audioUrl = (s3Key != null && s3Key.isNotEmpty)
          ? 'https://awos-see.s3.us-east-1.amazonaws.com/' + s3Key
          : null;

      // Si el backend no devuelve contentText en la respuesta del PATCH,
      // usamos el valor que enviamos nosotros (ya lo tenemos en 'body').
      final resolvedContent = json['contentText']?.toString() ??
          body['contentText']?.toString() ??
          '';

      return Capsule.fromJson({
        'id': (json['capsuleId'] ?? json['id'] ?? id).toString(),
        'title': json['title']?.toString() ?? body['title']?.toString() ?? '',
        'type': (json['contentType'] ?? 'TEXT').toString(),
        'content': resolvedContent,
        'audio_path': audioUrl,
        'is_active': json['isActive'] ?? true,
        'emotion_ids': parsedIds.isNotEmpty
            ? parsedIds.join(',')
            : (body['emotionIds'] as List?)?.join(',') ?? '',
        'created_at': json['createdAt'],
        'is_synced': true,
      });
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map
          ? e.response?.data['error'] ?? e.message
          : e.message;
      throw Exception('Error al actualizar capsula: $errorMsg');
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

      // Find a capsule to recommend — solo las ACTIVAS
      Capsule? recommendedCapsule;
      try {
        final allCapsules = await getCapsules();
        final activeCapsules = allCapsules.where((c) => c.isActive).toList();
        debugPrint(
            '[Crisis] Cápsulas disponibles: ${allCapsules.length} total, '
            '${activeCapsules.length} activas');
        if (activeCapsules.isNotEmpty && emotionIds.isNotEmpty) {
          for (final eid in emotionIds) {
            final matches = activeCapsules
                .where((c) => c.emotionIds.contains(eid))
                .toList();
            if (matches.isNotEmpty) {
              recommendedCapsule = matches.first;
              break;
            }
          }
          recommendedCapsule ??= activeCapsules.first;
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
    int? finalEvaluationId,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (breathingExerciseCompleted != null) {
        body['breathingExerciseCompleted'] = breathingExerciseCompleted;
      }
      if (usedCapsuleId != null) body['usedCapsuleId'] = usedCapsuleId;
      if (finalEvaluationId != null)
        body['finalEvaluationId'] = finalEvaluationId;

      debugPrint('[Crisis] PATCH /crisis/$id/progress body: $body');
      await _apiClient.coreDio.patch('/crisis/$id/progress', data: body);
      debugPrint(
          '[Crisis] PATCH /progress OK – finalEvaluationId=$finalEvaluationId');

      return Crisis(
        id: id,
        startedAt: DateTime.now(),
        emotion: 'En progreso',
        evaluation: '',
        breathingCompleted: breathingExerciseCompleted ?? false,
      );
    } on DioException catch (e) {
      debugPrint('[Crisis] PATCH /progress ERROR: ${e.response?.data}');
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
    try {
      final response = await _apiClient.coreDio.get('/victories');
      final List<dynamic> rawList = response.data;

      return rawList.map((data) {
        return Victory(
          id: data['victoryId']?.toString() ?? 'temp',
          name: data['victoryType'] != null
              ? data['victoryType']['name']
              : 'Victoria',
          occurredAt:
              DateTime.tryParse(data['occurredAt'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo victorias: $e');
      return [];
    }
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
  Future<User> updateProfile(
      {String? preferredName,
      File? avatarImage,
      bool clearAvatar = false}) async {
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

        try {
          await Dio().put(
            uploadUrl,
            data: fileBytes,
            options: Options(
              headers: {
                Headers.contentTypeHeader: 'image/jpeg',
              },
            ),
          );
        } on DioException catch (s3Error) {
          final rawBody = s3Error.response?.data?.toString() ?? '';
          if (rawBody.contains('ExpiredToken') || rawBody.contains('expired')) {
            throw Exception(
              'S3_EXPIRED_TOKEN: Las credenciales del servidor para subir '
              'archivos han expirado. Por favor avisa al administrador.',
            );
          }
          throw Exception('S3_UPLOAD_ERROR: No se pudo subir el avatar.');
        }
      }

      // 2. Call PUT /users/profile with updated data
      final Map<String, dynamic> body = {};
      if (preferredName != null) body['preferredName'] = preferredName;
      if (avatarKey != null) body['avatarKey'] = avatarKey;
      if (clearAvatar) {
        body['avatarKey'] =
            ''; // Sending empty string to force Prisma to clear it
      }

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

      final String? finalAvatarKey =
          clearAvatar ? null : (data['avatarKey'] ?? avatarKey);
      final updatedAvatarUrl = clearAvatar
          ? null
          : (data['avatarUrl'] ??
              (finalAvatarKey != null
                  ? 'https://awos-see.s3.us-east-1.amazonaws.com/$finalAvatarKey'
                  : null));

      if (clearAvatar) {
        await prefs.remove('user_avatar');
      } else if (updatedAvatarUrl != null) {
        await prefs.setString('user_avatar', updatedAvatarUrl);
      }

      return User(
        id: data['id'] ?? prefs.getString('user_id') ?? '',
        email: data['email'] ?? prefs.getString('user_email') ?? '',
        nombrePreferido: updatedName,
        token: prefs.getString('auth_token') ?? '',
        avatarUrl: clearAvatar
            ? null
            : (updatedAvatarUrl ?? prefs.getString('user_avatar')),
      );
    } on DioException catch (e) {
      String errorMsg = e.message ?? 'Error desconocido';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMsg = e.response!.data['error']?.toString() ??
              e.response!.data.toString();
        } else {
          errorMsg = e.response!.data.toString();
        }
      }
      throw Exception('Error al actualizar perfil: $errorMsg');
    } catch (e) {
      throw Exception('Excepción local: $e');
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
