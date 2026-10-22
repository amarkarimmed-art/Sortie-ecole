import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseDto> login(String login, String password);
  Future<UserDto> getMe(String token);
  Future<void> logout(String token);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<AuthResponseDto> login(String login, String password) async {
    final response = await dio.post(
      '/login',
      data: LoginRequestDto(
        login: login,
        password: password,
        appType: 'parent',
      ).toJson(),
    );

    return AuthResponseDto.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserDto> getMe(String token) async {
    final response = await dio.get(
      '/me',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    return UserDto.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String token) async {
    await dio.post(
      '/logout',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}
