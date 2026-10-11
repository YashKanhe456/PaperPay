import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/formatters.dart';
import '../../customers/providers/customer_provider.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    required this.mode,
    required this.status,
    this.billMonth,
    this.billYear,
    this.paidAt,
    this.notes,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      mode: json['mode']?.toString() ?? 'cash',
      status: json['status']?.toString() ?? 'pending',
      billMonth: (json['month'] as num?)?.toInt(),
      billYear: (json['year'] as num?)?.toInt(),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      notes: json['notes']?.toString(),
    );
  }

  final String id;
  final String customerId;
  final String customerName;
  final double amount;
  final String mode;
  final String status;
  final int? billMonth;
  final int? billYear;
  final DateTime? paidAt;
  final String? notes;
}

// ─── Provider ────────────────────────────────────────────────────────────────

class _PaymentState {
  const _PaymentState({
    this.payments = const [],
    this.todayTotal = 0,
    this.isLoading = false,
    this.isSaving = false,
    this.filter = 'All',
    this.error,
  });
  final List<PaymentRecord> payments;
  final double todayTotal;
  final bool isLoading;
  final bool isSaving;
  final String filter;
  final String? error;
  _PaymentState copyWith({
    List<PaymentRecord>? payments,
    double? todayTotal,
    bool? isLoading,
    bool? isSaving,
    String? filter,
    String? error,
    bool clearError = false,
  }) =>
      _PaymentState(
        payments: payments ?? this.payments,
        todayTotal: todayTotal ?? this.todayTotal,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        filter: filter ?? this.filter,
        error: clearError ? null : error ?? this.error,
      );
}

