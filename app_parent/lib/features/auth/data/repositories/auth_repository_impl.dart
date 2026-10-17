import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final FlutterSecureStorage secureStorage;

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _schoolIdKey = 'auth_school_id';
  static const String _childIdsKey = 'auth_child_ids';

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
  });

  @override
  Future<void> requestOtp(String phone) async {
    await remoteDataSource.requestOtp(phone);
  }

  @override
  Future<AuthResponseDto> verifyOtp(String phone, String code) async {
    final response = await remoteDataSource.verifyOtp(phone, code);
    await secureStorage.write(key: _tokenKey, value: response.token);
    await secureStorage.write(key: _userIdKey, value: response.user.id);
    await secureStorage.write(key: _schoolIdKey, value: response.user.schoolId);
    final childIds = response.user.children.map((c) => c.id).join(',');
    await secureStorage.write(key: _childIdsKey, value: childIds);
    return response;
  }

  @override
  Future<String?> getToken() async {
    return await secureStorage.read(key: _tokenKey);
  }

  @override
  Future<void> logout() async {
    await secureStorage.delete(key: _tokenKey);
    await secureStorage.delete(key: _userIdKey);
    await secureStorage.delete(key: _schoolIdKey);
    await secureStorage.delete(key: _childIdsKey);
  }
}
