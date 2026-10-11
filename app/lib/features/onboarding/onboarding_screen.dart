import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (idToken == null) throw Exception('Auth token missing');

      final api = ApiService();
      await api.dio.post<Map<String, dynamic>>(
        '/agencies/register',
        data: {
          'token': idToken,
          'name': _nameCtrl.text.trim(),
          'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
          'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
          'pincode': _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
          'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'gst_number': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        },
      );

      // Update auth state with new user (who now has agency_id)
      await ref.read(authProvider.notifier).loadSavedUser();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.adminDashboard, (_) => false);
      }
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?.containsKey('message') == true
          ? e.response!.data['message'] as String
          : 'Registration fail ho gayi. Dobara try karein.';
      setState(() { _isSaving = false; _error = msg; });
    } catch (e) {
      setState(() { _isSaving = false; _error = 'Kuch galat ho gaya. Dobara try karein.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Agency Setup Karein',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apni newspaper agency ki basic details bharein.',
                style: TextStyle(fontSize: 15, color: Colors.black45),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Agency Name *'),
                    _field(_nameCtrl, 'e.g. Sharma Newspapers',
                        validator: (v) => v == null || v.trim().isEmpty ? 'Agency name required' : null),
                    const SizedBox(height: 16),
                    _label('City'),
                    _field(_cityCtrl, 'e.g. Pune'),
                    const SizedBox(height: 16),
                    _label('State'),
                    _field(_stateCtrl, 'e.g. Maharashtra'),
                    const SizedBox(height: 16),
                    _label('Pincode'),
                    _field(_pincodeCtrl, '6-digit pincode', type: TextInputType.number),
                    const SizedBox(height: 16),
                    _label('Address'),
                    _field(_addressCtrl, 'Shop/office address'),
                    const SizedBox(height: 16),
                    _label('GST Number (optional)'),
                    _field(_gstCtrl, 'e.g. 27AAACP1234A1Z5'),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Start Agency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
      );

  Widget _field(TextEditingController ctrl, String hint, {String? Function(String?)? validator, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
