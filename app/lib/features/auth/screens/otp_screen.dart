import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = 30;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  String get _otp => _controllers.map((controller) => controller.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6 || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final success = await ref.read(authProvider.notifier).login(widget.phone, _otp);

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (!success) {
      return;
    }

    final user = ref.read(authProvider).currentUser;
    final route = switch (user?.role) {
      'agency_admin' => AppRoutes.adminDashboard,
      'customer' => AppRoutes.customerHome,
      _ => AppRoutes.phoneLogin,
    };

    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) {
      return;
    }

    await ref.read(authProvider.notifier).sendOtp(widget.phone);

    if (!mounted) {
      return;
    }

    for (final controller in _controllers) {
      controller.clear();
    }

    _focusNodes.first.requestFocus();
    setState(() {
      _submitting = false;
    });
    _startTimer();
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_otp.length == 6) {
      unawaited(_verify());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('OTP Verify')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '+91 ${widget.phone}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('6 digit OTP daaliye'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: (value) => _onOtpChanged(index, value),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _verify,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text('Verify OTP'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _secondsLeft == 0 ? _resend : null,
              child: Text(
                _secondsLeft == 0
                    ? 'Resend OTP'
                    : 'Resend in $_secondsLeft sec',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
