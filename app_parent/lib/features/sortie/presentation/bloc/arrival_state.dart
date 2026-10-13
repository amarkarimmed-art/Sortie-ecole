import 'package:equatable/equatable.dart';
import 'package:sortie_models/sortie_models.dart';

import '../../domain/failures/arrival_exceptions.dart';

abstract class ArrivalState extends Equatable {
  const ArrivalState();

  @override
  List<Object?> get props => [];
}

/// État initial au chargement de l'écran.
class ArrivalInitial extends ArrivalState {
  const ArrivalInitial();
}

/// État lors de la capture des coordonnées GPS via Geolocator.
class ArrivalLocating extends ArrivalState {
  const ArrivalLocating();
}

/// État lors de l'envoi de la requête HTTP POST /v1/arrivals au serveur Laravel.
class ArrivalSubmitting extends ArrivalState {
  final double latitude;
  final double longitude;

  const ArrivalSubmitting({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}

/// État de succès après confirmation de l'arrivée par l'API backend.
class ArrivalSuccess extends ArrivalState {
  final ArrivalResponse response;

  const ArrivalSuccess(this.response);

  @override
  List<Object?> get props => [response];
}

/// État de défaillance transportant l'exception exacte rencontrée.
class ArrivalFailure extends ArrivalState {
  final ArrivalException exception;

  const ArrivalFailure(this.exception);

  String get message => exception.message;

  @override
  List<Object?> get props => [exception];
}
