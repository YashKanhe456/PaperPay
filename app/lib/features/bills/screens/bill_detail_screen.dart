import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/bill_model.dart';
import '../providers/bill_provider.dart';
import '../services/pdf_service.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({
    required this.billId,
    super.key,
  });

  final String billId;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  final PdfService _pdfService = const PdfService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billProvider.notifier).loadBillDetail(widget.billId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billProvider);
    final bill = state.selectedBill;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bill Detail')),
      body: state.detailLoading
          ? const Center(child: CircularProgressIndicator())
          : bill == null
              ? _BillErrorState(
                  message: state.error ?? 'Bill detail nahi mila',
                  onRetry: () => ref.read(billProvider.notifier).loadBillDetail(widget.billId),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(bill: bill),
                    const SizedBox(height: 16),
                    _BreakdownCard(bill: bill),
                    const SizedBox(height: 16),
                    _BillItemsCard(items: bill.billItems),
                  ],
                ),
      bottomNavigationBar: bill == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    label: 'Record Cash Payment',
                    color: AppColors.success,
                    onTap: () => _recordCashPayment(bill),
                  ),
                  _ActionButton(
                    label: 'Download PDF',
                    color: AppColors.primary,
                    onTap: () => _downloadPdf(bill),
                  ),
                  _ActionButton(
                    label: 'Send on WhatsApp',
                    color: AppColors.secondary,
                    onTap: () => _sendOnWhatsApp(bill),
                  ),
                  _ActionButton(
                    label: 'Mark as Paid',
                    color: AppColors.warning,
                    onTap: () => _markAsPaid(bill),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _recordCashPayment(BillModel bill) async {
    final result = await showDialog<_CashPaymentInput>(
      context: context,
      builder: (_) => _CashPaymentDialog(maxAmount: bill.finalAmount),
    );

    if (result == null) {
      return;
    }

    final ok = await ref.read(billProvider.notifier).recordCashPayment(
          bill: bill,
          amount: result.amount,
          notes: result.notes,
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(billProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Cash payment recorded.' : (state.error ?? 'Payment failed')),
      ),
    );
  }

  Future<void> _downloadPdf(BillModel bill) async {
    try {
      await _pdfService.downloadBillPdf(bill);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF generate nahi ho paya.')),
      );
    }
  }

  Future<void> _sendOnWhatsApp(BillModel bill) async {
    try {
      await _pdfService.shareBillWhatsApp(bill);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp kholne mein dikkat hui.')),
      );
    }
  }

  Future<void> _markAsPaid(BillModel bill) async {
    final ok = await ref.read(billProvider.notifier).updateBillStatus(
          billId: bill.id,
          status: 'paid',
          notes: 'Marked as paid from app',
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(billProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Bill marked as paid.' : (state.error ?? 'Update failed')),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.bill});

  final BillModel bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bill.customerName ?? 'Customer',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            bill.phone ?? '',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.58)),
          ),
          const SizedBox(height: 18),
          Text(
            Formatters.formatCurrency(bill.finalAmount),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.dueDate == null
                      ? 'Due date not set'
                      : 'Due ${Formatters.formatDate(bill.dueDate!)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _DetailStatusChip(status: bill.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.bill});

  final BillModel bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _BreakdownRow(label: 'Base', value: Formatters.formatCurrency(bill.amount)),
          _BreakdownRow(
            label: 'Discount',
            value: '-${Formatters.formatCurrency(bill.discount)}',
            color: AppColors.success,
          ),
          _BreakdownRow(
            label: 'Late fee',
            value: '+${Formatters.formatCurrency(bill.lateFee)}',
            color: AppColors.warning,
          ),
          const Divider(height: 24),
          _BreakdownRow(
            label: 'Final amount',
            value: Formatters.formatCurrency(bill.finalAmount),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _BillItemsCard extends StatelessWidget {
  const _BillItemsCard({required this.items});

  final List<BillItemModel> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('Bill items nahi mile')
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.newspaperName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.days} days | ${Formatters.formatCurrency(item.ratePerDay)}/day',
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(item.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: color ?? Colors.black87,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      fontSize: isBold ? 18 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textStyle)),
          Text(value, style: textStyle),
        ],
      ),
    );
  }
}

class _DetailStatusChip extends StatelessWidget {
  const _DetailStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status.toLowerCase()) {
      'paid' => (AppColors.success.withValues(alpha: 0.14), AppColors.success),
      'partial' => (AppColors.warning.withValues(alpha: 0.14), AppColors.warning),
      _ => (AppColors.danger.withValues(alpha: 0.12), AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _BillErrorState extends StatelessWidget {
  const _BillErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.danger),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _CashPaymentDialog extends StatefulWidget {
  const _CashPaymentDialog({required this.maxAmount});

  final double maxAmount;

  @override
  State<_CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<_CashPaymentDialog> {
  late final TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.maxAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Cash Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text.trim());
            if (amount == null || amount <= 0) {
              return;
            }
            Navigator.of(context).pop(
              _CashPaymentInput(
                amount: amount,
                notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CashPaymentInput {
  const _CashPaymentInput({
    required this.amount,
    this.notes,
  });

  final double amount;
  final String? notes;
}
