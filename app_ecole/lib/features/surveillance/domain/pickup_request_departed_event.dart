import 'package:equatable/equatable.dart';

/// Événement Reverb diffusé lors du départ d'un élève (transition class_notified -> on_the_way).
///
/// Respecte strictement la règle de minimisation (loi 09-08, ADR 0008, CA23) :
/// pas de nom complet, pas de photo, pas de téléphone.
class PickupRequestDepartedEvent extends Equatable {
  final String requestId;
  final String schoolId;
  final String childInitial;
  final DateTime? departedAt;

  const PickupRequestDepartedEvent({
    required this.requestId,
    required this.schoolId,
    required this.childInitial,
    this.departedAt,
  });

  factory PickupRequestDepartedEvent.fromJson(Map<String, dynamic> json) {
    final departedAtStr = json['departed_at'] as String?;
    return PickupRequestDepartedEvent(
      requestId: json['request_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      childInitial: json['child_initial'] as String? ?? '',
      departedAt: departedAtStr != null ? DateTime.tryParse(departedAtStr) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'school_id': schoolId,
        'child_initial': childInitial,
        if (departedAt != null) 'departed_at': departedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        requestId,
        schoolId,
        childInitial,
        departedAt,
      ];
}
