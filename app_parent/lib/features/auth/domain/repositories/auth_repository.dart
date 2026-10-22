import 'package:sortie_models/sortie_models.dart';

abstract class AuthRepository {
  Future<AuthResponseDto> login(String login, String password);
  Future<UserDto?> checkAuthStatus();
  Future<String?> getToken();
  Future<void> logout();
}
