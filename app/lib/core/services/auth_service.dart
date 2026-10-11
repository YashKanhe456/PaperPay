import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'session_service.dart';

/// Core-level AuthService. Used by modules that only need sign-out
/// without the full OTP flow (which lives in features/auth/services).
class AuthService {
  static const String _boxName = 'paperpay_auth';
  static const String _userKey = 'current_user';

  Future<void> signOut() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.delete(_userKey);
    } catch (_) {}
    try {
      await SessionService.clear();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
