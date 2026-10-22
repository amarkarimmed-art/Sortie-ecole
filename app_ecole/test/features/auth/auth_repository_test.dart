import 'package:app_ecole/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDioAdapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

void main() {
  group('AuthRepository - Login avec mot de passe & Sessions', () {
    late Dio dio;
    late FakeDioAdapter fakeAdapter;
    late AuthRepositoryImpl repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
      fakeAdapter = FakeDioAdapter();
      dio.httpClientAdapter = fakeAdapter;
      repository = AuthRepositoryImpl(dio: dio, baseUrl: 'http://127.0.0.1:8000');
    });

    test('login réussit avec code 200 pour un surveillant', () async {
      fakeAdapter.handler = (options) {
        expect(options.path, endsWith('/api/login'));
        expect(options.data['login'], 'surveillant@alamal');
        expect(options.data['password'], 'secret');
        expect(options.data['app_type'], 'ecole');

        return ResponseBody.fromString(
          '''
          {
            "token": "sanctum_token_test_123",
            "user": {
              "id": "u-123",
              "name": "Ahmed Surveillant",
              "login": "surveillant@alamal",
              "phone": "+212612345678",
              "role": "surveillant",
              "locale": "fr",
              "school_id": "school-abc-123",
              "school_name": "École Al Amal",
              "children": []
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final response = await repository.login('surveillant@alamal', 'secret');
      expect(response.token, 'sanctum_token_test_123');
      expect(response.user.name, 'Ahmed Surveillant');
      expect(response.user.role, 'surveillant');
      expect(response.user.schoolId, 'school-abc-123');
      expect(response.user.schoolName, 'École Al Amal');
    });

    test('login refuse la connexion si le rôle est parent', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '''
          {
            "token": "token_parent",
            "user": {
              "id": "u-parent",
              "name": "Fatima Parent",
              "login": "parent@alamal",
              "role": "parent",
              "locale": "fr",
              "school_id": "school-abc-123",
              "children": []
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.login('parent@alamal', 'secret'),
        throwsA(isA<AuthUnauthorizedRoleException>()),
      );
    });

    test('login lève AuthInvalidCredentialsException en cas de 401', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '{"message": "Identifiants incorrects."}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.login('wrong@alamal', 'badpass'),
        throwsA(isA<AuthInvalidCredentialsException>()),
      );
    });

    test('login lève AuthRateLimitException en cas de 429', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '{"message": "Trop de tentatives, réessayez dans une minute."}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.login('surveillant@alamal', 'badpass'),
        throwsA(isA<AuthRateLimitException>()),
      );
    });

    test('login lève AuthSchoolSuspendedException en cas de 403 école suspendue', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '{"message": "École suspendue, contactez l\'administration."}',
          403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.login('surveillant@alamal', 'secret'),
        throwsA(isA<AuthSchoolSuspendedException>()),
      );
    });

    test('checkSession retourne UserDto en cas de session valide', () async {
      fakeAdapter.handler = (options) {
        expect(options.path, endsWith('/api/me'));
        expect(options.headers['Authorization'], 'Bearer valid_token');

        return ResponseBody.fromString(
          '''
          {
            "user": {
              "id": "u-123",
              "name": "Ahmed Surveillant",
              "login": "surveillant@alamal",
              "role": "surveillant",
              "locale": "fr",
              "school_id": "school-abc-123",
              "school_name": "École Al Amal",
              "children": []
            }
          }
          ''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final user = await repository.checkSession('valid_token');
      expect(user.id, 'u-123');
      expect(user.name, 'Ahmed Surveillant');
      expect(user.role, 'surveillant');
    });

    test('logout appelle POST /api/logout', () async {
      bool called = false;
      fakeAdapter.handler = (options) {
        expect(options.path, endsWith('/api/logout'));
        expect(options.headers['Authorization'], 'Bearer valid_token');
        called = true;

        return ResponseBody.fromString(
          '{"message": "Déconnexion réussie."}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      await repository.logout('valid_token');
      expect(called, isTrue);
    });
  });
}
