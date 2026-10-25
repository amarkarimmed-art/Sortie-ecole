import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sortie_ui/sortie_ui.dart';

import 'core/auth_session_memory.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/surveillance/presentation/surveillance_screen.dart';
import 'l10n/app_localizations.dart';

/// Point d'entrée de l'application école (tablette accueil + téléphone surveillant).
///
/// Offline-First avec Drift (ADR 0007).
/// Bilingue FR/AR, RTL complet, conforme Loi 09-08 et design system Sortie.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SortieEcoleApp());
}

class SortieEcoleApp extends StatefulWidget {
  final String initialRoute;
  final Locale? initialLocale;

  const SortieEcoleApp({
    super.key,
    this.initialRoute = '/',
    this.initialLocale,
  });

  /// Permet de basculer la langue (FR/AR) dynamiquement depuis n'importe quel écran.
  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_SortieEcoleAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<SortieEcoleApp> createState() => _SortieEcoleAppState();
}

class _SortieEcoleAppState extends State<SortieEcoleApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale ?? const Locale('fr');
  }

  void setLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sortie d'école — Accueil & Surveillance",
      theme: SortieTheme.lightTheme,
      locale: _locale,
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
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 500) {
              return child;
            }
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE2E8F0), Color(0xFFF0F4F9)],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    decoration: BoxDecoration(
                      color: SortieColors.background,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      initialRoute: widget.initialRoute,
      routes: {
        '/': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/surveillance': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? token;
          String? schoolId;
          String? schoolName;
          String? schoolLogo;

          if (args is Map<String, dynamic>) {
            token = args['token'] as String?;
            schoolId = args['schoolId'] as String?;
            schoolName = args['schoolName'] as String?;
            schoolLogo = args['schoolLogo'] as String?;
          } else if (args is String) {
            token = args;
          }

          return SurveillanceScreen(
            token: token ?? AuthSessionMemory.token,
            schoolId: schoolId ?? AuthSessionMemory.schoolId,
            schoolName: schoolName ?? AuthSessionMemory.schoolName,
            schoolLogo: schoolLogo ?? AuthSessionMemory.schoolLogo,
          );
        },
      },
    );
  }
}
