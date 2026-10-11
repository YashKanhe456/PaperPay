class CustomerAppData {
  const CustomerAppData({
    required this.customer,
    this.currentBill,
    this.activeSubscriptions = const [],
    this.bills = const [],
    this.payments = const [],
    this.todayDelivery = const [],
    this.deliveryHistory = const [],
    this.loyaltyPoints = 0,
    this.complaints = const [],
    required this.quickInfo,
  });

  final CustomerProfile customer;
  final CustomerBill? currentBill;
  final List<CustomerSubscription> activeSubscriptions;
  final List<CustomerBill> bills;
  final List<CustomerPayment> payments;
  final List<CustomerDeliveryItem> todayDelivery;
  final List<DeliveryHistoryDay> deliveryHistory;
  final int loyaltyPoints;
  final List<CustomerComplaint> complaints;
  final CustomerQuickInfo quickInfo;

  factory CustomerAppData.fromJson(Map<String, dynamic> json) {
    return CustomerAppData(
      customer: CustomerProfile.fromJson(
        Map<String, dynamic>.from(json['customer'] as Map? ?? const {}),
      ),
      currentBill: json['current_bill'] == null
          ? null
          : CustomerBill.fromJson(
              Map<String, dynamic>.from(json['current_bill'] as Map),
            ),
      activeSubscriptions: ((json['active_subscriptions'] as List<dynamic>?) ?? const [])
          .map((item) => CustomerSubscription.fromJson(item as Map<String, dynamic>))
          .toList(),
      bills: ((json['bills'] as List<dynamic>?) ?? const [])
          .map((item) => CustomerBill.fromJson(item as Map<String, dynamic>))
          .toList(),
      payments: ((json['payments'] as List<dynamic>?) ?? const [])
          .map((item) => CustomerPayment.fromJson(item as Map<String, dynamic>))
          .toList(),
      todayDelivery: ((json['today_delivery'] as List<dynamic>?) ?? const [])
          .map((item) => CustomerDeliveryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryHistory: ((json['delivery_history'] as List<dynamic>?) ?? const [])
          .map((item) => DeliveryHistoryDay.fromJson(item as Map<String, dynamic>))
          .toList(),
      loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
      complaints: ((json['complaints'] as List<dynamic>?) ?? const [])
          .map((item) => CustomerComplaint.fromJson(item as Map<String, dynamic>))
          .toList(),
      quickInfo: CustomerQuickInfo.fromJson(
        Map<String, dynamic>.from(json['quick_info'] as Map? ?? const {}),
      ),
    );
  }

  CustomerAppData copyWith({
    CustomerProfile? customer,
    CustomerBill? currentBill,
    List<CustomerSubscription>? activeSubscriptions,
    List<CustomerBill>? bills,
    List<CustomerPayment>? payments,
    List<CustomerDeliveryItem>? todayDelivery,
    List<DeliveryHistoryDay>? deliveryHistory,
    int? loyaltyPoints,
    List<CustomerComplaint>? complaints,
    CustomerQuickInfo? quickInfo,
  }) {
    return CustomerAppData(
      customer: customer ?? this.customer,
      currentBill: currentBill ?? this.currentBill,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      bills: bills ?? this.bills,
      payments: payments ?? this.payments,
      todayDelivery: todayDelivery ?? this.todayDelivery,
      deliveryHistory: deliveryHistory ?? this.deliveryHistory,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      complaints: complaints ?? this.complaints,
      quickInfo: quickInfo ?? this.quickInfo,
    );
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.area,
    this.landmark,
    this.category,
    this.status,
    this.totalOutstanding = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? area;
  final String? landmark;
  final String? category;
  final String? status;
  final double totalOutstanding;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      area: json['area']?.toString(),
      landmark: json['landmark']?.toString(),
      category: json['category']?.toString(),
      status: json['status']?.toString(),
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0,
    );
  }

  CustomerProfile copyWith({
    String? name,
    String? email,
    String? address,
  }) {
    return CustomerProfile(
      id: id,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      address: address ?? this.address,
      area: area,
      landmark: landmark,
      category: category,
      status: status,
      totalOutstanding: totalOutstanding,
    );
  }
}

