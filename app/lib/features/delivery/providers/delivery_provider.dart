import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/offline_storage.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/sync_service.dart';
import '../models/delivery_model.dart';

final deliveryProvider = NotifierProvider<DeliveryNotifier, DeliveryState>(() {
  return DeliveryNotifier();
});

class DeliveryState {
  const DeliveryState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.areas = const [],
    this.summary = const DeliverySummaryModel(
      delivered: 0,
      pending: 0,
      missed: 0,
      holiday: 0,
      wrongPaper: 0,
      wetPaper: 0,
    ),
    this.marked = 0,
    this.total = 0,
    this.filter = 'all',
  });

  final bool isLoading;
  final bool isSaving;
  final String? error;
  final List<DeliveryAreaModel> areas;
  final DeliverySummaryModel summary;
  final int marked;
  final int total;
  final String filter;

  DeliveryState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    List<DeliveryAreaModel>? areas,
    DeliverySummaryModel? summary,
    int? marked,
    int? total,
    String? filter,
    bool clearError = false,
  }) {
    return DeliveryState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
      areas: areas ?? this.areas,
      summary: summary ?? this.summary,
      marked: marked ?? this.marked,
      total: total ?? this.total,
      filter: filter ?? this.filter,
    );
  }
}

class DeliveryNotifier extends Notifier<DeliveryState> {
  static const statuses = <String>[
    'delivered',
    'pending',
    'missed',
    'customer_holiday',
    'wrong_paper',
    'wet_paper',
  ];

  @override
  DeliveryState build() {
    return const DeliveryState();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);
  OfflineStorage get _storage => ref.read(offlineStorageProvider);
  SyncService get _syncService => ref.read(syncServiceProvider);

  Future<void> loadToday() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final queued = await _storage.getPendingDeliveries();

