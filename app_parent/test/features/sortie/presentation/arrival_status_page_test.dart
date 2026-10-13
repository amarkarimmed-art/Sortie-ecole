import 'package:app_parent/features/sortie/domain/failures/arrival_exceptions.dart';
import 'package:app_parent/features/sortie/presentation/bloc/arrival_bloc.dart';
import 'package:app_parent/features/sortie/presentation/bloc/arrival_event.dart';
import 'package:app_parent/features/sortie/presentation/bloc/arrival_state.dart';
import 'package:app_parent/features/sortie/presentation/pages/arrival_status_page.dart';
import 'package:app_parent/features/sortie/presentation/widgets/arrival_status_badge.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sortie_models/sortie_models.dart';

class MockArrivalBloc extends MockBloc<ArrivalEvent, ArrivalState>
    implements ArrivalBloc {}

void main() {
  late MockArrivalBloc mockArrivalBloc;

  setUp(() {
    mockArrivalBloc = MockArrivalBloc();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<ArrivalBloc>.value(
        value: mockArrivalBloc,
        child: const ArrivalStatusPage(),
      ),
    );
  }

  group('ArrivalStatusPage & ArrivalStatusBadge UI tests', () {
    testWidgets('affiche l\'état initial d\'invitation', (tester) async {
      when(() => mockArrivalBloc.state).thenReturn(const ArrivalInitial());

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Vous êtes devant l\'école ?'), findsOneWidget);
      expect(find.text('Je suis arrivé'), findsOneWidget);
    });

    testWidgets('affiche le badge de recherche GPS quand ArrivalLocating', (tester) async {
      when(() => mockArrivalBloc.state).thenReturn(const ArrivalLocating());

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(ArrivalStatusBadge), findsOneWidget);
      expect(find.text('Recherche GPS en cours'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('affiche le badge vert de succès quand ArrivalSuccess', (tester) async {
      const response = ArrivalResponse(
        id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'processed',
        textFr: 'Votre arrivée est enregistrée.',
      );

      when(() => mockArrivalBloc.state).thenReturn(const ArrivalSuccess(response));

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(ArrivalStatusBadge), findsOneWidget);
      expect(find.text('Arrivée confirmée'), findsOneWidget);
      expect(find.text('Votre arrivée est enregistrée.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('affiche le badge orange hors rayon avec bouton d\'actualisation', (tester) async {
      when(() => mockArrivalBloc.state).thenReturn(
        const ArrivalFailure(OutOfRadiusException()),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(ArrivalStatusBadge), findsOneWidget);
      expect(find.text('Trop loin de l\'école'), findsOneWidget);
      expect(find.text('Actualiser ma position'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);

      // Clic sur actualiser déclenche l'événement
      await tester.tap(find.text('Actualiser ma position'));
      verify(() => mockArrivalBloc.add(const SignalArrivalRequested())).called(1);
    });

    testWidgets('affiche le badge rouge d\'erreur critique avec bouton Réessayer', (tester) async {
      when(() => mockArrivalBloc.state).thenReturn(
        const ArrivalFailure(NetworkArrivalException()),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(ArrivalStatusBadge), findsOneWidget);
      expect(find.text('Signalement impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Clic sur Réessayer déclenche l'événement
      await tester.tap(find.text('Réessayer'));
      verify(() => mockArrivalBloc.add(const SignalArrivalRequested())).called(1);
    });
  });
}
