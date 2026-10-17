import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';

/// Exceptions métier pour l'authentification app_ecole (F01).
abstract class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthUserNotFoundException extends AuthException {
  const AuthUserNotFoundException([super.message = 'Utilisateur introuvable.']);
}

class AuthRateLimitException extends AuthException {
  const AuthRateLimitException([super.message = 'Trop de tentatives.']);
}

class AuthInvalidOtpException extends AuthException {
  const AuthInvalidOtpException([super.message = 'Code OTP invalide ou expiré.']);
}

class AuthValidationException extends AuthException {
  const AuthValidationException([super.message = 'Erreur de validation.']);
}

class AuthUnauthorizedRoleException extends AuthException {
  const AuthUnauthorizedRoleException([
    super.message = 'Accès réservé au personnel scolaire (surveillant, accueil, direction).',
  ]);
}

class AuthNetworkException extends AuthException {
  const AuthNetworkException([super.message = 'Erreur réseau.']);
}

/// Helper pour normaliser les numéros de téléphone marocains au format E.164.
String normalizeMoroccanPhone(String input) {
  final clean = input.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
  if (clean.startsWith('+212')) {
    return clean;
  }
  if (clean.startsWith('00212')) {
    return '+212${clean.substring(5)}';
  }
  if (clean.startsWith('0') && clean.length == 10) {
    return '+212${clean.substring(1)}';
  }
  if (clean.length == 9 && (clean.startsWith('5') || clean.startsWith('6') || clean.startsWith('7') || clean.startsWith('8'))) {
    return '+212$clean';
  }
  if (!clean.startsWith('+')) {
    return '+$clean';
  }
  return clean;
}

/// Helper de masquage de numéro conforme Loi 09-08 (Minimisation et confidentialité).
String maskMoroccanPhone(String phone) {
  final normalized = normalizeMoroccanPhone(phone);
  if (normalized.length >= 9) {
    final start = normalized.substring(0, normalized.length - 6);
    final end = normalized.substring(normalized.length - 2);
    return '$start •• •• •• $end';
  }
  return phone;
}

/// Contrat du repository d'authentification.
abstract class AuthRepository {
  Future<void> requestOtp(String phone);
  Future<AuthResponseDto> verifyOtp(String phone, String code);
}

/// Implémentation Dio du repository d'authentification.
class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final String _baseUrl;

  /// Rôles autorisés sur l'application école (tablette d'accueil et surveillance).
  static const Set<String> allowedStaffRoles = {
    'surveillant',
    'supervisor',
    'agent',
    'concierge',
    'direction',
    'director',
    'admin',
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
  Future<void> requestOtp(String rawPhone) async {
    final phone = normalizeMoroccanPhone(rawPhone);
    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/auth/login',
        data: {'phone': phone},
      );

      if (response.statusCode != 200) {
        throw const AuthNetworkException();
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        throw const AuthUserNotFoundException();
      } else if (statusCode == 429) {
        throw const AuthRateLimitException();
      } else if (statusCode == 422) {
        throw const AuthValidationException();
      }
      throw AuthNetworkException(e.message ?? 'Erreur réseau');
    }
  }

  @override
  Future<AuthResponseDto> verifyOtp(String rawPhone, String code) async {
    final phone = normalizeMoroccanPhone(rawPhone);
    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/auth/verify',
        data: {
          'phone': phone,
          'code': code.trim(),
        },
      );

      dynamic responseData = response.data;
      if (responseData is String) {
        responseData = jsonDecode(responseData);
      }

      if (response.statusCode == 200 && responseData is Map<String, dynamic>) {
        final authResponse =
            AuthResponseDto.fromJson(responseData);

        // Vérification de sécurité métier : l'application école est réservée au personnel
        final role = authResponse.user.role.toLowerCase();
        if (role == 'parent') {
          throw const AuthUnauthorizedRoleException();
        }

        return authResponse;
      }
      throw const AuthNetworkException();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw const AuthInvalidOtpException();
      } else if (statusCode == 422) {
        throw const AuthValidationException();
      } else if (statusCode == 404) {
        throw const AuthUserNotFoundException();
      }
      throw AuthNetworkException(e.message ?? 'Erreur réseau');
    }
  }
}
