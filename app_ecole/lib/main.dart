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
      home: const SurveillanceScreen(
        token: '7|4WsEVz7nnJwh1hwqv574gF4j91UJL9GBHTDMeyqJfb6a3bfe',
        schoolId: '11111111-1111-1111-1111-111111111111',
      ),
      routes: {
        '/surveillance': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return SurveillanceScreen(token: token);
        },
      },
    );
  }
}
