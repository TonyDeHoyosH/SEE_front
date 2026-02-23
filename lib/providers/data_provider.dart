import 'package:flutter/foundation.dart';
import '../models/emotion.dart';
import '../models/victory_type.dart';
import '../models/evaluation.dart';
import '../models/dashboard_data.dart';
import '../services/base_api_service.dart';

class DataProvider extends ChangeNotifier {
  final CoreApiService _coreService;

  List<Emotion> _emotions = [];
  List<VictoryType> _victoryTypes = [];
  List<Evaluation> _evaluations = [];
  DashboardData? _dashboardData;

  bool _isLoading = false;
  String? _errorMessage;

  DataProvider(this._coreService);

  List<Emotion> get emotions => _emotions;
  List<VictoryType> get victoryTypes => _victoryTypes;
  List<Evaluation> get evaluations => _evaluations;
  DashboardData? get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCatalogs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final catalogs = await _coreService.getCatalogs();

      _emotions = (catalogs['emotions'] as List)
          .map((json) => Emotion.fromJson(json as Map<String, dynamic>))
          .toList();

      _victoryTypes = (catalogs['victory_types'] as List)
          .map((json) => VictoryType.fromJson(json as Map<String, dynamic>))
          .toList();

      _evaluations = (catalogs['evaluations'] as List)
          .map((json) => Evaluation.fromJson(json as Map<String, dynamic>))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _dashboardData = await _coreService.getDashboard();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Emotion? getEmotionById(int id) {
    try {
      return _emotions.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  VictoryType? getVictoryTypeById(int id) {
    try {
      return _victoryTypes.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  Evaluation? getEvaluationById(int id) {
    try {
      return _evaluations.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }
}
