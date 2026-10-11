import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/customer_app_model.dart';
import '../providers/customer_app_provider.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key, required this.bill});

  final CustomerBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerAppProvider);
    final order = state.latestOrder;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pay Bill')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.monthLabel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  Formatters.formatCurrency(bill.finalAmount),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                const Text('Razorpay order banaakar payment flow start kiya ja sakta hai.'),
                const SizedBox(height: 20),
                if (state.error != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      state.error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            final ok = await ref.read(customerAppProvider.notifier).createPaymentOrder(bill);
                            if (!context.mounted) {
                              return;
                            }
                            final latest = ref.read(customerAppProvider).latestOrder;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok && latest != null
                                      ? 'Order ready: ${latest.orderId}'
                                      : (ref.read(customerAppProvider).error ?? 'Payment start nahi hua'),
                                ),
                              ),
                            );
                          },
                    child: Text(state.isSubmitting ? 'Creating Order...' : 'Start Payment'),
                  ),
                ),
              ],
            ),
          ),
          if (order != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text('Order ID: ${order.orderId}'),
                  const SizedBox(height: 8),
                  Text('Amount: ${Formatters.formatCurrency(order.amount / 100)}'),
                  const SizedBox(height: 8),
                  Text('Key: ${order.razorpayKey}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Razorpay order tayyar hai. Checkout integration add hote hi direct payment yahin khulega.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
