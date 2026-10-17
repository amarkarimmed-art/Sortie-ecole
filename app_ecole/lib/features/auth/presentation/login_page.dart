import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/auth_repository.dart';

/// Écran de connexion pour l'application école (tablette d'accueil & surveillant).
///
/// Flow d'authentification en 2 étapes par SMS OTP (F01) :
/// 1. Saisie du numéro de téléphone professionnel (Maroc +212)
/// 2. Saisie du code secret à 6 chiffres avec compte à rebours de renvoi.
///
/// Conforme aux règles projet :
/// - Loi 09-08 : masquage du numéro de téléphone, badge de conformité CNDP
/// - Style Flutter : zéro texte en dur (ARB), RTL natif (start/end, EdgeInsetsDirectional),
///   cibles tactiles ≥ 48dp, injection d'horloge [Clock], contraste élevé plein soleil.
class LoginPage extends StatefulWidget {
  final AuthRepository? repository;
  final Clock? clock;

  const LoginPage({
    super.key,
    this.repository,
    this.clock,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _LoginStep {
  phone,
  otp,
}

class _LoginPageState extends State<LoginPage> {
  late final AuthRepository _repository;
  late final Clock _clock;

  _LoginStep _step = _LoginStep.phone;

  // Contrôleurs de formulaires
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _otpFocusNode = FocusNode();

  // États UI
  bool _isLoading = false;
  String? _errorMessage;

  // Gestion du compte à rebours de renvoi OTP (injectable via clock)
  static const int _resendCooldownSeconds = 60;
  DateTime? _cooldownEndsAt;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AuthRepositoryImpl();
    _clock = widget.clock ?? clock;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _countdownTimer?.cancel();
    _cooldownEndsAt = _clock.now().add(const Duration(seconds: _resendCooldownSeconds));
    _remainingSeconds = _resendCooldownSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = _clock.now();
      if (_cooldownEndsAt == null || now.isAfter(_cooldownEndsAt!)) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _cooldownEndsAt = null;
        });
      } else {
        setState(() {
          _remainingSeconds = _cooldownEndsAt!.difference(now).inSeconds;
          if (_remainingSeconds < 0) _remainingSeconds = 0;
        });
      }
    });
  }

  Future<void> _handlePhoneSubmit() async {
    _errorMessage = null;
    if (!(_phoneFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();

    try {
      await _repository.requestOtp(phone);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _step = _LoginStep.otp;
        _otpController.clear();
      });

      _startCooldown();

      // Focus automatique sur le champ OTP après transition
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _otpFocusNode.requestFocus();
        }
      });
    } on AuthUserNotFoundException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurUtilisateurIntrouvable;
      });
    } on AuthRateLimitException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurTropDeTentatives;
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

  Future<void> _handleOtpSubmit() async {
    _errorMessage = null;
    if (!(_otpFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();

    try {
      final authResponse = await _repository.verifyOtp(phone, code);
      if (!mounted) return;

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

      // Navigation vers SurveillanceScreen avec les données du token Sanctum et schoolId
      Navigator.of(context).pushReplacementNamed(
        '/surveillance',
        arguments: {
          'token': authResponse.token,
          'schoolId': authResponse.user.schoolId,
          'userName': authResponse.user.name,
          'userRole': authResponse.user.role,
        },
      );
    } on AuthInvalidOtpException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurOtpEchoue;
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

  Future<void> _handleResendOtp() async {
    if (_remainingSeconds > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();

    try {
      await _repository.requestOtp(phone);
      if (!mounted) return;

      _startCooldown();
      setState(() {
        _isLoading = false;
      });
    } on AuthRateLimitException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.loginErreurTropDeTentatives;
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

  void _handleChangePhone() {
    setState(() {
      _step = _LoginStep.phone;
      _errorMessage = null;
      _otpController.clear();
      _countdownTimer?.cancel();
      _remainingSeconds = 0;
      _cooldownEndsAt = null;
    });
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
              vertical: 24.0,
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
                        minimumSize: const Size(48, 48), // Cible tactile ≥ 48dp
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.language_rounded, size: 20),
                      label: Text(
                        currentLocale.languageCode == 'ar' ? 'FR' : 'عربي',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Header : Logo / Titre / Badge de rôle personnel
                  _buildHeader(l10n),

                  const SizedBox(height: 24),

                  // Carte principale avec bordure nette et ombre douce
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
                    padding: const EdgeInsetsDirectional.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bannière d'erreur si présente
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(_errorMessage!),
                          const SizedBox(height: 20),
                        ],

                        // Étape 1 (Téléphone) ou Étape 2 (Code OTP)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _step == _LoginStep.phone
                              ? _buildPhoneStep(l10n)
                              : _buildOtpStep(l10n),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Pied de page : Confidentialité CNDP & Loi 09-08
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
        // Icône de l'établissement avec dégradé subtil
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

        // Titre de l'espace école
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

        // Sous-titre
        Text(
          l10n.loginSousTitre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: SortieColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Badge « Personnel scolaire »
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

  Widget _buildPhoneStep(AppLocalizations l10n) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const Key('login_step_phone'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.loginNumeroLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SortieColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Champ de saisie téléphone avec indicatif Maroc +212
          TextFormField(
            key: const Key('login_input_phone'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\+\s]')),
            ],
            decoration: InputDecoration(
              hintText: l10n.loginNumeroHint,
              prefixIcon: Container(
                margin: const EdgeInsetsDirectional.only(end: 12),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: BorderDirectional(
                    end: BorderSide(color: SortieColors.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🇲🇦',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.loginIndicatifMaroc,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: SortieColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.loginErreurTelephoneRequis;
              }
              final normalized = normalizeMoroccanPhone(value);
              // Format marocain valide : +212 suivi de 9 chiffres (ex. +2126XXXXXXXX ou +2127XXXXXXXX)
              if (!RegExp(r'^\+212[5-8]\d{8}$').hasMatch(normalized)) {
                return l10n.loginErreurTelephoneInvalide;
              }
              return null;
            },
            onFieldSubmitted: (_) => _handlePhoneSubmit(),
          ),

          const SizedBox(height: 8),
          Text(
            l10n.loginAideSaisie,
            style: const TextStyle(
              fontSize: 12,
              color: SortieColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Bouton Recevoir le code SMS (≥ 48dp)
          SortiePrimaryButton(
            key: const Key('login_btn_envoyer_code'),
            label: l10n.loginBoutonEnvoyer,
            icon: Icons.sms_outlined,
            isLoading: _isLoading,
            onPressed: _handlePhoneSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(AppLocalizations l10n) {
    final rawPhone = _phoneController.text.trim();
    final maskedPhone = maskMoroccanPhone(rawPhone);

    return Form(
      key: _otpFormKey,
      child: Column(
        key: const Key('login_step_otp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre de l'étape OTP
          Text(
            l10n.loginTitreOtp,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: SortieColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Numéro masqué selon Loi 09-08
          Text(
            l10n.loginSousTitreOtp(maskedPhone),
            style: const TextStyle(
              fontSize: 13,
              color: SortieColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),

          // Bouton Modifier le numéro
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('login_btn_modifier_numero'),
              onPressed: _isLoading ? null : _handleChangePhone,
              style: TextButton.styleFrom(
                foregroundColor: SortieColors.secondary,
                minimumSize: const Size(48, 48), // Cible tactile ≥ 48dp
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                l10n.loginBoutonModifierNumero,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Champ de saisie du code OTP à 6 chiffres
          TextFormField(
            key: const Key('login_input_otp'),
            focusNode: _otpFocusNode,
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
              color: SortieColors.textPrimary,
            ),
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.loginOtpHint,
              hintStyle: TextStyle(
                fontSize: 24,
                letterSpacing: 10,
                color: SortieColors.border,
              ),
              prefixIcon: const Icon(Icons.password_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.loginErreurOtpRequis;
              }
              if (value.trim().length != 6) {
                return l10n.loginErreurOtpInvalide;
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleOtpSubmit(),
          ),

          const SizedBox(height: 12),

          // Compte à rebours de renvoi du code
          Center(
            child: _remainingSeconds > 0
                ? Text(
                    l10n.loginRenvoyerDans(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 13,
                      color: SortieColors.textSecondary,
                    ),
                  )
                : TextButton.icon(
                    key: const Key('login_btn_renvoyer_code'),
                    onPressed: _isLoading ? null : _handleResendOtp,
                    style: TextButton.styleFrom(
                      foregroundColor: SortieColors.primary,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      l10n.loginBoutonRenvoyer,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          // Bouton Valider et se connecter
          SortiePrimaryButton(
            key: const Key('login_btn_valider_connexion'),
            label: l10n.loginBoutonValider,
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isLoading,
            onPressed: _handleOtpSubmit,
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
