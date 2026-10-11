import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../auth/providers/auth_provider.dart';
import '../customer_app/providers/customer_app_provider.dart';
import '../customer_app/screens/customer_bills_screen.dart';
import '../customer_app/screens/customer_profile_screen.dart';
import '../customer_app/screens/delivery_status_screen.dart';
import '../customer_app/screens/my_newspapers_screen.dart';
import '../customer_app/screens/payment_screen.dart';
import '../customer_app/screens/raise_complaint_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    _CustomerNavItem('Home', Icons.home_outlined),
    _CustomerNavItem('Bills', Icons.receipt_long_outlined),
    _CustomerNavItem('Papers', Icons.newspaper_outlined),
    _CustomerNavItem('Complaints', Icons.report_problem_outlined),
    _CustomerNavItem('Profile', Icons.person_outline),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customerAppProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final state = ref.watch(customerAppProvider);
    final user = authState.currentUser;
    final appData = state.data;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());
    final currentBill = appData?.currentBill;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PaperPay'),
        actions: [
          IconButton(
            onPressed: () => ref.read(customerAppProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(customerAppProvider.notifier).load(),
        child: state.isLoading && appData == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Namaste ${appData?.customer.name.isNotEmpty == true ? appData!.customer.name : (user?.name ?? 'Customer')}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.error ?? 'Aaj ka bill aur delivery update yahin dikhega.',
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF274CB8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A1E3A8A),
                          blurRadius: 24,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                monthLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                currentBill?.status.toUpperCase() ?? 'NO BILL',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          Formatters.formatCurrency(currentBill?.finalAmount ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentBill?.dueDate == null
                              ? 'Current bill ready hote hi yahan due date dikhegi.'
                              : 'Due date: ${Formatters.formatDate(currentBill!.dueDate!)}',
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              minimumSize: const Size.fromHeight(64),
                            ),
                            onPressed: currentBill == null
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PaymentScreen(bill: currentBill),
                                      ),
                                    );
                                  },
                            child: const Text('PAY NOW'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _QuickInfoCard(
                        icon: Icons.newspaper_rounded,
                        label: 'Papers Count',
                        value: '${appData?.quickInfo.papersCount ?? 0}',
                        color: AppColors.primary,
                        onTap: () => _openPage(const MyNewspapersScreen()),
                      ),
                      _QuickInfoCard(
                        icon: Icons.local_shipping_rounded,
                        label: 'Today Delivery',
                        value: _deliveryLabel(appData?.quickInfo.todayDeliveryStatus),
                        color: (appData?.quickInfo.todayDeliveryStatus == 'delivered')
                            ? AppColors.success
                            : AppColors.warning,
                        onTap: () => _openPage(const DeliveryStatusScreen()),
                      ),
                      _QuickInfoCard(
                        icon: Icons.stars_rounded,
                        label: 'Loyalty Points',
                        value: '${appData?.loyaltyPoints ?? 0}',
                        color: AppColors.success,
                        onTap: () => _openPage(const CustomerBillsScreen()),
                      ),
                      _QuickInfoCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Outstanding',
                        value: Formatters.formatCurrency(appData?.customer.totalOutstanding ?? 0),
                        color: AppColors.secondary,
                        onTap: () => _openPage(const CustomerBillsScreen()),
                      ),
                    ],
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
                          'Account Summary',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Phone: ${appData?.customer.phone ?? user?.phone ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('Area: ${appData?.customer.area ?? '-'}'),
                        const SizedBox(height: 8),
                        Text('Language: ${user?.language == 'hi' ? 'Hindi' : 'English'}'),
                        const SizedBox(height: 8),
                        Text('Updated: ${Formatters.formatDate(DateTime.now())}'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          _openTab(index);
        },
        destinations: _destinations
            .map((_CustomerNavItem item) => NavigationDestination(icon: Icon(item.icon), label: item.label))
            .toList(),
      ),
    );
  }

  void _openTab(int index) {
    final page = switch (index) {
      1 => const CustomerBillsScreen(),
      2 => const MyNewspapersScreen(),
      3 => const RaiseComplaintScreen(),
      4 => const CustomerProfileScreen(),
      _ => null,
    };

    if (index == 0 || page == null) {
      return;
    }

    _openPage(page);
  }

  String _deliveryLabel(String? status) {
    return switch (status) {
      'delivered' => 'Delivered',
      'missed' => 'Missed',
      'wrong_paper' => 'Wrong Paper',
      'wet_paper' => 'Wet Paper',
      _ => 'Pending',
    };
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  const _QuickInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _CustomerNavItem {
  const _CustomerNavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
