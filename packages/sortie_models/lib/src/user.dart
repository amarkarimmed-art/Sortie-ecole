import 'package:equatable/equatable.dart';
import 'child.dart';

class UserDto extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String role;
  final String locale;
  final String schoolId;
  final List<ChildDto> children;

  const UserDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.locale,
    required this.schoolId,
    this.children = const [],
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      locale: json['locale'] as String? ?? 'fr',
      schoolId: json['school_id'] as String,
      children: (json['children'] as List<dynamic>?)
              ?.map((c) => ChildDto.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
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
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, name, phone, role, locale, schoolId, children];
}
