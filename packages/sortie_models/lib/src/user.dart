import 'package:equatable/equatable.dart';
import 'child.dart';

class UserDto extends Equatable {
  final String id;
  final String name;
  final String? login;
  final String? phone;
  final String role;
  final String locale;
  final String schoolId;
  final String? schoolName;
  final String? schoolLogo;
  final List<ChildDto> children;

  const UserDto({
    required this.id,
    required this.name,
    this.login,
    this.phone,
    required this.role,
    required this.locale,
    required this.schoolId,
    this.schoolName,
    this.schoolLogo,
    this.children = const [],
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String,
      name: json['name'] as String,
      login: json['login'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      locale: json['locale'] as String? ?? 'fr',
      schoolId: json['school_id'] as String,
      schoolName: json['school_name'] as String?,
      schoolLogo: json['school_logo'] as String?,
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
      if (login != null) 'login': login,
      'phone': phone,
      'role': role,
      'locale': locale,
      'school_id': schoolId,
      if (schoolName != null) 'school_name': schoolName,
      if (schoolLogo != null) 'school_logo': schoolLogo,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        login,
        phone,
        role,
        locale,
        schoolId,
        schoolName,
        schoolLogo,
        children,
      ];
}
