import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_config.dart';
import 'session_service.dart';

class ApiService {
  ApiService() {
    dio = Dio(
      BaseOptions(
        baseUrl: kIsWeb
            ? 'http://localhost:3000/api'
            : '${AppConfig.apiUrl}/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  late final Dio dio;

  static const Duration requestTimeout = Duration(seconds: 10);

  String? get agencyId => SessionService.agencyId;
  String? get userId => SessionService.userId;

  Future<Options> authOptions() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return Options(
      headers: token == null || token.isEmpty
          ? const <String, String>{}
          : <String, String>{'Authorization': 'Bearer $token'},
    );
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
