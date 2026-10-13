/// Sortie Models — DTOs partagés entre app_parent et app_ecole.
///
/// Définis selon api/openapi.yaml (Contract-First, ADR 0001).
/// Ce package ne connaît pas la structure Laravel backend.
library sortie_models;

export 'src/auth.dart';
export 'src/user.dart';
export 'src/child.dart';
export 'src/arrival.dart';
