import 'package:test/test.dart';
import 'package:sortie_models/sortie_models.dart';

void main() {
  group('ArrivalSignalRequest', () {
    test('sérialisation et désérialisation avec child_ids, in_radius et distance_meters', () {
      const childIds = ['dfe9382a-d28b-4896-8b0c-816ec6ac49b5'];
      const inRadius = true;
      const distanceMeters = 50;

      const request = ArrivalSignalRequest(
        childIds: childIds,
        inRadius: inRadius,
        distanceMeters: distanceMeters,
      );

      final json = request.toJson();
      expect(json, {
        'child_ids': childIds,
        'in_radius': inRadius,
        'distance_meters': distanceMeters,
      });

      final fromJson = ArrivalSignalRequest.fromJson(json);
      expect(fromJson.childIds, equals(childIds));
      expect(fromJson.inRadius, equals(inRadius));
      expect(fromJson.distanceMeters, equals(distanceMeters));
      expect(fromJson, equals(request));
    });

    test('sérialisation sans distance_meters (null)', () {
      const childIds = ['dfe9382a-d28b-4896-8b0c-816ec6ac49b5'];
      const inRadius = false;

      const request = ArrivalSignalRequest(
        childIds: childIds,
        inRadius: inRadius,
      );

      final json = request.toJson();
      expect(json, {
        'child_ids': childIds,
        'in_radius': inRadius,
      });
      expect(json.containsKey('distance_meters'), isFalse);
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