    try {
      final options = await _apiService.authOptions();
      final todayResponse = await _apiService.dio.get<Map<String, dynamic>>(
        '/deliveries/today',
        queryParameters: {'agency_id': agencyId},
        options: options,
      ).timeout(ApiService.requestTimeout);
      final summaryResponse = await _apiService.dio.get<Map<String, dynamic>>(
        '/deliveries/summary',
        queryParameters: {'agency_id': agencyId},
        options: options,
      ).timeout(ApiService.requestTimeout);

      final todayJson = _asMap(todayResponse.data);
      final summaryJson = _asMap(summaryResponse.data);
      final areas = ((todayJson['areas'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => DeliveryAreaModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final mergedAreas = _mergeQueuedUpdates(areas, queued);

      state = state.copyWith(
        isLoading: false,
        areas: mergedAreas,
        total: _totalFromPayload(todayJson, mergedAreas),
        marked: _countMarked(mergedAreas),
        summary: _summaryWithQueued(DeliverySummaryModel.fromJson(summaryJson), queued),
      );
    } on DioException catch (error) {
      final fallbackAreas = _mergeQueuedUpdates(state.areas, queued);
      state = state.copyWith(
        isLoading: false,
        areas: fallbackAreas,
        total: fallbackAreas.fold<int>(0, (sum, area) => sum + area.customers.length),
        marked: _countMarked(fallbackAreas),
        error: _messageFromError(error),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Delivery data load nahi hua. Retry karein.',
      );
    }
  }

  Future<bool> markCustomer({
    required DeliveryCustomerModel customer,
    required String status,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final timestamp = DateTime.now();
      for (final paper in customer.newspapers) {
        await _storage.saveDelivery(
          DeliveryModel(
            id: '${customer.customerId}_${paper.newspaperId}_${timestamp.microsecondsSinceEpoch}',
            customerId: customer.customerId,
            newspaperId: paper.newspaperId,
            date: DateTime.now().toIso8601String(),
            status: status,
            notes: 'Admin marked from delivery screen',
            createdAt: timestamp.toIso8601String(),
          ),
        );
      }

      _applyOptimisticStatus(customer.customerId, status);
      final synced = await _syncService.syncAll();
      if (synced) {
        await loadToday();
      } else {
        state = state.copyWith(isSaving: false);
      }
      return true;
    } on DioException catch (error) {
      state = state.copyWith(isSaving: false, error: _messageFromError(error));
      return false;
    } catch (_) {
      state = state.copyWith(isSaving: false, error: 'Delivery save nahi hua.');
      return false;
    }
  }

  Future<bool> bulkMarkArea({
    required String area,
    required List<DeliveryCustomerModel> customers,
    required String status,
  }) async {
    final activeCustomers = customers.where((item) => !item.isHolidayToday).toList();
    if (activeCustomers.isEmpty) {
      state = state.copyWith(error: '$area mein active customers nahi mile.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final timestamp = DateTime.now();
      for (final customer in activeCustomers) {
        for (final paper in customer.newspapers) {
          await _storage.saveDelivery(
            DeliveryModel(
              id: '${customer.customerId}_${paper.newspaperId}_${timestamp.microsecondsSinceEpoch}_${area.hashCode}',
              customerId: customer.customerId,
              newspaperId: paper.newspaperId,
              date: DateTime.now().toIso8601String(),
              status: status,
              notes: 'Bulk marked from $area',
              createdAt: timestamp.toIso8601String(),
            ),
          );
        }
        _applyOptimisticStatus(customer.customerId, status);
      }

      final synced = await _syncService.syncAll();
      if (synced) {
        await loadToday();
      } else {
        state = state.copyWith(isSaving: false);
      }
      return true;
    } on DioException catch (error) {
      state = state.copyWith(isSaving: false, error: _messageFromError(error));
      return false;
    } catch (_) {
      state = state.copyWith(isSaving: false, error: 'Bulk update nahi hua.');
      return false;
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  List<DeliveryAreaModel> _mergeQueuedUpdates(
    List<DeliveryAreaModel> areas,
    List<DeliveryModel> queued,
  ) {
    if (queued.isEmpty) {
      return areas;
    }

    final latestByPaper = <String, DeliveryModel>{};
    for (final item in queued) {
      latestByPaper['${item.customerId}_${item.newspaperId}'] = item;
    }

    return areas.map((area) {
      return DeliveryAreaModel(
        area: area.area,
        customers: area.customers.map((customer) {
          var nextStatus = customer.status;
          final nextPapers = customer.newspapers.map((paper) {
            final queuedItem = latestByPaper['${customer.customerId}_${paper.newspaperId}'];
            if (queuedItem == null) {
              return paper;
            }
            nextStatus = queuedItem.status;
            return paper.copyWith(status: queuedItem.status, notes: queuedItem.notes);
          }).toList();

          return customer.copyWith(status: nextStatus, newspapers: nextPapers);
        }).toList(),
      );
    }).toList();
  }

  DeliverySummaryModel _summaryWithQueued(
    DeliverySummaryModel summary,
    List<DeliveryModel> queued,
  ) {
    if (queued.isEmpty) {
      return summary;
    }

    var delivered = summary.delivered;
    var pending = summary.pending;
    var missed = summary.missed;
    var holiday = summary.holiday;
    var wrongPaper = summary.wrongPaper;
    var wetPaper = summary.wetPaper;

    for (final item in queued) {
      if (pending > 0) {
        pending -= 1;
      }
      switch (item.status) {
        case 'delivered':
          delivered += 1;
          break;
        case 'missed':
          missed += 1;
          break;
        case 'customer_holiday':
          holiday += 1;
          break;
        case 'wrong_paper':
          wrongPaper += 1;
          break;
        case 'wet_paper':
          wetPaper += 1;
          break;
      }
    }

    return DeliverySummaryModel(
      delivered: delivered,
      pending: pending,
      missed: missed,
      holiday: holiday,
      wrongPaper: wrongPaper,
      wetPaper: wetPaper,
    );
  }

  void _applyOptimisticStatus(String customerId, String status) {
    final updatedAreas = state.areas.map((area) {
      return DeliveryAreaModel(
        area: area.area,
        customers: area.customers.map((customer) {
          if (customer.customerId != customerId) {
            return customer;
          }
          return customer.copyWith(
            status: status,
            newspapers: customer.newspapers
                .map((paper) => paper.copyWith(status: status))
                .toList(),
          );
        }).toList(),
      );
    }).toList();

    state = state.copyWith(
      areas: updatedAreas,
      total: updatedAreas.fold<int>(0, (sum, area) => sum + area.customers.length),
      marked: _countMarked(updatedAreas),
      summary: _applySummaryDelta(state.summary, status),
      isSaving: false,
    );
  }

  DeliverySummaryModel _applySummaryDelta(DeliverySummaryModel summary, String status) {
    final nextPending = summary.pending > 0 ? summary.pending - 1 : 0;
    return switch (status) {
      'delivered' => DeliverySummaryModel(
          delivered: summary.delivered + 1,
          pending: nextPending,
          missed: summary.missed,
          holiday: summary.holiday,
          wrongPaper: summary.wrongPaper,
          wetPaper: summary.wetPaper,
        ),
      'missed' => DeliverySummaryModel(
          delivered: summary.delivered,
          pending: nextPending,
          missed: summary.missed + 1,
          holiday: summary.holiday,
          wrongPaper: summary.wrongPaper,
          wetPaper: summary.wetPaper,
        ),
      'customer_holiday' => DeliverySummaryModel(
          delivered: summary.delivered,
          pending: nextPending,
          missed: summary.missed,
          holiday: summary.holiday + 1,
          wrongPaper: summary.wrongPaper,
          wetPaper: summary.wetPaper,
        ),
      'wrong_paper' => DeliverySummaryModel(
          delivered: summary.delivered,
          pending: nextPending,
          missed: summary.missed,
          holiday: summary.holiday,
          wrongPaper: summary.wrongPaper + 1,
          wetPaper: summary.wetPaper,
        ),
      'wet_paper' => DeliverySummaryModel(
          delivered: summary.delivered,
          pending: nextPending,
          missed: summary.missed,
          holiday: summary.holiday,
          wrongPaper: summary.wrongPaper,
          wetPaper: summary.wetPaper + 1,
        ),
      _ => summary,
    };
  }

  int _countMarked(List<DeliveryAreaModel> areas) {
    var marked = 0;
    for (final area in areas) {
      for (final customer in area.customers) {
        if (customer.status != 'pending') {
          marked += 1;
        }
      }
    }
    return marked;
  }

  int _totalFromPayload(Map<String, dynamic> payload, List<DeliveryAreaModel> areas) {
    final progress = payload['progress'];
    if (progress is Map) {
      return (progress['total'] as num?)?.toInt() ??
          areas.fold<int>(0, (sum, item) => sum + item.customers.length);
    }
    return areas.fold<int>(0, (sum, item) => sum + item.customers.length);
  }

  String _messageFromError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Delivery data load nahi hua. Retry karein.';
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Delivery data load nahi hua. Retry karein.';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }
}
