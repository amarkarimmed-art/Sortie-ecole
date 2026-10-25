import 'package:flutter/material.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../domain/failures/arrival_exceptions.dart';
import '../bloc/arrival_state.dart';

/// Badge dynamique de statut d'arrivée F03 (Style Google Material 3).
///
/// Affiche l'état visuel approprié selon l'état du BLoC :
/// - En cours (recherche GPS / envoi serveur)
/// - Succès (confirmé, badge vert hautement contrasté)
/// - Hors rayon (badge orange d'attente avec bouton d'actualisation)
/// - Erreur critique (badge rouge avec bouton pour réessayer)
class ArrivalStatusBadge extends StatelessWidget {
  final ArrivalState state;
  final VoidCallback? onRetry;
  final VoidCallback? onRefreshLocation;

  const ArrivalStatusBadge({
    super.key,
    required this.state,
    this.onRetry,
    this.onRefreshLocation,
  });

  @override
  Widget build(BuildContext context) {
    if (state is ArrivalLocating) {
      return _buildLoadingBadge(
        context: context,
        title: 'Recherche GPS en cours',
        subtitle: 'Localisation de votre smartphone...',
        icon: Icons.gps_fixed_rounded,
      );
    }

    if (state is ArrivalSubmitting) {
      return _buildLoadingBadge(
        context: context,
        title: 'Transmission à l\'école',
        subtitle: 'Validation de votre présence au portail...',
        icon: Icons.send_rounded,
      );
    }

    if (state is ArrivalSuccess) {
      final success = state as ArrivalSuccess;
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final message = isArabic
          ? (success.response.textAr ?? 'تم تأكيد وصولكم بنجاح.')
          : (success.response.textFr ?? 'Votre arrivée a bien été confirmée auprès de l\'école.');

      return _buildCard(
        backgroundColor: Colors.white,
        borderColor: const Color(0xFFCEEAD6),
        iconColor: const Color(0xFF137333),
        haloColor: const Color(0xFFE6F4EA),
        icon: Icons.check_circle_rounded,
        title: 'Arrivée confirmée',
        message: message,
      );
    }

    if (state is ArrivalFailure) {
      final failure = state as ArrivalFailure;

      if (failure.exception is OutOfRadiusException) {
        return _buildOutOfRadiusBadge(context, failure.message);
      }

      return _buildCriticalErrorBadge(context, failure);
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingBadge({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD3E3FD), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0FE),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(SortieColors.primary),
                  ),
                ),
                Icon(icon, color: SortieColors.primary, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: SortieColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: SortieColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfRadiusBadge(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFEEFC3), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF7E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFB06000),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trop loin de l\'école',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB45309),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // Bouton de rafraîchissement avec zone tactile ≥ 48dp
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onRefreshLocation,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Actualiser ma position'), // hardcoded-ok
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF92400E),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                minimumSize: const Size(64, 48), // Cible tactile ≥ 48dp
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalErrorBadge(BuildContext context, ArrivalFailure failure) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFECDCA), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: SortieColors.error,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Signalement impossible',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            failure.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB91C1C),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // Bouton de réessai avec zone tactile ≥ 48dp
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text('Réessayer'), // hardcoded-ok
              style: ElevatedButton.styleFrom(
                backgroundColor: SortieColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(64, 48), // Cible tactile ≥ 48dp
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
    required Color haloColor,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: haloColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: SortieColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
