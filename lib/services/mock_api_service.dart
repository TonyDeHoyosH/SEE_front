import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_api_service.dart';
import '../models/user.dart';
import '../models/emotion.dart';
import '../models/victory_type.dart';
import '../models/evaluation.dart';
import '../models/capsule.dart';
import '../models/crisis.dart';
import '../models/victory.dart';
import '../models/dashboard_data.dart';

class MockApiService
    implements AuthApiService, CoreApiService, ReportsApiService {
  @override
  Future<User> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));

    final userJson = {
      "id": "uuid-user-123",
      "email": email,
      "nombrePreferido": "Usuario",
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock.token",
    };

    return User.fromJson(userJson);
  }

  @override
  Future<void> sendTelemetrySnapshot(String googleAccessToken) async {
    // Mock
  }

  @override
  Future<User> register(
    String email,
    String password,
    String nombrePreferido,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    final userJson = {
      "id": "uuid-user-${DateTime.now().millisecondsSinceEpoch}",
      "email": email,
      "nombrePreferido": nombrePreferido,
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock.token",
    };

    return User.fromJson(userJson);
  }

  @override
  Future<User> googleLogin(
      String email, String nombrePreferido, String? googleAccessToken) async {
    await Future.delayed(const Duration(seconds: 1));
    return User(
      id: 'mock-google-1',
      email: email,
      nombrePreferido: nombrePreferido,
      token: 'mock-google-token',
    );
  }

  @override
  Future<void> deleteAccount() async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulate successful deletion for the UI
  }

  @override
  Future<Map<String, dynamic>> getCatalogs() async {
    await Future.delayed(const Duration(seconds: 1));

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
  Future<DashboardData> getDashboard() async {
    await Future.delayed(const Duration(seconds: 1));

    final dashboardJson = {
      'weekly_victories_count': 5,
      'last_crisis': {
        "id": "uuid-crisis-999",
        "started_at": "2026-02-10T14:00:00Z",
        "emotion": "Ansiedad",
        "evaluation": "Mejor",
        "breathing_completed": true,
      },
    };

    return DashboardData.fromJson(dashboardJson);
  }

  @override
  Future<List<Emotion>> getEmotions() async {
    await Future.delayed(const Duration(seconds: 1));

    final emotionsJson = [
      {"id": 1, "name": "Miedo"},
      {"id": 2, "name": "Tristeza"},
      {"id": 3, "name": "Ira"},
      {"id": 4, "name": "Ansiedad"},
      {"id": 5, "name": "Vacío"},
    ];

    return emotionsJson.map((json) => Emotion.fromJson(json)).toList();
  }

  @override
  Future<List<VictoryType>> getVictoryTypes() async {
    await Future.delayed(const Duration(seconds: 1));

    final typesJson = [
      {"id": 1, "name": "Higiene"},
      {"id": 2, "name": "No Consumo"},
      {"id": 3, "name": "Ejercicio"},
      {"id": 4, "name": "Alimentación"},
    ];

    return typesJson.map((json) => VictoryType.fromJson(json)).toList();
  }

  @override
  Future<List<Evaluation>> getEvaluations() async {
    await Future.delayed(const Duration(seconds: 1));

    final evaluationsJson = [
      {"id": 1, "description": "Mejor"},
      {"id": 2, "description": "Igual"},
      {"id": 3, "description": "Peor"},
    ];

    return evaluationsJson.map((json) => Evaluation.fromJson(json)).toList();
  }

  @override
  Future<List<Capsule>> getCapsules({int? emotionId}) async {
    await Future.delayed(const Duration(seconds: 1));

    final capsulesJson = [
      {
        "id": "uuid-capsule-555",
        "title": "Respira conmigo",
        "content": "Inhala en 4, sostén en 7, exhala en 8. Repite este ciclo.",
        "emotion_id": 4,
        "is_active": true,
      },
      {
        "id": "uuid-capsule-556",
        "title": "Momento de calma",
        "content": "Cierra los ojos y encuentra tu centro interior.",
        "emotion_id": 1,
        "is_active": true,
      },
      {
        "id": "uuid-capsule-557",
        "title": "Ejercicio de grounding",
        "content": "Identifica 5 cosas que ves, 4 que tocas, 3 que escuchas...",
        "emotion_id": 4,
        "is_active": true,
      },
    ];

    var capsules = capsulesJson.map((json) => Capsule.fromJson(json)).toList();

    if (emotionId != null) {
      capsules =
          capsules.where((c) => c.emotionIds.contains(emotionId)).toList();
    }

    return capsules;
  }

  @override
  Future<Capsule> getCapsuleById(String id) async {
    await Future.delayed(const Duration(seconds: 1));

    final capsuleJson = {
      "id": id,
      "title": "Respira conmigo",
      "content": "Inhala en 4, sostén en 7, exhala en 8. Repite este ciclo.",
      "emotion_id": 4,
      "is_active": true,
    };

    return Capsule.fromJson(capsuleJson);
  }

  @override
  Future<Map<String, dynamic>> createCrisis(
      List<int> emotionIds, int intensityLevel) async {
    await Future.delayed(const Duration(seconds: 1));

    final crisis = Crisis(
      id: 'crisis_${DateTime.now().millisecondsSinceEpoch}',
      startedAt: DateTime.now(),
      emotion: 'Varias emociones', // Fallback
      emotionIds: emotionIds,
      intensity: intensityLevel,
      evaluation: '',
      breathingCompleted: false,
    );

    // Recommend a capsule based on emotion
    Capsule? recommendedCapsule;
    final allCapsules = await getCapsules();

    if (allCapsules.isNotEmpty && emotionIds.isNotEmpty) {
      // Pick first matching capsule for any of the emotions
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
    if (allCapsules.isNotEmpty && recommendedCapsule == null) {
      recommendedCapsule = allCapsules.first;
    }

    return {
      'crisis': crisis,
      'capsule': recommendedCapsule,
    };
  }

  @override
  Future<Crisis> updateCrisisProgress(
    String id, {
    bool? breathingExerciseCompleted,
    String? usedCapsuleId,
    int? finalEvaluationId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Crisis(
      id: id,
      startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      emotion: 'En progreso',
      evaluation: '',
      breathingCompleted: breathingExerciseCompleted ?? false,
    );
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
    await Future.delayed(const Duration(milliseconds: 500));
    return Crisis(
      id: id,
      startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      emotion: 'Ansiedad',
      evaluation: notes ?? 'Mejor',
      breathingCompleted: true,
    );
  }

  @override
  Future<List<Crisis>> getMyCrises() async {
    await Future.delayed(const Duration(seconds: 1));

    final crisesJson = [
      {
        "id": "uuid-crisis-999",
        "started_at": "2026-02-10T14:00:00Z",
        "emotion": "Ansiedad",
        "evaluation": "Mejor",
        "breathing_completed": true,
      },
      {
        "id": "uuid-crisis-998",
        "started_at": "2026-02-08T10:30:00Z",
        "emotion": "Miedo",
        "evaluation": "Igual",
        "breathing_completed": true,
      },
    ];

    return crisesJson.map((json) => Crisis.fromJson(json)).toList();
  }

  @override
  Future<void> syncOfflineCrises() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> syncOfflineVictories() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> syncProfilePhoto(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<Victory> createVictory(String name, DateTime occurredAt) async {
    await Future.delayed(const Duration(seconds: 1));

    final victoryJson = {
      "id": "uuid-victory-${DateTime.now().millisecondsSinceEpoch}",
      "name": name,
      "occurred_at": occurredAt.toIso8601String(),
    };

    return Victory.fromJson(victoryJson);
  }

  @override
  Future<List<Victory>> getMyVictories() async {
    await Future.delayed(const Duration(seconds: 1));

    final victoriesJson = [
      {
        "id": "uuid-victory-101",
        "name": "Higiene",
        "occurred_at":
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        "id": "uuid-victory-102",
        "name": "No Consumo",
        "occurred_at":
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        "id": "uuid-victory-103",
        "name": "Ejercicio",
        "occurred_at":
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
    ];

    return victoriesJson.map((json) => Victory.fromJson(json)).toList();
  }

  @override
  Future<void> deleteVictoryType(int id) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<Capsule> createCapsule({
    required String title,
    required String type, // 'TEXT' or 'AUDIO'
    String? contentText,
    File? audioFile,
    required List<int> emotionIds,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    final capsuleJson = {
      "id": "capsule_${DateTime.now().millisecondsSinceEpoch}",
      "title": title,
      "content": contentText ?? '',
      "emotion_ids": emotionIds.join(','),
      "is_active": true,
      "type": type.toLowerCase(),
      "audio_path": audioFile?.path,
    };

    return Capsule.fromJson(capsuleJson);
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
    await Future.delayed(const Duration(seconds: 1));
    return Capsule(
        id: id,
        title: title ?? 'Editado',
        content: contentText ?? '...',
        emotionIds: emotionIds ?? [],
        isActive: isActive ?? true);
  }

  @override
  Future<void> deleteCapsule(String id) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<User> updateProfile(
      {String? preferredName,
      File? avatarImage,
      bool clearAvatar = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    final currentName = prefs.getString('user_nombre') ?? 'Usuario';
    return User(
      id: 'uuid-user-123',
      email: prefs.getString('user_email') ?? 'mock@see.app',
      nombrePreferido: preferredName ?? currentName,
      token: prefs.getString('auth_token') ?? 'mock.token',
      avatarUrl: clearAvatar
          ? null
          : (avatarImage != null
              ? 'https://picsum.photos/200?mock=${DateTime.now().millisecondsSinceEpoch}'
              : null),
    );
  }

  @override
  Future<String> getReportUrl() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return 'https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1';
  }
}
