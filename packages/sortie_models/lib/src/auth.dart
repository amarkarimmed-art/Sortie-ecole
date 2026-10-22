import 'package:equatable/equatable.dart';
import 'user.dart';

class LoginRequestDto extends Equatable {
  final String login;
  final String password;
  final String? appType;

  const LoginRequestDto({
    required this.login,
    required this.password,
    this.appType,
  });

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) {
    return LoginRequestDto(
      login: json['login'] as String,
      password: json['password'] as String,
      appType: json['app_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'login': login,
      'password': password,
      if (appType != null) 'app_type': appType,
    };
  }

  @override
  List<Object?> get props => [login, password, appType];
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