class CustomerSubscription {
  const CustomerSubscription({
    required this.id,
    required this.rate,
    required this.status,
    required this.newspaperId,
    required this.newspaperName,
    this.language,
  });

  final String id;
  final double rate;
  final String status;
  final String newspaperId;
  final String newspaperName;
  final String? language;

  factory CustomerSubscription.fromJson(Map<String, dynamic> json) {
    return CustomerSubscription(
      id: json['id']?.toString() ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'active',
      newspaperId: json['newspaper_id']?.toString() ?? '',
      newspaperName: json['newspaper_name']?.toString() ?? 'Paper',
      language: json['language']?.toString(),
    );
  }
}

class CustomerBill {
  const CustomerBill({
    required this.id,
    required this.month,
    required this.year,
    required this.amount,
    required this.finalAmount,
    required this.status,
    this.discount = 0,
    this.lateFee = 0,
    this.dueDate,
    this.paidAt,
    this.pdfUrl,
  });

  final String id;
  final int month;
  final int year;
  final double amount;
  final double finalAmount;
  final String status;
  final double discount;
  final double lateFee;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? pdfUrl;

  factory CustomerBill.fromJson(Map<String, dynamic> json) {
    return CustomerBill(
      id: json['id']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['final_amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'unpaid',
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      lateFee: (json['late_fee'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? ''),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      pdfUrl: json['pdf_url']?.toString(),
    );
  }

  String get monthLabel {
    const months = [
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
    if (month < 1 || month > 12) {
      return '$year';
    }
    return '${months[month - 1]} $year';
  }
}

class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.amount,
    required this.status,
    this.mode,
    this.paidAt,
    this.billId,
  });

  final String id;
  final double amount;
  final String status;
  final String? mode;
  final DateTime? paidAt;
  final String? billId;

  factory CustomerPayment.fromJson(Map<String, dynamic> json) {
    return CustomerPayment(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      mode: json['mode']?.toString(),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      billId: json['bill_id']?.toString(),
    );
  }
}

class CustomerDeliveryItem {
  const CustomerDeliveryItem({
    required this.id,
    required this.newspaperName,
    required this.status,
    this.photoProofUrl,
    this.notes,
  });

  final String id;
  final String newspaperName;
  final String status;
  final String? photoProofUrl;
  final String? notes;

  factory CustomerDeliveryItem.fromJson(Map<String, dynamic> json) {
    return CustomerDeliveryItem(
      id: json['id']?.toString() ?? '',
      newspaperName: json['newspaper_name']?.toString() ?? 'Paper',
      status: json['status']?.toString() ?? 'pending',
      photoProofUrl: json['photo_proof_url']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class DeliveryHistoryDay {
  const DeliveryHistoryDay({
    required this.date,
    required this.items,
  });

  final String date;
  final List<CustomerDeliveryItem> items;

  factory DeliveryHistoryDay.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryDay(
      date: json['date']?.toString() ?? '',
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .map((item) => CustomerDeliveryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerComplaint {
  const CustomerComplaint({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    this.raisedAt,
  });

  final String id;
  final String category;
  final String description;
  final String status;
  final DateTime? raisedAt;

  factory CustomerComplaint.fromJson(Map<String, dynamic> json) {
    return CustomerComplaint(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Other',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      raisedAt: DateTime.tryParse(json['raised_at']?.toString() ?? ''),
    );
  }
}

class CustomerQuickInfo {
  const CustomerQuickInfo({
    required this.papersCount,
    required this.todayDeliveryStatus,
  });

  final int papersCount;
  final String todayDeliveryStatus;

  factory CustomerQuickInfo.fromJson(Map<String, dynamic> json) {
    return CustomerQuickInfo(
      papersCount: (json['papers_count'] as num?)?.toInt() ?? 0,
      todayDeliveryStatus: json['today_delivery_status']?.toString() ?? 'pending',
    );
  }
}

class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.razorpayKey,
  });

  final String orderId;
  final double amount;
  final String razorpayKey;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      orderId: json['order_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      razorpayKey: json['razorpay_key']?.toString() ?? '',
    );
  }
}
