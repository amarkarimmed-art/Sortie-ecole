import 'package:equatable/equatable.dart';

/// Objet de Réponse : ArrivalResponse
///
/// Traite le retour d'information de l'API backend Laravel
/// concernant le statut du signalement d'arrivée (F03).
class ArrivalResponse extends Equatable {
  final String id;
  final String status;
  final String? textAr;
  final String? textFr;

  const ArrivalResponse({
    required this.id,
    required this.status,
    this.textAr,
    this.textFr,
  });

  /// Désérialisation depuis un Map JSON avec conversion snake_case -> camelCase.
  factory ArrivalResponse.fromJson(Map<String, dynamic> json) {
    return ArrivalResponse(
      id: json['id'] as String,
      status: json['status'] as String,
      textAr: json['text_ar'] as String?,
      textFr: json['text_fr'] as String?,
    );
  }

  /// Sérialisation vers un Map JSON standard.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'text_ar': textAr,
      'text_fr': textFr,
    };
  }

  @override
  List<Object?> get props => [id, status, textAr, textFr];
}
