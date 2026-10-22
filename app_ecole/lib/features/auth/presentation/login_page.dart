import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/auth_repository.dart';

/// Écran de connexion pour l'application école (tablette d'accueil & surveillant).
///
/// Flow d'authentification par Login + Mot de passe.
/// Formulaire centré, touches ≥ 48dp, support RTL et bilinguisme FR/AR.
class LoginPage extends StatefulWidget {
  final AuthRepository? repository;
  final FlutterSecureStorage? storage;

  const LoginPage({
    super.key,
    this.repository,
    this.storage,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthRepository _repository;
  late final FlutterSecureStorage _storage;

  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AuthRepositoryImpl();
    _storage = widget.storage ?? const FlutterSecureStorage();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final schoolId = await _storage.read(key: 'auth_school_id');
      final userName = await _storage.read(key: 'auth_user_name');
      final userRole = await _storage.read(key: 'auth_user_role');
      final schoolName = await _storage.read(key: 'auth_school_name');
      final schoolLogo = await _storage.read(key: 'auth_school_logo');

      if (token != null && token.isNotEmpty && mounted) {
        Navigator.of(context).pushReplacementNamed(
          '/surveillance',
          arguments: {
            'token': token,
            'schoolId': schoolId,
            'userName': userName,
            'userRole': userRole,
            'schoolName': schoolName,
            'schoolLogo': schoolLogo,
          },
        );
      }
    } catch (_) {}
  }

  Future<void> _handleLoginSubmit() async {
    _errorMessage = null;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final login = _loginController.text.trim();
    final password = _passwordController.text;

    try {
      final authResponse = await _repository.login(login, password);
      if (!mounted) return;

      try {
        await _storage.write(key: 'auth_token', value: authResponse.token);
        await _storage.write(key: 'auth_school_id', value: authResponse.user.schoolId);
        await _storage.write(key: 'auth_user_name', value: authResponse.user.name);
        await _storage.write(key: 'auth_user_role', value: authResponse.user.role);
        if (authResponse.user.schoolName != null) {
          await _storage.write(key: 'auth_school_name', value: authResponse.user.schoolName);
        }
        if (authResponse.user.schoolLogo != null) {
          await _storage.write(key: 'auth_school_logo', value: authResponse.user.schoolLogo);
        }
      } catch (_) {
        // Ignorer l'absence du channel natif en test
      }

      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.loginSucces)),
            ],
          ),
          backgroundColor: SortieColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacementNamed(
        '/surveillance',
        arguments: {
          'token': authResponse.token,
          'schoolId': authResponse.user.schoolId,
          'userName': authResponse.user.name,
          'userRole': authResponse.user.role,
          'schoolName': authResponse.user.schoolName,
          'schoolLogo': authResponse.user.schoolLogo,
        },
      );
    } on AuthInvalidCredentialsException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurIdentifiantsIncorrects;
      });
    } on AuthRateLimitException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurTropDeTentatives;
      });
    } on AuthSchoolSuspendedException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurEcoleSuspendue;
      });
    } on AuthUnauthorizedRoleException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurRoleNonAutorise;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurReseau;
      });
    }
  }

  void _toggleLanguage() {
    final currentLocale = Localizations.localeOf(context);
    final nextLocale = currentLocale.languageCode == 'ar'
        ? const Locale('fr')
        : const Locale('ar');
    SortieEcoleApp.setLocale(context, nextLocale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);

    return Scaffold(
      backgroundColor: SortieColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barre d'outils supérieure : sélecteur de langue bilingue FR / AR
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: TextButton.icon(
                      key: const Key('login_btn_langue'),
                      onPressed: _toggleLanguage,
                      style: TextButton.styleFrom(
                        foregroundColor: SortieColors.textSecondary,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.language_rounded, size: 20),
                      label: Text(
                        currentLocale.languageCode == 'ar' ? 'FR' : 'عربي',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Header : Logo / Titre / Badge de rôle personnel
                  _buildHeader(l10n),

                  const SizedBox(height: 16),

                  // Carte principale
                  Container(
                    decoration: BoxDecoration(
                      color: SortieColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SortieColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: SortieColors.textPrimary.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsetsDirectional.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            _buildErrorBanner(_errorMessage!),
                            const SizedBox(height: 20),
                          ],

                          // Champ Login / Identifiant
                          Text(
                            l10n.loginIdentifiantLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SortieColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('login_input_identifiant'),
                            controller: _loginController,
                            keyboardType: TextInputType.text,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: l10n.loginIdentifiantHint,
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.loginErreurIdentifiantRequis;
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleLoginSubmit(),
                          ),

                          const SizedBox(height: 18),

                          // Champ Mot de passe
                          Text(
                            l10n.loginMotDePasseLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SortieColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('login_input_password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              hintText: l10n.loginMotDePasseHint,
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                key: const Key('login_btn_toggle_password'),
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
                                return l10n.loginErreurMotDePasseRequis;
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleLoginSubmit(),
                          ),

                          const SizedBox(height: 28),

                          // Bouton Se connecter (≥ 48dp)
                          SortiePrimaryButton(
                            key: const Key('login_btn_se_connecter'),
                            label: l10n.loginBoutonSeConnecter,
                            icon: Icons.login_rounded,
                            isLoading: _isLoading,
                            onPressed: _handleLoginSubmit,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildComplianceFooter(l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SortieColors.primary,
                SortieColors.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: SortieColors.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.loginTitre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: SortieColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.loginSousTitre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: SortieColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: SortieColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SortieColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: SortieColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.loginBadgePersonnel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SortieColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      key: const Key('login_error_banner'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: SortieColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SortieColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: SortieColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SortieColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceFooter(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: SortieColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            l10n.loginBadgeSecurite,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: SortieColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
