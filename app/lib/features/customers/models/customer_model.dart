import '../../../core/utils/formatters.dart';

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.agencyId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.area,
    this.landmark,
    this.gpsLat,
    this.gpsLng,
    this.altContact,
    required this.category,
    required this.status,
    this.startDate,
    required this.totalOutstanding,
    required this.lifetimeValue,
    this.notes,
    this.createdAt,
    this.daysOverdue = 0,
    this.amountOverdue = 0,
    this.subscriptions = const [],
    this.recentBills = const [],
    this.paymentHistory = const [],
    this.healthScore,
  });

  final String id;
  final String agencyId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? area;
  final String? landmark;
  final double? gpsLat;
  final double? gpsLng;
  final String? altContact;
  final String category;
  final String status;
  final DateTime? startDate;
  final double totalOutstanding;
  final double lifetimeValue;
  final String? notes;
  final DateTime? createdAt;
  final int daysOverdue;
  final double amountOverdue;
  final List<CustomerSubscription> subscriptions;
  final List<CustomerBill> recentBills;
  final List<CustomerPayment> paymentHistory;
  final CustomerHealthScore? healthScore;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      agencyId: json['agency_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      area: json['area']?.toString(),
      landmark: json['landmark']?.toString(),
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      altContact: json['alt_contact']?.toString(),
      category: json['category']?.toString() ?? 'New',
      status: json['status']?.toString() ?? 'active',
      startDate: _parseDate(json['start_date']),
      totalOutstanding: Formatters.parseDouble(json['total_outstanding']),
      lifetimeValue: Formatters.parseDouble(json['lifetime_value']),
      notes: json['notes']?.toString(),
      createdAt: _parseDate(json['created_at']),
      daysOverdue: Formatters.parseInt(json['days_overdue']),
      amountOverdue: Formatters.parseDouble(json['amount_overdue']),
      subscriptions: (json['subscriptions'] as List<dynamic>? ?? const [])
          .map((item) => CustomerSubscription.fromJson(item as Map<String, dynamic>))
          .toList(),
      recentBills: (json['recent_bills'] as List<dynamic>? ?? const [])
          .map((item) => CustomerBill.fromJson(item as Map<String, dynamic>))
          .toList(),
      paymentHistory: (json['payment_history'] as List<dynamic>? ?? const [])
          .map((item) => CustomerPayment.fromJson(item as Map<String, dynamic>))
          .toList(),
      healthScore: json['health_score'] is Map<String, dynamic>
          ? CustomerHealthScore.fromJson(json['health_score'] as Map<String, dynamic>)
          : null,
    );
  }

  factory CustomerModel.fromDetailJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return CustomerModel.fromJson({
      ...customer,
      'subscriptions': json['subscriptions'],
      'recent_bills': json['recent_bills'],
      'payment_history': json['payment_history'],
      'health_score': json['health_score'],
    });
  }

  CustomerModel copyWith({
    int? daysOverdue,
    double? amountOverdue,
    List<CustomerSubscription>? subscriptions,
    List<CustomerBill>? recentBills,
    List<CustomerPayment>? paymentHistory,
    CustomerHealthScore? healthScore,
  }) {
    return CustomerModel(
      id: id,
      agencyId: agencyId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      area: area,
      landmark: landmark,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      altContact: altContact,
      category: category,
      status: status,
      startDate: startDate,
      totalOutstanding: totalOutstanding,
      lifetimeValue: lifetimeValue,
      notes: notes,
      createdAt: createdAt,
      daysOverdue: daysOverdue ?? this.daysOverdue,
      amountOverdue: amountOverdue ?? this.amountOverdue,
      subscriptions: subscriptions ?? this.subscriptions,
      recentBills: recentBills ?? this.recentBills,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      healthScore: healthScore ?? this.healthScore,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

class CustomerSubscription {
  const CustomerSubscription({
    required this.id,
    required this.newspaperId,
    required this.newspaperName,
    required this.rate,
    this.startDate,
    this.endDate,
    required this.status,
    required this.planType,
    required this.autoRenew,
    this.pauseFrom,
    this.pauseTo,
  });

  final String id;
  final String newspaperId;
  final String newspaperName;
  final double rate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String planType;
  final bool autoRenew;
  final DateTime? pauseFrom;
  final DateTime? pauseTo;

  factory CustomerSubscription.fromJson(Map<String, dynamic> json) {
    return CustomerSubscription(
      id: json['id']?.toString() ?? '',
      newspaperId: json['newspaper_id']?.toString() ?? '',
      newspaperName: json['newspaper_name']?.toString() ?? '',
      rate: Formatters.parseDouble(json['rate']),
      startDate: CustomerModel._parseDate(json['start_date']),
      endDate: CustomerModel._parseDate(json['end_date']),
      status: json['status']?.toString() ?? 'active',
      planType: json['plan_type']?.toString() ?? 'monthly',
      autoRenew: json['auto_renew'] as bool? ?? true,
      pauseFrom: CustomerModel._parseDate(json['pause_from']),
      pauseTo: CustomerModel._parseDate(json['pause_to']),
    );
  }
}

class CustomerBill {
  const CustomerBill({
    required this.id,
    required this.month,
    required this.year,
    required this.finalAmount,
    this.dueDate,
    required this.status,
    this.generatedAt,
    this.paidAt,
  });

  final String id;
  final int month;
  final int year;
  final double finalAmount;
  final DateTime? dueDate;
  final String status;
  final DateTime? generatedAt;
  final DateTime? paidAt;

  factory CustomerBill.fromJson(Map<String, dynamic> json) {
    return CustomerBill(
      id: json['id']?.toString() ?? '',
      month: Formatters.parseInt(json['month']),
      year: Formatters.parseInt(json['year']),
      finalAmount: Formatters.parseDouble(json['final_amount']),
      dueDate: CustomerModel._parseDate(json['due_date']),
      status: json['status']?.toString() ?? 'unpaid',
      generatedAt: CustomerModel._parseDate(json['generated_at']),
      paidAt: CustomerModel._parseDate(json['paid_at']),
    );
  }
}

class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.amount,
    this.mode,
    required this.status,
    this.gateway,
    this.paidAt,
    this.notes,
    this.billId,
    this.month,
    this.year,
  });

  final String id;
  final double amount;
  final String? mode;
  final String status;
  final String? gateway;
  final DateTime? paidAt;
  final String? notes;
  final String? billId;
  final int? month;
  final int? year;

  factory CustomerPayment.fromJson(Map<String, dynamic> json) {
    return CustomerPayment(
      id: json['id']?.toString() ?? '',
      amount: Formatters.parseDouble(json['amount']),
      mode: json['mode']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      gateway: json['gateway']?.toString(),
      paidAt: CustomerModel._parseDate(json['paid_at']),
      notes: json['notes']?.toString(),
      billId: json['bill_id']?.toString(),
      month: Formatters.parseInt(json['month']),
      year: Formatters.parseInt(json['year']),
    );
  }
}

class CustomerHealthScore {
  const CustomerHealthScore({
    required this.score,
    required this.paymentHistory,
    required this.deliveryIssues,
    required this.tenureMonths,
    required this.referralsMade,
  });

  final int score;
  final int paymentHistory;
  final int deliveryIssues;
  final int tenureMonths;
  final int referralsMade;

  factory CustomerHealthScore.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return CustomerHealthScore(
      score: Formatters.parseInt(json['score']),
      paymentHistory: Formatters.parseInt(breakdown['payment_history']),
      deliveryIssues: Formatters.parseInt(breakdown['delivery_issues']),
      tenureMonths: Formatters.parseInt(breakdown['tenure_months']),
      referralsMade: Formatters.parseInt(breakdown['referrals_made']),
    );
  }
}

class NewspaperOption {
  const NewspaperOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
