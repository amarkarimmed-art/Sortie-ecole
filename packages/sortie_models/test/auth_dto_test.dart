import 'package:test/test.dart';
import 'package:sortie_models/sortie_models.dart';

void main() {
  group('LoginRequestDto', () {
    test('sérialisation et désérialisation avec app_type', () {
      const dto = LoginRequestDto(
        login: 'parent.test@ecole',
        password: 'password123',
        appType: 'parent',
      );

      final json = dto.toJson();
      expect(json, {
        'login': 'parent.test@ecole',
        'password': 'password123',
        'app_type': 'parent',
      });

      final fromJson = LoginRequestDto.fromJson(json);
      expect(fromJson, equals(dto));
    });

    test('sérialisation sans app_type', () {
      const dto = LoginRequestDto(
        login: 'surveillant@ecole',
        password: 'secretPassword',
      );

      final json = dto.toJson();
      expect(json, {
        'login': 'surveillant@ecole',
        'password': 'secretPassword',
      });
      expect(json.containsKey('app_type'), isFalse);
    });
  });

  group('UserDto', () {
    test('désérialisation avec login, school_name, school_logo et phone null', () {
      final json = {
        'id': 'user-123',
        'name': 'Oussama Alami',
        'login': 'parent.alami@alamal',
        'phone': null,
        'role': 'parent',
        'locale': 'fr',
        'school_id': 'school-456',
        'school_name': 'École Al Amal',
        'school_logo': 'https://example.com/logo.png',
        'children': [],
      };

      final user = UserDto.fromJson(json);
      expect(user.id, 'user-123');
      expect(user.name, 'Oussama Alami');
      expect(user.login, 'parent.alami@alamal');
      expect(user.phone, isNull);
      expect(user.schoolName, 'École Al Amal');
      expect(user.schoolLogo, 'https://example.com/logo.png');

      final serialized = user.toJson();
      expect(serialized['login'], 'parent.alami@alamal');
      expect(serialized['school_name'], 'École Al Amal');
      expect(serialized['school_logo'], 'https://example.com/logo.png');
    });
  });
}
