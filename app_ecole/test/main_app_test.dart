import 'package:app_ecole/features/auth/presentation/login_page.dart';
import 'package:app_ecole/features/surveillance/presentation/surveillance_screen.dart';
import 'package:app_ecole/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SortieEcoleApp - Démarrage et routes', () {
    testWidgets('L\'application démarre sur LoginPage par défaut sans token en dur', (tester) async {
      await tester.pumpWidget(const SortieEcoleApp());
      await tester.pumpAndSettle();

      // Vérifie que l'écran affiché est LoginPage et non directement SurveillanceScreen
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SurveillanceScreen), findsNothing);
      expect(find.text('Connexion Espace École'), findsOneWidget);
    });

    testWidgets('La route /surveillance affiche SurveillanceScreen', (tester) async {
      await tester.pumpWidget(
        const SortieEcoleApp(initialRoute: '/surveillance'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SurveillanceScreen), findsOneWidget);
    });
  });
}
