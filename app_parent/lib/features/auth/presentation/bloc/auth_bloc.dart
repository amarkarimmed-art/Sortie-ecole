import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<CheckAuthStatusRequested>(_onCheckAuthStatusRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final response = await authRepository.login(event.login, event.password);
      emit(AuthAuthenticated(user: response.user, token: response.token));
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;

      if (statusCode == 401 || statusCode == 422) {
        emit(const AuthFailure('Login ou mot de passe incorrect'));
      } else if (statusCode == 429) {
        emit(const AuthFailure('Trop de tentatives, réessayez dans une minute'));
      } else if (statusCode == 403) {
        if (msg != null && msg.toString().contains('suspendue')) {
          emit(const AuthFailure('École suspendue, contactez l\'administration'));
        } else {
          emit(const AuthFailure('Ce compte n\'est pas autorisé sur l\'application Parent'));
        }
      } else {
        emit(AuthFailure(msg?.toString() ?? 'Erreur de connexion.'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onCheckAuthStatusRequested(
    CheckAuthStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final token = await authRepository.getToken();
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }
      final user = await authRepository.checkAuthStatus();
      if (user != null) {
        emit(AuthAuthenticated(user: user, token: token));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await authRepository.logout();
    emit(const AuthUnauthenticated());
  }
}
