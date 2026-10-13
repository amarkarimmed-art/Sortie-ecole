import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';

abstract class AuthRemoteDataSource {
  Future<void> requestOtp(String phone);
  Future<AuthResponseDto> verifyOtp(String phone, String code);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<void> requestOtp(String phone) async {
    await dio.post(
      '/v1/auth/login',
      data: LoginRequestDto(phone: phone).toJson(),
    );
  }

  @override
  Future<AuthResponseDto> verifyOtp(String phone, String code) async {
    final response = await dio.post(
      '/v1/auth/verify',
      data: VerifyRequestDto(phone: phone, code: code).toJson(),
    );

    return AuthResponseDto.fromJson(response.data as Map<String, dynamic>);
  }
}
