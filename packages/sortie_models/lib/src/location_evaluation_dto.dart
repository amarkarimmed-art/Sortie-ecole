import 'package:equatable/equatable.dart';

import 'schedule_status_dto.dart';

class LocationEvaluationRequestDto extends Equatable {
  final double posLat;
  final double posLng;
  final double? accuracyMeters;
  final DateTime? capturedAt;

  const LocationEvaluationRequestDto({
    required this.posLat,
    required this.posLng,
    this.accuracyMeters,
    this.capturedAt,
  });

  factory LocationEvaluationRequestDto.fromJson(Map<String, dynamic> json) {
    return LocationEvaluationRequestDto(
      posLat: (json['pos_lat'] as num).toDouble(),
      posLng: (json['pos_lng'] as num).toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      capturedAt: json['captured_at'] != null ? DateTime.parse(json['captured_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pos_lat': posLat,
      'pos_lng': posLng,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (capturedAt != null) 'captured_at': capturedAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [posLat, posLng, accuracyMeters, capturedAt];
}

class LocationEvaluationResponseDto extends Equatable {
  final String proximityState;
  final int? distanceMeters;
  final int? perimeterRadius;
  final bool canSignalArrival;
  final ScheduleStatusDto? schedule;
  final String? messageFr;
  final String? messageAr;

  const LocationEvaluationResponseDto({
    required this.proximityState,
    this.distanceMeters,
    this.perimeterRadius = 50,
    required this.canSignalArrival,
    this.schedule,
    this.messageFr,
    this.messageAr,
  });

  factory LocationEvaluationResponseDto.fromJson(Map<String, dynamic> json) {
    return LocationEvaluationResponseDto(
      proximityState: json['proximity_state'] as String? ?? 'out_of_zone',
      distanceMeters: json['distance_meters'] as int? ?? 0,
      perimeterRadius: json['perimeter_radius'] as int? ?? 50,
      canSignalArrival: json['can_signal_arrival'] as bool? ?? false,
      schedule: ScheduleStatusDto.fromJson((json['schedule'] as Map<String, dynamic>?) ?? {}),
      messageFr: json['message_fr'] as String? ?? '',
      messageAr: json['message_ar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'proximity_state': proximityState,
      'distance_meters': distanceMeters,
      'perimeter_radius': perimeterRadius,
      'can_signal_arrival': canSignalArrival,
      'schedule': schedule?.toJson(),
      'message_fr': messageFr,
      'message_ar': messageAr,
    };
  }

  @override
  List<Object?> get props => [
        proximityState,
        distanceMeters,
        perimeterRadius,
        canSignalArrival,
        schedule,
        messageFr,
        messageAr,
      ];
}
