import 'package:hive/hive.dart';

class CashCollectionModel {
  const CashCollectionModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.notes,
    this.synced = false,
    this.createdAt,
  });

  final String id;
  final String customerId;
  final double amount;
  final String date;
  final String? notes;
  final bool synced;
  final String? createdAt;

  CashCollectionModel copyWith({
    bool? synced,
  }) {
    return CashCollectionModel(
      id: id,
      customerId: customerId,
      amount: amount,
      date: date,
      notes: notes,
      synced: synced ?? this.synced,
      createdAt: createdAt,
    );
  }
}

class CashCollectionModelAdapter extends TypeAdapter<CashCollectionModel> {
  @override
  final int typeId = 3;

  @override
  CashCollectionModel read(BinaryReader reader) {
    return CashCollectionModel(
      id: reader.readString(),
      customerId: reader.readString(),
      amount: reader.readDouble(),
      date: reader.readString(),
      notes: reader.readBool() ? reader.readString() : null,
      synced: reader.readBool(),
      createdAt: reader.readBool() ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, CashCollectionModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.customerId)
      ..writeDouble(obj.amount)
      ..writeString(obj.date)
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
