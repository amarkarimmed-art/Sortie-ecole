import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_ui/sortie_ui.dart';

import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/phone_input_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

  final secureStorage = const FlutterSecureStorage();
  final authRemoteDataSource = AuthRemoteDataSourceImpl(dio: dio);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    secureStorage: secureStorage,
  );

  runApp(
    SortieParentApp(
      authRepository: authRepository,
    ),
  );
}

class SortieParentApp extends StatelessWidget {
  final AuthRepositoryImpl authRepository;

  const SortieParentApp({
    super.key,
    required this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(authRepository: authRepository),
      child: MaterialApp(
        title: "Sortie d'école",
        theme: SortieTheme.lightTheme,
        supportedLocales: const [
          Locale('fr'),
          Locale('ar'),
        ],
        home: const PhoneInputPage(),
      ),
    );
  }
}
