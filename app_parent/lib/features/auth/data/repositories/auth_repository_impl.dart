import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';
import '../../../../core/auth_session_memory.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final FlutterSecureStorage secureStorage;

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _schoolIdKey = 'auth_school_id';
  static const String _schoolNameKey = 'auth_school_name';
  static const String _schoolLogoKey = 'auth_school_logo';
  static const String _childIdsKey = 'auth_child_ids';

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
  });

  @override
  Future<AuthResponseDto> login(String login, String password) async {
    final response = await remoteDataSource.login(login, password);
    await secureStorage.write(key: _tokenKey, value: response.token);
    await secureStorage.write(key: _userIdKey, value: response.user.id);
    await secureStorage.write(key: _schoolIdKey, value: response.user.schoolId);
    if (response.user.schoolName != null) {
      await secureStorage.write(key: _schoolNameKey, value: response.user.schoolName);
    }
    if (response.user.schoolLogo != null) {
      await secureStorage.write(key: _schoolLogoKey, value: response.user.schoolLogo);
    }
    final childIdsList = response.user.children.map((c) => c.id).toList();
    final childIds = childIdsList.join(',');
    await secureStorage.write(key: _childIdsKey, value: childIds);

    // Synchronisation immédiate en RAM
    AuthSessionMemory.setSession(
      token: response.token,
      userId: response.user.id,
      schoolId: response.user.schoolId,
      schoolName: response.user.schoolName,
      schoolLogo: response.user.schoolLogo,
      childIds: childIdsList,
    );

    return response;
  }

  @override
  Future<UserDto?> checkAuthStatus() async {
    final token = await secureStorage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      AuthSessionMemory.clear();
      return null;
    }
    try {
      final user = await remoteDataSource.getMe(token);
      await secureStorage.write(key: _userIdKey, value: user.id);
      await secureStorage.write(key: _schoolIdKey, value: user.schoolId);
      if (user.schoolName != null) {
        await secureStorage.write(key: _schoolNameKey, value: user.schoolName);
      }
      if (user.schoolLogo != null) {
        await secureStorage.write(key: _schoolLogoKey, value: user.schoolLogo);
      }
      final childIdsList = user.children.map((c) => c.id).toList();
      final childIds = childIdsList.join(',');
      await secureStorage.write(key: _childIdsKey, value: childIds);

      // Synchronisation immédiate en RAM
      AuthSessionMemory.setSession(
        token: token,
        userId: user.id,
        schoolId: user.schoolId,
        schoolName: user.schoolName,
        schoolLogo: user.schoolLogo,
        childIds: childIdsList,
      );

      return user;
    } catch (_) {
      await logout();
      return null;
    }
  }

  @override
  Future<String?> getToken() async {
    return AuthSessionMemory.token ?? await secureStorage.read(key: _tokenKey);
  }

  @override
  Future<void> logout() async {
    AuthSessionMemory.clear();
    final token = await secureStorage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        await remoteDataSource.logout(token);
      } catch (_) {}
    }
    await secureStorage.delete(key: _tokenKey);
    await secureStorage.delete(key: _userIdKey);
    await secureStorage.delete(key: _schoolIdKey);
    await secureStorage.delete(key: _schoolNameKey);
    await secureStorage.delete(key: _schoolLogoKey);
    await secureStorage.delete(key: _childIdsKey);
  }
}
