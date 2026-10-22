import 'package:app_parent/features/sortie/data/datasources/arrival_remote_datasource.dart';
import 'package:app_parent/features/sortie/data/repositories/arrival_repository_impl.dart';
import 'package:app_parent/features/sortie/domain/failures/arrival_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortie_models/sortie_models.dart';

class MockArrivalRemoteDataSource implements ArrivalRemoteDataSource {
  ArrivalResponse? responseToReturn;
  Map<String, dynamic>? statusToReturn;
  DioException? errorToThrow;

  @override
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return responseToReturn!;
  }

  @override
  Future<Map<String, dynamic>> getArrivalStatus() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return statusToReturn ?? {'arrival': null, 'pickup_requests': []};
  }

  @override
  Future<ScheduleStatusDto> getScheduleStatus() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return const ScheduleStatusDto(
      isOpen: true,
      closesAt: '17:30',
      nextOpeningAt: null,
      perimeterRadius: 50,
      gateConfigured: true,
      messageFr: 'Sortie en cours',
      messageAr: 'الخروج مستمر',
    );
  }

  @override
  Future<LocationEvaluationResponseDto> evaluateLocation(
    LocationEvaluationRequestDto request,
  ) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return const LocationEvaluationResponseDto(
      proximityState: 'in_perimeter',
      distanceMeters: 25,
      perimeterRadius: 50,
      canSignalArrival: true,
    );
  }
}

void main() {
  group('ArrivalRepositoryImpl', () {
    late MockArrivalRemoteDataSource mockRemoteDataSource;
    late ArrivalRepositoryImpl repository;

    const testRequest = ArrivalSignalRequest(
      childIds: ['550e8400-e29b-41d4-a716-446655440000'],
      inRadius: true,
      distanceMeters: 50,
    );

    setUp(() {
      mockRemoteDataSource = MockArrivalRemoteDataSource();
      repository = ArrivalRepositoryImpl(remoteDataSource: mockRemoteDataSource);
    });

    test('retourne ArrivalResponse en cas de succès', () async {
      const expectedResponse = ArrivalResponse(
        id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'processed',
        textAr: 'تم تسجيل وصولكم',
        textFr: 'Votre arrivée a été enregistrée',
      );

      mockRemoteDataSource.responseToReturn = expectedResponse;

      final result = await repository.signalArrival(testRequest);
      expect(result, equals(expectedResponse));
    });

    test('lance RateLimitException quand le serveur retourne 429', () async {
      mockRemoteDataSource.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/v1/arrivals'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/arrivals'),
          statusCode: 429,
          data: {'message': 'Trop de requêtes'},
        ),
      );

      expect(
        () => repository.signalArrival(testRequest),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('lance OutOfRadiusException quand le serveur retourne 400 ou 422', () async {
      mockRemoteDataSource.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/v1/arrivals'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/arrivals'),
          statusCode: 400,
          data: {'message': 'Hors du rayon autorisé'},
        ),
      );

      expect(
        () => repository.signalArrival(testRequest),
        throwsA(isA<OutOfRadiusException>()),
      );
    });

    test('lance UnauthorizedArrivalException quand le serveur retourne 401', () async {
      mockRemoteDataSource.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/v1/arrivals'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/arrivals'),
          statusCode: 401,
          data: {'message': 'Non authentifié'},
        ),
      );

      expect(
        () => repository.signalArrival(testRequest),
        throwsA(isA<UnauthorizedArrivalException>()),
      );
    });

    test('lance NetworkArrivalException en cas de problème de connexion', () async {
      mockRemoteDataSource.errorToThrow = DioException(
        requestOptions: RequestOptions(path: '/v1/arrivals'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(
        () => repository.signalArrival(testRequest),
        throwsA(isA<NetworkArrivalException>()),
      );
    });
  });
}
