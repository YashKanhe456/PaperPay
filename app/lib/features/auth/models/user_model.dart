import 'package:hive/hive.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.agencyId,
    this.language,
    this.theme,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String? agencyId;
  final String? language;
  final String? theme;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? '',
      agencyId: json['agency_id']?.toString(),
      language: json['language']?.toString(),
      theme: json['theme']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'agency_id': agencyId,
      'language': language,
      'theme': theme,
    };
  }
}

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 1;

  @override
  UserModel read(BinaryReader reader) {
    return UserModel(
      id: reader.readString(),
      name: reader.readString(),
      phone: reader.readString(),
      email: reader.readBool() ? reader.readString() : null,
      role: reader.readString(),
      agencyId: reader.readBool() ? reader.readString() : null,
      language: reader.readBool() ? reader.readString() : null,
      theme: reader.readBool() ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.phone)
      ..writeBool(obj.email != null);
    if (obj.email != null) {
      writer.writeString(obj.email!);
    }
    writer
      ..writeString(obj.role)
      ..writeBool(obj.agencyId != null);
    if (obj.agencyId != null) {
      writer.writeString(obj.agencyId!);
    }
    writer.writeBool(obj.language != null);
    if (obj.language != null) {
      writer.writeString(obj.language!);
    }
    writer.writeBool(obj.theme != null);
    if (obj.theme != null) {
      writer.writeString(obj.theme!);
    }
  }
}
