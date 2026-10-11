import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../models/bill_model.dart';
import '../providers/bill_provider.dart';

class BillListScreen extends ConsumerStatefulWidget {
  const BillListScreen({super.key});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  final List<String> _statuses = const ['All', 'Unpaid', 'Paid', 'Overdue', 'Partial'];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billProvider.notifier).loadBills(refresh: true);
      ref.read(billProvider.notifier).loadDefaulters();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      ref.read(billProvider.notifier).loadBills();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billProvider);
    final years = List<int>.generate(5, (index) => DateTime.now().year - 2 + index);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.defaulters),
            icon: const Icon(Icons.warning_amber_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        onPressed: state.isGenerating ? null : _generateBills,
        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        label: Text(
          state.isGenerating ? 'Generating...' : 'Generate Bills',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: () => ref.read(billProvider.notifier).loadBills(refresh: true),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                scrollDirection: Axis.horizontal,
                children: _statuses.map((String status) {
                  final selected = state.status == status;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(status),
                      selected: selected,
                      onSelected: (_) => ref.read(billProvider.notifier).setStatus(status),
                      selectedColor: AppColors.primary.withValues(alpha: 0.14),
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: state.month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(12, (index) => index + 1)
                          .map(
                            (month) => DropdownMenuItem(
                              value: month,
                              child: Text(DateFormat('MMMM').format(DateTime(2026, month))),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => ref.read(billProvider.notifier).setMonth(value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: state.year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: years
                          .map((year) => DropdownMenuItem(value: year, child: Text('$year')))
                          .toList(),
                      onChanged: (value) => ref.read(billProvider.notifier).setYear(value),
                    ),
                  ),
                ],
              ),
            ),
            if (state.generateMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _InfoBanner(message: state.generateMessage!),
              ),
            Expanded(
              child: state.isLoading && state.bills.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.bills.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 140),
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Center(child: Text('Bills nahi mile')),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: state.bills.length + (state.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.bills.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _BillCard(bill: state.bills[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateBills() async {
    final ok = await ref.read(billProvider.notifier).generateBills();
    if (!mounted) {
      return;
    }
    final state = ref.read(billProvider);
    final message = ok
        ? (state.generateMessage ?? 'Bills generated')
        : (state.error ?? 'Bills generate nahi hue');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});

  final BillModel bill;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(bill.year, bill.month));
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.billDetail, arguments: bill.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bill.customerName ?? 'Customer',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusChip(status: bill.daysOverdue > 0 && bill.status == 'unpaid' ? 'Overdue' : bill.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              bill.phone ?? '',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  Formatters.formatCurrency(bill.finalAmount),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (bill.daysOverdue > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${bill.daysOverdue} days overdue',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status.toLowerCase()) {
      'paid' => (AppColors.success.withValues(alpha: 0.14), AppColors.success),
      'partial' => (AppColors.warning.withValues(alpha: 0.16), AppColors.warning),
      'overdue' => (AppColors.danger.withValues(alpha: 0.14), AppColors.danger),
      _ => (AppColors.primary.withValues(alpha: 0.12), AppColors.primary),
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
