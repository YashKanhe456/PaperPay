import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/sync_service.dart';
import '../models/delivery_model.dart';
import '../providers/delivery_provider.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  static const filters = <String>['all', 'pending', 'marked'];
  final int _selectedNav = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryProvider.notifier).loadToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final progress = state.total == 0 ? 0.0 : state.marked / state.total;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Delivery Tracking',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          _SyncBadge(syncStatus: syncStatus),
          IconButton(
            onPressed: () => ref.read(syncStatusProvider.notifier).syncNow(),
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: () => ref.read(deliveryProvider.notifier).loadToday(),
        child: state.isLoading && state.areas.isEmpty
            ? const _DeliveryShimmer()
            : state.error != null && state.areas.isEmpty
                ? _DeliveryErrorState(
                    message: state.error!,
                    onRetry: () => ref.read(deliveryProvider.notifier).loadToday(),
                  )
                : state.areas.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 140),
                          Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Center(child: Text('Aaj ke deliveries abhi available nahi hain.')),
                        ],
                      )
                    : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.secondary, Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1AF97316),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Progress',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${state.marked}/${state.total} marked',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetricChip(label: 'Delivered', value: state.summary.delivered),
                            _MetricChip(label: 'Pending', value: state.summary.pending),
                            _MetricChip(label: 'Missed', value: state.summary.missed),
                            _MetricChip(label: 'Holiday', value: state.summary.holiday),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (state.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: filters.map((filter) {
                        final selected = state.filter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: selected,
                            onSelected: (_) => ref.read(deliveryProvider.notifier).setFilter(filter),
                            selectedColor: AppColors.primary.withValues(alpha: 0.14),
                            label: Text(
                              switch (filter) {
                                'pending' => 'Pending',
                                'marked' => 'Marked',
                                _ => 'All',
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...state.areas.map((area) {
                    final filteredCustomers = area.customers.where((customer) {
                      return switch (state.filter) {
                        'pending' => customer.status == 'pending',
                        'marked' => customer.status != 'pending',
                        _ => true,
                      };
                    }).toList();

                    if (filteredCustomers.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return _AreaSection(
                      area: area.area,
                      customers: filteredCustomers,
                      isSaving: state.isSaving,
                      onBulkDelivered: () => _bulkMarkArea(area, filteredCustomers),
                      onStatusChanged: (customer, status) => _markCustomer(customer, status),
                    );
                  }),
                ],
              ),
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
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _selectedNav) {
      return;
    }
    final routes = [
      AppRoutes.adminDashboard,
      AppRoutes.customers,
      AppRoutes.bills,
      AppRoutes.payments,
      AppRoutes.delivery,
      AppRoutes.reports,
    ];
    Navigator.pushReplacementNamed(context, routes[index]);
  }

  Future<void> _markCustomer(DeliveryCustomerModel customer, String status) async {
    final ok = await ref.read(deliveryProvider.notifier).markCustomer(
          customer: customer,
          status: status,
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(deliveryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '${customer.name} updated' : (state.error ?? 'Update failed'))),
    );
  }

  Future<void> _bulkMarkArea(DeliveryAreaModel area, List<DeliveryCustomerModel> customers) async {
    final ok = await ref.read(deliveryProvider.notifier).bulkMarkArea(
          area: area.area,
          customers: customers,
          status: 'delivered',
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(deliveryProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '${area.area} marked delivered' : (state.error ?? 'Bulk update failed'))),
    );
  }
}

class _DeliveryShimmer extends StatelessWidget {
  const _DeliveryShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryErrorState extends StatelessWidget {
  const _DeliveryErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.danger),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _AreaSection extends StatelessWidget {
  const _AreaSection({
    required this.area,
    required this.customers,
    required this.isSaving,
    required this.onBulkDelivered,
    required this.onStatusChanged,
  });

  final String area;
  final List<DeliveryCustomerModel> customers;
  final bool isSaving;
  final VoidCallback onBulkDelivered;
  final Future<void> Function(DeliveryCustomerModel customer, String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${customers.length} customers',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: isSaving ? null : onBulkDelivered,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Bulk Delivered'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...customers.map(
            (customer) => _CustomerDeliveryCard(
              customer: customer,
              isSaving: isSaving,
              onStatusChanged: onStatusChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDeliveryCard extends StatelessWidget {
  const _CustomerDeliveryCard({
    required this.customer,
    required this.isSaving,
    required this.onStatusChanged,
  });

  final DeliveryCustomerModel customer;
  final bool isSaving;
  final Future<void> Function(DeliveryCustomerModel customer, String status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final statusValue = customer.isHolidayToday ? 'customer_holiday' : customer.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (customer.category?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    customer.category!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              customer.address,
              customer.landmark,
            ].where((item) => item != null && item.isNotEmpty).join(', '),
            style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: customer.newspapers
                .map(
                  (paper) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      paper.newspaperName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: statusValue,
            decoration: const InputDecoration(labelText: 'Delivery Status'),
            items: DeliveryNotifier.statuses
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(_labelForStatus(status)),
                  ),
                )
                .toList(),
            onChanged: customer.isHolidayToday || isSaving
                ? null
                : (value) {
                    if (value != null) {
                      onStatusChanged(customer, value);
                    }
                  },
          ),
        ],
      ),
    );
  }

  String _labelForStatus(String status) {
    return switch (status) {
      'delivered' => 'Delivered',
      'missed' => 'Missed',
      'customer_holiday' => 'Customer Holiday',
      'wrong_paper' => 'Wrong Paper',
      'wet_paper' => 'Wet Paper',
      _ => 'Pending',
    };
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({
    required this.syncStatus,
  });

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final color = !syncStatus.isOnline
        ? AppColors.danger
        : syncStatus.isSyncing
            ? AppColors.warning
            : syncStatus.totalPending > 0
                ? AppColors.secondary
                : AppColors.success;
    final label = !syncStatus.isOnline
        ? 'Offline'
        : syncStatus.isSyncing
            ? 'Syncing'
            : syncStatus.totalPending > 0
                ? '${syncStatus.totalPending} pending'
                : 'Synced';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
