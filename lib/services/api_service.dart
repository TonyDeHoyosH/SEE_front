import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

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
  final _storage = const FlutterSecureStorage();

  String? _resolveMediaUrl(String? path, {bool isAudio = false}) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;

    // Cloudinary Base URL depending on resource type
    final resourceType = isAudio ? 'video' : 'image';
    return 'https://res.cloudinary.com/dob7ey43j/$resourceType/upload/$path';
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------
  @override
  Future<(User?, String?)> login(String email, String password) async {
    try {
      final response = await _apiClient.authDio.post('/login', data: {
        'email': email,
        'password': password,
      });

      debugPrint('==== RESPUESTA LOGIN BACKEND ====');
      debugPrint('Type: ${response.data.runtimeType}');
      debugPrint('Data: ${response.data}');
      debugPrint('=================================');

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Formato de respuesta inesperado: ${data.runtimeType}');
      }

      // ── Detectar flujo 2FA ────────────────────────────────────────────────
      if (data['requires2FA'] == true) {
        final tempToken = data['tempToken'] as String?;
        if (tempToken == null || tempToken.isEmpty) {
          throw Exception('El servidor solicitó 2FA pero no envió tempToken.');
        }
        debugPrint('[2FA] requires2FA=true → redirigiendo a verificación');
        return (null, tempToken);
      }

      // ── Login normal sin 2FA ──────────────────────────────────────────────
      final token = data['token'] ?? data['accessToken'] ?? '';
      final rawUser = data['user'] ?? data['userData'] ?? data;
      final userData =
          rawUser is Map<String, dynamic> ? rawUser : <String, dynamic>{};

      final user = User(
        id: (userData['id'] ?? userData['userId'] ?? '').toString(),
        email: userData['email'] ?? email,
        nombrePreferido:
            userData['name'] ?? userData['preferredName'] ?? 'Usuario',
        token: token,
        avatarUrl: userData['avatarUrl'] ??
            _resolveMediaUrl(userData['avatarKey']?.toString()),
      );

      await _storage.write(key: 'auth_token', value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_nombre', user.nombrePreferido);

      return (user, null);
    } on DioException catch (e) {
      debugPrint('==== ERROR LOGIN ==== status: ${e.response?.statusCode}');
      debugPrint('Data: ${e.response?.data}');
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['error'] ?? errorData['message'] ?? e.message)
          : e.message;
      throw Exception('Error en login: $errorMsg');
    }
  }

  @override
  Future<User> verify2fa(String tempToken, String token2FA) async {
    try {
      final response =
          await _apiClient.authDio.post('/login/verify-2fa', data: {
        'tempToken': tempToken,
        'token2FA': token2FA,
      });

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] ?? data['accessToken'] ?? '';
      final rawUser = data['user'] ?? data['userData'] ?? data;
      final userData =
          rawUser is Map<String, dynamic> ? rawUser : <String, dynamic>{};

      final user = User(
        id: (userData['id'] ?? userData['userId'] ?? '').toString(),
        email: userData['email'] ?? '',
        nombrePreferido:
            userData['name'] ?? userData['preferredName'] ?? 'Usuario',
        token: token,
        avatarUrl: userData['avatarUrl'] ??
            _resolveMediaUrl(userData['avatarKey']?.toString()),
      );

      await _storage.write(key: 'auth_token', value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_nombre', user.nombrePreferido);

      return user;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['error'] ?? errorData['message'] ?? e.message)
          : e.message;
      throw Exception('Código 2FA inválido: $errorMsg');
    }
  }

  @override
  Future<Map<String, String>> generate2fa(String userId) async {
    try {
      debugPrint('==== 2FA GENERATE ==== userId enviado: $userId');
      final response =
          await _apiClient.authDio.post('/2fa/generate', data: {
        'userId': userId,
      });
      debugPrint('==== 2FA GENERATE RESPONSE: ${response.data}');
      final data = response.data as Map<String, dynamic>;

      return {
        'qrCodeUrl': data['qrCodeUrl'] ?? data['otpauth_url'] ?? '',
        'secret': data['secret'] ?? '',
      };
    } on DioException catch (e) {
      debugPrint('==== 2FA GENERATE ERROR ==== status: ${e.response?.statusCode}');
      debugPrint('Body: ${e.response?.data}');
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['error'] ?? errorData['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
    }
  }

  @override
  Future<bool> enable2fa(String userId, String token) async {
    try {
      debugPrint('==== 2FA ENABLE ==== userId: $userId, token: $token');
      await _apiClient.authDio.post('/2fa/enable', data: {
        'userId': userId,
        'token': token,
      });
      return true;
    } on DioException catch (e) {
      debugPrint('==== 2FA ENABLE ERROR ==== status: ${e.response?.statusCode}');
      debugPrint('Body: ${e.response?.data}');
      final errorData = e.response?.data;
      final errorMsg = errorData is Map
          ? (errorData['error'] ?? errorData['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
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

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userId = (data['userId'] ?? '').toString();

      final user = User(
        id: userId,
        email: email,
        nombrePreferido: nombrePreferido,
        token: token,
        avatarUrl: data['avatarUrl'] ??
            _resolveMediaUrl(data['avatarKey']?.toString()),
      );

      await _storage.write(key: 'auth_token', value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_nombre', user.nombrePreferido);

      return user;
    } on DioException catch (e) {
      debugPrint('==== ERROR REGISTER ==== status: ${e.response?.statusCode}');
      debugPrint('Data: ${e.response?.data}');
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
      final token = data['token'] ?? '';
      final userResponse = data['user'] ?? data;

      final appUser = User(
        id: (userResponse['id'] ?? userResponse['userId'] ?? '').toString(),
        email: userResponse['email'] ?? email,
        nombrePreferido:
            userResponse['name'] ?? userResponse['preferredName'] ?? nombrePreferido,
        token: token,
        avatarUrl: userResponse['avatarUrl'] ??
            _resolveMediaUrl(userResponse['avatarKey']?.toString()),
      );

      await _storage.write(key: 'auth_token', value: token);
      final prefs = await SharedPreferences.getInstance();
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
      rethrow;
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
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _apiClient.coreDio.get('/catalogs/emotions');
      if (response.data is List) {
        final list = response.data as List;
        await prefs.setString('cached_emotions', jsonEncode(list));
        return list.map((e) => Emotion.fromJson(e)).toList();
      }
      return _fallbackEmotions(prefs);
    } catch (_) {
      return _fallbackEmotions(prefs);
    }
  }

  List<Emotion> _fallbackEmotions(SharedPreferences prefs) {
    final cached = prefs.getString('cached_emotions');
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        return list
            .map((e) => Emotion.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error decodificando emociones cacheadas: $e');
      }
    }
    return _mockEmotions();
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
          audioUrl = _resolveMediaUrl(s3Key, isAudio: true);
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

        // Opsert en local DB (INSERT IGNORE + UPDATE sin tocar is_active)
        await LocalDatabaseService.upsertCapsuleFromBackend(capsuleMap);

        // Download audio file to local storage if it's an audio capsule and has a valid URL
        if (contentType.toUpperCase() == 'AUDIO' &&
            audioUrl != null &&
            localAudio == audioUrl) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final localPath = '${appDir.path}/capsule_$capsuleId.mp4';
            final localFile = File(localPath);
            if (!await localFile.exists()) {
              debugPrint(
                  'Downloading audio for capsule $capsuleId to $localPath');
              await Dio().download(audioUrl, localPath);
            }
            // Update localAudio and map
            localAudio = localPath;
            capsuleMap['audio_path'] = localPath;
            await LocalDatabaseService.upsertCapsuleFromBackend(
                capsuleMap); // update audio_path
          } catch (e) {
            debugPrint('Error downloading audio for capsule $capsuleId: $e');
          }
        }

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

      // Deduplicate by ID properly
      final Map<String, Capsule> uniqueCapsules = {};
      for (final c in capsules) {
        uniqueCapsules[c.id] = c;
      }
      final dedupedCapsules = uniqueCapsules.values.toList();

      if (emotionId != null) {
        return dedupedCapsules
            .where((c) => c.emotionIds.contains(emotionId))
            .toList();
      }
      return dedupedCapsules;
    } catch (e) {
      debugPrint('getCapsules error, cargando desde local DB: $e');

      final localRows = await LocalDatabaseService.getAllCapsules();
      final Map<String, Capsule> localById = {};
      for (final row in localRows) {
        final c = Capsule.fromJson({
          'id': row['id'],
          'title': row['title'],
          'type': row['type'],
          'content': row['content'],
          'audio_path': row['audio_path'],
          'is_active': row['is_active'] == 1,
          'emotion_ids': row['emotion_ids'],
          'created_at': row['created_at'],
          'is_synced': row['is_synced'] == 1,
        });
        localById[c.id] = c;
      }
      final offlineCapsules = localById.values.toList();

      if (emotionId != null) {
        return offlineCapsules
            .where((c) => c.emotionIds.contains(emotionId))
            .toList();
      }
      return offlineCapsules;
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
            await _apiClient.coreDio.get('/media/upload-url', queryParameters: {
          'filename': fileName,
          'fileType': 'audio/mp4',
        });

        debugPrint('==== PRESIGNED URL RESPONSE ====');
        debugPrint('Type: ${presignRes.data.runtimeType}');
        debugPrint('Data: ${presignRes.data}');
        debugPrint('================================');

        final presignData = presignRes.data as Map<String, dynamic>;
        String uploadUrl = presignData['uploadUrl'] ?? presignData['url'];

        // CORRECCIÓN: Si el backend por defecto devuelve el endpoint de imágenes,
        // Cloudinary rechazará el audio. Forzamos el endpoint a 'video' (usado para audio).
        if (uploadUrl.contains('/image/upload')) {
          uploadUrl = uploadUrl.replaceAll('/image/upload', '/video/upload');
        }

        // Jaitovich devuelve fileUrl (URL limpia) y uploadUrl (pre-signed S3)
        s3Key = presignData['fileUrl'] ??
            presignData['key'] ??
            presignData['s3Key'];

        // PASO 2: Subir directamente a Cloudinary con POST
        try {
          final fields = <String, dynamic>{};
          final allowedList = [
            'api_key',
            'timestamp',
            'signature',
            'folder',
            'public_id',
            'upload_preset'
          ];
          presignData.forEach((k, v) {
            final normalizedKey = k == 'apiKey' ? 'api_key' : k;
            if (allowedList.contains(normalizedKey)) {
              fields[normalizedKey] = v;
            }
          });

          if (presignData['key'] != null) {
            fields['public_id'] = presignData['key'];
          }

          fields['file'] =
              await MultipartFile.fromFile(audioFile.path, filename: fileName);

          final formData = FormData.fromMap(fields);

          final uploadDio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 30),
          ));
          await uploadDio.post(
            uploadUrl,
            data: formData,
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
      String? createdAudioUrl =
          _resolveMediaUrl(createdS3Key, isAudio: type == 'AUDIO');

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
            await _apiClient.coreDio.get('/media/upload-url', queryParameters: {
          'filename': fileName,
          'fileType': 'audio/mp4',
        });
        final presignData = presignRes.data as Map<String, dynamic>;
        String uploadUrl = presignData['uploadUrl'] ?? presignData['url'];

        // CORRECCIÓN: Forzar el endpoint a 'video' (audio) para Cloudinary
        if (uploadUrl.contains('/image/upload')) {
          uploadUrl = uploadUrl.replaceAll('/image/upload', '/video/upload');
        }

        final newS3Key = presignData['fileUrl'] ??
            presignData['key'] ??
            presignData['s3Key'];

        try {
          final fields = <String, dynamic>{};
          final allowedList = [
            'api_key',
            'timestamp',
            'signature',
            'folder',
            'public_id',
            'upload_preset'
          ];
          presignData.forEach((k, v) {
            final normalizedKey = k == 'apiKey' ? 'api_key' : k;
            if (allowedList.contains(normalizedKey)) {
              fields[normalizedKey] = v;
            }
          });

          if (presignData['key'] != null) {
            fields['public_id'] = presignData['key'];
          }

          fields['file'] =
              await MultipartFile.fromFile(audioFile.path, filename: fileName);

          final formData = FormData.fromMap(fields);

          final uploadDio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 30),
          ));
          await uploadDio.post(
            uploadUrl,
            data: formData,
          );
          body['s3Key'] = newS3Key;
          debugPrint('==== AUDIO ACTUALIZADO EN CLOUDINARY: $newS3Key ====');
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

      if (isActive == false) {
        try {
          final localRow = await LocalDatabaseService.getCapsuleById(id);
          if (localRow != null) {
            final existingAudio = localRow['audio_path'] as String?;
            if (existingAudio != null && !existingAudio.startsWith('http')) {
              final file = File(existingAudio);
              if (await file.exists()) {
                await file.delete();
                debugPrint('Audio local eliminado al desactivar cápsula.');
              }
            }
          }
        } catch (e) {
          debugPrint(
              'Error eliminando audio local tras desactivar cápsula: $e');
        }
      }

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
      final audioUrl = _resolveMediaUrl(s3Key, isAudio: true);

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

      // Cleanup offline files and db row
      try {
        final localRow = await LocalDatabaseService.getCapsuleById(id);
        if (localRow != null) {
          final existingAudio = localRow['audio_path'] as String?;
          if (existingAudio != null && !existingAudio.startsWith('http')) {
            final file = File(existingAudio);
            if (await file.exists()) {
              await file.delete();
              debugPrint('Audio local eliminado al borrar cápsula.');
            }
          }
        }
        await LocalDatabaseService.deleteCapsule(id);
      } catch (e) {
        debugPrint('Error limpiando datos locales al borrar cápsula: $e');
      }
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
        'intensityLevel': intensityLevel,
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
    } catch (e) {
      debugPrint('Error de red al crear crisis, usando modo offline: $e');

      final crisisId = 'local_${DateTime.now().millisecondsSinceEpoch}';

      final crisis = Crisis(
        id: crisisId,
        startedAt: DateTime.now(),
        emotion: 'Varias emociones',
        emotionIds: emotionIds,
        intensity: intensityLevel,
        evaluation: '',
        breathingCompleted: false,
      );

      // Insert en local DB
      await LocalDatabaseService.insertCrisis({
        'id': crisis.id,
        'started_at': crisis.startedAt.toIso8601String(),
        'emotion': crisis.emotion,
        'emotion_ids': emotionIds.join(','),
        'intensity': crisis.intensity,
        'evaluation': crisis.evaluation,
        'breathing_completed': crisis.breathingCompleted ? 1 : 0,
        'is_synced': 0, // No sincronizado con backend
        'reflection_pending': 1,
      });

      // Find a capsule to recommend — solo las ACTIVAS (y de paso obtenemos las locales si no hay red)
      Capsule? recommendedCapsule;
      try {
        final localRows = await LocalDatabaseService.getAllCapsules();
        final localCapsules = localRows.map((row) {
          return Capsule.fromJson({
            'id': row['id'],
            'title': row['title'],
            'type': row['type'],
            'content': row['content'],
            'audio_path': row['audio_path'],
            'is_active': row['is_active'] == 1,
            'emotion_ids': row['emotion_ids'],
            'created_at': row['created_at'],
            'is_synced': row['is_synced'] == 1,
          });
        }).toList();

        final activeCapsules = localCapsules.where((c) => c.isActive).toList();
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
      if (finalEvaluationId != null) {
        body['finalEvaluationId'] = finalEvaluationId;
      }

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
    } catch (e) {
      debugPrint(
          '[Crisis] PATCH /progress ERROR, guardando local e indicando offline: $e');

      // Persist locally AND rethrow so the caller (endCrisis) knows to mark
      // the crisis as is_synced = 0 for later synchronization.
      await LocalDatabaseService.updateCrisisProgress(
        id,
        breathingCompleted: breathingExerciseCompleted,
        finalEvaluationId: finalEvaluationId,
      );

      rethrow;
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
    } catch (e) {
      debugPrint('Error guardando reflexión red, usando local: $e');

      await LocalDatabaseService.updateCrisisReflection(
        id,
        trigger: triggerDesc ?? '',
        location: location ?? '',
        company: companion ?? '',
        substance: substanceUse ?? '',
      );

      return Crisis(
        id: id,
        startedAt: DateTime.now(),
        emotion: 'Completada',
        evaluation: notes ?? '',
        breathingCompleted: true,
      );
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
  // OFFLINE SYNC
  // ---------------------------------------------------------------------------
  @override
  Future<void> syncOfflineCrises({CancelToken? cancelToken}) async {
    final unsynced = await LocalDatabaseService.getUnsyncedCrises();
    if (unsynced.isEmpty) return;

    debugPrint(
        'Iniciando sincronización de ${unsynced.length} crisis offline...');

    for (final crisisMap in unsynced) {
      try {
        final localId = crisisMap['id'] as String;
        final intensity = crisisMap['intensity'] as int? ?? 5;
        final emotionIdsStr = crisisMap['emotion_ids'] as String? ?? '';
        final emotionIds = emotionIdsStr
            .split(',')
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList();

        // 1. Crear crisis
        final res = await _apiClient.coreDio.post('/crisis',
            data: {
              'intensityLevel': intensity,
              'emotionIds': emotionIds,
            },
            cancelToken: cancelToken);

        final newCrisisId = res.data['crisisId'];

        // 2. updateProgress
        final breathingCompleted = crisisMap['breathing_completed'] == 1;
        await _apiClient.coreDio.patch('/crisis/$newCrisisId/progress',
            data: {
              'breathingExerciseCompleted': breathingCompleted,
              if (crisisMap['evaluation'] != null &&
                  crisisMap['evaluation'].toString().isNotEmpty)
                'finalEvaluationId':
                    int.tryParse(crisisMap['evaluation'].toString()),
            },
            cancelToken: cancelToken);

        // 3. saveReflection
        final reflectionPending = crisisMap['reflection_pending'] == 1;
        if (!reflectionPending) {
          await _apiClient.coreDio.put(
            '/crisis/$newCrisisId/reflection',
            data: {
              if (crisisMap['reflection_trigger'] != null)
                'triggerDesc': crisisMap['reflection_trigger'],
              if (crisisMap['reflection_location'] != null)
                'location': crisisMap['reflection_location'],
              if (crisisMap['reflection_company'] != null)
                'companion': crisisMap['reflection_company'],
              if (crisisMap['reflection_substance'] != null)
                'substanceUse': crisisMap['reflection_substance'],
              if (crisisMap['evaluation'] != null &&
                  crisisMap['evaluation'].toString().isNotEmpty)
                'finalEvaluationId':
                    int.tryParse(crisisMap['evaluation'].toString()),
            },
            cancelToken: cancelToken,
          );
        }

        // 4. Mark as synced and delete from local pending to avoid duplicate
        final db = await LocalDatabaseService.database;
        await db.delete('crisis', where: 'id = ?', whereArgs: [localId]);
        debugPrint('Sincronizada crisis $localId exitosamente.');
      } catch (e) {
        final localId = crisisMap['id'] as String;
        debugPrint('==== ERROR SYNC CRISIS ($localId) ====');
        debugPrint('Error: $e');
        if (e is DioException) {
          debugPrint('Status: ${e.response?.statusCode}');
          debugPrint('Body: ${e.response?.data}');
        }
        debugPrint('=============================================');
      }
    }
  }

  @override
  Future<void> syncOfflineVictories({CancelToken? cancelToken}) async {
    final pending = await LocalDatabaseService.getPendingVictories();
    if (pending.isEmpty) return;

    debugPrint('Sincronizando ${pending.length} victorias offline...');
    for (final row in pending) {
      final rowId = row['id'] as int;
      final defId = row['definition_id'] as int;
      final name = row['victory_name'] as String;
      final loggedDate = row['logged_date'] as String?;
      try {
        final payload = {
          'victoryTypeId': defId,
          if (loggedDate != null) 'occurredAt': loggedDate,
        };

        debugPrint('==== SINCRONIZANDO VICTORIA OFFLINE ====');
        debugPrint('Payload: $payload');
        debugPrint('========================================');

        await _apiClient.coreDio
            .post('/victories', data: payload, cancelToken: cancelToken);

        await LocalDatabaseService.deletePendingVictory(rowId);
        debugPrint('Victoria offline "$name" sincronizada.');
      } catch (e) {
        debugPrint('==== ERROR SYNC VICTORIA (defId=$defId, name=$name) ====');
        debugPrint('Error: $e');
        if (e is DioException) {
          debugPrint('Status: ${e.response?.statusCode}');
          debugPrint('Body: ${e.response?.data}');
        }
        debugPrint('========================================================');
      }
    }
  }

  @override
  Future<void> syncProfilePhoto(String userId,
      {CancelToken? cancelToken}) async {
    final cache = await LocalDatabaseService.getProfileCache(userId);
    if (cache == null) return;
    final isSynced = (cache['is_synced'] as int? ?? 1) == 1;
    if (isSynced) return;

    final localPath = cache['local_path'] as String?;
    if (localPath == null) return;

    final file = File(localPath);
    if (!await file.exists()) {
      await LocalDatabaseService.clearProfileCache(userId);
      return;
    }

    try {
      debugPrint('Sincronizando foto de perfil offline desde $localPath...');
      final updatedUser =
          await updateProfile(avatarImage: file, cancelToken: cancelToken);

      // Persist new remote URL in SharedPreferences so UI refreshes
      final prefs = await SharedPreferences.getInstance();
      if (updatedUser.avatarUrl != null) {
        await prefs.setString('user_avatar', updatedUser.avatarUrl!);
      }

      // Mark as synced in local cache
      await LocalDatabaseService.markProfileCacheSynced(userId);
      debugPrint('Foto de perfil sincronizada. URL: ${updatedUser.avatarUrl}');
    } catch (e) {
      debugPrint('Error sincronizando foto de perfil: $e');
    }
  }

  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  @override
  Future<Victory> createVictory(String name, DateTime occurredAt,
      {int? victoryTypeId}) async {
    try {
      final payload = {
        if (victoryTypeId != null) 'victoryTypeIds': [victoryTypeId],
        'newCustomVictoryName': name,
        // 'occurredAt': occurredAt.toIso8601String(), // Validar backend
      };

      debugPrint('==== ENVIANDO VICTORIA NUEVA ====');
      debugPrint('Payload: $payload');
      debugPrint('=================================');

      final response =
          await _apiClient.coreDio.post('/victories', data: payload);
      return Victory(
        id: response.data['insertedIds']?.first?.toString() ?? 'temp',
        name: name,
        occurredAt: occurredAt,
      );
    } catch (e) {
      debugPrint('Error en createVictory: $e');
      rethrow;
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
  Future<User> getMyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final response = await _apiClient.coreDio.get('/users/profile');
    final data = response.data['user'] ?? response.data;
    final avatarUrl = data['avatarUrl'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await prefs.setString('user_avatar', avatarUrl);
    }
    return User(
      id: data['id']?.toString() ?? prefs.getString('user_id') ?? '',
      email: data['email'] ?? prefs.getString('user_email') ?? '',
      nombrePreferido: data['preferredName'] ??
          data['name'] ??
          prefs.getString('user_nombre') ??
          '',
      token: prefs.getString('auth_token') ?? '',
      avatarUrl: avatarUrl,
    );
  }

  @override
  Future<User> updateProfile(
      {String? preferredName,
      File? avatarImage,
      bool clearAvatar = false,
      CancelToken? cancelToken}) async {
    try {
      String? avatarKey;

      // 1. If there's an avatar image, upload it to Cloudinary first
      if (avatarImage != null) {
        final fileName = avatarImage.path.split('/').last;
        final presignRes = await _apiClient.coreDio.get('/media/upload-url',
            queryParameters: {
              'filename': fileName,
              'fileType': 'image/jpeg',
            },
            cancelToken: cancelToken);

        final presignData = presignRes.data as Map<String, dynamic>;
        final uploadUrl = presignData['uploadUrl'] ?? presignData['url'];
        avatarKey = presignData['fileUrl'] ??
            presignData['key'] ??
            presignData['s3Key'];

        try {
          final fields = <String, dynamic>{};
          final allowedList = [
            'api_key',
            'timestamp',
            'signature',
            'folder',
            'public_id',
            'upload_preset'
          ];
          presignData.forEach((k, v) {
            final normalizedKey = k == 'apiKey' ? 'api_key' : k;
            if (allowedList.contains(normalizedKey)) {
              fields[normalizedKey] = v;
            }
          });

          if (presignData['key'] != null) {
            fields['public_id'] = presignData['key'];
          }

          fields['file'] = await MultipartFile.fromFile(avatarImage.path,
              filename: fileName);

          final formData = FormData.fromMap(fields);

          final uploadDio = Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 30),
          ));
          await uploadDio.post(
            uploadUrl,
            data: formData,
            cancelToken: cancelToken,
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

      final response = await _apiClient.coreDio
          .put('/users/profile', data: body, cancelToken: cancelToken);

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
          : (data['avatarUrl'] ?? _resolveMediaUrl(finalAvatarKey?.toString()));

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
  Future<String> getReportUrl() async {
    final reportsService = HttpReportsApiService();
    return await reportsService.getReportUrl();
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
