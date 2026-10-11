import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/formatters.dart';
import 'providers/dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).load();
    });
  }

  Future<void> _reload() => ref.read(dashboardProvider.notifier).load();

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);

    final routes = <String>[
      AppRoutes.adminDashboard,
      AppRoutes.customers,
      AppRoutes.bills,
      AppRoutes.payments,
      AppRoutes.delivery,
      AppRoutes.reports,
    ];

    Navigator.of(context).pushNamed(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'PaperPay',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PaperPay Agency',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.newspaper_rounded, color: AppColors.primary),
              title: const Text('Newspapers', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushNamed(context, AppRoutes.newspapers),
            ),
            ListTile(
              leading: const Icon(Icons.payments_rounded, color: AppColors.primary),
              title: const Text('Incoming Payments', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushNamed(context, AppRoutes.payments),
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_rounded, color: AppColors.primary),
              title: const Text('Customer Complaints', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushNamed(context, AppRoutes.complaints),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: AppColors.secondary),
              title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: _reload,
        child: _buildBody(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Bills'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Delivery'),
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined_rounded), label: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final state = ref.watch(dashboardProvider);

    if (state.isLoading) {
      return const DashboardShimmer();
    }

    if (state.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.danger.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text(
            state.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _reload,
            child: Text(
              state.error == 'Please logout and login again' ? 'Logout and Login Again' : 'Retry',
            ),
          ),
        ],
      );
    }

    final dashboard = state.data;
    if (dashboard == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 600)],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const SectionTitle('Summary'),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SummaryCard(
                color: AppColors.primary,
                icon: Icons.people_alt_rounded,
                value: dashboard.totalCustomers.toString(),
                label: 'Total Customers',
              ),
              SummaryCard(
                color: AppColors.success,
                icon: Icons.currency_rupee_rounded,
                value: Formatters.formatCurrency(dashboard.todayCollection),
                label: 'Today Collected',
              ),
              SummaryCard(
                color: AppColors.danger,
                icon: Icons.warning_amber_rounded,
                value: Formatters.formatCurrency(dashboard.pendingDues),
                label: 'Pending Dues',
              ),
              SummaryCard(
                color: AppColors.secondary,
                icon: Icons.local_shipping_rounded,
                value: '${dashboard.deliveriesDoneToday}/${dashboard.deliveriesTotalToday}',
                label: 'Deliveries',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Quick Actions'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            QuickActionCard(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Add Customer',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.addCustomer),
            ),
            QuickActionCard(
              icon: Icons.receipt_long_rounded,
              label: 'Generate Bills',
              color: AppColors.success,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.bills),
            ),
            QuickActionCard(
              icon: Icons.campaign_rounded,
              label: 'Send Reminders',
              color: AppColors.secondary,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.defaulters),
            ),
            QuickActionCard(
              icon: Icons.report_problem_rounded,
              label: 'View Defaulters',
              color: AppColors.danger,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.defaulters),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Monthly Revenue'),
        const SizedBox(height: 12),
        RevenueChart(bars: state.monthlyBars),
        const SizedBox(height: 24),
        Row(
          children: [
            const SectionTitle('Recent Activity'),
            const Spacer(),
            Text(
              '${dashboard.collectionRate.toStringAsFixed(0)}% collection',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...dashboard.recentActivity.map(_buildActivityTile),
      ],
    );
  }

  Widget _buildActivityTile(ActivityItem item) {
    final style = _activityStyle(item.type);
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.$2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.$1, color: style.$2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.timeLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _activityStyle(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return (Icons.payments_rounded, AppColors.success);
      case 'missed':
        return (Icons.cancel_rounded, AppColors.danger);
      case 'new_customer':
      case 'customer':
        return (Icons.person_add_alt_rounded, AppColors.primary);
      case 'complaint':
        return (Icons.report_gmailerrorred_rounded, AppColors.secondary);
      default:
        return (Icons.notifications_active_rounded, AppColors.warning);
    }
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final Color color;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 116,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class RevenueChart extends StatelessWidget {
  const RevenueChart({required this.bars, super.key});

  final List<MonthlyBar> bars;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _maxY,
          gridData: FlGridData(
            show: true,
            horizontalInterval: _maxY <= 0 ? 1 : _maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.black.withValues(alpha: 0.06), strokeWidth: 1);
            },
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value == 0 ? '0' : '${(value / 1000).round()}k',
                    style: TextStyle(fontSize: 11, color: Colors.black.withValues(alpha: 0.45)),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      bars[index].label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(bars.length, (index) {
            final item = bars[index];
            final isCurrentMonth = index == bars.length - 1;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.collected.toDouble(),
                  width: 20,
                  color: isCurrentMonth ? AppColors.secondary : AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  double get _maxY {
    if (bars.isEmpty) return 100;
    final highest = bars
        .map((item) => item.collected)
        .fold<double>(0, (previous, value) => value > previous ? value : previous);
    return highest <= 0 ? 100 : highest * 1.3;
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

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
            height: 116,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: List.generate(
              4,
              (_) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 260,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 72,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
