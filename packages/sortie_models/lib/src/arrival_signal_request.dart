import 'package:equatable/equatable.dart';

/// Objet de Requête : ArrivalSignalRequest
///
/// Encapsule les coordonnées géographiques et les identifiants des enfants
/// envoyés par le smartphone du parent lors du signalement d'arrivée (F03).
class ArrivalSignalRequest extends Equatable {
  final double latitude;
  final double longitude;
  final List<String> childIds;
  final bool inRadius;
  final int? distanceMeters;

  const ArrivalSignalRequest({
    required this.latitude,
    required this.longitude,
    this.childIds = const [],
    this.inRadius = true,
    this.distanceMeters,
  });

  /// Désérialisation depuis un Map JSON.
  factory ArrivalSignalRequest.fromJson(Map<String, dynamic> json) {
    return ArrivalSignalRequest(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      childIds: (json['child_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      inRadius: json['in_radius'] as bool? ?? true,
      distanceMeters: json['distance_meters'] as int?,
    );
  }

  /// Sérialisation vers un Map JSON standard.
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (childIds.isNotEmpty) 'child_ids': childIds,
      if (childIds.isNotEmpty) 'in_radius': inRadius,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
    };
  }

  @override
  List<Object?> get props => [latitude, longitude, childIds, inRadius, distanceMeters];
}
