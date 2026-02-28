import 'package:flutter/foundation.dart';
import '../models/crisis.dart';
import '../models/capsule.dart';
import '../services/base_api_service.dart';
import '../services/local_database_service.dart';

class CrisisProvider extends ChangeNotifier {
  final CoreApiService _coreService;

  Crisis? _currentCrisis;
  Capsule? _recommendedCapsule;
  bool _isLoading = false;
  String? _errorMessage;

  CrisisProvider(this._coreService);

  Crisis? get currentCrisis => _currentCrisis;
  Capsule? get recommendedCapsule => _recommendedCapsule;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> startCrisis(List<int> emotionIds, int intensityLevel) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result =
          await _coreService.createCrisis(emotionIds, intensityLevel);
      _currentCrisis = result['crisis'] as Crisis;
      _recommendedCapsule = result['capsule'] as Capsule?;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> endCrisis(String evaluation, bool breathingCompleted) async {
    if (_currentCrisis == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _coreService.updateCrisis(
        _currentCrisis!.id,
        evaluation: evaluation,
        breathingCompleted: breathingCompleted,
      );

      await LocalDatabaseService.insertCrisis({
        'id': _currentCrisis!.id,
        'started_at': _currentCrisis!.startedAt.toIso8601String(),
        'emotion': _currentCrisis!.emotion,
        'emotion_ids': _currentCrisis!.emotionIds.join(','),
        'intensity': _currentCrisis!.intensity,
        'evaluation': evaluation,
        'breathing_completed': breathingCompleted ? 1 : 0,
        'is_synced': 1,
        'reflection_pending': 1,
      });

      _currentCrisis = _currentCrisis!.copyWith(evaluation: evaluation);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      await LocalDatabaseService.insertCrisis({
        'id': _currentCrisis!.id,
        'started_at': _currentCrisis!.startedAt.toIso8601String(),
        'emotion': _currentCrisis!.emotion,
        'emotion_ids': _currentCrisis!.emotionIds.join(','),
        'intensity': _currentCrisis!.intensity,
        'evaluation': evaluation,
        'breathing_completed': breathingCompleted ? 1 : 0,
        'is_synced': 0,
        'reflection_pending': 1,
      });

      _currentCrisis = _currentCrisis!.copyWith(evaluation: evaluation);
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveReflection({
    required String crisisId,
    required String trigger,
    required String location,
    required String company,
    required String substance,
  }) async {
    await LocalDatabaseService.updateCrisisReflection(
      crisisId,
      trigger: trigger,
      location: location,
      company: company,
      substance: substance,
    );

    _currentCrisis = null;
    _recommendedCapsule = null;
    notifyListeners();
  }

  Future<void> skipReflection(String crisisId) async {
    _currentCrisis = null;
    _recommendedCapsule = null;
    notifyListeners();
  }

  void clearCrisis() {
    _currentCrisis = null;
    _recommendedCapsule = null;
    _errorMessage = null;
    notifyListeners();
  }
}
