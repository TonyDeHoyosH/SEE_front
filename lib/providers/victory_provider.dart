import 'package:flutter/foundation.dart';
import '../services/local_database_service.dart';
import '../services/base_api_service.dart';

class VictoryDefinition {
  final int id;
  final String name;

  VictoryDefinition({required this.id, required this.name});
}

class VictoryLog {
  final String name;
  final String loggedDate;

  VictoryLog({required this.name, required this.loggedDate});
}

class VictoryProvider extends ChangeNotifier {
  final CoreApiService apiService;

  List<VictoryDefinition> _definitions = [];
  Set<int> _todayChecked = {};
  List<VictoryLog> _history = [];
  bool _isLoading = false;

  VictoryProvider(this.apiService);

  List<VictoryDefinition> get definitions => _definitions;
  Set<int> get todayChecked => _todayChecked;
  List<VictoryLog> get history => _history;
  bool get isLoading => _isLoading;

  void clear() {
    _definitions = [];
    _todayChecked = {};
    _history = [];
    notifyListeners();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final backendVictories = await apiService.getMyVictories();
      if (backendVictories.isNotEmpty) {
        await LocalDatabaseService.syncVictoriesFromBackend(backendVictories);
      }
    } catch (e) {
      debugPrint('Error syncing victories from backend: $e');
    }

    final defsRaw = await LocalDatabaseService.getAllVictoryDefinitions();
    _definitions = defsRaw
        .map((d) => VictoryDefinition(
              id: d['id'] as int,
              name: d['name'] as String,
            ))
        .toList();

    _todayChecked = await LocalDatabaseService.getTodayLoggedIds();

    final historyRaw = await LocalDatabaseService.getVictoryHistory();
    _history = historyRaw
        .map((h) => VictoryLog(
              name: h['name'] as String,
              loggedDate: h['logged_date'] as String,
            ))
        .toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDefinition(String name) async {
    final id = await LocalDatabaseService.insertVictoryDefinition(name);
    _definitions.add(VictoryDefinition(id: id, name: name));
    notifyListeners();
  }

  Future<void> updateDefinition(int id, String newName) async {
    await LocalDatabaseService.updateVictoryDefinition(id, newName);
    final index = _definitions.indexWhere((d) => d.id == id);
    if (index != -1) {
      _definitions[index] = VictoryDefinition(id: id, name: newName);
    }
    await _refreshHistory();
    notifyListeners();
  }

  Future<void> deleteDefinition(int id) async {
    // Delete from API explicitly
    try {
      await apiService.deleteVictoryType(id);
    } catch (e) {
      debugPrint(
          'Warning: No pudo borrar en backend ($e) pero continuará localmente');
    }

    await LocalDatabaseService.deleteVictoryDefinition(id);
    _definitions.removeWhere((d) => d.id == id);
    _todayChecked.remove(id);
    await _refreshHistory();
    notifyListeners();
  }

  Future<void> toggleCheck(int definitionId) async {
    if (_todayChecked.contains(definitionId)) {
      await LocalDatabaseService.unlogVictoryToday(definitionId);
      _todayChecked.remove(definitionId);
    } else {
      await LocalDatabaseService.logVictoryToday(definitionId);
      _todayChecked.add(definitionId);

      try {
        final def = _definitions.firstWhere((d) => d.id == definitionId);
        await apiService.createVictory(def.name, DateTime.now(), victoryTypeId: definitionId);
      } catch (e) {
        // Offline: queue in pending_victories for later sync
        debugPrint('Victoria sin internet, guardando offline: $e');
        try {
          final def = _definitions.firstWhere((d) => d.id == definitionId);
          await LocalDatabaseService.insertPendingVictory(
            definitionId: definitionId,
            victoryName: def.name,
            loggedDate: DateTime.now().toIso8601String(),
          );
        } catch (_) {}
      }
    }
    await _refreshHistory();
    notifyListeners();
  }

  Future<void> _refreshHistory() async {
    final historyRaw = await LocalDatabaseService.getVictoryHistory();
    _history = historyRaw
        .map((h) => VictoryLog(
              name: h['name'] as String,
              loggedDate: h['logged_date'] as String,
            ))
        .toList();
  }
}
