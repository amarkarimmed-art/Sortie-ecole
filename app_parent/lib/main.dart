import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_ui/sortie_ui.dart';

import 'core/auth_session_memory.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/sortie/data/datasources/arrival_remote_datasource.dart';
import 'features/sortie/data/repositories/arrival_repository_impl.dart';
import 'features/sortie/presentation/bloc/arrival_bloc.dart';
import 'features/sortie/presentation/pages/arrival_status_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = const FlutterSecureStorage();

  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = AuthSessionMemory.token ?? await secureStorage.read(key: 'auth_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
    ),
  );
  final authRemoteDataSource = AuthRemoteDataSourceImpl(dio: dio);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    secureStorage: secureStorage,
  );

  final arrivalRemoteDataSource = ArrivalRemoteDataSourceImpl(
    dio: dio,
    secureStorage: secureStorage,
  );
  final arrivalRepository = ArrivalRepositoryImpl(
    remoteDataSource: arrivalRemoteDataSource,
  );

  runApp(
    SortieParentApp(
      authRepository: authRepository,
      arrivalRepository: arrivalRepository,
    ),
  );
}

class SortieParentApp extends StatelessWidget {
  final AuthRepositoryImpl authRepository;
  final ArrivalRepositoryImpl arrivalRepository;

  const SortieParentApp({
    super.key,
    required this.authRepository,
    required this.arrivalRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepository: authRepository)
            ..add(const CheckAuthStatusRequested()),
        ),
        BlocProvider<ArrivalBloc>(
          create: (_) => ArrivalBloc(
            arrivalRepository: arrivalRepository,
            secureStorage: authRepository.secureStorage,
          ),
        ),
      ],
      child: MaterialApp(
        title: "Sortie d'école",
        theme: SortieTheme.lightTheme,
        localizationsDelegates: const [
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
        home: const AppAuthRoot(),
      ),
    );
  }
}

class AppAuthRoot extends StatelessWidget {
  const AppAuthRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        // Ne pas reconstruire la racine lors de AuthLoading (la page courante gère son propre chargement)
        if (current is AuthLoading) return false;
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const ArrivalStatusPage();
        }
        if (state is AuthInitial) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return const LoginPage();
      },
    );
  }
}
