import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/emotion.dart';
import '../models/victory_type.dart';
import '../models/evaluation.dart';
import '../models/capsule.dart';
import '../models/crisis.dart';
import '../models/victory.dart';
import '../models/dashboard_data.dart';
import 'api_client.dart';
import 'base_api_service.dart';

class HttpCoreApiService implements CoreApiService {
  final ApiClient _client = ApiClient(baseUrl: ApiConfig.coreUrl);

  @override
  Future<Map<String, dynamic>> getCatalogs() async {
    final data = await _client.get('/catalogs');
    return data as Map<String, dynamic>;
  }

  @override
  Future<DashboardData> getDashboard() async {
    final data = await _client.get('/dashboard');
    return DashboardData.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Emotion>> getEmotions() async {
    final data = await _client.get('/emotions');
    return (data as List)
        .map((e) => Emotion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<VictoryType>> getVictoryTypes() async {
    final data = await _client.get('/victory-types');
    return (data as List)
        .map((e) => VictoryType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Evaluation>> getEvaluations() async {
    final data = await _client.get('/evaluations');
    return (data as List)
        .map((e) => Evaluation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Capsule>> getCapsules({int? emotionId}) async {
    final params =
        emotionId != null ? {'emotion_id': emotionId.toString()} : null;
    final data = await _client.get('/capsules', queryParams: params);
    return (data as List)
        .map((e) => Capsule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Capsule> getCapsuleById(String id) async {
    final data = await _client.get('/capsules/$id');
    return Capsule.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Capsule> createCapsule({
    required String title,
    required String content,
    required int emotionId,
  }) async {
    final data = await _client.post('/capsules', {
      'title': title,
      'content': content,
      'emotion_id': emotionId,
    });
    return Capsule.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> createCrisis(String emotion) async {
    final data = await _client.post('/crises', {'emotion': emotion});
    return data as Map<String, dynamic>;
  }

  @override
  Future<Crisis> updateCrisis(
    String id, {
    String? evaluation,
    bool? breathingCompleted,
  }) async {
    final body = <String, dynamic>{};
    if (evaluation != null) body['evaluation'] = evaluation;
    if (breathingCompleted != null) {
      body['breathing_completed'] = breathingCompleted;
    }
    final data = await _client.patch('/crises/$id', body);
    return Crisis.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Crisis>> getMyCrises() async {
    final data = await _client.get('/crises/me');
    return (data as List)
        .map((e) => Crisis.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Victory> createVictory(String name, DateTime occurredAt) async {
    final data = await _client.post('/victories', {
      'name': name,
      'occurred_at': occurredAt.toIso8601String(),
    });
    return Victory.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Victory>> getMyVictories() async {
    final data = await _client.get('/victories/me');
    return (data as List)
        .map((e) => Victory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<User> updateProfile({String? preferredName, File? avatarImage}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final uri = Uri.parse('${ApiConfig.coreUrl}/api/users/profile');

    final request = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Bearer $token';

    if (preferredName != null) {
      request.fields['preferredName'] = preferredName;
    }
    if (avatarImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatarImage.path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar perfil: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson({
      ...json,
      'token': token,
    });
  }
}
