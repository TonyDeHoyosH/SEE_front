import '../models/user.dart';
import '../models/emotion.dart';
import '../models/victory_type.dart';
import '../models/evaluation.dart';
import '../models/capsule.dart';
import '../models/crisis.dart';
import '../models/victory.dart';
import '../models/dashboard_data.dart';
import 'dart:io';

abstract class AuthApiService {
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, String nombrePreferido);
  Future<User> googleLogin(
      String email, String nombrePreferido, String? googleAccessToken);
  Future<void> deleteAccount();
}

abstract class CoreApiService {
  Future<Map<String, dynamic>> getCatalogs();
  Future<DashboardData> getDashboard();

  Future<List<Emotion>> getEmotions();
  Future<List<VictoryType>> getVictoryTypes();
  Future<List<Evaluation>> getEvaluations();

  Future<List<Capsule>> getCapsules({int? emotionId});
  Future<Capsule> getCapsuleById(String id);
  Future<Capsule> createCapsule({
    required String title,
    required String type, // 'TEXT' or 'AUDIO'
    String? contentText,
    File? audioFile,
    required List<int> emotionIds,
  });
  Future<Capsule> updateCapsule(
    String id, {
    String? title,
    String? contentText,
    List<int>? emotionIds,
    bool? isActive,
    File? audioFile,
  });
  Future<void> deleteCapsule(String id);

  Future<Map<String, dynamic>> createCrisis(
      List<int> emotionIds, int intensityLevel);
  Future<Crisis> updateCrisisProgress(
    String id, {
    bool? breathingExerciseCompleted,
    String? usedCapsuleId,
    int? finalEvaluationId, // enviado inmediatamente al elegir evaluación
  });
  Future<Crisis> saveCrisisReflection(
    String id, {
    String? triggerDesc,
    String? location,
    String? companion,
    String? substanceUse,
    String? notes,
    int? finalEvaluationId,
  });
  Future<List<Crisis>> getMyCrises();

  Future<Victory> createVictory(String name, DateTime occurredAt);
  Future<List<Victory>> getMyVictories();
  Future<void> deleteVictoryType(int id);

  Future<User> updateProfile(
      {String? preferredName, File? avatarImage, bool clearAvatar = false});
  Future<void> sendTelemetrySnapshot(String googleAccessToken);
}

abstract class ReportsApiService {
  Future<String> getClinicalReportUrl();
}
