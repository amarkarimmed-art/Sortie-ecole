import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<RequestOtpSubmitted>(_onRequestOtpSubmitted);
    on<VerifyOtpSubmitted>(_onVerifyOtpSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onRequestOtpSubmitted(
    RequestOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await authRepository.requestOtp(event.phone);
      emit(OtpSentSuccess(event.phone));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onVerifyOtpSubmitted(
    VerifyOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final response = await authRepository.verifyOtp(event.phone, event.code);
      emit(AuthAuthenticated(user: response.user, token: response.token));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await authRepository.logout();
    emit(const AuthInitial());
  }
}
