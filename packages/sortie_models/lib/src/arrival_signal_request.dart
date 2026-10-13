import 'package:equatable/equatable.dart';

/// Objet de Requête : ArrivalSignalRequest
///
/// Encapsule les coordonnées géographiques envoyées par le smartphone
/// du parent lors du clic sur le bouton d'arrivée (F03).
class ArrivalSignalRequest extends Equatable {
  final double latitude;
  final double longitude;

  const ArrivalSignalRequest({
    required this.latitude,
    required this.longitude,
  });

  /// Désérialisation depuis un Map JSON.
  factory ArrivalSignalRequest.fromJson(Map<String, dynamic> json) {
    return ArrivalSignalRequest(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// Sérialisation vers un Map JSON standard.
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  List<Object?> get props => [latitude, longitude];
}
