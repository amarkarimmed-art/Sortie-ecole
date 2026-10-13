import 'package:equatable/equatable.dart';

class ArrivalSignalRequestDto extends Equatable {
  final List<String> childIds;
  final bool inRadius;
  final int? distanceMeters;

  const ArrivalSignalRequestDto({
    required this.childIds,
    required this.inRadius,
    this.distanceMeters,
  });

  factory ArrivalSignalRequestDto.fromJson(Map<String, dynamic> json) {
    return ArrivalSignalRequestDto(
      childIds: List<String>.from(json['child_ids'] as List),
      inRadius: json['in_radius'] as bool,
      distanceMeters: json['distance_meters'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'child_ids': childIds,
      'in_radius': inRadius,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
    };
  }

  @override
  List<Object?> get props => [childIds, inRadius, distanceMeters];
}

class PickupRequestSummaryDto extends Equatable {
  final String id;
  final String childId;
  final String status;
  final bool inRadius;
  final int? distanceMeters;
  final DateTime? createdAt;

  const PickupRequestSummaryDto({
    required this.id,
    required this.childId,
    required this.status,
    required this.inRadius,
    this.distanceMeters,
    this.createdAt,
  });

  factory PickupRequestSummaryDto.fromJson(Map<String, dynamic> json) {
    return PickupRequestSummaryDto(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      status: json['status'] as String,
      inRadius: json['in_radius'] as bool? ?? false,
      distanceMeters: json['distance_meters'] as int?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'status': status,
      'in_radius': inRadius,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, childId, status, inRadius, distanceMeters, createdAt];
}

class ArrivalResponseDto extends Equatable {
  final String id;
  final String schoolId;
  final String userId;
  final bool inRadius;
  final int? distanceMeters;
  final List<PickupRequestSummaryDto> pickupRequests;
  final DateTime createdAt;

  const ArrivalResponseDto({
    required this.id,
    required this.schoolId,
    required this.userId,
    required this.inRadius,
    this.distanceMeters,
    required this.pickupRequests,
    required this.createdAt,
  });

  factory ArrivalResponseDto.fromJson(Map<String, dynamic> json) {
    return ArrivalResponseDto(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      userId: json['user_id'] as String,
      inRadius: json['in_radius'] as bool,
      distanceMeters: json['distance_meters'] as int?,
      pickupRequests: (json['pickup_requests'] as List? ?? [])
          .map((e) => PickupRequestSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'user_id': userId,
      'in_radius': inRadius,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      'pickup_requests': pickupRequests.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, schoolId, userId, inRadius, distanceMeters, pickupRequests, createdAt];
}
