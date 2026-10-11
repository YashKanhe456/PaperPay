import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../bills/models/bill_model.dart';
import '../../bills/services/pdf_service.dart';
import '../models/customer_app_model.dart';
import '../providers/customer_app_provider.dart';

class CustomerBillsScreen extends ConsumerWidget {
  const CustomerBillsScreen({super.key});

  static const _pdfService = PdfService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerAppProvider);
    final bills = state.data?.bills ?? const <CustomerBill>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Bills')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(customerAppProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (bills.isEmpty)
              const _EmptyCard(message: 'Abhi koi bill available nahi hai.'),
            ...bills.map(
              (bill) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bill.monthLabel,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        _StatusChip(status: bill.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      Formatters.formatCurrency(bill.finalAmount),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bill.paidAt != null
                          ? 'Paid on ${Formatters.formatDate(bill.paidAt!)}'
                          : 'Due ${bill.dueDate == null ? '-' : Formatters.formatDate(bill.dueDate!)}',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _downloadReceipt(context, bill),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Receipt'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceipt(BuildContext context, CustomerBill bill) async {
    try {
      if (bill.pdfUrl != null && bill.pdfUrl!.isNotEmpty) {
        final opened = await launchUrl(
          Uri.parse(bill.pdfUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt open nahi hua. Dobara try karein.')),
          );
        }
        return;
      }

      await _pdfService.downloadBillPdf(_toBillModel(bill));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt generate nahi hua. Dobara try karein.')),
      );
    }
  }

  BillModel _toBillModel(CustomerBill bill) {
    return BillModel(
      id: bill.id,
      customerId: '',
      agencyId: '',
      month: bill.month,
      year: bill.year,
      amount: bill.amount,
      discount: bill.discount,
      lateFee: bill.lateFee,
      finalAmount: bill.finalAmount,
      dueDate: bill.dueDate,
      status: bill.status,
      paidAt: bill.paidAt,
      pdfUrl: bill.pdfUrl,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'paid' => AppColors.success,
      'partial' => AppColors.warning,
      'unpaid' => AppColors.danger,
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(message),
    );
  }
}
