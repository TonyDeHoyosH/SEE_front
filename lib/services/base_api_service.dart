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
    required String content,
    required List<int> emotionIds,
  });

  Future<Map<String, dynamic>> createCrisis(
      List<int> emotionIds, int intensityLevel);
  Future<Crisis> updateCrisis(
    String id, {
    String? evaluation,
    bool? breathingCompleted,
  });
  Future<List<Crisis>> getMyCrises();

  Future<Victory> createVictory(String name, DateTime occurredAt);
  Future<List<Victory>> getMyVictories();
  Future<void> deleteVictoryType(int id);

  Future<User> updateProfile({String? preferredName, File? avatarImage});
}

abstract class ReportsApiService {
  Future<String> getClinicalReportUrl();
}