// REFACTORED TO Notifier to resolve "StateNotifier not found" issues on Chrome
class _PaymentNotifier extends Notifier<_PaymentState> {
  @override
  _PaymentState build() {
    return const _PaymentState();
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
        '/payments',
        queryParameters: {'agency_id': agencyId, 'limit': 50},
        options: await _api.authOptions(),
      ).timeout(ApiService.requestTimeout);
      final payload = res.data ?? {};
      final list = (payload['payments'] as List<dynamic>? ?? [])
          .map((dynamic e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      final today = DateTime.now();
      final todayTotal = list
          .where((p) {
            if (p.paidAt == null) return false;
            final d = p.paidAt!;
            return d.year == today.year && d.month == today.month && d.day == today.day;
          })
          .fold<double>(0, (sum, p) => sum + p.amount);
      state = state.copyWith(payments: list, todayTotal: todayTotal, isLoading: false);
    } on DioException catch (e) {
      final msg = _message(e, 'Payments load nahi hue.');
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<bool> recordCash({
    required String customerId,
    required double amount,
    String? notes,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final userId = SessionService.userId ?? '';
      await _api.dio.post<Map<String, dynamic>>(
        '/payments/cash',
        data: {'customer_id': customerId, 'amount': amount, 'received_by': userId, 'notes': notes},
        options: await _api.authOptions(),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await load();
      return true;
    } on DioException catch (e) {
      final msg = _message(e, 'Payment record nahi hua.');
      state = state.copyWith(isSaving: false, error: msg);
      return false;
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
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

final _paymentProvider = NotifierProvider.autoDispose<_PaymentNotifier, _PaymentState>(() {
  return _PaymentNotifier();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  static const _filters = ['All', 'Cash', 'Online', 'Overdue'];
  final int _selectedNav = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_paymentProvider.notifier).load();
    });
  }

  List<PaymentRecord> _filtered(List<PaymentRecord> all, String filter) {
    switch (filter) {
      case 'Cash':
        return all.where((p) => p.mode == 'cash').toList();
      case 'Online':
        return all.where((p) => p.mode != 'cash').toList();
      case 'Overdue':
        return all.where((p) => p.status == 'pending' || p.status == 'overdue').toList();
      default:
        return all;
    }
  }

  void _showRecordCashSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordCashSheet(
        onSubmit: ({required customerId, required amount, notes}) async {
          if (amount > 1000) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Bade payment ki pushtimaan?'),
                content: Text('${Formatters.formatCurrency(amount)} record karein?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                ],
              ),
            );
            if (confirm != true) return false;
          }
          return ref.read(_paymentProvider.notifier).recordCash(
                customerId: customerId,
                amount: amount,
                notes: notes,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_paymentProvider);
    final filtered = _filtered(state.payments, state.filter);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Payments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.success,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Record Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: _showRecordCashSheet,
      ),
      body: Column(
        children: [
          // Today collection card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aaj ka collection', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      Formatters.formatCurrency(state.todayTotal),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: _filters.map((f) {
                final selected = f == state.filter;
                return GestureDetector(
                  onTap: () => ref.read(_paymentProvider.notifier).setFilter(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // List
          Expanded(
            child: state.isLoading
                ? _buildShimmer()
                : filtered.isEmpty
                    ? _buildEmpty(state.error)
                    : RefreshIndicator(
                        color: AppColors.secondary,
                        onRefresh: () => ref.read(_paymentProvider.notifier).load(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _PaymentCard(payment: filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNav,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Bills'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Delivery'),
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined_rounded), label: 'Reports'),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _selectedNav) {
      return;
    }
    final routes = <String>[
      AppRoutes.adminDashboard,
      AppRoutes.customers,
      AppRoutes.bills,
      AppRoutes.payments,
      AppRoutes.delivery,
      AppRoutes.reports,
    ];
    Navigator.of(context).pushReplacementNamed(routes[index]);
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 88,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildEmpty(String? error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(error ?? 'Koi payment nahi mili', style: const TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      );
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final PaymentRecord payment;

  Color get _modeColor {
    switch (payment.mode) {
      case 'cash':
        return AppColors.success;
      case 'upi':
        return AppColors.primary;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _modeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.currency_rupee_rounded, color: _modeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _modeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(payment.mode.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _modeColor)),
                    ),
                    if (payment.billMonth != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${_monthLabel(payment.billMonth!)} ${payment.billYear}',
                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ],
                ),
                if (payment.paidAt != null)
                  Text(Formatters.formatDate(payment.paidAt!),
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          Text(
            Formatters.formatCurrency(payment.amount),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(int m) {
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m >= 1 && m <= 12 ? labels[m - 1] : '--';
  }
}

// ─── Record Cash Bottom Sheet ─────────────────────────────────────────────────

class _RecordCashSheet extends ConsumerStatefulWidget {
  const _RecordCashSheet({required this.onSubmit});

  final Future<bool> Function({
    required String customerId,
    required double amount,
    String? notes,
  }) onSubmit;

  @override
  ConsumerState<_RecordCashSheet> createState() => _RecordCashSheetState();
}

class _RecordCashSheetState extends ConsumerState<_RecordCashSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer chunein'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _isSaving = true);
    final ok = await widget.onSubmit(
      customerId: _selectedCustomerId!,
      amount: double.parse(_amountController.text),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider).customers;
    final search = _searchController.text.toLowerCase();
    final filtered = search.isEmpty
        ? customers
        : customers.where((c) => c.name.toLowerCase().contains(search) || c.phone.contains(search)).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cash Payment Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Customer search karein...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_selectedCustomerName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text(_selectedCustomerName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ] else if (_searchController.text.isNotEmpty && filtered.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: filtered.take(5).length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return ListTile(
                      title: Text(c.name),
                      subtitle: Text(c.phone),
                      onTap: () => setState(() {
                        _selectedCustomerId = c.id;
                        _selectedCustomerName = c.name;
                        _searchController.clear();
                      }),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Amount (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount darj karein';
                if (double.tryParse(v) == null) return 'Valid amount darj karein';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Notes (optional)',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Record Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
