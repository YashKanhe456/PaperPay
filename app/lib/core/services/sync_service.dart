import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'offline_storage.dart';
import '../../features/delivery/models/delivery_model.dart';
import '../../shared/models/cash_collection_model.dart';

final offlineStorageProvider = Provider<OfflineStorage>((ref) => OfflineStorage());

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    apiService: ref.read(apiServiceProvider),
    storage: ref.read(offlineStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(() {
  return SyncStatusNotifier();
});

class SyncStatus {
  const SyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingDeliveries = 0,
    this.pendingCashCollections = 0,
    this.lastSyncedAt,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingDeliveries;
  final int pendingCashCollections;
  final DateTime? lastSyncedAt;

  int get totalPending => pendingDeliveries + pendingCashCollections;

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingDeliveries,
    int? pendingCashCollections,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingDeliveries: pendingDeliveries ?? this.pendingDeliveries,
      pendingCashCollections: pendingCashCollections ?? this.pendingCashCollections,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    return const SyncStatus();
  }

  SyncService get _service => ref.read(syncServiceProvider);
  StreamSubscription<SyncStatus>? _subscription;

  void start() {
    _subscription ??= _service.statusStream.listen((SyncStatus status) => state = status);
    _service.start();
  }

  Future<bool> syncNow() async {
    return _service.syncAll();
  }

  void dispose() {
    _subscription?.cancel();
  }
}

class SyncService with WidgetsBindingObserver {
  SyncService({
    required ApiService apiService,
    required OfflineStorage storage,
  })  : _apiService = apiService,
        _storage = storage;

  final ApiService _apiService;
  final OfflineStorage _storage;
  final StreamController<SyncStatus> _controller = StreamController<SyncStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pollTimer;
  bool _started = false;
  bool _isSyncing = false;
  SyncStatus _status = const SyncStatus();

  Stream<SyncStatus> get statusStream => _controller.stream;

  void start() {
    if (_started) {
      _emit();
      return;
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      final online = _isOnline(results);
      await _refreshCounts(isOnline: online);
      if (online) {
        await syncAll();
      }
    });
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_status.isOnline) {
        await syncAll();
      } else {
        await _refreshCounts(isOnline: false);
      }
    });
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final online = await checkConnectivity();
    if (online) {
      await syncAll();
    }
  }

  Future<bool> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final online = _isOnline(results);
    await _refreshCounts(isOnline: online);
    return online;
  }

  Future<bool> syncPendingDeliveries() async {
    final pending = await _storage.getPendingDeliveries();
    if (pending.isEmpty) {
      await _refreshCounts();
      return true;
    }

    for (final DeliveryModel item in pending) {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/deliveries/mark',
        data: {
          'customer_id': item.customerId,
          'newspaper_id': item.newspaperId,
          'date': item.date,
          'status': item.status,
          'notes': item.notes,
        },
        options: await _apiService.authOptions(),
      ).timeout(ApiService.requestTimeout);
      await _storage.markDeliverySynced(item.id);
    }

    await _storage.clearSyncedDeliveries();
    await _refreshCounts();
    return true;
  }

  Future<bool> syncPendingCash() async {
    final pending = await _storage.getPendingCashCollections();
    if (pending.isEmpty) {
      await _refreshCounts();
      return true;
    }

    for (final CashCollectionModel item in pending) {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/cash-collections',
        data: {
          'customer_id': item.customerId,
          'amount': item.amount,
          'date': item.date,
          'notes': item.notes,
        },
        options: await _apiService.authOptions(),
      ).timeout(ApiService.requestTimeout);
      await _storage.markCashCollectionSynced(item.id);
    }

    await _storage.clearSyncedCashCollections();
    await _refreshCounts();
    return true;
  }

  Future<bool> syncAll() async {
    if (_isSyncing) {
      return false;
    }

    final online = await checkConnectivity();
    if (!online) {
      return false;
    }

    _isSyncing = true;
    _status = _status.copyWith(isSyncing: true);
    _emit();

    try {
      await syncPendingDeliveries();
      await syncPendingCash();
      _status = _status.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
      );
      _emit();
      return true;
    } on DioException {
      _status = _status.copyWith(isSyncing: false);
      _emit();
      return false;
    } finally {
      _isSyncing = false;
      await _refreshCounts();
    }
  }

  Future<void> _refreshCounts({bool? isOnline}) async {
    _status = _status.copyWith(
      isOnline: isOnline ?? _status.isOnline,
      pendingDeliveries: (await _storage.getPendingDeliveries()).length,
      pendingCashCollections: (await _storage.getPendingCashCollections()).length,
    );
    _emit();
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncAll());
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_status);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _pollTimer?.cancel();
    _controller.close();
  }
}
