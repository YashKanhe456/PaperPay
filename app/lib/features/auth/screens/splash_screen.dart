import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await ref.read(authProvider.notifier).loadSavedUser();
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    final user = ref.read(authProvider).currentUser;

    String route;
    if (user == null) {
      route = AppRoutes.phoneLogin;
    } else if (user.role == 'agency_admin' && (user.agencyId == null || user.agencyId!.isEmpty)) {
      route = AppRoutes.onboarding;
    } else if (user.role == 'agency_admin') {
      route = AppRoutes.adminDashboard;
    } else if (user.role == 'customer') {
      route = AppRoutes.customerHome;
    } else {
      route = AppRoutes.phoneLogin;
    }


    try {
      Navigator.of(context).pushReplacementNamed(route);
    } catch (_) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.phoneLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PaperPay',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Aapka Akhbar, Aapka Hisab',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
