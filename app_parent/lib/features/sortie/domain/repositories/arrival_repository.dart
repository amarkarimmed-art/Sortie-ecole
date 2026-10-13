import 'package:sortie_models/sortie_models.dart';

abstract class ArrivalRepository {
  /// Signale l'arrivée du parent à l'école avec les coordonnées GPS fournies.
  ///
  /// Lève une [ArrivalException] (ex: [OutOfRadiusException], [RateLimitException]) en cas d'échec.
  Future<ArrivalResponse> signalArrival(ArrivalSignalRequest request);
}
