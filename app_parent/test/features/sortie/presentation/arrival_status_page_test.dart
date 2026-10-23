import 'dart:ui';

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
import 'package:sortie_ui/sortie_ui.dart';

class MockArrivalBloc extends MockBloc<ArrivalEvent, ArrivalState>
    implements ArrivalBloc {}

void main() {
  late MockArrivalBloc mockArrivalBloc;

  setUp(() {
    mockArrivalBloc = MockArrivalBloc();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: SortieTheme.lightTheme,
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

    testWidgets('affiche les étapes de progression et l\'indicateur temps réel quand ArrivalSuccess', (tester) async {
      const response = ArrivalResponse(
        id: '550e8400-e29b-41d4-a716-446655440000',
        status: 'class_notified',
        textFr: 'Votre enfant est appelé.',
      );

      when(() => mockArrivalBloc.state).thenReturn(
        const ArrivalSuccess(response, realtimeStatus: 'class_notified'),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Progression de la sortie'), findsOneWidget);
      expect(find.text('Arrivée signalée (en attente d\'appel)'), findsOneWidget);
      expect(find.text('Classe prévenue — Votre enfant est appelé'), findsOneWidget);
      expect(find.text('Enfant en chemin vers le portail'), findsOneWidget);
      expect(find.text('Enfant remis — Bonne rentrée !'), findsOneWidget);
      expect(find.byKey(const Key('parent_reverb_status_indicator')), findsOneWidget);
    });

    testWidgets('survol souris (PointerDeviceKind.mouse) sans crash layout ni mouse_tracker dans tous les états', (tester) async {
      final statesToTest = <ArrivalState>[
        const ArrivalInitial(),
        const ArrivalLocating(),
        const ArrivalSuccess(
          ArrivalResponse(
            id: '550e8400-e29b-41d4-a716-446655440000',
            status: 'processed',
            textFr: 'Votre arrivée est enregistrée.',
          ),
        ),
        const ArrivalFailure(OutOfRadiusException()),
        const ArrivalFailure(NetworkArrivalException()),
      ];

      for (final state in statesToTest) {
        when(() => mockArrivalBloc.state).thenReturn(state);
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        await tester.pump();
        await gesture.moveTo(const Offset(200, 100));
        await tester.pump();
        await gesture.moveTo(const Offset(200, 350));
        await tester.pump();
        await gesture.moveTo(const Offset(200, 550));
        await tester.pump();

        await gesture.removePointer();
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });
  });
}
