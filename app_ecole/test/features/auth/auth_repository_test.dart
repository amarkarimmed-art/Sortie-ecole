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
  group('AuthRepository - Helpers marocains & Loi 09-08', () {
    test('normalizeMoroccanPhone normalise les différents formats au format E.164 (+212)', () {
      expect(normalizeMoroccanPhone('+212612345678'), '+212612345678');
      expect(normalizeMoroccanPhone('0612345678'), '+212612345678');
      expect(normalizeMoroccanPhone('0712345678'), '+212712345678');
      expect(normalizeMoroccanPhone('0522123456'), '+212522123456');
      expect(normalizeMoroccanPhone('612345678'), '+212612345678');
      expect(normalizeMoroccanPhone('00212612345678'), '+212612345678');
      expect(normalizeMoroccanPhone('06 12 34 56 78'), '+212612345678');
    });

    test('maskMoroccanPhone masque les chiffres intermédiaires conformément à la Loi 09-08', () {
      final masked = maskMoroccanPhone('0612345678');
      expect(masked, contains('+2126'));
      expect(masked, contains('•• •• ••'));
      expect(masked, contains('78'));
      expect(masked, isNot(contains('123456')));
    });
  });

  group('AuthRepository - Appels HTTP Dio', () {
    late Dio dio;
    late FakeDioAdapter fakeAdapter;
    late AuthRepositoryImpl repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));
      fakeAdapter = FakeDioAdapter();
      dio.httpClientAdapter = fakeAdapter;
      repository = AuthRepositoryImpl(dio: dio, baseUrl: 'http://127.0.0.1:8000');
    });

    test('requestOtp réussit avec un code 200', () async {
      fakeAdapter.handler = (options) {
        expect(options.path, endsWith('/api/v1/auth/login'));
        expect(options.data['phone'], '+212612345678');
        return ResponseBody.fromString(
          '{"message": "Code envoyé par SMS."}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      await expectLater(
        repository.requestOtp('0612345678'),
        completes,
      );
    });

    test('requestOtp lève AuthUserNotFoundException en cas de 404', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '{"message": "Utilisateur introuvable."}',
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.requestOtp('0600000000'),
        throwsA(isA<AuthUserNotFoundException>()),
      );
    });

    test('requestOtp lève AuthRateLimitException en cas de 429', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '{"message": "Trop de tentatives."}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.requestOtp('0612345678'),
        throwsA(isA<AuthRateLimitException>()),
      );
    });

    test('verifyOtp retourne AuthResponseDto pour un surveillant', () async {
      fakeAdapter.handler = (options) {
        expect(options.path, endsWith('/api/v1/auth/verify'));
        expect(options.data['code'], '123456');
        return ResponseBody.fromString(
          '''
          {
            "token": "sanctum_token_test_123",
            "user": {
              "id": "u-123",
              "name": "Ahmed Surveillant",
              "phone": "+212612345678",
              "role": "surveillant",
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

      final response = await repository.verifyOtp('0612345678', '123456');
      expect(response.token, 'sanctum_token_test_123');
      expect(response.user.name, 'Ahmed Surveillant');
      expect(response.user.role, 'surveillant');
      expect(response.user.schoolId, 'school-abc-123');
    });

    test('verifyOtp refuse la connexion si le rôle est parent', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '''
          {
            "token": "token_parent",
            "user": {
              "id": "u-parent",
              "name": "Fatima Parent",
              "phone": "+212612345678",
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
        () => repository.verifyOtp('0612345678', '123456'),
        throwsA(isA<AuthUnauthorizedRoleException>()),
      );
    });

    test('verifyOtp lève AuthInvalidOtpException en cas de 401', () async {
      fakeAdapter.handler = (options) {
        return ResponseBody.fromString(
          '{"message": "Code OTP invalide ou expiré."}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      expect(
        () => repository.verifyOtp('0612345678', '000000'),
        throwsA(isA<AuthInvalidOtpException>()),
      );
    });
  });
}
