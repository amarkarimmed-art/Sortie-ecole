import 'package:flutter/material.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../domain/failures/arrival_exceptions.dart';
import '../bloc/arrival_state.dart';

/// Badge dynamique de statut d'arrivée F03.
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
        backgroundColor: const Color(0xFFF0FDF4), // Green 50
        borderColor: SortieColors.success,
        iconColor: SortieColors.success,
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
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: SortieColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortieColors.primaryLight, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(SortieColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: SortieColors.primary, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: SortieColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: SortieColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutOfRadiusBadge(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortieColors.warning, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_off_rounded,
                color: SortieColors.warning,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trop loin de l\'école',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E), // Amber 900
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB45309), // Amber 700
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bouton de rafraîchissement avec zone tactile ≥ 48dp
          OutlinedButton.icon(
            onPressed: onRefreshLocation,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Actualiser ma position'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              side: const BorderSide(color: SortieColors.warning, width: 1.5),
              minimumSize: const Size.fromHeight(48), // Cible tactile ≥ 48dp
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalErrorBadge(BuildContext context, ArrivalFailure failure) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), // Red 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortieColors.error, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: SortieColors.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Signalement impossible',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B), // Red 800
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      failure.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB91C1C), // Red 700
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bouton de réessai avec zone tactile ≥ 48dp
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.replay_rounded, size: 20),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SortieColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48), // Cible tactile ≥ 48dp
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: SortieColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
