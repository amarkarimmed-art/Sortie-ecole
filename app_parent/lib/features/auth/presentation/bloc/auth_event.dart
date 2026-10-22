import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends AuthEvent {
  final String login;
  final String password;

  const LoginSubmitted({required this.login, required this.password});

  @override
  List<Object?> get props => [login, password];
}

class CheckAuthStatusRequested extends AuthEvent {
  const CheckAuthStatusRequested();
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
