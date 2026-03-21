import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/base_api_service.dart';
import '../services/local_database_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  final CoreApiService _coreService;
  final String? Function() _getUserId;
  final Future<void> Function()? _onSyncComplete;

  bool _isOnline = true;
  bool _hasPendingSync = false;
  bool _isSyncing = false;
  CancelToken? _cancelToken;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityProvider(
    this._coreService,
    this._getUserId, {
    Future<void> Function()? onSyncComplete,
  }) : _onSyncComplete = onSyncComplete {
    _init();
  }

  bool get isOnline => _isOnline;
  bool get hasPendingSync => _hasPendingSync;
  bool get isSyncing => _isSyncing;

  void cancelSync() {
    if (_isSyncing && _cancelToken != null) {
      _cancelToken!.cancel('Cancelado por el usuario');
      _cancelToken = null;
      _isSyncing = false;
      refreshPendingStatus(); // Auto notifies listeners safely
    }
  }

  Future<void> _init() async {
    // Check current status at startup
    final result = await Connectivity().checkConnectivity();
    _isOnline = _resultsHaveConnection(result);
    if (_isOnline) await refreshPendingStatus();
    notifyListeners();

    // Listen to changes
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final wasOnline = _isOnline;
      _isOnline = _resultsHaveConnection(results);

      if (!wasOnline && _isOnline) {
        // Just came back online – auto-sync all pending data
        debugPrint('[Connectivity] Conexión restaurada, sincronizando...');
        await syncAll();
      }

      notifyListeners();
    });
  }

  bool _resultsHaveConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  /// Check if there are any pending items to sync in SQLite.
  Future<void> refreshPendingStatus() async {
    try {
      final hasCrises = (await LocalDatabaseService.getUnsyncedCrises()).isNotEmpty;
      final hasVictories = await LocalDatabaseService.hasPendingVictories();
      final userId = _getUserId();
      final hasPhoto = userId != null
          ? await LocalDatabaseService.hasPendingProfilePhoto(userId)
          : false;
      _hasPendingSync = hasCrises || hasVictories || hasPhoto;
    } catch (e) {
      debugPrint('[Connectivity] Error revisando pendientes: $e');
      _hasPendingSync = false;
    }
    notifyListeners();
  }

  /// Manually triggered sync (button press) or auto-sync on reconnect.
  Future<void> syncAll() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    _cancelToken = CancelToken();
    notifyListeners();

    try {
      final userId = _getUserId();

      await Future.wait([
        _coreService.syncOfflineCrises(cancelToken: _cancelToken).catchError((e) {
          debugPrint('[Sync] Crisis error: $e');
          return null;
        }),
        _coreService.syncOfflineVictories(cancelToken: _cancelToken).catchError((e) {
          debugPrint('[Sync] Victorias error: $e');
          return null;
        }),
        if (userId != null)
          _coreService.syncProfilePhoto(userId, cancelToken: _cancelToken).catchError((e) {
            debugPrint('[Sync] Foto error: $e');
            return null;
          }),
      ]);
    } finally {
      if (_isSyncing) { // Si se canceló ya está en false
        _isSyncing = false;
        _cancelToken = null;
        await refreshPendingStatus();
        if (_onSyncComplete != null) {
          await _onSyncComplete!().catchError((e) {
            debugPrint('[Sync] onSyncComplete error: $e');
          });
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
