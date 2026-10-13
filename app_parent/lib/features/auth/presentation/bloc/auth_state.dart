import 'package:equatable/equatable.dart';
import 'package:sortie_models/sortie_models.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class OtpSentSuccess extends AuthState {
  final String phone;

  const OtpSentSuccess(this.phone);

  @override
  List<Object?> get props => [phone];
}

class AuthAuthenticated extends AuthState {
  final UserDto user;
  final String token;

  const AuthAuthenticated({required this.user, required this.token});

  @override
  List<Object?> get props => [user, token];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
