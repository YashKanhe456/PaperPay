import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// REFACTORED TO Notifier (Riverpod 2.0+) to resolve compiler "state" resolution bugs
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthState {
  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.verificationId,
    this.phone,
    this.error,
    this.resendToken,
  });

  final UserModel? currentUser;
  final bool isLoading;
  final String? verificationId;
  final String? phone;
  final String? error;
  final int? resendToken;

  AuthState copyWith({
    UserModel? currentUser,
    bool? isLoading,
    String? verificationId,
    String? phone,
    String? error,
    int? resendToken,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      verificationId: verificationId ?? this.verificationId,
      phone: phone ?? this.phone,
      error: clearError ? null : error ?? this.error,
      resendToken: resendToken ?? this.resendToken,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  AuthService get _authService => ref.read(authServiceProvider);

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, phone: phone, clearError: true);

    try {
      await _authService.sendOTP(
        phone,
        forceResendingToken: state.resendToken,
        codeSent: (verificationId, resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
            phone: phone,
            clearError: true,
          );
        },
        verificationFailed: (error) {
          state = state.copyWith(
            isLoading: false,
            error: error.message ?? 'OTP send failed',
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          state = state.copyWith(verificationId: verificationId, isLoading: false);
        },
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          final user = await _authService.getOrCreateUser();
          state = state.copyWith(currentUser: user, isLoading: false, clearError: true);
        },
      );

      return true;
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: message.isEmpty ? 'OTP bhejne mein dikkat hui' : message,
      );
      return false;
    }
  }

  Future<bool> login(String phone, String otp) async {
    final verificationId = state.verificationId;

    if (verificationId == null) {
      state = state.copyWith(error: 'OTP session expired. Please request again.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.verifyOTP(verificationId, otp);
      final user = await _authService.getOrCreateUser();
      state = state.copyWith(
        currentUser: user,
        isLoading: false,
        phone: phone,
        clearError: true,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.message ?? 'OTP verify failed',
      );
      return false;
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['message'] is String
          ? data['message'] as String
          : error.message ?? 'Backend login failed';
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        error: message.isEmpty ? 'Login failed. Please try again.' : message,
      );
      return false;
    }
  }

  Future<void> loadSavedUser() async {
    final user = await _authService.getLocalUser();
    state = state.copyWith(currentUser: user);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }
}
