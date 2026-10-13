import 'package:sortie_models/sortie_models.dart';

abstract class AuthRepository {
  Future<void> requestOtp(String phone);
  Future<AuthResponseDto> verifyOtp(String phone, String code);
  Future<String?> getToken();
  Future<void> logout();
}
