import 'package:equatable/equatable.dart';

class UserDto extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String locale;
  final String schoolId;

  const UserDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.locale,
    required this.schoolId,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      locale: json['locale'] as String? ?? 'fr',
      schoolId: json['school_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'role': role,
      'locale': locale,
      'school_id': schoolId,
    };
  }

  @override
  List<Object?> get props => [id, name, phone, role, locale, schoolId];
}
