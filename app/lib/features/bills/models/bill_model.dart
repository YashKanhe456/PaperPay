import '../../../core/utils/formatters.dart';

class BillModel {
  const BillModel({
    required this.id,
    required this.customerId,
    required this.agencyId,
    required this.month,
    required this.year,
    required this.amount,
    required this.discount,
    required this.lateFee,
    required this.finalAmount,
    this.dueDate,
    required this.status,
    this.generatedAt,
    this.paidAt,
    this.pdfUrl,
    this.notes,
    this.customerName,
    this.phone,
    this.area,
    this.daysOverdue = 0,
    this.billItems = const [],
  });

  final String id;
  final String customerId;
  final String agencyId;
  final int month;
  final int year;
  final double amount;
  final double discount;
  final double lateFee;
  final double finalAmount;
  final DateTime? dueDate;
  final String status;
  final DateTime? generatedAt;
  final DateTime? paidAt;
  final String? pdfUrl;
  final String? notes;
  final String? customerName;
  final String? phone;
  final String? area;
  final int daysOverdue;
  final List<BillItemModel> billItems;

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      agencyId: json['agency_id']?.toString() ?? '',
      month: Formatters.parseInt(json['month']),
      year: Formatters.parseInt(json['year']),
      amount: Formatters.parseDouble(json['amount']),
      discount: Formatters.parseDouble(json['discount']),
      lateFee: Formatters.parseDouble(json['late_fee']),
      finalAmount: Formatters.parseDouble(json['final_amount']),
      dueDate: _parseDate(json['due_date']),
      status: json['status']?.toString() ?? 'unpaid',
      generatedAt: _parseDate(json['generated_at']),
      paidAt: _parseDate(json['paid_at']),
      pdfUrl: json['pdf_url']?.toString(),
      notes: json['notes']?.toString(),
      customerName: json['customer_name']?.toString(),
      phone: json['phone']?.toString(),
      area: json['area']?.toString(),
      daysOverdue: json['days_overdue'] != null 
          ? Formatters.parseInt(json['days_overdue']) 
          : _deriveOverdueDays(
        _parseDate(json['due_date']),
        json['status']?.toString() ?? 'unpaid',
      ),
      billItems: (json['bill_items'] as List<dynamic>? ?? const [])
          .map((item) => BillItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  BillModel copyWith({
    int? daysOverdue,
    List<BillItemModel>? billItems,
    String? status,
    DateTime? paidAt,
  }) {
    return BillModel(
      id: id,
      customerId: customerId,
      agencyId: agencyId,
      month: month,
      year: year,
      amount: amount,
      discount: discount,
      lateFee: lateFee,
      finalAmount: finalAmount,
      dueDate: dueDate,
      status: status ?? this.status,
      generatedAt: generatedAt,
      paidAt: paidAt ?? this.paidAt,
      pdfUrl: pdfUrl,
      notes: notes,
      customerName: customerName,
      phone: phone,
      area: area,
      daysOverdue: daysOverdue ?? this.daysOverdue,
      billItems: billItems ?? this.billItems,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  static int _deriveOverdueDays(DateTime? dueDate, String status) {
    if (dueDate == null || status.toLowerCase() == 'paid') {
      return 0;
    }
    final diff = DateTime.now().difference(dueDate).inDays;
    return diff > 0 ? diff : 0;
  }
}

class BillItemModel {
  const BillItemModel({
    required this.newspaperName,
    required this.days,
    required this.ratePerDay,
    required this.total,
  });

  final String newspaperName;
  final int days;
  final double ratePerDay;
  final double total;

  factory BillItemModel.fromJson(Map<String, dynamic> json) {
    return BillItemModel(
      newspaperName: json['newspaper_name']?.toString() ?? 'Paper',
      days: json['billable_days'] != null
          ? Formatters.parseInt(json['billable_days'])
          : Formatters.parseInt(json['days']),
      ratePerDay: json['rate_per_day'] != null
          ? Formatters.parseDouble(json['rate_per_day'])
          : Formatters.parseDouble(json['rate']),
      total: json['amount'] != null
          ? Formatters.parseDouble(json['amount'])
          : Formatters.parseDouble(json['total']),
    );
  }
}

class DefaulterModel {
  const DefaulterModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.finalAmount,
    required this.daysOverdue,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String phone;
  final double finalAmount;
  final int daysOverdue;

  factory DefaulterModel.fromJson(Map<String, dynamic> json) {
    return DefaulterModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      finalAmount: Formatters.parseDouble(json['final_amount']),
      daysOverdue: Formatters.parseInt(json['days_overdue']),
    );
  }
}
