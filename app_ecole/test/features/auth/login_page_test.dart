import 'package:app_ecole/features/auth/data/auth_repository.dart';
import 'package:app_ecole/features/auth/presentation/login_page.dart';
import 'package:app_ecole/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:sortie_ui/sortie_ui.dart';

class MockAuthRepository implements AuthRepository {
  bool shouldFailLogin = false;
  AuthException? loginException;
  String? lastLogin;
  String? lastPassword;

  AuthResponseDto successResponse = const AuthResponseDto(
    token: 'test_sanctum_token_456',
    user: UserDto(
      id: 'usr-surveillant-1',
      name: 'Youssef Surveillant',
      login: 'surveillant@alamal',
      phone: '+212612345678',
      role: 'surveillant',
      locale: 'fr',
      schoolId: 'school-uuid-999',
      schoolName: 'École Al Amal',
    ),
  );

  @override
  Future<AuthResponseDto> login(String login, String password) async {
    lastLogin = login;
    lastPassword = password;
    if (shouldFailLogin) {
      throw loginException ?? const AuthInvalidCredentialsException();
    }
    return successResponse;
  }

  @override
  Future<UserDto> checkSession(String token) async {
    return successResponse.user;
  }

  @override
  Future<void> logout(String token) async {}
}

Widget buildTestableWidget({
  required Widget child,
  Locale locale = const Locale('fr'),
  Map<String, WidgetBuilder>? routes,
}) {
  return MaterialApp(
    theme: SortieTheme.lightTheme,
    locale: locale,
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
    home: child,
    routes: routes ?? {},
  );
}

void main() {
  group('LoginPage - Rendu initial & UI/UX', () {
    late MockAuthRepository mockRepository;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      mockRepository = MockAuthRepository();
    });

    testWidgets('Affiche les éléments du formulaire de connexion avec Login + Mot de passe', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      // Titre & badge
      expect(find.text('Connexion Espace École'), findsOneWidget);
      expect(find.text('Personnel scolaire'), findsOneWidget);

      // Champs et boutons avec les clés demandées
      expect(find.byKey(const Key('login_input_identifiant')), findsOneWidget);
      expect(find.byKey(const Key('login_input_password')), findsOneWidget);
      expect(find.byKey(const Key('login_btn_toggle_password')), findsOneWidget);
      expect(find.byKey(const Key('login_btn_se_connecter')), findsOneWidget);
      expect(find.byKey(const Key('login_btn_langue')), findsOneWidget);
    });

    testWidgets('Validation des champs obligatoires si soumis vides', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      final submitBtn = find.byKey(const Key('login_btn_se_connecter'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir votre identifiant'), findsOneWidget);
    });

    testWidgets('Toggle mot de passe visible/masqué', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      final passwordFinder = find.byKey(const Key('login_input_password'));
      expect(passwordFinder, findsOneWidget);

      final toggleFinder = find.byKey(const Key('login_btn_toggle_password'));
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('Affiche le bandeau d\'erreur lors d\'identifiants incorrects (401)', (tester) async {
      mockRepository.shouldFailLogin = true;
      mockRepository.loginException = const AuthInvalidCredentialsException();

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_identifiant')), 'surveillant@alamal');
      await tester.enterText(find.byKey(const Key('login_input_password')), 'badpass');

      final submitBtn = find.byKey(const Key('login_btn_se_connecter'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.text('Login ou mot de passe incorrect'), findsOneWidget);
    });

    testWidgets('Affiche le bandeau d\'erreur école suspendue (403)', (tester) async {
      mockRepository.shouldFailLogin = true;
      mockRepository.loginException = const AuthSchoolSuspendedException();

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_identifiant')), 'surveillant@alamal');
      await tester.enterText(find.byKey(const Key('login_input_password')), 'password');

      final submitBtn = find.byKey(const Key('login_btn_se_connecter'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.text('École suspendue, contactez l\'administration'), findsOneWidget);
    });

    testWidgets('Succès de connexion et navigation vers /surveillance', (tester) async {
      bool navigatedToSurveillance = false;

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
          routes: {
            '/surveillance': (context) {
              navigatedToSurveillance = true;
              return const Scaffold(body: Text('Écran Surveillance'));
            },
          },
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_identifiant')), 'surveillant@alamal');
      await tester.enterText(find.byKey(const Key('login_input_password')), 'password123');

      final submitBtn = find.byKey(const Key('login_btn_se_connecter'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(navigatedToSurveillance, isTrue);
      expect(find.text('Écran Surveillance'), findsOneWidget);
    });
  });
}
