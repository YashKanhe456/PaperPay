import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = const ['All', 'VIP', 'Regular', 'Risky', 'New'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerProvider.notifier).loadCustomers(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(customerProvider.notifier).loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        onPressed: () async {
          await Navigator.of(context).pushNamed(AppRoutes.addCustomer);
          if (mounted) {
            ref.read(customerProvider.notifier).loadCustomers(refresh: true);
          }
        },
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text(
          'Add Customer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: () => ref.read(customerProvider.notifier).loadCustomers(refresh: true),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  ref.read(customerProvider.notifier).setSearch(value);
                },
                decoration: InputDecoration(
                  hintText: 'Name ya phone se search karein',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(customerProvider.notifier).setSearch('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: _categories.map((category) {
                  final selected = state.category == category;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      selected: selected,
                      onSelected: (_) {
                        ref.read(customerProvider.notifier).setCategory(category);
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.14),
                      label: Text(category),
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading && state.customers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.customers.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'Customers nahi mile',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: state.customers.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.customers.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final customer = state.customers[index];
                            return _CustomerCard(customer: customer);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.customerDetail, arguments: customer.id);
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
                    customer.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _categoryColor(customer.category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    customer.category,
                    style: TextStyle(
                      color: _categoryColor(customer.category),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.black.withValues(alpha: 0.55)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customer.area?.isNotEmpty == true ? customer.area! : 'Area not added',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    customer.totalOutstanding > 0
                        ? 'Outstanding ${Formatters.formatCurrency(customer.totalOutstanding)}'
                        : 'No outstanding',
                    style: TextStyle(
                      color: customer.totalOutstanding > 0
                          ? AppColors.danger
                          : AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (customer.daysOverdue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${customer.daysOverdue} days overdue',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'vip':
        return AppColors.secondary;
      case 'risky':
        return AppColors.danger;
      case 'regular':
        return AppColors.primary;
      default:
        return AppColors.success;
    }
  }
}
