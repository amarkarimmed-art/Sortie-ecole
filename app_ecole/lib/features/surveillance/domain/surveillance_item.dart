import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'pickup_request_called_event.dart';

/// Demande au statut `class_notified` affichée sur l'écran du surveillant.
///
/// CA11 : Triée par `calledAt` ascendant, groupée par `className`.
class SurveillanceItem extends Equatable {
  final String requestId;
  final String childId;
  final String childInitial;
  final String childName;
  final String className;
  final DateTime calledAt;
  final String status;
  final String? parentName;
  final String? parentUserId;
  final int? liveDistanceMeters;
  final String proximityState;
  final String? arrivedAt;

  const SurveillanceItem({
    required this.requestId,
    required this.childId,
    required this.childInitial,
    required this.childName,
    required this.className,
    required this.calledAt,
    required this.status,
    this.parentName,
    this.parentUserId,
    this.liveDistanceMeters,
    this.proximityState = 'in_perimeter',
    this.arrivedAt,
  });

  String get id => requestId;

  factory SurveillanceItem.fromJson(Map<String, dynamic> json) {
    final rawName = json['child_name'] as String? ?? '';
    final initial = rawName.isNotEmpty
        ? '${rawName[0]}.'
        : (json['child_initial'] as String? ?? '');
    final calledAtStr = (json['called_at'] ?? json['created_at']) as String?;
    final calledAt = calledAtStr != null
        ? DateTime.tryParse(calledAtStr) ?? clock.now()
        : clock.now();

    return SurveillanceItem(
      requestId: json['id'] as String? ?? json['request_id'] as String? ?? '',
      childId: json['child_id'] as String? ?? '',
      childInitial: initial,
      childName: rawName.isNotEmpty ? rawName : initial,
      className: json['class_name'] as String? ?? '',
      calledAt: calledAt,
      status: json['status'] as String? ?? 'requested',
      parentName: json['parent_name'] as String?,
      parentUserId: json['parent_user_id'] as String?,
      liveDistanceMeters: (json['live_distance_meters'] as num?)?.toInt() ??
          (json['distance_meters'] as num?)?.toInt(),
      proximityState: json['proximity_state'] as String? ?? 'in_perimeter',
      arrivedAt: json['arrived_at'] as String?,
    );
  }

  factory SurveillanceItem.fromCalledEvent(PickupRequestCalledEvent event) {
    return SurveillanceItem(
      requestId: event.requestId,
      childId: '',
      childInitial: event.childInitial,
      childName: event.childName,
      className: event.className,
      calledAt: event.receivedAt,
      status: 'class_notified',
    );
  }

  SurveillanceItem copyWith({
    String? requestId,
    String? childId,
    String? childInitial,
    String? childName,
    String? className,
    DateTime? calledAt,
    String? status,
    String? parentName,
    String? parentUserId,
    int? liveDistanceMeters,
    String? proximityState,
    String? arrivedAt,
  }) {
    return SurveillanceItem(
      requestId: requestId ?? this.requestId,
      childId: childId ?? this.childId,
      childInitial: childInitial ?? this.childInitial,
      childName: childName ?? this.childName,
      className: className ?? this.className,
      calledAt: calledAt ?? this.calledAt,
      status: status ?? this.status,
      parentName: parentName ?? this.parentName,
      parentUserId: parentUserId ?? this.parentUserId,
      liveDistanceMeters: liveDistanceMeters ?? this.liveDistanceMeters,
      proximityState: proximityState ?? this.proximityState,
      arrivedAt: arrivedAt ?? this.arrivedAt,
    );
  }

  @override
  List<Object?> get props => [
        requestId,
        childId,
        childInitial,
        childName,
        className,
        calledAt,
        status,
        parentName,
        parentUserId,
        liveDistanceMeters,
        proximityState,
        arrivedAt,
      ];
}
