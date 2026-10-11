import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/formatters.dart';
import '../models/bill_model.dart';
import '../providers/bill_provider.dart';

class DefaultersScreen extends ConsumerStatefulWidget {
  const DefaultersScreen({super.key});

  @override
  ConsumerState<DefaultersScreen> createState() => _DefaultersScreenState();
}

class _DefaultersScreenState extends ConsumerState<DefaultersScreen> {
  final Set<String> _selectedIds = <String>{};
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billProvider.notifier).loadDefaulters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billProvider);
    final totalAmount = state.defaulters.fold<double>(
      0,
      (sum, item) => sum + item.finalAmount,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4F4),
      appBar: AppBar(
        backgroundColor: AppColors.danger,
        title: const Text(
          'Defaulters',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: state.defaultersLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overdue Summary',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Formatters.formatCurrency(totalAmount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.defaulters.length} customers overdue',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedIds.length == state.defaulters.length &&
                            state.defaulters.isNotEmpty,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedIds
                                ..clear()
                                ..addAll(state.defaulters.map((item) => item.id));
                            } else {
                              _selectedIds.clear();
                            }
                          });
                        },
                      ),
                      const Text(
                        'Select all',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _selectedIds.isEmpty ? null : _sendBulkReminders,
                        child: const Text('Send Reminders'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: state.defaulters.length,
                    itemBuilder: (context, index) {
                      final item = state.defaulters[index];
                      final selected = _selectedIds.contains(item.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? AppColors.danger.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedIds.add(item.id);
                                      } else {
                                        _selectedIds.remove(item.id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    item.customerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${item.daysOverdue} days',
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Formatters.formatCurrency(item.finalAmount),
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(item.phone),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _openWhatsApp(item),
                                  child: const Text('WhatsApp'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _callCustomer(item.phone),
                                  child: const Text('Call'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                  ),
                                  onPressed: () => _markPaid(item),
                                  child: const Text('Mark Paid'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _sendBulkReminders() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      _showMessage('Please logout and login again');
      return;
    }

    try {
      await _apiService.dio.post<Map<String, dynamic>>(
        '/notifications/send-reminder',
        data: {
          'agency_id': agencyId,
          'bill_ids': _selectedIds.toList(),
          'channel': 'whatsapp',
        },
        options: await _apiService.authOptions(),
      ).timeout(ApiService.requestTimeout);
      _showMessage('Selected reminders bhej diye gaye.');
    } on DioException catch (error) {
      final data = error.response?.data;
      _showMessage(
        data is Map<String, dynamic> && data['message'] is String
            ? data['message'] as String
            : 'Reminder bhejne mein dikkat hui.',
      );
    }
  }

  Future<void> _openWhatsApp(DefaulterModel item) async {
    final message = Uri.encodeComponent(
      '${item.customerName} ji, ${Formatters.formatCurrency(item.finalAmount)} baaki hai. कृपया payment kar dein.',
    );
    final phone = item.phone.replaceAll(RegExp(r'\D'), '');
    final normalized = phone.length == 10 ? '91$phone' : phone;
    await launchUrl(
      Uri.parse('https://wa.me/$normalized?text=$message'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _callCustomer(String phone) async {
    final sanitized = phone.replaceAll(RegExp(r'\s+'), '');
    await launchUrl(
      Uri.parse('tel:$sanitized'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _markPaid(DefaulterModel item) async {
    final bill = BillModel(
      id: item.id,
      customerId: item.customerId,
      agencyId: SessionService.agencyId ?? '',
      month: DateTime.now().month,
      year: DateTime.now().year,
      amount: item.finalAmount,
      discount: 0,
      lateFee: 0,
      finalAmount: item.finalAmount,
      status: 'unpaid',
      customerName: item.customerName,
      phone: item.phone,
    );

    final ok = await ref.read(billProvider.notifier).markBillPaid(bill);
    if (!mounted) {
      return;
    }
    _showMessage(ok ? 'Bill marked as paid.' : (ref.read(billProvider).error ?? 'Mark paid failed'));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
