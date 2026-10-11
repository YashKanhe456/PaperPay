import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/customer_app_model.dart';

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final customerAppProvider =
    NotifierProvider<CustomerAppNotifier, CustomerAppState>(() {
  return CustomerAppNotifier();
});

class CustomerAppState {
  const CustomerAppState({
    this.data,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.latestOrder,
  });

  final CustomerAppData? data;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final PaymentOrder? latestOrder;

  CustomerAppState copyWith({
    CustomerAppData? data,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    PaymentOrder? latestOrder,
  }) {
    return CustomerAppState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : error ?? this.error,
      latestOrder: latestOrder ?? this.latestOrder,
    );
  }
}

class CustomerAppNotifier extends Notifier<CustomerAppState> {
  @override
  CustomerAppState build() {
    return const CustomerAppState();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/customer-app/me',
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      final payload = response.data ?? <String, dynamic>{};
      state = state.copyWith(
        isLoading: false,
        data: CustomerAppData.fromJson(payload),
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _message(error, 'Customer data load nahi hua.'),
      );
    }
  }

  Future<bool> createPaymentOrder(CustomerBill bill) async {
    final data = state.data;
    if (data == null) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/payments/razorpay/create-order',
        data: {
          'bill_id': bill.id,
          'customer_id': data.customer.id,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(
        isSubmitting: false,
        latestOrder: PaymentOrder.fromJson(response.data ?? <String, dynamic>{}),
      );
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _message(error, 'Payment order nahi ban paaya.'),
      );
      return false;
    }
  }

  Future<bool> submitComplaint({
    required String category,
    required String description,
    String? photoUrl,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/customer-app/complaints',
        data: {
          'category': category,
          'description': description,
          'photo_url': photoUrl,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      final complaint = CustomerComplaint.fromJson(
        Map<String, dynamic>.from(response.data?['complaint'] as Map? ?? const {}),
      );
      final data = state.data;
      state = state.copyWith(
        isSubmitting: false,
        data: data == null
            ? data
            : data.copyWith(
                complaints: [complaint, ...data.complaints],
              ),
      );
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _message(error, 'Complaint submit nahi hua.'),
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? email,
    String? address,
    String? language,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final response = await _apiService.dio.put<Map<String, dynamic>>(
        '/customer-app/profile',
        data: {
          'name': name,
          'email': email,
          'address': address,
          'language': language,
        },
        options: Options(headers: await _headers()),
      ).timeout(ApiService.requestTimeout);
      final updated = CustomerProfile.fromJson(
        Map<String, dynamic>.from(response.data?['customer'] as Map? ?? const {}),
      );
      final data = state.data;
      state = state.copyWith(
        isSubmitting: false,
        data: data == null ? data : data.copyWith(customer: updated),
      );
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: _message(error, 'Profile update nahi hua.'),
      );
      return false;
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null || token.isEmpty) {
      return <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  String _message(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }
}
