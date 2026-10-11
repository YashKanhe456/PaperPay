import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/services/api_service.dart';
import '../../../core/utils/formatters.dart';

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

class DashboardState {
  const DashboardState({
    this.isLoading = false,
    this.error,
    this.data,
    this.monthlyBars = const <MonthlyBar>[],
  });

  final bool isLoading;
  final String? error;
  final DashboardData? data;
  final List<MonthlyBar> monthlyBars;

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    DashboardData? data,
    List<MonthlyBar>? monthlyBars,
    bool clearError = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      data: data ?? this.data,
      monthlyBars: monthlyBars ?? this.monthlyBars,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardState();

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> load() async {
    final box = Hive.box('user');
    final agencyId = box.get('agency_id')?.toString();

    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Please logout and login again',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final options = await _api.authOptions();
      final now = DateTime.now();
      final responses = await Future.wait<Response<dynamic>>([
        _api.dio
            .get<Map<String, dynamic>>(
              '/reports/dashboard',
              queryParameters: {'agency_id': agencyId},
              options: options,
            )
            .timeout(ApiService.requestTimeout),
        _api.dio
            .get<Map<String, dynamic>>(
              '/reports/monthly',
              queryParameters: {'agency_id': agencyId, 'year': now.year},
              options: options,
            )
            .timeout(ApiService.requestTimeout),
      ]);

      final dashboardJson = _asMap(responses[0].data);
      final monthlyJson = _asMap(responses[1].data);
      debugPrint('Dashboard response: $dashboardJson');
      debugPrint('Dashboard monthly response: $monthlyJson');

      final monthlyRows = (monthlyJson['months'] as List<dynamic>? ?? const []);
      final monthlyBars = monthlyRows
          .whereType<Map>()
          .map((item) => MonthlyBar.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(
        isLoading: false,
        data: DashboardData.fromJson(dashboardJson),
        monthlyBars: _lastSixMonths(monthlyBars, now),
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(error),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Dashboard load failed: $error',
      );
    }
  }

  List<MonthlyBar> _lastSixMonths(List<MonthlyBar> bars, DateTime now) {
    final byMonth = <int, MonthlyBar>{
      for (final bar in bars) bar.month: bar,
    };

    return List<MonthlyBar>.generate(6, (index) {
      final target = DateTime(now.year, now.month - (5 - index));
      return byMonth[target.month] ??
          MonthlyBar(
            month: target.month,
            billed: 0,
            collected: 0,
            pending: 0,
          );
    });
  }

  String _errorMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }

    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }

    return 'Unable to load dashboard right now.';
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}

class DashboardData {
  DashboardData({
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

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final recent = (json['recent_activity'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((item) => ActivityItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return DashboardData(
      totalCustomers: Formatters.parseInt(json['total_customers']),
      todayCollection: Formatters.parseDouble(json['today_collection']),
      pendingDues: Formatters.parseDouble(json['pending_dues']),
      deliveriesDoneToday: Formatters.parseInt(json['deliveries_done_today']),
      deliveriesTotalToday: Formatters.parseInt(json['deliveries_total_today']),
      overdueCount: Formatters.parseInt(json['overdue_count']),
      monthlyRevenue: Formatters.parseDouble(json['monthly_revenue']),
      collectionRate: Formatters.parseDouble(json['collection_rate']),
      recentActivity: recent.take(10).toList(),
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
  final List<ActivityItem> recentActivity;
}

class MonthlyBar {
  const MonthlyBar({
    required this.month,
    required this.billed,
    required this.collected,
    required this.pending,
  });

  factory MonthlyBar.fromJson(Map<String, dynamic> json) {
    return MonthlyBar(
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

  String get label {
    const labels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return month < 1 || month > 12 ? '--' : labels[month - 1];
  }
}

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timeLabel,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final action = (json['action'] as String? ?? 'Activity').trim();
    final entity = (json['entity'] as String? ?? '').trim();
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    final type = _resolveType(action, entity);

    return ActivityItem(
      title: action.isEmpty ? 'Recent activity' : _titleCase(action.replaceAll('_', ' ')),
      subtitle: entity.isEmpty ? 'PaperPay update' : _titleCase(entity.replaceAll('_', ' ')),
      type: type,
      timeLabel: timestamp == null ? '--' : Formatters.formatDate(timestamp),
    );
  }

  final String title;
  final String subtitle;
  final String type;
  final String timeLabel;

  static String _resolveType(String action, String entity) {
    final haystack = '${action.toLowerCase()} ${entity.toLowerCase()}';
    if (haystack.contains('payment')) return 'payment';
    if (haystack.contains('missed')) return 'missed';
    if (haystack.contains('complaint')) return 'complaint';
    if (haystack.contains('customer')) return 'new_customer';
    return 'activity';
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
