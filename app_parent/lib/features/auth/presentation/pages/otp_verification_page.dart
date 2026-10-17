import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../sortie/data/datasources/arrival_remote_datasource.dart';
import '../../../sortie/data/repositories/arrival_repository_impl.dart';
import '../../../sortie/presentation/bloc/arrival_bloc.dart';
import '../../../sortie/presentation/pages/arrival_status_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class OtpVerificationPage extends StatefulWidget {
  final String phone;

  const OtpVerificationPage({super.key, required this.phone});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final code = _codeController.text.trim();
      context.read<AuthBloc>().add(
            VerifyOtpSubmitted(phone: widget.phone, code: code),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification'),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final schoolId = state.user.schoolId;
            final childIds = state.user.children.map((c) => c.id).toList();
            // L'utilisateur est connecté et le token est persisté
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connexion réussie !'),
                backgroundColor: SortieColors.success,
              ),
            );
            // Naviguer vers l'écran d'arrivée avec son ArrivalBloc local
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) {
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
                  )..interceptors.add(
                      InterceptorsWrapper(
                        onRequest: (options, handler) async {
                          final token = await secureStorage.read(key: 'auth_token');
                          if (token != null) {
                            options.headers['Authorization'] = 'Bearer $token';
                          }
                          return handler.next(options);
                        },
                      ),
                    );

                  final remoteDataSource = ArrivalRemoteDataSourceImpl(
                    dio: dio,
                    schoolId: schoolId,
                    secureStorage: secureStorage,
                  );
                  final arrivalRepository = ArrivalRepositoryImpl(
                    remoteDataSource: remoteDataSource,
                  );

                  return BlocProvider<ArrivalBloc>(
                    create: (_) => ArrivalBloc(
                      arrivalRepository: arrivalRepository,
                      childIds: childIds,
                      secureStorage: secureStorage,
                    ),
                    child: const ArrivalStatusPage(),
                  );
                },
              ),
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: SortieColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                      color: SortieColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Code de confirmation',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: SortieColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saisissez le code à 6 chiffres envoyé au ${widget.phone}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SortieColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '000000',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length != 6) {
                          return 'Le code doit contenir 6 chiffres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SortiePrimaryButton(
                      label: 'Valider',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
