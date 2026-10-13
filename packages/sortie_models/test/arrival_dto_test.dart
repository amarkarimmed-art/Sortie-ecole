import 'package:test/test.dart';
import 'package:sortie_models/sortie_models.dart';

void main() {
  group('ArrivalSignalRequest', () {
    test('sérialisation et désérialisation avec coordonnées GPS de Rabat/Salé', () {
      // Coordonnées GPS réelles (Rabat / Salé, Maroc)
      const latitude = 34.020882;
      const longitude = -6.841650;

      final request = const ArrivalSignalRequest(
        latitude: latitude,
        longitude: longitude,
      );

      // Sérialisation vers JSON
      final json = request.toJson();
      expect(json, {
        'latitude': latitude,
        'longitude': longitude,
      });

      // Désérialisation depuis JSON
      final fromJson = ArrivalSignalRequest.fromJson(json);
      expect(fromJson.latitude, equals(latitude));
      expect(fromJson.longitude, equals(longitude));
      expect(fromJson, equals(request));
    });

    test('gère correctement les coordonnées envoyées sous forme de nombres entiers', () {
      final json = {
        'latitude': 34,
        'longitude': -7,
      };

      final request = ArrivalSignalRequest.fromJson(json);
      expect(request.latitude, equals(34.0));
      expect(request.longitude, equals(-7.0));
    });
  });

  group('ArrivalResponse', () {
    test('désérialisation complète avec mapping snake_case vers camelCase et intégrité UUID', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      const status = 'processed';
      const textAr = 'تم تسجيل وصولكم بنجاح';
      const textFr = 'Votre arrivée a été enregistrée avec succès';

      final json = {
        'id': uuid,
        'status': status,
        'text_ar': textAr,
        'text_fr': textFr,
      };

      final response = ArrivalResponse.fromJson(json);

      expect(response.id, equals(uuid));
      expect(response.status, equals(status));
      expect(response.textAr, equals(textAr));
      expect(response.textFr, equals(textFr));

      // Sérialisation vers JSON
      final serialized = response.toJson();
      expect(serialized['id'], equals(uuid));
      expect(serialized['status'], equals(status));
      expect(serialized['text_ar'], equals(textAr));
      expect(serialized['text_fr'], equals(textFr));

      // Égalité des objets (Equatable)
      final roundTrip = ArrivalResponse.fromJson(serialized);
      expect(roundTrip, equals(response));
    });

    test('désérialisation avec messages textuels absents (null)', () {
      const uuid = 'a3b8cd12-9876-4abc-9999-123456789abc';
      const status = 'stored';

      final json = {
        'id': uuid,
        'status': status,
      };

      final response = ArrivalResponse.fromJson(json);

      expect(response.id, equals(uuid));
      expect(response.status, equals(status));
      expect(response.textAr, isNull);
      expect(response.textFr, isNull);

      final serialized = response.toJson();
      expect(serialized['id'], equals(uuid));
      expect(serialized['status'], equals(status));
      expect(serialized['text_ar'], isNull);
      expect(serialized['text_fr'], isNull);
    });

    test('gère les différents statuts de retour backend (processed, stored, failed)', () {
      final statuses = ['processed', 'stored', 'failed'];

      for (final s in statuses) {
        final json = {
          'id': 'c8a2b5e1-1111-2222-3333-444455556666',
          'status': s,
          'text_ar': 'رسالة',
          'text_fr': 'message',
        };

        final response = ArrivalResponse.fromJson(json);
        expect(response.status, equals(s));
      }
    });
  });
}
