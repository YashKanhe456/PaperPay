import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/customer_app_provider.dart';

class DeliveryStatusScreen extends ConsumerWidget {
  const DeliveryStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerAppProvider);
    final todayItems = state.data?.todayDelivery ?? const [];
    final history = state.data?.deliveryHistory ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Delivery Status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (todayItems.isEmpty)
                  const Text('Aaj ki delivery update abhi pending hai.'),
                ...todayItems.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.status == 'delivered'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: item.status == 'delivered' ? AppColors.success : AppColors.danger,
                    ),
                    title: Text(item.newspaperName),
                    subtitle: Text(item.status.replaceAll('_', ' ')),
                    trailing: item.photoProofUrl?.isNotEmpty == true
                        ? const Icon(Icons.photo_library_outlined)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last 7 Days',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: history.take(7).map((day) {
                    final date = DateTime.tryParse(day.date);
                    final success = day.items.every((item) => item.status == 'delivered');
                    return Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: success
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            date == null ? '--' : DateFormat('dd').format(date),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(date == null ? '' : DateFormat('MMM').format(date)),
                          const SizedBox(height: 6),
                          Icon(
                            success ? Icons.check_rounded : Icons.timelapse_rounded,
                            color: success ? AppColors.success : AppColors.warning,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
