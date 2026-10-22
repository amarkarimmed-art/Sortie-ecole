import 'package:equatable/equatable.dart';

/// Objet de Requête : ArrivalSignalRequest (F03)
///
/// Encapsule les identifiants des enfants, le statut du rayon
/// et optionnellement les coordonnées GPS temps réel pour validation serveur.
class ArrivalSignalRequest extends Equatable {
  final List<String> childIds;
  final bool inRadius;
  final int? distanceMeters;
  final double? posLat;
  final double? posLng;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final String? proximityState;

  const ArrivalSignalRequest({
    required this.childIds,
    this.inRadius = true,
    this.distanceMeters,
    this.posLat,
    this.posLng,
    this.accuracyMeters,
    this.capturedAt,
    this.proximityState,
  });

  /// Désérialisation depuis un Map JSON.
  factory ArrivalSignalRequest.fromJson(Map<String, dynamic> json) {
    return ArrivalSignalRequest(
      childIds: (json['child_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      inRadius: json['in_radius'] as bool? ?? true,
      distanceMeters: json['distance_meters'] as int?,
      posLat: (json['pos_lat'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble(),
      posLng: (json['pos_lng'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble() ??
          (json['accuracy'] as num?)?.toDouble(),
      capturedAt: json['captured_at'] != null
          ? DateTime.parse(json['captured_at'] as String)
          : (json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : null),
      proximityState: json['proximity_state'] as String?,
    );
  }

  /// Sérialisation vers un Map JSON standard.
  Map<String, dynamic> toJson() => {
        'child_ids': childIds,
        'in_radius': inRadius,
        if (distanceMeters != null) 'distance_meters': distanceMeters,
        if (posLat != null) 'pos_lat': posLat,
        if (posLng != null) 'pos_lng': posLng,
        if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
        if (capturedAt != null) 'captured_at': capturedAt!.toIso8601String(),
        if (proximityState != null) 'proximity_state': proximityState,
      };

  @override
  List<Object?> get props => [
        childIds,
        inRadius,
        distanceMeters,
        posLat,
        posLng,
        accuracyMeters,
        capturedAt,
        proximityState,
      ];
}
