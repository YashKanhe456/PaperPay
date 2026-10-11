import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final ApiService _apiService = ApiService();
  BuildContext? _navigatorContext;

  void setContext(BuildContext context) {
    _navigatorContext = context;
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      // FCM on web requires VAPID key — skip for now
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Request permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Get and register FCM token
    await _registerToken(messaging);

    // Refresh token listener
    messaging.onTokenRefresh.listen(_postToken);

    // Foreground messages — show snackbar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final context = _navigatorContext;
      if (context != null && context.mounted) {
        final notification = message.notification;
        if (notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title ?? 'PaperPay',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (notification.body != null)
                    Text(notification.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    // Background tap — navigate
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // App opened from terminated state via notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _postToken(token);
      }
    } catch (_) {
      // Non-fatal — token registration happens opportunistically
    }
  }

  Future<void> _postToken(String token) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return;

      await _apiService.dio.post<Map<String, dynamic>>(
        '/notifications/register-token',
        data: {'fcm_token': token},
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );
    } catch (_) {
      // Non-fatal
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final context = _navigatorContext;
    if (context == null || !context.mounted) return;

    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case 'complaint':
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/complaints',
          (route) => route.isFirst,
        );
        break;
      case 'payment':
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/payments',
          (route) => route.isFirst,
        );
        break;
      default:
        break;
    }
  }
}
