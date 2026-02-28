import 'dart:io';
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

      final data = response.data;
      final token = data['token'];
      final userData = data['user'];

      final user = User(
        id: userData['id'] ?? userData['userId'] ?? '',
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
      throw Exception(e.response?.data['error'] ??
          'Error de red durante el login: ${e.message}');
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

      final data = response.data;
      final token = data['token'];
      final userId = data['userId'];

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
      throw Exception(e.response?.data['error'] ??
          'Error de red durante el registro: ${e.message}');
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
    // MOCK: Backend aún no tiene GET /emotions
    return [
      Emotion(id: 1, name: "Miedo"),
      Emotion(id: 2, name: "Tristeza"),
      Emotion(id: 3, name: "Ira"),
      Emotion(id: 4, name: "Ansiedad"),
      Emotion(id: 5, name: "Vacío"),
    ];
  }

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
    required String content,
    required List<int> emotionIds,
  }) async {
    try {
      final response = await _apiClient.coreDio.post('/capsules', data: {
        'title': title,
        'contentType': 'TEXT',
        'contentText': content,
        'emotionIds': emotionIds,
      });

      final json = response.data;
      return Capsule.fromJson({
        ...json,
        'is_active': json['isActive'] ?? true,
        'content': json['contentText'] ?? '',
      });
    } on DioException catch (e) {
      final errorMsg = e.response?.data['error'] ?? e.message;
      throw Exception('Error al crear cápsula: $errorMsg');
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
  Future<Crisis> updateCrisis(String id,
      {String? evaluation, bool? breathingCompleted}) async {
    try {
      // 1. Terminar Crisis
      final response = await _apiClient.coreDio.put('/crisis/\$id/end', data: {
        'breathingCompleted': breathingCompleted ?? true,
        // Backend maps evaluation string to an ID typically, let's keep it null if unknown or use notes
        'notes': evaluation
      });

      final data = response.data['crisis'];

      return Crisis(
        id: data['crisisId'],
        startedAt: DateTime.tryParse(data['startedAt']) ?? DateTime.now(),
        emotion: 'Completada',
        evaluation: evaluation ?? '',
        breathingCompleted: data['breathingExerciseCompleted'] ?? false,
      );
    } on DioException catch (e) {
      print('Error finalizando crisis: ${e.response?.data}');
      throw Exception('Error al actualizar crisis.');
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
        // Backend expect: userId is injected by token. It usually expects victoryTypeId.
        // Since we don't have ID mapping nicely here if 'name' is just a string, we might break if backend expects integer IDs.
        // In victory.controller.ts registerVictories likely expects { victories: [{victoryTypeId, occurredAt}] }
        // Let's perform a best-effort mock/fallback until specific API design matches
      });
      return Victory(id: 'temp', name: name, occurredAt: occurredAt);
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

  // ---------------------------------------------------------------------------
  // PROFILE & REPORTS
  // ---------------------------------------------------------------------------
  @override
  Future<User> updateProfile({String? preferredName, File? avatarImage}) async {
    final prefs = await SharedPreferences.getInstance();
    return User(
      id: 'uuid-user-123',
      email: prefs.getString('user_email') ?? 'email@test.com',
      nombrePreferido:
          preferredName ?? prefs.getString('user_nombre') ?? 'User',
      token: prefs.getString('auth_token') ?? '',
    );
  }

  @override
  Future<String> getClinicalReportUrl() async {
    final reportsService = HttpReportsApiService();
    return await reportsService.getClinicalReportUrl();
  }
}
