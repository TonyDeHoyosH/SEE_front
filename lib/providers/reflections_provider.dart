import 'package:flutter/material.dart';
import '../services/local_database_service.dart';

class ReflectionsProvider extends ChangeNotifier {
  int _pendingCount = 0;
  List<Map<String, dynamic>> _pendingReflections = [];

  int get pendingCount => _pendingCount;
  List<Map<String, dynamic>> get pendingReflections => _pendingReflections;

  /// Loads pending reflections from the local database and updates the count.
  /// Should be called on app start, after a crisis ends without reflection, 
  /// and after a reflection is successfully submitted.
  Future<void> loadPending() async {
    final results = await LocalDatabaseService.getPendingReflections();
    _pendingReflections = List<Map<String, dynamic>>.from(results);
    _pendingCount = _pendingReflections.length;
    notifyListeners();
  }

  /// Reduces count and removes from list manually for instant UI updates.
  void removePending(String crisisId) {
    _pendingReflections.removeWhere((r) => r['id'] == crisisId);
    _pendingCount = _pendingReflections.length;
    notifyListeners();
  }
}
