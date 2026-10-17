import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

/// Événement Reverb diffusé lors de l'appel d'un élève (transition requested -> class_notified).
///
/// Respecte strictement la règle de minimisation (loi 09-08, ADR 0008, CA13) :
/// pas de nom complet, pas de photo, pas de téléphone.
class PickupRequestCalledEvent extends Equatable {
  final String requestId;
  final String schoolId;
  final String className;
  final String childName;
  final DateTime receivedAt;

  const PickupRequestCalledEvent({
    required this.requestId,
    required this.schoolId,
    required this.className,
    required this.childName,
    required this.receivedAt,
  });

  String get childInitial => childName.isNotEmpty ? '${childName[0]}.' : '';

  factory PickupRequestCalledEvent.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    return PickupRequestCalledEvent(
      requestId: json['request_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      childName: json['child_name'] as String? ??
          json['child_initial'] as String? ??
          '',
      receivedAt: receivedAt ?? clock.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'school_id': schoolId,
        'class_name': className,
        'child_name': childName,
      };

  @override
  List<Object?> get props => [
        requestId,
        schoolId,
        className,
        childName,
        receivedAt,
      ];
}
