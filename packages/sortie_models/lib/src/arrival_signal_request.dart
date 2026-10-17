import 'package:equatable/equatable.dart';

/// Objet de Requête : ArrivalSignalRequest (F03)
///
/// Encapsule les identifiants des enfants et le statut du rayon
/// conformément au contrat backend (Loi 09-08 : aucune coordonnée GPS brute).
class ArrivalSignalRequest extends Equatable {
  final List<String> childIds;
  final bool inRadius;
  final int? distanceMeters;

  const ArrivalSignalRequest({
    required this.childIds,
    required this.inRadius,
    this.distanceMeters,
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
    );
  }

  /// Sérialisation vers un Map JSON standard.
  Map<String, dynamic> toJson() => {
        'child_ids': childIds,
        'in_radius': inRadius,
        if (distanceMeters != null) 'distance_meters': distanceMeters,
      };

  @override
  List<Object?> get props => [childIds, inRadius, distanceMeters];
}
