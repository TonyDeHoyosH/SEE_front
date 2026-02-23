import 'dart:io';
import 'base_api_service.dart';
import '../models/user.dart';
import '../models/emotion.dart';
import '../models/victory_type.dart';
import '../models/evaluation.dart';
import '../models/capsule.dart';
import '../models/crisis.dart';
import '../models/victory.dart';
import '../models/dashboard_data.dart';
import 'api_client.dart';
import '../config/api_config.dart';

// Archivo conservado por compatibilidad histórica.
// Usar HttpAuthApiService y HttpCoreApiService en su lugar.
@Deprecated('Use HttpAuthApiService and HttpCoreApiService')
class HttpApiService implements AuthApiService, CoreApiService {
  final ApiClient _authClient = ApiClient(baseUrl: ApiConfig.authUrl);
  final ApiClient _coreClient = ApiClient(baseUrl: ApiConfig.coreUrl);

  @override
  Future<User> login(String email, String password) async {
    final data = await _authClient.post(
        '/login', {'email': email, 'password': password},
        requiresAuth: false);
    return User.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<User> register(
      String email, String password, String nombrePreferido) async {
    final data = await _authClient.post(
        '/register',
        {
          'email': email,
          'password': password,
          'nombre_preferido': nombrePreferido
        },
        requiresAuth: false);
    return User.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getCatalogs() async {
    return (await _coreClient.get('/catalogs')) as Map<String, dynamic>;
  }

  @override
  Future<DashboardData> getDashboard() async {
    return DashboardData.fromJson(
        (await _coreClient.get('/dashboard')) as Map<String, dynamic>);
  }

  @override
  Future<List<Emotion>> getEmotions() async {
    return ((await _coreClient.get('/emotions')) as List)
        .map((e) => Emotion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<VictoryType>> getVictoryTypes() async {
    return ((await _coreClient.get('/victory-types')) as List)
        .map((e) => VictoryType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Evaluation>> getEvaluations() async {
    return ((await _coreClient.get('/evaluations')) as List)
        .map((e) => Evaluation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Capsule>> getCapsules({int? emotionId}) async {
    final params =
        emotionId != null ? {'emotion_id': emotionId.toString()} : null;
    return ((await _coreClient.get('/capsules', queryParams: params)) as List)
        .map((e) => Capsule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Capsule> getCapsuleById(String id) async {
    return Capsule.fromJson(
        (await _coreClient.get('/capsules/$id')) as Map<String, dynamic>);
  }

  @override
  Future<Capsule> createCapsule(
      {required String title,
      required String content,
      required int emotionId}) async {
    return Capsule.fromJson((await _coreClient.post('/capsules', {
      'title': title,
      'content': content,
      'emotion_id': emotionId
    })) as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> createCrisis(String emotion) async {
    return (await _coreClient.post('/crises', {'emotion': emotion}))
        as Map<String, dynamic>;
  }

  @override
  Future<Crisis> updateCrisis(String id,
      {String? evaluation, bool? breathingCompleted}) async {
    final body = <String, dynamic>{};
    if (evaluation != null) body['evaluation'] = evaluation;
    if (breathingCompleted != null)
      body['breathing_completed'] = breathingCompleted;
    return Crisis.fromJson(
        (await _coreClient.patch('/crises/$id', body)) as Map<String, dynamic>);
  }

  @override
  Future<List<Crisis>> getMyCrises() async {
    return ((await _coreClient.get('/crises/me')) as List)
        .map((e) => Crisis.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Victory> createVictory(String name, DateTime occurredAt) async {
    return Victory.fromJson((await _coreClient.post('/victories', {
      'name': name,
      'occurred_at': occurredAt.toIso8601String()
    })) as Map<String, dynamic>);
  }

  @override
  Future<List<Victory>> getMyVictories() async {
    return ((await _coreClient.get('/victories/me')) as List)
        .map((e) => Victory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<User> updateProfile({String? preferredName, File? avatarImage}) async {
    throw UnimplementedError('Use HttpCoreApiService.updateProfile instead.');
  }
}
