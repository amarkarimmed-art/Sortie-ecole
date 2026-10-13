abstract class ArrivalException implements Exception {
  final String message;
  const ArrivalException(this.message);

  @override
  String toString() => message;
}

class OutOfRadiusException extends ArrivalException {
  const OutOfRadiusException([
    super.message = 'Vous devez être à proximité immédiate de l\'établissement pour signaler votre arrivée.',
  ]);
}

class RateLimitException extends ArrivalException {
  const RateLimitException([
    super.message = 'Trop de requêtes successives. Veuillez patienter avant de réessayer.',
  ]);
}

class UnauthorizedArrivalException extends ArrivalException {
  const UnauthorizedArrivalException([
    super.message = 'Session expirée ou non autorisée.',
  ]);
}

class NetworkArrivalException extends ArrivalException {
  const NetworkArrivalException([
    super.message = 'Impossible de joindre le serveur. Vérifiez votre connexion Internet.',
  ]);
}

class ServerArrivalException extends ArrivalException {
  const ServerArrivalException([
    super.message = 'Une erreur interne est survenue sur le serveur.',
  ]);
}

class LocationServiceDisabledException extends ArrivalException {
  const LocationServiceDisabledException([
    super.message = 'Les services de localisation GPS sont désactivés sur votre appareil.',
  ]);
}

class LocationPermissionDeniedException extends ArrivalException {
  const LocationPermissionDeniedException([
    super.message = 'L\'autorisation d\'accès à la position GPS a été refusée.',
  ]);
}
