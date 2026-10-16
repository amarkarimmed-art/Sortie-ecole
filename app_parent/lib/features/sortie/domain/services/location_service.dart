import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;
import '../failures/arrival_exceptions.dart';

/// Service d'abstraction de la géolocalisation native.
abstract class LocationService {
  Future<({double latitude, double longitude})> getCurrentCoordinates();
}

/// Implémentation réelle utilisant le package Geolocator.
class GeolocatorLocationService implements LocationService {
  @override
  Future<({double latitude, double longitude})> getCurrentCoordinates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
        'L\'autorisation d\'accès GPS a été définitivement refusée. Veuillez l\'activer dans les paramètres.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return (latitude: position.latitude, longitude: position.longitude);
  }
}
