import 'package:flutter/material.dart';

/// Point d'entrée de l'application école (tablette + surveillant).
///
/// Offline-First avec Drift (ADR 0007).
/// Bilingue FR/AR, RTL complet.
/// Boutons d'action dans la moitié inférieure de l'écran.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Initialiser Drift DB, DI (get_it), Reverb WebSocket, etc.
  runApp(const SortieEcoleApp());
}

class SortieEcoleApp extends StatelessWidget {
  const SortieEcoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sortie d'école — Accueil",
      supportedLocales: const [
        Locale('fr'),
        Locale('ar'),
      ],
      home: const Scaffold(
        body: Center(
          child: Text('Sortie d\'école — App École'), // hardcoded-ok
        ),
      ),
    );
  }
}
