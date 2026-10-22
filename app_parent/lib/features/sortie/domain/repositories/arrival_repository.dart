import 'package:sortie_models/sortie_models.dart';

abstract class ArrivalRepository {
  /// Signale l'arrivée du parent à l'école avec les coordonnées GPS fournies.
  ///
  /// Lève une [ArrivalException] (ex: [OutOfRadiusException], [RateLimitException]) en cas d'échec.
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request);

  /// Récupère le statut de la dernière arrivée enregistrée.
  Future<Map<String, dynamic>> getArrivalStatus();

  /// Récupère l'état dynamique des horaires de l'école (F03).
  Future<ScheduleStatusDto> getScheduleStatus();

  /// Évalue la position GPS en premier plan (F03).
  Future<LocationEvaluationResponseDto> evaluateLocation(
      LocationEvaluationRequestDto request);
}
