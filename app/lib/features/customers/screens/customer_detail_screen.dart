import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/formatters.dart';
import '../../subscriptions/subscription_provider.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({
    required this.customerId,
    super.key,
  });

  final String customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    await Future.wait([
      ref.read(customerProvider.notifier).fetchCustomerDetail(widget.customerId),
      ref.read(subscriptionProvider.notifier).loadForCustomer(widget.customerId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    final customer = state.customerDetail;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Customer Detail'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.secondary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Bills'),
              Tab(text: 'Payments'),
              Tab(text: 'Timeline'),
              Tab(text: 'Subscriptions'),
            ],
          ),
        ),
        body: state.detailLoading
            ? const _CustomerDetailShimmer()
            : customer == null
                ? _ErrorState(
                    message: state.error ?? 'Customer detail nahi mila',
                    onRetry: _loadAll,
                  )
                : Column(
                    children: [
                      _Header(customer: customer),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _InlineError(message: state.error!),
                        ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _OverviewTab(customer: customer),
                            _BillsTab(bills: customer.recentBills),
                            _PaymentsTab(payments: customer.paymentHistory),
                            _TimelineTab(customer: customer),
                            _SubscriptionsTab(customerId: widget.customerId),
                          ],
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: customer == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionButton(
                      label: 'Record Payment',
                      color: AppColors.success,
                      onPressed: () => _openPaymentFlow(customer),
                    ),
                    _ActionButton(
                      label: 'Send Reminder',
                      color: AppColors.secondary,
                      onPressed: () => _sendReminder(customer),
                    ),
                    _ActionButton(
                      label: _hasPausedSubscription(ref.watch(subscriptionProvider).subscriptions)
                          ? 'Resume'
                          : 'Pause',
                      color: AppColors.warning,
                      onPressed: () => _togglePause(customer),
                    ),
                    _ActionButton(
                      label: 'Edit',
                      color: AppColors.primary,
                      onPressed: () => _editCustomer(customer),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  bool _hasPausedSubscription(List<SubscriptionModel> subscriptions) {
    return subscriptions.any((item) => item.status == 'paused');
  }

  Future<void> _openPaymentFlow(CustomerModel customer) async {
    final targetBill = customer.recentBills.cast<CustomerBill?>().firstWhere(
          (bill) => bill != null && bill.status != 'paid',
          orElse: () => null,
        );

    if (!mounted) {
      return;
    }

    if (targetBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is customer ke paas abhi unpaid bill nahi hai.')),
      );
      return;
    }

    Navigator.of(context).pushNamed(AppRoutes.billDetail, arguments: targetBill.id);
  }

  Future<void> _sendReminder(CustomerModel customer) async {
    final agencyId = SessionService.agencyId;
    final dueBillIds = customer.recentBills
        .where((bill) => bill.status != 'paid')
        .map((bill) => bill.id)
        .toList();

    if (agencyId == null || agencyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please logout and login again')),
      );
      return;
    }

    if (dueBillIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder ke liye unpaid bill nahi mila.')),
      );
      return;
    }

    try {
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/notifications/send-reminder',
        data: {
          'agency_id': agencyId,
          'bill_ids': dueBillIds,
          'channel': 'whatsapp',
        },
        options: await _apiService.authOptions(),
      ).timeout(ApiService.requestTimeout);

      final reminders = response.data?['reminders'] as List<dynamic>? ?? const [];
      final link = reminders.isNotEmpty
          ? (reminders.first as Map<String, dynamic>)['link']?.toString()
          : null;

      if (link != null && link.isNotEmpty) {
        await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder bhej diya gaya.')),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['message'] is String
          ? data['message'] as String
          : 'Reminder bhejne mein dikkat hui.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _togglePause(CustomerModel customer) async {
    final subscriptions = ref.read(subscriptionProvider).subscriptions;
    final hasPaused = _hasPausedSubscription(subscriptions);
    if (hasPaused) {
      final ok = await ref.read(customerProvider.notifier).resumeCustomer(customer.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Customer resume ho gaya.' : 'Resume nahi hua.')),
      );
      if (ok) {
        await ref.read(subscriptionProvider.notifier).loadForCustomer(customer.id);
      }
      return;
    }

    final result = await showDialog<_PauseResult>(
      context: context,
      builder: (_) => const _PauseCustomerDialog(),
    );

    if (result == null) {
      return;
    }

    final ok = await ref.read(customerProvider.notifier).pauseCustomer(
          customerId: customer.id,
          fromDate: result.fromDate,
          toDate: result.toDate,
          reason: result.reason,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Customer pause ho gaya.' : 'Pause nahi hua.')),
    );
    if (ok) {
      await ref.read(subscriptionProvider.notifier).loadForCustomer(customer.id);
    }
  }

  Future<void> _editCustomer(CustomerModel customer) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditCustomerDialog(customer: customer),
    );

    if (result == null) {
      return;
    }

    final ok = await ref.read(customerProvider.notifier).updateCustomer(
          customerId: customer.id,
          payload: result,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Customer update ho gaya.' : 'Update nahi hua.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final score = customer.healthScore?.score ?? 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  customer.phone,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(label: customer.category, color: AppColors.primary),
                    if (customer.area?.isNotEmpty == true)
                      _Tag(label: customer.area!, color: AppColors.secondary),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  color: _scoreColor(score),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const Text(
                        'Health',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) {
      return AppColors.success;
    }
    if (score >= 50) {
      return AppColors.warning;
    }
    return AppColors.danger;
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _InfoCard(
          title: 'Address',
          child: Text(
            [
              customer.address,
              customer.landmark,
              customer.area,
            ].where((item) => item != null && item.isNotEmpty).join(', ').isEmpty
                ? 'Address not available'
                : [
                    customer.address,
                    customer.landmark,
                    customer.area,
                  ].where((item) => item != null && item.isNotEmpty).join(', '),
          ),
        ),
        _InfoCard(
          title: 'Overview',
          child: Column(
            children: [
              _DataRow(label: 'Outstanding', value: Formatters.formatCurrency(customer.totalOutstanding)),
              _DataRow(label: 'Lifetime Value', value: Formatters.formatCurrency(customer.lifetimeValue)),
              _DataRow(label: 'Customer Since', value: customer.startDate == null ? '--' : Formatters.formatDate(customer.startDate!)),
              _DataRow(label: 'Alt Contact', value: customer.altContact ?? '--'),
            ],
          ),
        ),
        _InfoCard(
          title: 'Subscriptions',
          child: customer.subscriptions.isEmpty
              ? const Text('No active subscriptions')
              : Column(
                  children: customer.subscriptions.map((subscription) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(subscription.newspaperName),
                      subtitle: Text(subscription.planType),
                      trailing: Text(
                        Formatters.formatCurrency(subscription.rate),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _BillsTab extends StatelessWidget {
  const _BillsTab({required this.bills});

  final List<CustomerBill> bills;

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return const Center(child: Text('Last 3 bills nahi mile'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: bills.map((bill) {
        final label = DateFormat('MMM yyyy').format(DateTime(bill.year, bill.month));
        return _InfoCard(
          title: label,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bill.status.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                Formatters.formatCurrency(bill.finalAmount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.payments});

  final List<CustomerPayment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(child: Text('Payment history nahi mili'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: payments.map((payment) {
        return _InfoCard(
          title: payment.mode ?? 'Payment',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  payment.paidAt == null ? 'Pending' : Formatters.formatDate(payment.paidAt!),
                ),
              ),
              Text(
                Formatters.formatCurrency(payment.amount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final items = <_TimelineEntry>[
      ...customer.paymentHistory.map(
        (payment) => _TimelineEntry(
          title: 'Payment received',
          subtitle: payment.mode ?? payment.status,
          date: payment.paidAt,
          color: AppColors.success,
        ),
      ),
      ...customer.recentBills.map(
        (bill) => _TimelineEntry(
          title: 'Bill generated',
          subtitle: '${DateFormat('MMM yyyy').format(DateTime(bill.year, bill.month))} ${bill.status}',
          date: bill.generatedAt ?? bill.dueDate,
          color: AppColors.primary,
        ),
      ),
      ...customer.subscriptions.map(
        (subscription) => _TimelineEntry(
          title: 'Subscription active',
          subtitle: subscription.newspaperName,
          date: subscription.startDate,
          color: AppColors.secondary,
        ),
      ),
    ]..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));

    if (items.isEmpty) {
      return const Center(child: Text('Timeline empty hai'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item.subtitle),
                  ],
                ),
              ),
              Text(
                item.date == null ? '--' : Formatters.formatDate(item.date!),
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SubscriptionsTab extends ConsumerWidget {
  const _SubscriptionsTab({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final subs = state.subscriptions;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.addSubscription, arguments: customerId),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Subscription'),
          ),
        ),
        const SizedBox(height: 12),
        if (subs.isEmpty)
          const _InfoCard(
            title: 'Subscriptions',
            child: Text('Koi subscription nahi hai'),
          )
        else
          ...subs.map((subscription) {
            final isPaused = subscription.status == 'paused';
            return _InfoCard(
              title: subscription.newspaperName,
              child: Column(
                children: [
                  _DataRow(label: 'Plan', value: subscription.planType),
                  _DataRow(label: 'Rate', value: Formatters.formatCurrency(subscription.rate)),
                  _DataRow(label: 'Status', value: subscription.status.toUpperCase()),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final ok = isPaused
                                ? await ref.read(subscriptionProvider.notifier).resume(subscription.id, customerId)
                                : await ref.read(subscriptionProvider.notifier).pause(subscription.id, customerId);
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? (isPaused ? 'Subscription resume ho gayi.' : 'Subscription pause ho gayi.')
                                    : (state.error ?? 'Action failed')),
                              ),
                            );
                            ref.read(customerProvider.notifier).fetchCustomerDetail(customerId);
                          },
                          child: Text(isPaused ? 'Resume' : 'Pause Subscription'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.color,
  });

  final String title;
  final String subtitle;
  final DateTime? date;
  final Color color;
}

class _CustomerDetailShimmer extends StatelessWidget {
  const _CustomerDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 128, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 120,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined, size: 64, color: AppColors.danger),
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

class _EditCustomerDialog extends StatefulWidget {
  const _EditCustomerDialog({required this.customer});

  final CustomerModel customer;

  @override
  State<_EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<_EditCustomerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _areaController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _notesController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone.replaceAll('+91', ''));
    _emailController = TextEditingController(text: widget.customer.email ?? '');
    _addressController = TextEditingController(text: widget.customer.address ?? '');
    _areaController = TextEditingController(text: widget.customer.area ?? '');
    _landmarkController = TextEditingController(text: widget.customer.landmark ?? '');
    _notesController = TextEditingController(text: widget.customer.notes ?? '');
    _category = widget.customer.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Customer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(_nameController, 'Name'),
            _dialogField(_phoneController, 'Phone (10 digits)', keyboardType: TextInputType.phone),
            _dialogField(_emailController, 'Email'),
            _dialogField(_addressController, 'Address', maxLines: 2),
            _dialogField(_areaController, 'Area'),
            _dialogField(_landmarkController, 'Landmark'),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const ['VIP', 'Regular', 'Risky', 'New']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            _dialogField(_notesController, 'Notes', maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(<String, dynamic>{
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'email': _emailController.text.trim(),
              'address': _addressController.text.trim(),
              'area': _areaController.text.trim(),
              'landmark': _landmarkController.text.trim(),
              'category': _category,
              'notes': _notesController.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _PauseCustomerDialog extends StatefulWidget {
  const _PauseCustomerDialog();

  @override
  State<_PauseCustomerDialog> createState() => _PauseCustomerDialogState();
}

class _PauseCustomerDialogState extends State<_PauseCustomerDialog> {
  final TextEditingController _reasonController = TextEditingController(text: 'Vacation');
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pause Customer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('From Date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_fromDate)),
            trailing: const Icon(Icons.date_range_rounded),
            onTap: () => _pickDate(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('To Date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_toDate)),
            trailing: const Icon(Icons.date_range_rounded),
            onTap: () => _pickDate(false),
          ),
          TextFormField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Reason'),
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
            Navigator.of(context).pop(
              _PauseResult(
                fromDate: DateFormat('yyyy-MM-dd').format(_fromDate),
                toDate: DateFormat('yyyy-MM-dd').format(_toDate),
                reason: _reasonController.text.trim().isEmpty ? 'Vacation' : _reasonController.text.trim(),
              ),
            );
          },
          child: const Text('Pause'),
        ),
      ],
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _fromDate = selected;
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = selected;
      }
    });
  }
}

class _PauseResult {
  const _PauseResult({
    required this.fromDate,
    required this.toDate,
    required this.reason,
  });

  final String fromDate;
  final String toDate;
  final String reason;
}
