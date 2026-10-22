import 'package:equatable/equatable.dart';

class QueueItemDto extends Equatable {
  final String id;
  final String childId;
  final String childName;
  final String className;
  final String status;
  final String? waitingZone;
  final String? photoUrl;
  final String? parentName;
  final String? proximityState;
  final int? distanceMeters;
  final DateTime createdAt;
  final DateTime? calledAt;

  const QueueItemDto({
    required this.id,
    required this.childId,
    required this.childName,
    required this.className,
    required this.status,
    this.waitingZone,
    this.photoUrl,
    this.parentName,
    this.proximityState,
    this.distanceMeters,
    required this.createdAt,
    this.calledAt,
  });

  factory QueueItemDto.fromJson(Map<String, dynamic> json) {
    return QueueItemDto(
      id: json['id'] as String,
      childId: json['child_id'] as String,
      childName: json['child_name'] as String,
      className: json['class_name'] as String,
      status: json['status'] as String,
      waitingZone: json['waiting_zone'] as String?,
      photoUrl: json['photo_url'] as String?,
      parentName: json['parent_name'] as String?,
      proximityState: json['proximity_state'] as String?,
      distanceMeters: json['distance_meters'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      calledAt: json['called_at'] != null ? DateTime.parse(json['called_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'child_id': childId,
      'child_name': childName,
      'class_name': className,
      'status': status,
      if (waitingZone != null) 'waiting_zone': waitingZone,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (parentName != null) 'parent_name': parentName,
      if (proximityState != null) 'proximity_state': proximityState,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      'created_at': createdAt.toIso8601String(),
      if (calledAt != null) 'called_at': calledAt!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        childId,
        childName,
        className,
        status,
        waitingZone,
        photoUrl,
        parentName,
        proximityState,
        distanceMeters,
        createdAt,
        calledAt,
      ];
}
