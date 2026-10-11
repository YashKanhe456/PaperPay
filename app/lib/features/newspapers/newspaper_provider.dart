import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class NewspaperModel {
  const NewspaperModel({
    required this.id,
    required this.agencyId,
    required this.name,
    this.language,
    this.type = 'daily',
    this.costPrice,
    this.sellingPrice = 0,
    this.publisher,
    this.status = 'active',
    this.activeSubscribers = 0,
  });

  factory NewspaperModel.fromJson(Map<String, dynamic> json) {
    return NewspaperModel(
      id: json['id']?.toString() ?? '',
      agencyId: json['agency_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      language: json['language']?.toString(),
      type: json['type']?.toString() ?? 'daily',
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      publisher: json['publisher']?.toString(),
      status: json['status']?.toString() ?? 'active',
      activeSubscribers: (json['active_subscribers'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String agencyId;
  final String name;
  final String? language;
  final String type;
  final double? costPrice;
  final double sellingPrice;
  final String? publisher;
  final String status;
  final int activeSubscribers;
}

// ─── State ───────────────────────────────────────────────────────────────────

class NewspaperState {
  const NewspaperState({
    this.newspapers = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<NewspaperModel> newspapers;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  NewspaperState copyWith({
    List<NewspaperModel>? newspapers,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return NewspaperState(
      newspapers: newspapers ?? this.newspapers,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final newspaperProvider = NotifierProvider<NewspaperNotifier, NewspaperState>(() {
  return NewspaperNotifier();
});

class NewspaperNotifier extends Notifier<NewspaperState> {
  @override
  NewspaperState build() {
    return const NewspaperState();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  Future<void> load() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/newspapers',
        queryParameters: {'agency_id': agencyId},
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      final list = (data['newspapers'] as List<dynamic>? ?? [])
          .map((dynamic e) => NewspaperModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(newspapers: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e, 'Newspapers load nahi hue.'));
    }
  }

  Future<bool> add({
    required String name,
    required double sellingPrice,
    double? costPrice,
    String? language,
    String type = 'daily',
    String? publisher,
  }) async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/newspapers',
        data: {
          'agency_id': agencyId,
          'name': name,
          'selling_price': sellingPrice,
          if (costPrice != null) 'cost_price': costPrice,
          if (language != null) 'language': language,
          'type': type,
          if (publisher != null) 'publisher': publisher,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await load();
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isSaving: false, error: _msg(e, 'Newspaper add nahi hua.'));
      return false;
    }
  }

  Future<bool> softDelete(String id) async {
    try {
      await _apiService.dio.delete<Map<String, dynamic>>(
        '/newspapers/$id',
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(
        newspapers: state.newspapers.where((n) => n.id != id).toList(),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _msg(e, 'Delete nahi hua.'));
      return false;
    }
  }

  Future<Map<String, String>> _headers() async {
    final options = await _apiService.authOptions();
    return Map<String, String>.from(options.headers ?? const <String, String>{});
  }

  String _msg(DioException e, String fallback) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
