import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../models/bill_model.dart';

final billApiProvider = Provider<ApiService>((ref) => ApiService());

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final billProvider = NotifierProvider<BillNotifier, BillState>(() {
  return BillNotifier();
});

class BillState {
  const BillState({
    this.bills = const [],
    this.defaulters = const [],
    this.selectedBill,
    this.isLoading = false,
    this.isGenerating = false,
    this.detailLoading = false,
    this.defaultersLoading = false,
    this.status = 'All',
    this.month,
    this.year,
    this.page = 1,
    this.limit = 20,
    this.hasMore = true,
    this.totalCount = 0,
    this.error,
    this.generateMessage,
  });

  final List<BillModel> bills;
  final List<DefaulterModel> defaulters;
  final BillModel? selectedBill;
  final bool isLoading;
  final bool isGenerating;
  final bool detailLoading;
  final bool defaultersLoading;
  final String status;
  final int? month;
  final int? year;
  final int page;
  final int limit;
  final bool hasMore;
  final int totalCount;
  final String? error;
  final String? generateMessage;

  BillState copyWith({
    List<BillModel>? bills,
    List<DefaulterModel>? defaulters,
    BillModel? selectedBill,
    bool? isLoading,
    bool? isGenerating,
    bool? detailLoading,
    bool? defaultersLoading,
    String? status,
    int? month,
    int? year,
    int? page,
    int? limit,
    bool? hasMore,
    int? totalCount,
    String? error,
    String? generateMessage,
    bool clearError = false,
    bool clearSelected = false,
    bool clearGenerateMessage = false,
  }) {
    return BillState(
      bills: bills ?? this.bills,
      defaulters: defaulters ?? this.defaulters,
      selectedBill: clearSelected ? null : selectedBill ?? this.selectedBill,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      detailLoading: detailLoading ?? this.detailLoading,
      defaultersLoading: defaultersLoading ?? this.defaultersLoading,
      status: status ?? this.status,
      month: month ?? this.month,
      year: year ?? this.year,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      error: clearError ? null : error ?? this.error,
      generateMessage: clearGenerateMessage
          ? null
          : generateMessage ?? this.generateMessage,
    );
  }
}

class BillNotifier extends Notifier<BillState> {
  @override
  BillState build() {
    return BillState(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
  }

  ApiService get _apiService => ref.read(billApiProvider);

  Future<void> loadBills({bool refresh = false}) async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }

