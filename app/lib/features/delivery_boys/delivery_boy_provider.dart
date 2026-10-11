import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../auth/providers/auth_provider.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class DeliveryBoyModel {
  const DeliveryBoyModel({
    required this.id,
    required this.agencyId,
    required this.name,
    this.phone,
    this.area,
    this.deliveredToday = 0,
    this.totalToday = 0,
  });

  factory DeliveryBoyModel.fromJson(Map<String, dynamic> json) {
    return DeliveryBoyModel(
      id: json['id']?.toString() ?? '',
      agencyId: json['agency_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      area: json['area']?.toString(),
      deliveredToday: (json['delivered_today'] as num?)?.toInt() ?? 0,
      totalToday: (json['total_today'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String agencyId;
  final String name;
  final String? phone;
  final String? area;
  final int deliveredToday;
  final int totalToday;
}

// ─── State ───────────────────────────────────────────────────────────────────

class DeliveryBoyState {
  const DeliveryBoyState({
    this.deliveryBoys = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<DeliveryBoyModel> deliveryBoys;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  DeliveryBoyState copyWith({
    List<DeliveryBoyModel>? deliveryBoys,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return DeliveryBoyState(
      deliveryBoys: deliveryBoys ?? this.deliveryBoys,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final deliveryBoyProvider = NotifierProvider<DeliveryBoyNotifier, DeliveryBoyState>(() {
  return DeliveryBoyNotifier();
});

class DeliveryBoyNotifier extends Notifier<DeliveryBoyState> {
  @override
  DeliveryBoyState build() {
    return const DeliveryBoyState();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  Future<void> load() async {
    final agencyId = ref.read(authProvider).currentUser?.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Agency nahi mili.');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/delivery-boys',
        queryParameters: {'agency_id': agencyId},
        options: Options(headers: await _headers()),
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      final list = (data['delivery_boys'] as List<dynamic>? ?? [])
          .map((dynamic e) => DeliveryBoyModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(deliveryBoys: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e, 'Delivery boys load nahi hue.'));
    }
  }

  Future<bool> add({required String name, String? phone, String? area}) async {
    final agencyId = ref.read(authProvider).currentUser?.agencyId;
    if (agencyId == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/delivery-boys',
        data: {'agency_id': agencyId, 'name': name, if (phone != null) 'phone': phone, if (area != null) 'area': area},
        options: Options(headers: await _headers()),
      );
      state = state.copyWith(isSaving: false);
      await load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isSaving: false, error: _msg(e, 'Add nahi hua.'));
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _apiService.dio.delete<Map<String, dynamic>>(
        '/delivery-boys/$id',
        options: Options(headers: await _headers()),
      );
      state = state.copyWith(
        deliveryBoys: state.deliveryBoys.where((d) => d.id != id).toList(),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _msg(e, 'Delete nahi hua.'));
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
