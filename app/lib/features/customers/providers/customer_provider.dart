import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../models/customer_model.dart';

final customerServiceProvider = Provider<ApiService>((ref) => ApiService());

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final customerProvider =
    NotifierProvider<CustomerNotifier, CustomerState>(() {
  return CustomerNotifier();
});

class CustomerState {
  const CustomerState({
    this.customers = const [],
    this.customerDetail,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSaving = false,
    this.detailLoading = false,
    this.search = '',
    this.category = 'All',
    this.page = 1,
    this.limit = 20,
    this.hasMore = true,
    this.totalCount = 0,
    this.error,
  });

  final List<CustomerModel> customers;
  final CustomerModel? customerDetail;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSaving;
  final bool detailLoading;
  final String search;
  final String category;
  final int page;
  final int limit;
  final bool hasMore;
  final int totalCount;
  final String? error;

  CustomerState copyWith({
    List<CustomerModel>? customers,
    CustomerModel? customerDetail,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSaving,
    bool? detailLoading,
    String? search,
    String? category,
    int? page,
    int? limit,
    bool? hasMore,
    int? totalCount,
    String? error,
    bool clearError = false,
    bool clearDetail = false,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      customerDetail: clearDetail ? null : customerDetail ?? this.customerDetail,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSaving: isSaving ?? this.isSaving,
      detailLoading: detailLoading ?? this.detailLoading,
      search: search ?? this.search,
      category: category ?? this.category,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class CustomerNotifier extends Notifier<CustomerState> {
  @override
  CustomerState build() {
    return const CustomerState();
  }

  ApiService get _apiService => ref.read(customerServiceProvider);

  static const List<NewspaperOption> availableNewspapers = [
    NewspaperOption(id: 'toi', name: 'Times of India'),
    NewspaperOption(id: 'hindu', name: 'The Hindu'),
    NewspaperOption(id: 'lokmat', name: 'Lokmat'),
    NewspaperOption(id: 'bhaskar', name: 'Dainik Bhaskar'),
    NewspaperOption(id: 'et', name: 'Economic Times'),
  ];

  Future<void> loadCustomers({bool refresh = false}) async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }

    final nextPage = refresh ? 1 : state.page;
    if (!refresh && (!state.hasMore || state.isLoadingMore || state.isLoading)) {
      return;
    }

    state = state.copyWith(
      isLoading: refresh || state.customers.isEmpty,
      isLoadingMore: !refresh && state.customers.isNotEmpty,
      error: null,
      clearError: true,
    );

    try {
      final headers = await _headers();
      final responses = await Future.wait<Response<dynamic>>([
        _apiService.dio.get<Map<String, dynamic>>(
          '/customers',
          queryParameters: {
            'agency_id': agencyId,
            'page': nextPage,
            'limit': state.limit,
            if (state.search.trim().isNotEmpty) 'search': state.search.trim(),
            if (state.category != 'All') 'category': state.category,
          },
          options: Options(headers: headers),
        ).timeout(ApiService.requestTimeout),
        _apiService.dio.get<Map<String, dynamic>>(
          '/customers/defaulters',
          queryParameters: {'agency_id': agencyId},
          options: Options(headers: headers),
        ).timeout(ApiService.requestTimeout),
      ]);

      final listJson = responses[0].data is Map<String, dynamic>
          ? responses[0].data as Map<String, dynamic>
          : <String, dynamic>{};
      final defaulterJson = responses[1].data is Map<String, dynamic>
          ? responses[1].data as Map<String, dynamic>
          : <String, dynamic>{};

      final defaulterMap = <String, CustomerModel>{};
      for (final dynamic item in (defaulterJson['defaulters'] as List<dynamic>? ?? const [])) {
        final customer = CustomerModel.fromJson(item as Map<String, dynamic>);
        defaulterMap[customer.id] = customer;
      }

      final incoming = (listJson['customers'] as List<dynamic>? ?? const [])
          .map((dynamic item) {
            final customer = CustomerModel.fromJson(item as Map<String, dynamic>);
            final defaulter = defaulterMap[customer.id];
            if (defaulter == null) {
              return customer;
            }
            return customer.copyWith(
              daysOverdue: defaulter.daysOverdue,
              amountOverdue: defaulter.amountOverdue,
            );
          })
          .toList();

      state = state.copyWith(
        customers: refresh ? incoming : [...state.customers, ...incoming],
        totalCount: (listJson['total_count'] as num?)?.toInt() ?? 0,
        page: nextPage + 1,
        hasMore: incoming.length >= state.limit,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: _messageFromError(error),
      );
    }
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value, page: 1, hasMore: true);
    await loadCustomers(refresh: true);
  }

  Future<void> setCategory(String value) async {
    state = state.copyWith(category: value, page: 1, hasMore: true);
    await loadCustomers(refresh: true);
  }

  Future<void> fetchCustomerDetail(String customerId) async {
    state = state.copyWith(detailLoading: true, clearDetail: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/customers/$customerId',
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);

      final payload = response.data ?? <String, dynamic>{};
      state = state.copyWith(
        customerDetail: CustomerModel.fromDetailJson(payload),
        detailLoading: false,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        detailLoading: false,
        error: _messageFromError(error),
      );
    }
  }

  Future<bool> createCustomer({
    required Map<String, dynamic> payload,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/customers',
        data: payload,
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await loadCustomers(refresh: true);
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _messageFromError(error),
      );
      return false;
    }
  }

  Future<bool> updateCustomer({
    required String customerId,
    required Map<String, dynamic> payload,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.put<Map<String, dynamic>>(
        '/customers/$customerId',
        data: payload,
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await fetchCustomerDetail(customerId);
      await loadCustomers(refresh: true);
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _messageFromError(error),
      );
      return false;
    }
  }

  Future<bool> pauseCustomer({
    required String customerId,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/customers/$customerId/pause',
        data: {
          'from_date': fromDate,
          'to_date': toDate,
          'reason': reason,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await fetchCustomerDetail(customerId);
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _messageFromError(error),
      );
      return false;
    }
  }

  Future<bool> resumeCustomer(String customerId) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/customers/$customerId/resume',
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await fetchCustomerDetail(customerId);
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _messageFromError(error),
      );
      return false;
    }
  }

  Future<Map<String, String>> _headers() async {
    final options = await _apiService.authOptions();
    return Map<String, String>.from(options.headers ?? const <String, String>{});
  }

  String _messageFromError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Customer data load nahi ho paaya.';
  }
}