    final nextPage = refresh ? 1 : state.page;
    if (!refresh && (!state.hasMore || state.isLoading)) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearGenerateMessage: true,
    );

    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/bills',
        queryParameters: {
          'agency_id': agencyId,
          'page': nextPage,
          if (state.status != 'All') 'status': _mapStatus(state.status),
          if (state.month != null) 'month': state.month,
          if (state.year != null) 'year': state.year,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);

      final payload = response.data ?? <String, dynamic>{};
      final incoming = (payload['bills'] as List<dynamic>? ?? const [])
          .map((dynamic item) => BillModel.fromJson(item as Map<String, dynamic>))
          .map((BillModel bill) => bill.copyWith(daysOverdue: _computeDaysOverdue(bill)))
          .toList();

      state = state.copyWith(
        bills: refresh ? incoming : [...state.bills, ...incoming],
        isLoading: false,
        totalCount: (payload['total_count'] as num?)?.toInt() ?? 0,
        page: nextPage + 1,
        hasMore: incoming.length >= state.limit,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _messageFromError(error, 'Bills load nahi huye.'),
      );
    }
  }

  Future<void> loadBillDetail(String billId) async {
    state = state.copyWith(detailLoading: true, clearSelected: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/bills/$billId',
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);

      final payload = response.data ?? <String, dynamic>{};
      final billJson = payload['bill'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final bill = BillModel.fromJson({
        ...billJson,
        'bill_items': payload['bill_items'],
      }).copyWith(daysOverdue: _computeDaysOverdue(BillModel.fromJson(billJson)));

      state = state.copyWith(
        detailLoading: false,
        selectedBill: bill,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        detailLoading: false,
        error: _messageFromError(error, 'Bill detail nahi mila.'),
      );
    }
  }

  Future<void> loadDefaulters() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }

    state = state.copyWith(defaultersLoading: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/bills/defaulters',
        queryParameters: {'agency_id': agencyId},
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);

      final payload = response.data ?? <String, dynamic>{};
      final rows = (payload['defaulters'] as List<dynamic>? ?? const [])
          .map((dynamic item) => DefaulterModel.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(defaultersLoading: false, defaulters: rows);
    } on DioException catch (error) {
      state = state.copyWith(
        defaultersLoading: false,
        error: _messageFromError(error, 'Defaulters load nahi hue.'),
      );
    }
  }

  Future<bool> generateBills() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return false;
    }

    state = state.copyWith(
      isGenerating: true,
      clearError: true,
      clearGenerateMessage: true,
    );
    try {
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/bills/generate',
        data: {
          'agency_id': agencyId,
          'month': state.month,
          'year': state.year,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);

      final payload = response.data ?? <String, dynamic>{};
      state = state.copyWith(
        isGenerating: false,
        generateMessage:
            '${payload['generated'] ?? 0} bills generated, ${payload['skipped'] ?? 0} skipped',
      );
      await loadBills(refresh: true);
      await loadDefaulters();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isGenerating: false,
        error: _messageFromError(error, 'Bills generate nahi hue.'),
      );
      return false;
    }
  }

  Future<bool> markBillPaid(BillModel bill) async {
    final userId = SessionService.userId;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(error: 'User session missing hai.');
      return false;
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/payments/cash',
        data: {
          'bill_id': bill.id,
          'customer_id': bill.customerId,
          'amount': bill.finalAmount,
          'received_by': userId,
          'notes': 'Marked paid from app',
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      await loadBills(refresh: true);
      await loadBillDetail(bill.id);
      await loadDefaulters();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        error: _messageFromError(error, 'Payment record nahi hua.'),
      );
      return false;
    }
  }

  Future<bool> recordCashPayment({
    required BillModel bill,
    required double amount,
    String? notes,
  }) async {
    final userId = SessionService.userId;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(error: 'User session missing hai.');
      return false;
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/payments/cash',
        data: {
          'bill_id': bill.id,
          'customer_id': bill.customerId,
          'amount': amount,
          'received_by': userId,
          'notes': notes,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      await loadBills(refresh: true);
      await loadBillDetail(bill.id);
      await loadDefaulters();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        error: _messageFromError(error, 'Payment record nahi hua.'),
      );
      return false;
    }
  }

  Future<bool> updateBillStatus({
    required String billId,
    required String status,
    String? notes,
  }) async {
    try {
      await _apiService.dio.put<Map<String, dynamic>>(
        '/bills/$billId',
        data: {
          'status': status,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      await loadBills(refresh: true);
      await loadBillDetail(billId);
      await loadDefaulters();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        error: _messageFromError(error, 'Bill update nahi hua.'),
      );
      return false;
    }
  }

  void setStatus(String value) {
    state = state.copyWith(status: value, page: 1, hasMore: true);
    loadBills(refresh: true);
  }

  void setMonth(int? value) {
    state = state.copyWith(month: value, page: 1, hasMore: true);
    loadBills(refresh: true);
  }

  void setYear(int? value) {
    state = state.copyWith(year: value, page: 1, hasMore: true);
    loadBills(refresh: true);
  }

  int _computeDaysOverdue(BillModel bill) {
    if (bill.status.toLowerCase() == 'paid' || bill.dueDate == null) {
      return 0;
    }
    final diff = DateTime.now().difference(bill.dueDate!).inDays;
    return diff > 0 ? diff : 0;
  }

  String _mapStatus(String status) {
    switch (status) {
      case 'Overdue':
        return 'unpaid';
      case 'Partial':
        return 'partial';
      default:
        return status.toLowerCase();
    }
  }

  Future<Map<String, String>> _headers() async {
    final options = await _apiService.authOptions();
    return Map<String, String>.from(options.headers ?? const <String, String>{});
  }

  String _messageFromError(DioException error, String fallback) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }
}
