import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class RequestOtpSubmitted extends AuthEvent {
  final String phone;

  const RequestOtpSubmitted(this.phone);

  @override
  List<Object?> get props => [phone];
}

class VerifyOtpSubmitted extends AuthEvent {
  final String phone;
  final String code;

  const VerifyOtpSubmitted({required this.phone, required this.code});

  @override
  List<Object?> get props => [phone, code];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
