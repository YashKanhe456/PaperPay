import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/formatters.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late final TabController _tabController;
  late int _selectedMonth;
  late int _selectedYear;
  final int _selectedNav = 5;
  bool _isLoading = true;
  String? _error;
  ReportsBundle? _bundle;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final agencyId = Hive.box('user').get('agency_id')?.toString();
    if (agencyId == null || agencyId.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please logout and login again';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final options = await _apiService.authOptions();
      final dashboard = await _safeGet(
        '/reports/dashboard',
        {'agency_id': agencyId},
        options,
      );
      final monthly = await _safeGet(
        '/reports/monthly',
        {'agency_id': agencyId, 'year': _selectedYear},
        options,
      );
      final collection = await _safeGet(
        '/reports/collection',
        {
          'agency_id': agencyId,
          'month': _selectedMonth,
          'year': _selectedYear,
        },
        options,
      );
      final profitLoss = await _safeGet(
        '/reports/pl',
        {
          'agency_id': agencyId,
          'month': _selectedMonth,
          'year': _selectedYear,
        },
        options,
      );
      final delivery = await _safeGet(
        '/reports/delivery',
        {
          'agency_id': agencyId,
          'month': _selectedMonth,
          'year': _selectedYear,
        },
        options,
      );

      setState(() {
        _bundle = ReportsBundle.fromResponses(
          dashboard: dashboard,
          monthly: monthly,
          collection: collection,
          profitLoss: profitLoss,
          delivery: delivery,
        );
        _isLoading = false;
      });
    } on DioException catch (error) {
      final data = error.response?.data;
      setState(() {
        _isLoading = false;
        _error = error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout
            ? 'Request timed out. Please try again.'
            : data is Map<String, dynamic> && data['message'] is String
                ? data['message'] as String
                : 'Reports load nahi ho paaye.';
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Reports load nahi ho paaye.';
      });
    }
  }

  Future<dynamic> _safeGet(
    String path,
    Map<String, dynamic> queryParameters,
    Options options,
  ) async {
    try {
      final response = await _apiService.dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      ).timeout(ApiService.requestTimeout);
      return response.data;
    } on DioException {
      return path.endsWith('/monthly') ? <dynamic>[] : <String, dynamic>{};
    }
  }

  void _onNavTap(int index) {
    if (index == _selectedNav) {
      return;
    }
    final routes = <String>[
      AppRoutes.adminDashboard,
      AppRoutes.customers,
      AppRoutes.bills,
      AppRoutes.payments,
      AppRoutes.delivery,
      AppRoutes.reports,
    ];
    Navigator.of(context).pushReplacementNamed(routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _HeaderFilterBar(
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
            onMonthChanged: (value) {
              setState(() => _selectedMonth = value);
              _loadReports();
            },
            onYearChanged: (value) {
              setState(() => _selectedYear = value);
              _loadReports();
            },
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFFF97316),
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Monthly'),
              Tab(text: 'Collection'),
              Tab(text: 'P&L'),
              Tab(text: 'Delivery'),
            ],
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
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
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined_rounded), label: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _ReportsShimmer();
    }

    if (_error != null) {
      return _ReportsErrorState(message: _error!, onRetry: _loadReports);
    }

    final bundle = _bundle;
    if (bundle == null) {
      return const SizedBox.shrink();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _DashboardTab(bundle: bundle),
        _MonthlyTab(items: bundle.monthly.months),
        _CollectionTab(collection: bundle.collection),
        _ProfitLossTab(report: bundle.profitLoss),
        _DeliveryTab(report: bundle.delivery),
      ],
    );
  }
}

