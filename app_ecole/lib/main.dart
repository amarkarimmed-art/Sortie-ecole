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
        token: '1|8wQfxcW4rmyoO2tMLT5r6zfbrocNQgfXMMNgk0HY6bc51190',
        schoolId: 'a301300a-fccd-4364-af68-de50852db309',
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
