import 'package:equatable/equatable.dart';

abstract class ArrivalEvent extends Equatable {
  const ArrivalEvent();

  @override
  List<Object?> get props => [];
}

/// Événement principal pour déclencher le signalement d'arrivée à l'école.
class SignalArrivalRequested extends ArrivalEvent {
  const SignalArrivalRequested();
}

/// Événement secondaire pour rafraîchir manuellement ou automatiquement le statut actuel.
class RefreshArrivalStatusRequested extends ArrivalEvent {
  const RefreshArrivalStatusRequested();
}

/// Événement temps réel émis lors de la réception d'une mise à jour de statut (WebSocket ou polling).
class ArrivalRealtimeStatusUpdated extends ArrivalEvent {
  final String status;
  final String? childName;

  const ArrivalRealtimeStatusUpdated(this.status, {this.childName});

  @override
  List<Object?> get props => [status, childName];
}
