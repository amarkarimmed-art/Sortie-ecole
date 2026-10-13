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
