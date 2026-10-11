import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    ApiService? apiService,
  })  : _firebaseAuth = firebaseAuth,
        _apiService = apiService ?? ApiService();

  static const String _boxName = 'paperpay_auth';
  static const String _userKey = 'current_user';

  final FirebaseAuth? _firebaseAuth;
  final ApiService _apiService;
  ConfirmationResult? _webConfirmationResult;

  FirebaseAuth? get _auth {
    if (_firebaseAuth != null) {
      return _firebaseAuth;
    }

    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> sendOTP(
    String phone, {
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    void Function(PhoneAuthCredential credential)? verificationCompleted,
    int? forceResendingToken,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase auth is not configured');
    }

    if (kIsWeb) {
      _webConfirmationResult = await auth.signInWithPhoneNumber('+91$phone');
      codeSent('web-session', null);
      return;
    }

    await auth.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 30),
      verificationCompleted: verificationCompleted ??
          (credential) async {
            await auth.signInWithCredential(credential);
          },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> verifyOTP(String verificationId, String otp) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase auth is not configured');
    }

    if (kIsWeb) {
      final confirmation = _webConfirmationResult;
      if (confirmation == null) {
        throw Exception('OTP session expired. Please request again.');
      }
      return confirmation.confirm(otp);
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );

    return auth.signInWithCredential(credential);
  }

  Future<UserModel> getOrCreateUser() async {
    final firebaseUser = _auth?.currentUser;
    if (firebaseUser == null) {
      throw Exception('Firebase user not found');
    }

    final idToken = await firebaseUser.getIdToken(true);
    final response = await _apiService.dio.post<Map<String, dynamic>>(
      '/auth/verify-token',
      data: {'token': idToken},
    );

    final payload = response.data ?? <String, dynamic>{};
    final user = UserModel.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map? ?? <String, dynamic>{}),
    );

    await saveUserToHive(user);
    return user;
  }

  Future<void> saveUserToHive(UserModel user) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_userKey, user.toJson());
    await SessionService.saveUser(user);
  }

  Future<UserModel?> getLocalUser() async {
    final box = await Hive.openBox(_boxName);
    Object? stored;
    try {
      stored = box.get(_userKey);
    } catch (_) {
      await box.delete(_userKey);
      return null;
    }
    if (stored is UserModel) {
      return stored;
    }

    if (stored is Map) {
      final user = UserModel.fromJson(Map<String, dynamic>.from(stored));
      await saveUserToHive(user);
      return user;
    }

    return null;
  }

  Future<void> logout() async {
    final box = await Hive.openBox(_boxName);
    await box.delete(_userKey);
    await SessionService.clear();
    _webConfirmationResult = null;
    await _auth?.signOut();
  }
}
