import 'package:flutter/material.dart';

/// Point d'entrée de l'application parent (tuteurs).
///
/// Bilingue FR/AR, RTL complet.
/// Pas de logique métier dans les widgets.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Initialiser Firebase, DI (get_it), etc.
  runApp(const SortieParentApp());
}

class SortieParentApp extends StatelessWidget {
  const SortieParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sortie d'école",
      // Le thème est fourni par packages/sortie_ui
      // La navigation est gérée par go_router
      // Les locales FR/AR sont chargées depuis lib/l10n/
      supportedLocales: const [
        Locale('fr'),
        Locale('ar'),
      ],
      home: const Scaffold(
        body: Center(
          child: Text('Sortie d\'école — App Parent'), // hardcoded-ok
        ),
      ),
    );
  }
}
