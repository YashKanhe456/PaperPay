import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:dio/dio.dart';

// ─── Settings Provider ────────────────────────────────────────────────────────

class AppSettings {
  const AppSettings({
    this.agencyName = '',
    this.ownerName = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.pincode = '',
    this.gst = '',
    this.language = 'hi',
    this.theme = 'light',
    this.notificationsEnabled = true,
    this.dueDateDay = 10,
    this.lateFee = 20,
    this.autoGenerateBills = true,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final String agencyName;
  final String ownerName;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final String gst;
  final String language;
  final String theme;
  final bool notificationsEnabled;
  final int dueDateDay;
  final int lateFee;
  final bool autoGenerateBills;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  AppSettings copyWith({
    String? agencyName, String? ownerName, String? phone, String? address,
    String? city, String? pincode, String? gst, String? language,
    String? theme, bool? notificationsEnabled, int? dueDateDay, int? lateFee,
    bool? autoGenerateBills, bool? isLoading, bool? isSaving, String? error,
    bool clearError = false,
  }) {
    return AppSettings(
      agencyName: agencyName ?? this.agencyName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      gst: gst ?? this.gst,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dueDateDay: dueDateDay ?? this.dueDateDay,
      lateFee: lateFee ?? this.lateFee,
      autoGenerateBills: autoGenerateBills ?? this.autoGenerateBills,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// REFACTORED TO Notifier to resolve "StateNotifier not found" issues on Chrome
class _SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return const AppSettings();
  }

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> load() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/settings',
        queryParameters: {'agency_id': agencyId},
        options: await _api.authOptions(),
      ).timeout(ApiService.requestTimeout);
      final s = (res.data?['data']?['settings'] ?? res.data?['settings']) as Map<String, dynamic>? ?? {};

      // Also fetch agency profile
      final agencyRes = await _api.dio.get<Map<String, dynamic>>(
        '/agencies/me',
        options: await _api.authOptions(),
      ).timeout(ApiService.requestTimeout);
      final agency = (agencyRes.data?['data']?['agency'] ?? agencyRes.data?['agency']) as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        agencyName: agency['name']?.toString() ?? '',
        address: agency['address']?.toString() ?? '',
        city: agency['city']?.toString() ?? '',
        pincode: agency['pincode']?.toString() ?? '',
        gst: agency['gst_number']?.toString() ?? '',
        language: s['language']?.toString() ?? 'hi',
        theme: s['theme']?.toString() ?? 'light',
        notificationsEnabled: s['notifications_enabled'] != 'false',
        dueDateDay: int.tryParse(s['due_date_day']?.toString() ?? '10') ?? 10,
        lateFee: int.tryParse(s['late_fee_amount']?.toString() ?? '20') ?? 20,
        autoGenerateBills: s['auto_generate_bills'] != 'false',
        isLoading: false,
      );
    } on DioException catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error, 'Settings load nahi hue.'));
    }
  }

  Future<bool> save({
    String? agencyName, String? address, String? city, String? pincode,
    String? gst, String? language, String? theme, bool? notificationsEnabled,
    int? dueDateDay, int? lateFee, bool? autoGenerateBills,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final opts = await _api.authOptions();

      await Future.wait([
        _api.dio.put<Map<String, dynamic>>('/agencies/me', data: {
          if (agencyName != null) 'name': agencyName,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (pincode != null) 'pincode': pincode,
          if (gst != null) 'gst_number': gst,
        }, options: opts).timeout(ApiService.requestTimeout),
        _api.dio.put<Map<String, dynamic>>('/settings', data: {
          'settings': {
            if (language != null) 'language': language,
            if (theme != null) 'theme': theme,
            if (notificationsEnabled != null) 'notifications_enabled': notificationsEnabled,
            if (dueDateDay != null) 'due_date_day': dueDateDay,
            if (lateFee != null) 'late_fee_amount': lateFee,
            if (autoGenerateBills != null) 'auto_generate_bills': autoGenerateBills,
          }
        }, options: opts).timeout(ApiService.requestTimeout),
      ]);

      state = state.copyWith(isSaving: false);
      return true;
    } on DioException catch (error) {
      state = state.copyWith(isSaving: false, error: _message(error, 'Save nahi hua.'));
      return false;
    }
  }

  String _message(DioException error, String fallback) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return fallback;
  }
}

