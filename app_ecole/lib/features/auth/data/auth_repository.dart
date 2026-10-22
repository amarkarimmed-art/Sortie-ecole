import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';

/// Exceptions métier pour l'authentification app_ecole.
abstract class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthInvalidCredentialsException extends AuthException {
  const AuthInvalidCredentialsException([
    super.message = 'Login ou mot de passe incorrect.',
  ]);
}

class AuthRateLimitException extends AuthException {
  const AuthRateLimitException([
    super.message = 'Trop de tentatives, réessayez dans une minute.',
  ]);
}

class AuthSchoolSuspendedException extends AuthException {
  const AuthSchoolSuspendedException([
    super.message = "École suspendue, contactez l'administration.",
  ]);
}

class AuthUnauthorizedRoleException extends AuthException {
  const AuthUnauthorizedRoleException([
    super.message = "Accès réservé aux surveillants et agents d'accueil.",
  ]);
}

class AuthValidationException extends AuthException {
  const AuthValidationException([
    super.message = 'Erreur de validation.',
  ]);
}

class AuthNetworkException extends AuthException {
  const AuthNetworkException([
    super.message = 'Erreur réseau.',
  ]);
}

/// Contrat du repository d'authentification.
abstract class AuthRepository {
  Future<AuthResponseDto> login(String login, String password);
  Future<UserDto> checkSession(String token);
  Future<void> logout(String token);
}

/// Implémentation Dio du repository d'authentification.
class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final String _baseUrl;

  /// Rôles autorisés sur l'application école.
  static const Set<String> allowedStaffRoles = {
    'surveillant',
    'concierge',
  };

  AuthRepositoryImpl({
    Dio? dio,
    String baseUrl = 'http://127.0.0.1:8000',
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ),
        _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;

  @override
  Future<AuthResponseDto> login(String login, String password) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/login',
        data: {
          'login': login.trim(),
          'password': password,
          'app_type': 'ecole',
        },
      );

      dynamic responseData = response.data;
      if (responseData is String) {
        responseData = jsonDecode(responseData);
      }

      if (response.statusCode == 200 && responseData is Map<String, dynamic>) {
        final authResponse = AuthResponseDto.fromJson(responseData);

        // Vérification de sécurité métier : réservé à surveillant ou concierge
        final role = authResponse.user.role.toLowerCase();
        if (!allowedStaffRoles.contains(role)) {
          throw const AuthUnauthorizedRoleException();
        }

        return authResponse;
      }

      throw const AuthNetworkException();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;

      if (statusCode == 401) {
        throw const AuthInvalidCredentialsException();
      } else if (statusCode == 429) {
        throw const AuthRateLimitException();
      } else if (statusCode == 403) {
        if (msg != null && msg.contains('suspendue')) {
          throw const AuthSchoolSuspendedException();
        }
        throw const AuthUnauthorizedRoleException();
      } else if (statusCode == 422) {
        throw const AuthInvalidCredentialsException();
      }
      throw AuthNetworkException(msg ?? e.message ?? 'Erreur réseau');
    }
  }

  @override
  Future<UserDto> checkSession(String token) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      dynamic responseData = response.data;
      if (responseData is String) {
        responseData = jsonDecode(responseData);
      }

      if (response.statusCode == 200 && responseData is Map<String, dynamic>) {
        final user = UserDto.fromJson(responseData['user'] as Map<String, dynamic>);
        final role = user.role.toLowerCase();
        if (!allowedStaffRoles.contains(role)) {
          throw const AuthUnauthorizedRoleException();
        }
        return user;
      }

      throw const AuthNetworkException();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;

      if (statusCode == 401) {
        throw const AuthInvalidCredentialsException();
      } else if (statusCode == 403) {
        if (msg != null && msg.contains('suspendue')) {
          throw const AuthSchoolSuspendedException();
        }
        throw const AuthUnauthorizedRoleException();
      }
      throw AuthNetworkException(msg ?? e.message ?? 'Erreur réseau');
    }
  }

  @override
  Future<void> logout(String token) async {
    try {
      await _dio.post(
        '$_baseUrl/api/logout',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } catch (_) {}
  }
}
