import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../sortie/presentation/pages/arrival_status_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            LoginSubmitted(
              login: _loginController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SortieColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ArrivalStatusPage()),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final errorMessage = state is AuthFailure ? state.message : null;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icône et titre
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: SortieColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: SortieColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.family_restroom_rounded,
                              size: 44,
                              color: SortieColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Espace Parents",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: SortieColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Connectez-vous pour signaler votre arrivée à l'école",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: SortieColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Bannière d'erreur
                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsetsDirectional.all(14),
                            decoration: BoxDecoration(
                              color: SortieColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SortieColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: SortieColors.error,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: const TextStyle(
                                      color: SortieColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Champ Login
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: SortieColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('parent_login_input'),
                          controller: _loginController,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            hintText: "Identifiant (ex. parent.alami@alamal)",
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Veuillez renseigner votre login";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Champ Mot de passe
                        const Text(
                          "Mot de passe",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: SortieColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          key: const Key('parent_password_input'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Votre mot de passe",
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Veuillez renseigner votre mot de passe";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        // Bouton Se connecter
                        SortiePrimaryButton(
                          key: const Key('parent_login_button'),
                          label: "Se connecter",
                          icon: Icons.login_rounded,
                          isLoading: isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
