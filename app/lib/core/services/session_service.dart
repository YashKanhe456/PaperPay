import 'package:hive_flutter/hive_flutter.dart';

import '../../features/auth/models/user_model.dart';

class SessionService {
  SessionService._();

  static const String authBoxName = 'paperpay_auth';
  static const String userBoxName = 'user';
  static const String currentUserKey = 'current_user';

  static Box<dynamic> get authBox => Hive.box(authBoxName);
  static Box<dynamic> get userBox => Hive.box(userBoxName);

  static UserModel? get currentUser {
    final dynamic authValue = authBox.get(currentUserKey);
    if (authValue is UserModel) {
      return authValue;
    }
    if (authValue is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(authValue));
    }

    final dynamic rawUser = userBox.get(currentUserKey);
    if (rawUser is UserModel) {
      return rawUser;
    }
    if (rawUser is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    }

    final agencyId = userBox.get('agency_id')?.toString();
    final userId = userBox.get('id')?.toString();
    final role = userBox.get('role')?.toString();
    final name = userBox.get('name')?.toString();
    final phone = userBox.get('phone')?.toString();
    if (userId != null && role != null) {
      return UserModel(
        id: userId,
        name: name ?? '',
        phone: phone ?? '',
        role: role,
        agencyId: agencyId,
        email: userBox.get('email')?.toString(),
        language: userBox.get('language')?.toString(),
        theme: userBox.get('theme')?.toString(),
      );
    }

    return null;
  }

  static String? get agencyId =>
      userBox.get('agency_id')?.toString() ?? currentUser?.agencyId;

  static String? get userId =>
      userBox.get('id')?.toString() ?? currentUser?.id;

  static String? get role =>
      userBox.get('role')?.toString() ?? currentUser?.role;

  static Future<void> saveUser(UserModel user) async {
    await authBox.put(currentUserKey, user.toJson());
    await userBox.put(currentUserKey, user.toJson());
    await userBox.put('id', user.id);
    await userBox.put('name', user.name);
    await userBox.put('phone', user.phone);
    await userBox.put('email', user.email);
    await userBox.put('role', user.role);
    await userBox.put('agency_id', user.agencyId);
    await userBox.put('language', user.language);
    await userBox.put('theme', user.theme);
  }

  static Future<void> clear() async {
    await authBox.delete(currentUserKey);
    await userBox.clear();
  }
}
