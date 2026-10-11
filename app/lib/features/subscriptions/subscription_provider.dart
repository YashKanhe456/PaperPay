import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.newspaperId,
    required this.rate,
    required this.status,
    this.planType = 'monthly',
    this.startDate,
    this.endDate,
    this.pauseFrom,
    this.pauseTo,
    this.autoRenew = true,
    this.newspaperName = '',
    this.customerName = '',
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      newspaperId: json['newspaper_id']?.toString() ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'active',
      planType: json['plan_type']?.toString() ?? 'monthly',
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      pauseFrom: json['pause_from'] != null ? DateTime.tryParse(json['pause_from'] as String) : null,
      pauseTo: json['pause_to'] != null ? DateTime.tryParse(json['pause_to'] as String) : null,
      autoRenew: json['auto_renew'] as bool? ?? true,
      newspaperName: json['newspaper_name']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
    );
  }

  final String id;
  final String customerId;
  final String newspaperId;
  final double rate;
  final String status;
  final String planType;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? pauseFrom;
  final DateTime? pauseTo;
  final bool autoRenew;
  final String newspaperName;
  final String customerName;

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
}

// ─── State ───────────────────────────────────────────────────────────────────

class SubscriptionState {
  const SubscriptionState({
    this.subscriptions = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<SubscriptionModel> subscriptions;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  SubscriptionState copyWith({
    List<SubscriptionModel>? subscriptions,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final subscriptionProvider = NotifierProvider<SubscriptionNotifier, SubscriptionState>(() {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    return const SubscriptionState();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  Future<void> loadForCustomer(String customerId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/subscriptions',
        queryParameters: {'customer_id': customerId},
        options: Options(headers: await _headers()),
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      final list = (data['subscriptions'] as List<dynamic>? ?? [])
          .map((dynamic e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(subscriptions: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e, 'Subscriptions load nahi hue.'));
    }
  }

  Future<bool> add({
    required String customerId,
    required String newspaperId,
    required double rate,
    String planType = 'monthly',
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/subscriptions',
        data: {
          'customer_id': customerId,
          'newspaper_id': newspaperId,
          'rate': rate,
          'plan_type': planType,
        },
        options: Options(headers: await _headers()),
      );
      state = state.copyWith(isSaving: false);
      await loadForCustomer(customerId);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isSaving: false, error: _msg(e, 'Subscription add nahi hua.'));
      return false;
    }
  }

  Future<bool> pause(String id, String customerId) async {
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/subscriptions/$id/pause',
        options: Options(headers: await _headers()),
      );
      await loadForCustomer(customerId);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _msg(e, 'Pause nahi hua.'));
      return false;
    }
  }

  Future<bool> resume(String id, String customerId) async {
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/subscriptions/$id/resume',
        options: Options(headers: await _headers()),
      );
      await loadForCustomer(customerId);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _msg(e, 'Resume nahi hua.'));
      return false;
    }
  }

  Future<bool> cancel(String id, String customerId) async {
    try {
      await _apiService.dio.delete<Map<String, dynamic>>(
        '/subscriptions/$id',
        options: Options(headers: await _headers()),
      );
      await loadForCustomer(customerId);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _msg(e, 'Cancel nahi hua.'));
      return false;
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
