import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/surveillance/presentation/surveillance_screen.dart';
import 'l10n/app_localizations.dart';

/// Point d'entrée de l'application école (tablette accueil + téléphone surveillant).
///
/// Offline-First avec Drift (ADR 0007).
/// Bilingue FR/AR, RTL complet.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SortieEcoleApp());
}

class SortieEcoleApp extends StatelessWidget {
  final String initialRoute;

  const SortieEcoleApp({
    super.key,
    this.initialRoute = '/',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sortie d'école - Accueil & Surveillance",
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('ar'),
      ],
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const Scaffold(
              body: Center(
                child: Text('Sortie d\'école - App école'),
              ),
            ),
        '/surveillance': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return SurveillanceScreen(token: token);
        },
      },
    );
  }
}
