import 'package:app_parent/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_parent/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app_parent/features/auth/presentation/bloc/auth_event.dart';
import 'package:app_parent/features/auth/presentation/bloc/auth_state.dart';
import 'package:app_parent/features/auth/presentation/pages/login_page.dart';
import 'package:app_parent/main.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sortie_models/sortie_models.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  group('AuthBloc tests', () {
    late MockAuthRepository mockAuthRepository;

    const testUser = UserDto(
      id: 'user-123',
      login: 'parent.test',
      role: 'parent',
      name: 'Test Parent',
      locale: 'fr',
      schoolId: 'school-123',
    );

    setUp(() {
      mockAuthRepository = MockAuthRepository();
    });

    test('l\'état initial est AuthInitial', () {
      final bloc = AuthBloc(authRepository: mockAuthRepository);
      expect(bloc.state, equals(const AuthInitial()));
    });

    blocTest<AuthBloc, AuthState>(
      'CheckAuthStatusRequested émet [AuthLoading, AuthAuthenticated] quand token et user valides',
      build: () {
        when(() => mockAuthRepository.getToken()).thenAnswer((_) async => 'fake-token');
        when(() => mockAuthRepository.checkAuthStatus()).thenAnswer((_) async => testUser);
        return AuthBloc(authRepository: mockAuthRepository);
      },
      act: (bloc) => bloc.add(const CheckAuthStatusRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(user: testUser, token: 'fake-token'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'CheckAuthStatusRequested émet [AuthLoading, AuthUnauthenticated] quand pas de token',
      build: () {
        when(() => mockAuthRepository.getToken()).thenAnswer((_) async => null);
        return AuthBloc(authRepository: mockAuthRepository);
      },
      act: (bloc) => bloc.add(const CheckAuthStatusRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'LogoutRequested appelle logout() et émet AuthUnauthenticated',
      build: () {
        when(() => mockAuthRepository.logout()).thenAnswer((_) async {});
        return AuthBloc(authRepository: mockAuthRepository);
      },
      act: (bloc) => bloc.add(const LogoutRequested()),
      expect: () => [
        const AuthUnauthenticated(),
      ],
    );
  });

  group('AppAuthRoot navigation & build tests', () {
    late MockAuthBloc mockAuthBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: const AppAuthRoot(),
        ),
      );
    }

    testWidgets('affiche CircularProgressIndicator quand AuthInitial', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('affiche LoginPage quand AuthUnauthenticated', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Espace Parents'), findsOneWidget);
    });
  });
}