final settingsProvider = NotifierProvider.autoDispose<_SettingsNotifier, AppSettings>(() {
  return _SettingsNotifier();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _agencyNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).load();
    });
  }

  void _populateFields(AppSettings s) {
    if (_populated) return;
    _agencyNameCtrl.text = s.agencyName;
    _addressCtrl.text = s.address;
    _cityCtrl.text = s.city;
    _pincodeCtrl.text = s.pincode;
    _gstCtrl.text = s.gst;
    _populated = true;
  }

  @override
  void dispose() {
    _agencyNameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final ok = await ref.read(settingsProvider.notifier).save(
          agencyName: _agencyNameCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          pincode: _pincodeCtrl.text.trim(),
          gst: _gstCtrl.text.trim(),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Agency profile saved ✓' : 'Save nahi hua'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Kya aap logout karna chahte hain?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/phone-login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    if (!s.isLoading && s.agencyName.isNotEmpty) _populateFields(s);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: s.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Section 1: Agency Profile ──────────────────────
                _SectionHeader(icon: Icons.business_rounded, title: 'Agency Profile'),
                _card(Column(
                  children: [
                    _field('Agency Name', _agencyNameCtrl, 'e.g. Sharma Newspapers'),
                    _field('Address', _addressCtrl, 'Full address'),
                    _field('City', _cityCtrl, 'e.g. Pune'),
                    _field('Pincode', _pincodeCtrl, '6-digit pincode', type: TextInputType.number),
                    _field('GST Number', _gstCtrl, 'Optional'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: s.isSaving ? null : _saveProfile,
                        child: s.isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                )),

                const SizedBox(height: 20),
                // ── Section 2: App Preferences ────────────────────
                _SectionHeader(icon: Icons.tune_rounded, title: 'App Preferences'),
                _card(Column(
                  children: [
                    _toggleRow(
                      'Language',
                      Icons.language_rounded,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['hi', 'en'].map((lang) {
                          final sel = s.language == lang;
                          return GestureDetector(
                            onTap: () => ref.read(settingsProvider.notifier).save(language: lang),
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary : Colors.white,
                                border: Border.all(color: AppColors.primary),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                lang == 'hi' ? 'हिंदी' : 'English',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 1),
                    _toggleRow(
                      'Dark Mode',
                      Icons.dark_mode_rounded,
                      trailing: Switch(
                        value: s.theme == 'dark',
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => ref.read(settingsProvider.notifier).save(theme: v ? 'dark' : 'light'),
                      ),
                    ),
                    const Divider(height: 1),
                    _toggleRow(
                      'Notifications',
                      Icons.notifications_rounded,
                      trailing: Switch(
                        value: s.notificationsEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => ref.read(settingsProvider.notifier).save(notificationsEnabled: v),
                      ),
                    ),
                  ],
                )),

                const SizedBox(height: 20),
                // ── Section 3: Billing Settings ───────────────────
                _SectionHeader(icon: Icons.receipt_long_rounded, title: 'Billing Settings'),
                _card(Column(
                  children: [
                    _toggleRow(
                      'Due Date (day of month)',
                      Icons.calendar_today_rounded,
                      trailing: DropdownButton<int>(
                        value: s.dueDateDay,
                        underline: const SizedBox(),
                        items: List.generate(28, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                            .toList(),
                        onChanged: (v) => ref.read(settingsProvider.notifier).save(dueDateDay: v),
                      ),
                    ),
                    const Divider(height: 1),
                    _toggleRow(
                      'Late Fee (₹)',
                      Icons.money_off_rounded,
                      trailing: DropdownButton<int>(
                        value: s.lateFee,
                        underline: const SizedBox(),
                        items: [0, 10, 20, 30, 50, 100]
                            .map((f) => DropdownMenuItem(value: f, child: Text('₹$f')))
                            .toList(),
                        onChanged: (v) => ref.read(settingsProvider.notifier).save(lateFee: v),
                      ),
                    ),
                    const Divider(height: 1),
                    _toggleRow(
                      'Auto-generate Bills',
                      Icons.auto_awesome_rounded,
                      trailing: Switch(
                        value: s.autoGenerateBills,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => ref.read(settingsProvider.notifier).save(autoGenerateBills: v),
                      ),
                    ),
                  ],
                )),

                const SizedBox(height: 20),
                // ── Section 4: Account ────────────────────────────
                _SectionHeader(icon: Icons.manage_accounts_rounded, title: 'Account'),
                _card(Column(
                  children: [
                    _toggleRow(
                      'App Version',
                      Icons.info_outline_rounded,
                      trailing: const Text('1.0.0', style: TextStyle(color: Colors.black45)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                      title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                      onTap: _logout,
                    ),
                  ],
                )),
                if (s.error != null) ...[
                  const SizedBox(height: 12),
                  Text(s.error!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                ],
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: type,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.all(16),
        child: child,
      );

  Widget _toggleRow(String title, IconData icon, {required Widget trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            trailing,
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
          ],
        ),
      );
}
