import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

/// Bouton « Je suis arrivé » (F03).
///
/// Contraintes respectées :
/// - Horloge injectée via [clock.now()] (Règle Flutter §4)
/// - Cible tactile minimale de 48x48 dp (Règle Flutter §3)
/// - Support RTL avec [EdgeInsetsDirectional] (Règle Flutter §2)
class JeSuisArriveButton extends StatelessWidget {
  final DateTime windowStart;
  final DateTime windowEnd;
  final VoidCallback? onArrived;
  final String label;

  const JeSuisArriveButton({
    super.key,
    required this.windowStart,
    required this.windowEnd,
    required this.label,
    this.onArrived,
  });

  bool get isWithinWindow {
    final now = clock.now();
    return now.isAfter(windowStart) && now.isBefore(windowEnd);
  }

  @override
  Widget build(BuildContext context) {
    final active = isWithinWindow;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48.0,
        minHeight: 48.0,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24.0,
            vertical: 14.0,
          ),
        ),
        onPressed: active ? onArrived : null,
        child: Text(label),
      ),
    );
  }
}
