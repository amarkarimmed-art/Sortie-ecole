import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/surveillance_repository.dart';
import '../../domain/surveillance_item.dart';

/// Carte représentant un élève appelé avec interface à 2 étapes (« En chemin » puis « Remis »).
///
/// Respecte les règles d'accessibilité (cible tactile ≥ 48dp, fort contraste)
/// et RTL natif (EdgeInsetsDirectional).
class ChildCallCard extends StatefulWidget {
  final SurveillanceItem item;
  final SurveillanceRepository? repository;
  final Future<void> Function(String requestId)? onDepart;
  final Future<void> Function(String requestId, {String? parentUserId})? onHandover;
  final String? token;

  const ChildCallCard({
    super.key,
    required this.item,
    this.repository,
    this.onDepart,
    this.onHandover,
    this.token,
  });

  @override
  State<ChildCallCard> createState() => _ChildCallCardState();
}

class _ChildCallCardState extends State<ChildCallCard> {
  bool _isLoading = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status;
  }

  @override
  void didUpdateWidget(covariant ChildCallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.status != widget.item.status) {
      _currentStatus = widget.item.status;
    }
  }

  bool get _isOnTheWay => _currentStatus == 'on_the_way';

  Future<void> _handleDepart() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.onDepart != null) {
        await widget.onDepart!(widget.item.id);
      } else if (widget.repository != null) {
        await widget.repository!.markDepart(widget.item.id, token: widget.token);
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStatus = 'on_the_way';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              l10n?.erreurDepart ?? 'Erreur lors du départ de l\'élève',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleHandover() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.onHandover != null) {
        await widget.onHandover!(
          widget.item.id,
          parentUserId: widget.item.parentUserId,
        );
      } else if (widget.repository != null) {
        await widget.repository!.markHandover(
          widget.item.id,
          parentUserId: widget.item.parentUserId,
          token: widget.token,
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              l10n?.erreurHandover ?? 'Erreur lors de la remise de l\'élève',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFormatter = DateFormat.Hm();
    final timeString = timeFormatter.format(widget.item.calledAt);
    final item = widget.item;

    final isOnTheWay = _isOnTheWay;

    // Badges de statut dynamique Google M3
    final Color statusBadgeBg = isOnTheWay
        ? const Color(0xFFD3E3FD)
        : const Color(0xFFFEF7E0);
    final Color statusBadgeFg = isOnTheWay
        ? const Color(0xFF041E49)
        : const Color(0xFFB06000);
    final String statusBadgeText = isOnTheWay
        ? (l10n?.statutEnCheminPortail ?? 'En chemin vers le portail')
        : (l10n?.statutDemandeEnClasse ?? 'Demandé / En classe');

    // Proximité
    final isInPerimeter = item.proximityState == 'in_perimeter';
    final proximityBadgeColor =
        isInPerimeter ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0);
    final proximityTextColor =
        isInPerimeter ? const Color(0xFF137333) : const Color(0xFFB06000);
    final proximityText =
        isInPerimeter ? (l10n?.dansLePerimetre ?? 'Dans le périmètre') : (l10n?.enApproche ?? 'En approche');

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: isOnTheWay ? const Color(0xFFC2E7FF) : const Color(0xFFE0E3E7),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar avec initiale
            CircleAvatar(
              radius: 22,
              backgroundColor: isOnTheWay ? const Color(0xFFD3E3FD) : const Color(0xFFCCFBF1),
              child: Text(
                item.childInitial.isNotEmpty ? item.childInitial : '?',
                style: TextStyle(
                  color: isOnTheWay ? const Color(0xFF0B57D0) : const Color(0xFF0F766E),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            // Détails : Nom en gras, classe, parent, heure et badge de statut
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.childName.isNotEmpty ? item.childName : item.childInitial,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SortieColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.className.isNotEmpty) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F9),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            item.className,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: SortieColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3.0),
                  // Nom du parent affiché clairement sous le nom de l'élève
                  Text(
                    item.parentName != null && item.parentName!.isNotEmpty
                        ? (l10n?.parentLabel(item.parentName!) ?? 'Parent : ${item.parentName}')
                        : (l10n != null ? l10n.parentLabel('—') : 'Parent : —'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: SortieColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Heure d'arrivée / appel
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: SortieColors.textSecondary,
                          ),
                          const SizedBox(width: 3.0),
                          Text(
                            timeString,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SortieColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Badge dynamique de statut
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: statusBadgeBg,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          statusBadgeText,
                          style: TextStyle(
                            color: statusBadgeFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Badge proximité
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: proximityBadgeColor,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          proximityText,
                          style: TextStyle(
                            color: proximityTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.liveDistanceMeters != null)
                        Text(
                          '${item.liveDistanceMeters} m',
                          style: const TextStyle(
                            fontSize: 11,
                            color: SortieColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            // Bouton d'action à 2 étapes avec la clé attendue 'bouton_parti_${item.id}'
            ElevatedButton.icon(
              key: Key('bouton_parti_${item.id}'),
              onPressed: _isLoading ? null : (isOnTheWay ? _handleHandover : _handleDepart),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      isOnTheWay
                          ? Icons.check_circle_outline_rounded
                          : Icons.directions_walk_rounded,
                      size: 18,
                    ),
              label: Text(
                isOnTheWay
                    ? (l10n?.boutonRemis ?? 'Remis')
                    : (l10n?.boutonEnChemin ?? 'En chemin'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOnTheWay ? const Color(0xFF146C2E) : const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                minimumSize: const Size(100, 48),
                elevation: 0,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 14.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
