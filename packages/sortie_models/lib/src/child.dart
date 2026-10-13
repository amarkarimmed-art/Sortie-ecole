import 'package:equatable/equatable.dart';

class ChildDto extends Equatable {
  final String id;
  final String schoolId;
  final String firstName;
  final String lastName;
  final String className;
  final String? photoUrl;

  const ChildDto({
    required this.id,
    required this.schoolId,
    required this.firstName,
    required this.lastName,
    required this.className,
    this.photoUrl,
  });

  factory ChildDto.fromJson(Map<String, dynamic> json) {
    return ChildDto(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      className: json['class_name'] as String,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'first_name': firstName,
      'last_name': lastName,
      'class_name': className,
      if (photoUrl != null) 'photo_url': photoUrl,
    };
  }

  @override
  List<Object?> get props => [id, schoolId, firstName, lastName, className, photoUrl];
}
