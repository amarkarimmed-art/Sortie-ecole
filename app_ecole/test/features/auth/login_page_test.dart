import 'package:app_ecole/features/auth/data/auth_repository.dart';
import 'package:app_ecole/features/auth/presentation/login_page.dart';
import 'package:app_ecole/l10n/app_localizations.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:sortie_ui/sortie_ui.dart';

class MockAuthRepository implements AuthRepository {
  bool shouldFailRequestOtp = false;
  AuthException? requestOtpException;
  String? lastRequestedPhone;

  bool shouldFailVerifyOtp = false;
  AuthException? verifyOtpException;
  String? lastVerifiedPhone;
  String? lastVerifiedCode;

  AuthResponseDto successResponse = const AuthResponseDto(
    token: 'test_sanctum_token_456',
    user: UserDto(
      id: 'usr-surveillant-1',
      name: 'Youssef Surveillant',
      phone: '+212612345678',
      role: 'surveillant',
      locale: 'fr',
      schoolId: 'school-uuid-999',
    ),
  );

  @override
  Future<void> requestOtp(String phone) async {
    lastRequestedPhone = phone;
    if (shouldFailRequestOtp) {
      throw requestOtpException ?? const AuthNetworkException();
    }
  }

  @override
  Future<AuthResponseDto> verifyOtp(String phone, String code) async {
    lastVerifiedPhone = phone;
    lastVerifiedCode = code;
    if (shouldFailVerifyOtp) {
      throw verifyOtpException ?? const AuthInvalidOtpException();
    }
    return successResponse;
  }
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
      mockRepository = MockAuthRepository();
    });

    testWidgets('Affiche les éléments de l\'étape téléphone avec design pro max', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      // Titre & badge
      expect(find.text('Connexion Espace École'), findsOneWidget);
      expect(find.text('Portail d\'accueil et surveillance des sorties d\'élèves'), findsOneWidget);
      expect(find.text('Personnel scolaire'), findsOneWidget);
      expect(find.text('+212'), findsOneWidget);
      expect(find.text('🇲🇦'), findsOneWidget);

      // Champs et boutons
      expect(find.byKey(const Key('login_input_phone')), findsOneWidget);
      expect(find.byKey(const Key('login_btn_envoyer_code')), findsOneWidget);
      expect(find.text('Recevoir le code SMS'), findsOneWidget);

      // Pied de page Loi 09-08
      expect(find.text('Conforme CNDP & Loi 09-08 — Données protégées'), findsOneWidget);

      // Bouton de changement de langue
      expect(find.byKey(const Key('login_btn_langue')), findsOneWidget);
    });

    testWidgets('Affiche une erreur de validation si le numéro est vide ou invalide', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      // Soumettre vide
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();
      expect(find.text('Veuillez saisir votre numéro de téléphone'), findsOneWidget);

      // Saisir un numéro invalide
      await tester.enterText(find.byKey(const Key('login_input_phone')), '1234');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();
      expect(find.text('Numéro de téléphone invalide (format attendu : 06/07XXXXXXXX)'), findsOneWidget);
    });

    testWidgets('Affiche une bannière d\'erreur si l\'utilisateur est introuvable (404)', (tester) async {
      mockRepository.shouldFailRequestOtp = true;
      mockRepository.requestOtpException = const AuthUserNotFoundException();

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(
        find.text('Utilisateur introuvable. Veuillez contacter l\'administration de l\'établissement.'),
        findsOneWidget,
      );
    });
  });

  group('LoginPage - Étape OTP et navigation vers SurveillanceScreen', () {
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
    });

    testWidgets('Passe à l\'étape OTP avec numéro masqué conforme Loi 09-08', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      // Vérifier la transition vers l'étape OTP
      expect(find.byKey(const Key('login_step_otp')), findsOneWidget);
      expect(find.text('Vérification du code SMS'), findsOneWidget);

      // Masquage Loi 09-08
      expect(find.textContaining('•• •• ••'), findsOneWidget);

      // Champ OTP présent
      expect(find.byKey(const Key('login_input_otp')), findsOneWidget);
      expect(find.byKey(const Key('login_btn_valider_connexion')), findsOneWidget);
    });

    testWidgets('Bouton Modifier le numéro permet de revenir à l\'étape téléphone', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_step_otp')), findsOneWidget);

      // Clic sur Modifier le numéro
      await tester.tap(find.byKey(const Key('login_btn_modifier_numero')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_step_phone')), findsOneWidget);
    });

    testWidgets('Compte à rebours de renvoi OTP utilise l\'horloge Clock', (tester) async {
      DateTime fakeTime = DateTime(2026, 10, 17, 15, 30, 0);
      Clock testClock = Clock(() => fakeTime);

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(
            repository: mockRepository,
            clock: testClock,
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      // Compte à rebours actif
      expect(find.textContaining('Renvoyer dans'), findsOneWidget);

      // Avancer le temps de 61 secondes
      fakeTime = fakeTime.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 2));

      // Le bouton Renvoyer le code redevient disponible
      expect(find.byKey(const Key('login_btn_renvoyer_code')), findsOneWidget);
    });

    testWidgets('Vérification OTP réussie navigue vers /surveillance avec le token et schoolId', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? receivedArguments;

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
          routes: {
            '/surveillance': (context) {
              receivedArguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return const Scaffold(
                body: Text('SurveillanceScreen Arrivé'),
              );
            },
          },
        ),
      );

      // Étape 1 : Téléphone
      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      // Étape 2 : OTP
      await tester.enterText(find.byKey(const Key('login_input_otp')), '123456');
      await tester.ensureVisible(find.byKey(const Key('login_btn_valider_connexion')));
      await tester.tap(find.byKey(const Key('login_btn_valider_connexion')));
      await tester.pumpAndSettle();

      // Vérifier la navigation
      expect(find.text('SurveillanceScreen Arrivé'), findsOneWidget);
      expect(receivedArguments, isNotNull);
      expect(receivedArguments!['token'], 'test_sanctum_token_456');
      expect(receivedArguments!['schoolId'], 'school-uuid-999');
      expect(receivedArguments!['userName'], 'Youssef Surveillant');
      expect(receivedArguments!['userRole'], 'surveillant');
    });

    testWidgets('Affiche une erreur si le code OTP est invalide (401)', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockRepository.shouldFailVerifyOtp = true;
      mockRepository.verifyOtpException = const AuthInvalidOtpException();

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_input_otp')), '000000');
      await tester.ensureVisible(find.byKey(const Key('login_btn_valider_connexion')));
      await tester.tap(find.byKey(const Key('login_btn_valider_connexion')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(
        find.text('Code SMS incorrect ou expiré. Veuillez réessayer.'),
        findsOneWidget,
      );
    });

    testWidgets('Refuse la connexion si le rôle est parent', (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockRepository.shouldFailVerifyOtp = true;
      mockRepository.verifyOtpException = const AuthUnauthorizedRoleException();

      await tester.pumpWidget(
        buildTestableWidget(
          child: LoginPage(repository: mockRepository),
        ),
      );

      await tester.enterText(find.byKey(const Key('login_input_phone')), '0612345678');
      await tester.tap(find.byKey(const Key('login_btn_envoyer_code')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_input_otp')), '123456');
      await tester.ensureVisible(find.byKey(const Key('login_btn_valider_connexion')));
      await tester.tap(find.byKey(const Key('login_btn_valider_connexion')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(
        find.text('Accès réservé au personnel de l\'école (surveillants, accueil, direction).'),
        findsOneWidget,
      );
    });
  });

  group('LoginPage - Support Bilingue et RTL', () {
    testWidgets('Affiche l\'interface en arabe lorsque la locale est ar', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepository = MockAuthRepository();

      await tester.pumpWidget(
        buildTestableWidget(
          locale: const Locale('ar'),
          child: LoginPage(repository: mockRepository),
        ),
      );

      expect(find.text('تسجيل الدخول — فضاء المدرسة'), findsOneWidget);
      expect(find.text('بوابة الاستقبال ومراقبة مغادرة التلاميذ'), findsOneWidget);
      expect(find.text('أطر المدرسة'), findsOneWidget);
      expect(find.text('توصل برمز التحقق عبر SMS'), findsOneWidget);
      expect(find.text('مطابق للجنة CNDP والقانون 09-08 — البيانات محمية'), findsOneWidget);
    });
  });
}
