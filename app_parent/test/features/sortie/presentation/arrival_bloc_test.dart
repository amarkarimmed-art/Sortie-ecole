import 'package:app_parent/features/sortie/domain/failures/arrival_exceptions.dart';
import 'package:app_parent/features/sortie/domain/repositories/arrival_repository.dart';
import 'package:app_parent/features/sortie/domain/services/location_service.dart';
import 'package:app_parent/features/sortie/presentation/bloc/arrival_bloc.dart';
import 'package:app_parent/features/sortie/presentation/bloc/arrival_event.dart';
import 'package:app_parent/features/sortie/presentation/bloc/arrival_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sortie_models/sortie_models.dart';

class MockArrivalRepository extends Mock implements ArrivalRepository {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const ArrivalSignalRequest(childIds: [], inRadius: true));
  });

  group('ArrivalBloc', () {
    late MockArrivalRepository mockArrivalRepository;
    late MockLocationService mockLocationService;

    // Coordonnées de test (Rabat / Salé)
    const testLatitude = 34.020882;
    const testLongitude = -6.841650;

    const testResponse = ArrivalResponse(
      id: '550e8400-e29b-41d4-a716-446655440000',
      status: 'processed',
      textAr: 'تم تسجيل وصولكم',
      textFr: 'Votre arrivée a été enregistrée',
    );

    setUp(() {
      mockArrivalRepository = MockArrivalRepository();
      mockLocationService = MockLocationService();
    });

    test('l\'état initial est ArrivalInitial', () {
      final bloc = ArrivalBloc(
        arrivalRepository: mockArrivalRepository,
        locationService: mockLocationService,
      );

      expect(bloc.state, equals(const ArrivalInitial()));
    });

    blocTest<ArrivalBloc, ArrivalState>(
      'émet [ArrivalLocating, ArrivalSubmitting, ArrivalSuccess] lors d\'un signalement nominal',
      build: () {
        when(() => mockLocationService.getCurrentCoordinates()).thenAnswer(
          (_) async => (latitude: testLatitude, longitude: testLongitude),
        );
        when(() => mockArrivalRepository.signalArrival(any())).thenAnswer(
          (_) async => testResponse,
        );
        return ArrivalBloc(
          arrivalRepository: mockArrivalRepository,
          locationService: mockLocationService,
        );
      },
      act: (bloc) => bloc.add(const SignalArrivalRequested()),
      expect: () => [
        const ArrivalLocating(),
        const ArrivalSubmitting(
          latitude: testLatitude,
          longitude: testLongitude,
        ),
        const ArrivalSuccess(testResponse),
      ],
      verify: (_) {
        verify(() => mockLocationService.getCurrentCoordinates()).called(1);
        verify(
          () => mockArrivalRepository.signalArrival(
            const ArrivalSignalRequest(
              childIds: [],
              inRadius: true,
              distanceMeters: 50,
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ArrivalBloc, ArrivalState>(
      'émet [ArrivalLocating, ArrivalFailure] lorsque les services GPS sont désactivés',
      build: () {
        when(() => mockLocationService.getCurrentCoordinates()).thenThrow(
          const LocationServiceDisabledException(),
        );
        return ArrivalBloc(
          arrivalRepository: mockArrivalRepository,
          locationService: mockLocationService,
        );
      },
      act: (bloc) => bloc.add(const SignalArrivalRequested()),
      expect: () => [
        const ArrivalLocating(),
        const ArrivalFailure(LocationServiceDisabledException()),
      ],
      verify: (_) {
        verify(() => mockLocationService.getCurrentCoordinates()).called(1);
        verifyNever(() => mockArrivalRepository.signalArrival(any()));
      },
    );

    blocTest<ArrivalBloc, ArrivalState>(
      'émet [ArrivalLocating, ArrivalFailure] lorsque les permissions GPS sont refusées',
      build: () {
        when(() => mockLocationService.getCurrentCoordinates()).thenThrow(
          const LocationPermissionDeniedException(),
        );
        return ArrivalBloc(
          arrivalRepository: mockArrivalRepository,
          locationService: mockLocationService,
        );
      },
      act: (bloc) => bloc.add(const SignalArrivalRequested()),
      expect: () => [
        const ArrivalLocating(),
        const ArrivalFailure(LocationPermissionDeniedException()),
      ],
      verify: (_) {
        verify(() => mockLocationService.getCurrentCoordinates()).called(1);
        verifyNever(() => mockArrivalRepository.signalArrival(any()));
      },
    );

    blocTest<ArrivalBloc, ArrivalState>(
      'émet [ArrivalLocating, ArrivalSubmitting, ArrivalFailure] quand le parent est hors rayon',
      build: () {
        when(() => mockLocationService.getCurrentCoordinates()).thenAnswer(
          (_) async => (latitude: testLatitude, longitude: testLongitude),
        );
        when(() => mockArrivalRepository.signalArrival(any())).thenThrow(
          const OutOfRadiusException(),
        );
        return ArrivalBloc(
          arrivalRepository: mockArrivalRepository,
          locationService: mockLocationService,
        );
      },
      act: (bloc) => bloc.add(const SignalArrivalRequested()),
      expect: () => [
        const ArrivalLocating(),
        const ArrivalSubmitting(
          latitude: testLatitude,
          longitude: testLongitude,
        ),
        const ArrivalFailure(OutOfRadiusException()),
      ],
    );

    blocTest<ArrivalBloc, ArrivalState>(
      'émet [ArrivalLocating, ArrivalSubmitting, ArrivalFailure] quand la limite de requêtes est atteinte',
      build: () {
        when(() => mockLocationService.getCurrentCoordinates()).thenAnswer(
          (_) async => (latitude: testLatitude, longitude: testLongitude),
        );
        when(() => mockArrivalRepository.signalArrival(any())).thenThrow(
          const RateLimitException(),
        );
        return ArrivalBloc(
          arrivalRepository: mockArrivalRepository,
          locationService: mockLocationService,
        );
      },
      act: (bloc) => bloc.add(const SignalArrivalRequested()),
      expect: () => [
        const ArrivalLocating(),
        const ArrivalSubmitting(
          latitude: testLatitude,
          longitude: testLongitude,
        ),
        const ArrivalFailure(RateLimitException()),
      ],
    );

    blocTest<ArrivalBloc, ArrivalState>(
      'émet [ArrivalLocating, ArrivalSubmitting, ArrivalFailure] en cas d\'erreur réseau',
      build: () {
        when(() => mockLocationService.getCurrentCoordinates()).thenAnswer(
          (_) async => (latitude: testLatitude, longitude: testLongitude),
        );
        when(() => mockArrivalRepository.signalArrival(any())).thenThrow(
          const NetworkArrivalException(),
        );
        return ArrivalBloc(
          arrivalRepository: mockArrivalRepository,
          locationService: mockLocationService,
        );
      },
      act: (bloc) => bloc.add(const SignalArrivalRequested()),
      expect: () => [
        const ArrivalLocating(),
        const ArrivalSubmitting(
          latitude: testLatitude,
          longitude: testLongitude,
        ),
        const ArrivalFailure(NetworkArrivalException()),
      ],
    );
  });
}
