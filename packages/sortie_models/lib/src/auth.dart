import 'package:equatable/equatable.dart';
import 'user.dart';

class LoginRequestDto extends Equatable {
  final String phone;

  const LoginRequestDto({required this.phone});

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) {
    return LoginRequestDto(
      phone: json['phone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
    };
  }

  @override
  List<Object?> get props => [phone];
}

class VerifyRequestDto extends Equatable {
  final String phone;
  final String code;

  const VerifyRequestDto({
    required this.phone,
    required this.code,
  });

  factory VerifyRequestDto.fromJson(Map<String, dynamic> json) {
    return VerifyRequestDto(
      phone: json['phone'] as String,
      code: json['code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'code': code,
    };
  }

  @override
  List<Object?> get props => [phone, code];
}

class AuthResponseDto extends Equatable {
  final String token;
  final UserDto user;

  const AuthResponseDto({
    required this.token,
    required this.user,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String,
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
    };
  }

  @override
  List<Object?> get props => [token, user];
}
