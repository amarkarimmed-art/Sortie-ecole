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

  const SurveillanceItem({
    required this.requestId,
    required this.childId,
    required this.childInitial,
    required this.childName,
    required this.className,
    required this.calledAt,
    required this.status,
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
      status: json['status'] as String? ?? 'class_notified',
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

  @override
  List<Object?> get props => [
        requestId,
        childId,
        childInitial,
        childName,
        className,
        calledAt,
        status,
      ];
}