class _HeaderFilterBar extends StatelessWidget {
  const _HeaderFilterBar({
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(5, (index) => DateTime.now().year - 2 + index);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(labelText: 'Month'),
              items: List.generate(12, (index) => index + 1)
                  .map(
                    (month) => DropdownMenuItem(
                      value: month,
                      child: Text(DateFormat('MMMM').format(DateTime(2026, month))),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onMonthChanged(value);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedYear,
              decoration: const InputDecoration(labelText: 'Year'),
              items: years.map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
              onChanged: (value) {
                if (value != null) {
                  onYearChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.bundle});

  final ReportsBundle bundle;

  @override
  Widget build(BuildContext context) {
    final dashboard = bundle.dashboard;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(label: 'Customers', value: '${dashboard.totalCustomers}', color: AppColors.primary),
            _SummaryCard(label: 'Today Collection', value: Formatters.formatCurrency(dashboard.todayCollection), color: AppColors.success),
            _SummaryCard(label: 'Pending Dues', value: Formatters.formatCurrency(dashboard.pendingDues), color: AppColors.danger),
            _SummaryCard(
              label: 'Deliveries',
              value: '${dashboard.deliveriesDoneToday}/${dashboard.deliveriesTotalToday}',
              color: AppColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MonthlyTrendCard(items: bundle.monthly.months),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Recent Activity',
          child: bundle.dashboard.recentActivity.isEmpty
              ? const Text('Recent activity available nahi hai.')
              : Column(
                  children: bundle.dashboard.recentActivity.map((item) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: item.color.withValues(alpha: 0.12),
                        child: Icon(item.icon, color: item.color),
                      ),
                      title: Text(item.label),
                      subtitle: Text(Formatters.formatDate(item.time)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _MonthlyTab extends StatelessWidget {
  const _MonthlyTab({required this.items});

  final List<MonthlyReportPoint> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MonthlyTrendCard(items: items),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Month-wise Summary',
          child: Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(Formatters.formatCurrency(item.billed)),
                    const SizedBox(width: 12),
                    Text(
                      Formatters.formatCurrency(item.collected),
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({required this.collection});

  final CollectionReport collection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Billed',
                value: Formatters.formatCurrency(collection.totalBilled),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Collected',
                value: Formatters.formatCurrency(collection.totalCollected),
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          label: 'Collection Rate',
          value: '${collection.collectionRate.toStringAsFixed(0)}%',
          color: AppColors.secondary,
        ),
        const SizedBox(height: 18),
        _PaperWiseRevenueChart(items: collection.paperWise),
        const SizedBox(height: 18),
        _PaymentModePieChart(items: collection.paymentModes),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Area-wise Collection',
          child: collection.areaWise.isEmpty
              ? const Text('Area-wise data available nahi hai.')
              : Column(
                  children: collection.areaWise.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text(Formatters.formatCurrency(item.value)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _ProfitLossTab extends StatelessWidget {
  const _ProfitLossTab({required this.report});

  final ProfitLossReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Revenue', value: Formatters.formatCurrency(report.revenue), color: AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Expenses', value: Formatters.formatCurrency(report.expenses), color: AppColors.danger)),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          label: 'Profit',
          value: Formatters.formatCurrency(report.profit),
          color: report.profit >= 0 ? AppColors.primary : AppColors.danger,
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Margin by Newspaper',
          child: report.newspaperMargins.isEmpty
              ? const Text('Margin data available nahi hai.')
              : Column(
                  children: report.newspaperMargins.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.newspaper, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text('${item.marginPercent.toStringAsFixed(1)}%'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({required this.report});

  final DeliveryReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (report.items.isEmpty)
          const _SectionCard(
            title: 'Delivery',
            child: Text('Delivery performance data available nahi hai.'),
          )
        else
          ...report.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SectionCard(
                title: item.name,
                child: Row(
                  children: [
                    Expanded(child: _MiniMetric(label: 'Success', value: '${item.successRate.toStringAsFixed(0)}%', color: AppColors.success)),
                    Expanded(child: _MiniMetric(label: 'Missed', value: '${item.missedCount}', color: AppColors.danger)),
                    Expanded(child: _MiniMetric(label: 'Photo', value: '${item.photoComplianceRate.toStringAsFixed(0)}%', color: AppColors.secondary)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.items});

  final List<MonthlyReportPoint> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Monthly Chart',
      child: SizedBox(
        height: 260,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.black.withValues(alpha: 0.05),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= items.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(items[index].label, style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(items.length, (index) {
              final item = items[index];
              final isCurrent = item.month == DateTime.now().month;
              return BarChartGroupData(
                x: index,
                barsSpace: 6,
                barRods: [
                  BarChartRodData(
                    toY: item.billed,
                    width: 12,
                    color: isCurrent ? AppColors.secondary : AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  BarChartRodData(
                    toY: item.collected,
                    width: 12,
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  BarChartRodData(
                    toY: item.pending,
                    width: 12,
                    color: AppColors.danger.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PaperWiseRevenueChart extends StatelessWidget {
  const _PaperWiseRevenueChart({required this.items});

  final List<BreakdownValue> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Paper-wise Revenue',
      child: SizedBox(
        height: 240,
        child: items.isEmpty
            ? const Center(child: Text('Paper-wise data available nahi hai.'))
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= items.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(items[index].label, style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(items.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: items[index].value,
                          width: 18,
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
      ),
    );
  }
}

class _PaymentModePieChart extends StatelessWidget {
  const _PaymentModePieChart({required this.items});

  final List<BreakdownValue> items;

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
    ];

    return _SectionCard(
      title: 'Payment Modes',
      child: items.isEmpty
          ? const Text('Payment mode data available nahi hai.')
          : Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: List.generate(items.length, (index) {
                        final item = items[index];
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: item.value,
                          radius: 50,
                          title: item.value.toStringAsFixed(0),
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(items.length, (index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.label)),
                        Text(Formatters.formatCurrency(item.value)),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _ReportsShimmer extends StatelessWidget {
  const _ReportsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.analytics_outlined, size: 64, color: AppColors.danger),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class ReportsBundle {
  ReportsBundle({
    required this.dashboard,
    required this.monthly,
    required this.collection,
    required this.profitLoss,
    required this.delivery,
  });

  factory ReportsBundle.fromResponses({
    required Map<String, dynamic> dashboard,
    required dynamic monthly,
    required Map<String, dynamic> collection,
    required Map<String, dynamic> profitLoss,
    required Map<String, dynamic> delivery,
  }) {
    return ReportsBundle(
      dashboard: ReportsDashboard.fromJson(dashboard),
      monthly: MonthlyTrendReport.fromJson(monthly),
      collection: CollectionReport.fromJson(collection),
      profitLoss: ProfitLossReport.fromJson(profitLoss),
      delivery: DeliveryReport.fromJson(delivery),
    );
  }

  final ReportsDashboard dashboard;
  final MonthlyTrendReport monthly;
  final CollectionReport collection;
  final ProfitLossReport profitLoss;
  final DeliveryReport delivery;
}

class ReportsDashboard {
  ReportsDashboard({
    required this.totalCustomers,
    required this.todayCollection,
    required this.pendingDues,
    required this.deliveriesDoneToday,
    required this.deliveriesTotalToday,
    required this.overdueCount,
    required this.monthlyRevenue,
    required this.collectionRate,
    required this.recentActivity,
  });

  factory ReportsDashboard.fromJson(Map<String, dynamic> json) {
    return ReportsDashboard(
      totalCustomers: Formatters.parseInt(json['total_customers']),
      todayCollection: Formatters.parseDouble(json['today_collection']),
      pendingDues: Formatters.parseDouble(json['pending_dues']),
      deliveriesDoneToday: Formatters.parseInt(json['deliveries_done_today']),
      deliveriesTotalToday: Formatters.parseInt(json['deliveries_total_today']),
      overdueCount: Formatters.parseInt(json['overdue_count']),
      monthlyRevenue: Formatters.parseDouble(json['monthly_revenue']),
      collectionRate: Formatters.parseDouble(json['collection_rate']),
      recentActivity: ((json['recent_activity'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => RecentActivity.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  final int totalCustomers;
  final double todayCollection;
  final double pendingDues;
  final int deliveriesDoneToday;
  final int deliveriesTotalToday;
  final int overdueCount;
  final double monthlyRevenue;
  final double collectionRate;
  final List<RecentActivity> recentActivity;
}

class RecentActivity {
  RecentActivity({
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    final action = json['action']?.toString() ?? 'activity';
    final (color, icon, label) = switch (action) {
      'payment_received' => (AppColors.success, Icons.payments_rounded, 'Payment received'),
      'customer_created' => (AppColors.primary, Icons.person_add_alt_1_rounded, 'New customer added'),
      'complaint_created' => (AppColors.secondary, Icons.report_problem_rounded, 'Complaint raised'),
      'delivery_missed' => (AppColors.danger, Icons.local_shipping_outlined, 'Delivery issue'),
      _ => (Colors.grey, Icons.history_rounded, action.replaceAll('_', ' ')),
    };
    return RecentActivity(
      label: label,
      time: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      color: color,
      icon: icon,
    );
  }

  final String label;
  final DateTime time;
  final Color color;
  final IconData icon;
}

class MonthlyTrendReport {
  MonthlyTrendReport({required this.months});

  factory MonthlyTrendReport.fromJson(dynamic json) {
    final raw = json is List
        ? json
        : json is Map<String, dynamic>
            ? (json['months'] as List<dynamic>? ?? const [])
            : const [];
    return MonthlyTrendReport(
      months: raw
          .whereType<Map>()
          .map((item) => MonthlyReportPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  final List<MonthlyReportPoint> months;
}

class MonthlyReportPoint {
  MonthlyReportPoint({
    required this.month,
    required this.billed,
    required this.collected,
    required this.pending,
  });

  factory MonthlyReportPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyReportPoint(
      month: Formatters.parseInt(json['month']),
      billed: Formatters.parseDouble(json['billed']),
      collected: Formatters.parseDouble(json['collected']),
      pending: Formatters.parseDouble(json['pending']),
    );
  }

  final int month;
  final double billed;
  final double collected;
  final double pending;

  String get label => DateFormat('MMM').format(DateTime(2024, month));
}

class CollectionReport {
  CollectionReport({
    required this.totalBilled,
    required this.totalCollected,
    required this.collectionRate,
    required this.paperWise,
    required this.areaWise,
    required this.paymentModes,
  });

  factory CollectionReport.fromJson(Map<String, dynamic> json) {
    return CollectionReport(
      totalBilled: Formatters.parseDouble(json['total_billed']),
      totalCollected: Formatters.parseDouble(json['total_collected']),
      collectionRate: Formatters.parseDouble(json['collection_rate'] ?? json['rate']),
      paperWise: ((json['paper_wise'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => BreakdownValue.fromJson(Map<String, dynamic>.from(item), ['newspaper'], ['collected', 'billed']))
          .toList(),
      areaWise: ((json['area_wise'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => BreakdownValue.fromJson(Map<String, dynamic>.from(item), ['area'], ['collected', 'billed']))
          .toList(),
      paymentModes: (((json['payment_mode'] as List<dynamic>?) ?? (json['payment_mode_wise'] as List<dynamic>?) ?? const []))
          .whereType<Map>()
          .map((item) => BreakdownValue.fromJson(Map<String, dynamic>.from(item), ['mode'], ['amount', 'collected']))
          .toList(),
    );
  }

  final double totalBilled;
  final double totalCollected;
  final double collectionRate;
  final List<BreakdownValue> paperWise;
  final List<BreakdownValue> areaWise;
  final List<BreakdownValue> paymentModes;
}

class BreakdownValue {
  BreakdownValue({
    required this.label,
    required this.value,
  });

  factory BreakdownValue.fromJson(
    Map<String, dynamic> json,
    List<String> labelKeys,
    List<String> valueKeys,
  ) {
    String label = '-';
    for (final key in labelKeys) {
      if (json[key] != null) {
        label = json[key].toString();
        break;
      }
    }

    double value = 0;
    for (final key in valueKeys) {
      if (json[key] != null) {
        value = Formatters.parseDouble(json[key]);
        break;
      }
    }

    return BreakdownValue(label: label, value: value);
  }

  final String label;
  final double value;
}

class ProfitLossReport {
  ProfitLossReport({
    required this.revenue,
    required this.expenses,
    required this.profit,
    required this.newspaperMargins,
  });

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    return ProfitLossReport(
      revenue: Formatters.parseDouble(json['revenue']),
      expenses: Formatters.parseDouble(json['expenses']),
      profit: Formatters.parseDouble(json['profit']),
      newspaperMargins: ((json['newspaper_margins'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => NewspaperMargin.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  final double revenue;
  final double expenses;
  final double profit;
  final List<NewspaperMargin> newspaperMargins;
}

class NewspaperMargin {
  NewspaperMargin({
    required this.newspaper,
    required this.marginPercent,
  });

  factory NewspaperMargin.fromJson(Map<String, dynamic> json) {
    return NewspaperMargin(
      newspaper: json['newspaper']?.toString() ?? 'Paper',
      marginPercent: Formatters.parseDouble(json['margin_percent']),
    );
  }

  final String newspaper;
  final double marginPercent;
}

class DeliveryReport {
  DeliveryReport({required this.items});

  factory DeliveryReport.fromJson(Map<String, dynamic> json) {
    return DeliveryReport(
      items: ((json['delivery_performance'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((item) => DeliveryPerformance.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  final List<DeliveryPerformance> items;
}

class DeliveryPerformance {
  DeliveryPerformance({
    required this.name,
    required this.successRate,
    required this.missedCount,
    required this.photoComplianceRate,
  });

  factory DeliveryPerformance.fromJson(Map<String, dynamic> json) {
    return DeliveryPerformance(
      name: json['delivery_boy_name']?.toString() ?? 'Unassigned',
      successRate: Formatters.parseDouble(json['success_rate']),
      missedCount: Formatters.parseInt(json['missed_count']),
      photoComplianceRate: Formatters.parseDouble(json['photo_compliance_rate']),
    );
  }

  final String name;
  final double successRate;
  final int missedCount;
  final double photoComplianceRate;
}
