import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sortie_ui/sortie_ui.dart';
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
            // L'utilisateur est connecté et le token est persisté
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connexion réussie !'),
                backgroundColor: SortieColors.success,
              ),
            );
            // Naviguer vers l'écran d'arrivée
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const ArrivalStatusPage(),
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
