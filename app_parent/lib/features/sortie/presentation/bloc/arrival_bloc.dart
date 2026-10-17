import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sortie_models/sortie_models.dart';

import '../../domain/failures/arrival_exceptions.dart';
import '../../domain/repositories/arrival_repository.dart';
import '../../domain/services/location_service.dart';
import 'arrival_event.dart';
import 'arrival_state.dart';

class ArrivalBloc extends Bloc<ArrivalEvent, ArrivalState> {
  final ArrivalRepository arrivalRepository;
  final LocationService locationService;
  final List<String> childIds;
  final FlutterSecureStorage? secureStorage;
  final double? schoolLatitude;
  final double? schoolLongitude;
  final double radiusMeters;

  ArrivalBloc({
    required this.arrivalRepository,
    LocationService? locationService,
    this.childIds = const [],
    this.secureStorage,
    this.schoolLatitude,
    this.schoolLongitude,
    this.radiusMeters = 250.0,
  })  : locationService = locationService ?? GeolocatorLocationService(),
        super(const ArrivalInitial()) {
    on<SignalArrivalRequested>(_onSignalArrivalRequested);
    on<RefreshArrivalStatusRequested>(_onRefreshArrivalStatusRequested);
  }

  Future<void> _onSignalArrivalRequested(
    SignalArrivalRequested event,
    Emitter<ArrivalState> emit,
  ) async {
    try {
      // 1. Émettre l'état de recherche GPS
      emit(const ArrivalLocating());

      // 2. Extraire la position actuelle (latitude/longitude)
      final coords = await locationService.getCurrentCoordinates();

      // 3. Émettre l'état d'envoi réseau
      emit(ArrivalSubmitting(
        latitude: coords.latitude,
        longitude: coords.longitude,
      ));

      List<String> effectiveChildIds = List<String>.from(childIds);
      if (effectiveChildIds.isEmpty && secureStorage != null) {
        final stored = await secureStorage?.read(key: 'auth_child_ids');
        if (stored != null && stored.isNotEmpty) {
          effectiveChildIds = stored.split(',').where((id) => id.isNotEmpty).toList();
        }
      }

      // Calcul de la distance et du rayon
      int? distanceMeters;
      bool inRadius = true;

      if (schoolLatitude != null && schoolLongitude != null) {
        final distance = Geolocator.distanceBetween(
          coords.latitude,
          coords.longitude,
          schoolLatitude!,
          schoolLongitude!,
        );
        // Loi 09-08 : distance arrondie aux 10m supérieurs
        distanceMeters = (distance / 10).ceil() * 10;
        inRadius = distance <= radiusMeters;
      } else {
        // Mode dev / fallback sans coordonnées d'école
        distanceMeters = 50;
        inRadius = true;
      }

      // 4. Appeler le repository d'arrivée avec le contrat backend strict
      final request = ArrivalSignalRequest(
        childIds: effectiveChildIds,
        inRadius: inRadius,
        distanceMeters: distanceMeters,
      );

      final response = await arrivalRepository.signalArrival(request);

      // 5. Émettre l'état de succès final
      emit(ArrivalSuccess(response));
    } on ArrivalException catch (e) {
      emit(ArrivalFailure(e));
    } catch (e) {
      emit(ArrivalFailure(ServerArrivalException(e.toString())));
    }
  }

  Future<void> _onRefreshArrivalStatusRequested(
    RefreshArrivalStatusRequested event,
    Emitter<ArrivalState> emit,
  ) async {
    // Si déjà dans un état d'arrivée, relance la mise à jour
    add(const SignalArrivalRequested());
  }
}
