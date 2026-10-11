import 'package:hive/hive.dart';
import '../../../core/utils/formatters.dart';

class DeliveryAreaModel {
  const DeliveryAreaModel({
    required this.area,
    required this.customers,
  });

  final String area;
  final List<DeliveryCustomerModel> customers;

  factory DeliveryAreaModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAreaModel(
      area: json['area']?.toString() ?? 'Unassigned',
      customers: (json['customers'] as List<dynamic>? ?? const [])
          .map((item) => DeliveryCustomerModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DeliveryCustomerModel {
  const DeliveryCustomerModel({
    required this.customerId,
    required this.name,
    this.phone,
    this.address,
    this.area,
    this.landmark,
    this.category,
    required this.status,
    required this.isHolidayToday,
    required this.newspapers,
  });

  final String customerId;
  final String name;
  final String? phone;
  final String? address;
  final String? area;
  final String? landmark;
  final String? category;
  final String status;
  final bool isHolidayToday;
  final List<DeliveryPaperModel> newspapers;

  factory DeliveryCustomerModel.fromJson(Map<String, dynamic> json) {
    return DeliveryCustomerModel(
      customerId: json['customer_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      area: json['area']?.toString(),
      landmark: json['landmark']?.toString(),
      category: json['category']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      isHolidayToday: json['is_holiday_today'] as bool? ?? false,
      newspapers: (json['newspapers'] as List<dynamic>? ?? const [])
          .map((item) => DeliveryPaperModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  DeliveryCustomerModel copyWith({
    String? status,
    List<DeliveryPaperModel>? newspapers,
  }) {
    return DeliveryCustomerModel(
      customerId: customerId,
      name: name,
      phone: phone,
      address: address,
      area: area,
      landmark: landmark,
      category: category,
      status: status ?? this.status,
      isHolidayToday: isHolidayToday,
      newspapers: newspapers ?? this.newspapers,
    );
  }
}

class DeliveryPaperModel {
  const DeliveryPaperModel({
    required this.newspaperId,
    required this.newspaperName,
    required this.rate,
    required this.status,
    this.notes,
  });

  final String newspaperId;
  final String newspaperName;
  final double rate;
  final String status;
  final String? notes;

  factory DeliveryPaperModel.fromJson(Map<String, dynamic> json) {
    return DeliveryPaperModel(
      newspaperId: json['newspaper_id']?.toString() ?? '',
      newspaperName: json['newspaper_name']?.toString() ?? 'Paper',
      rate: Formatters.parseDouble(json['rate']),
      status: json['status']?.toString() ?? 'pending',
      notes: json['notes']?.toString(),
    );
  }

  DeliveryPaperModel copyWith({
    String? status,
    String? notes,
  }) {
    return DeliveryPaperModel(
      newspaperId: newspaperId,
      newspaperName: newspaperName,
      rate: rate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class DeliverySummaryModel {
  const DeliverySummaryModel({
    required this.delivered,
    required this.pending,
    required this.missed,
    required this.holiday,
    required this.wrongPaper,
    required this.wetPaper,
  });

  final int delivered;
  final int pending;
  final int missed;
  final int holiday;
  final int wrongPaper;
  final int wetPaper;

  factory DeliverySummaryModel.fromJson(Map<String, dynamic> json) {
    return DeliverySummaryModel(
      delivered: Formatters.parseInt(json['delivered']),
      pending: Formatters.parseInt(json['pending']),
      missed: Formatters.parseInt(json['missed']),
      holiday: Formatters.parseInt(json['holiday']),
      wrongPaper: Formatters.parseInt(json['wrong_paper']),
      wetPaper: Formatters.parseInt(json['wet_paper']),
    );
  }
}

class DeliveryModel {
  const DeliveryModel({
    required this.id,
    required this.customerId,
    required this.newspaperId,
    required this.date,
    required this.status,
    this.notes,
    this.synced = false,
    this.createdAt,
  });

  final String id;
  final String customerId;
  final String newspaperId;
  final String date;
  final String status;
  final String? notes;
  final bool synced;
  final String? createdAt;

  DeliveryModel copyWith({
    bool? synced,
  }) {
    return DeliveryModel(
      id: id,
      customerId: customerId,
      newspaperId: newspaperId,
      date: date,
      status: status,
      notes: notes,
      synced: synced ?? this.synced,
      createdAt: createdAt,
    );
  }
}

class DeliveryModelAdapter extends TypeAdapter<DeliveryModel> {
  @override
  final int typeId = 2;

  @override
  DeliveryModel read(BinaryReader reader) {
    return DeliveryModel(
      id: reader.readString(),
      customerId: reader.readString(),
      newspaperId: reader.readString(),
      date: reader.readString(),
      status: reader.readString(),
      notes: reader.readBool() ? reader.readString() : null,
      synced: reader.readBool(),
      createdAt: reader.readBool() ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, DeliveryModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.customerId)
      ..writeString(obj.newspaperId)
      ..writeString(obj.date)
      ..writeString(obj.status)
      ..writeBool(obj.notes != null);
    if (obj.notes != null) {
      writer.writeString(obj.notes!);
    }
    writer
      ..writeBool(obj.synced)
      ..writeBool(obj.createdAt != null);
    if (obj.createdAt != null) {
      writer.writeString(obj.createdAt!);
    }
  }
}
