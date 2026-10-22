import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/surveillance_repository.dart';
import '../../domain/surveillance_item.dart';

/// Carte représentant un élève appelé.
///
/// Respecte les règles d'accessibilité (cible tactile ≥ 48dp, fort contraste)
/// et RTL natif (EdgeInsetsDirectional).
class ChildCallCard extends StatefulWidget {
  final SurveillanceItem item;
  final SurveillanceRepository? repository;
  final Future<void> Function(String requestId)? onDepart;
  final String? token;

  const ChildCallCard({
    super.key,
    required this.item,
    this.repository,
    this.onDepart,
    this.token,
  });

  @override
  State<ChildCallCard> createState() => _ChildCallCardState();
}

class _ChildCallCardState extends State<ChildCallCard> {
  bool _isLoading = false;
  bool _isDeparted = false;

  Future<void> _handleDepart() async {
    if (_isLoading || _isDeparted) return;
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
          _isDeparted = true;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final timeFormatter = DateFormat.Hm();
    final timeString = timeFormatter.format(widget.item.calledAt);
    final item = widget.item;
    final isInPerimeter = item.proximityState == 'in_perimeter';
    final proximityBadgeColor =
        isInPerimeter ? Colors.green.shade100 : Colors.amber.shade100;
    final proximityTextColor =
        isInPerimeter ? Colors.green.shade900 : Colors.amber.shade900;
    final proximityText =
        isInPerimeter ? l10n.dansLePerimetre : l10n.enApproche;

    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: 8.0),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48.0),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12.0),
          child: Row(
            children: [
              // Avatar avec initiale uniquement (loi 09-08)
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  item.childInitial.isNotEmpty ? item.childInitial : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              // Nom de l'enfant, parent et heure
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.childName.isNotEmpty ? item.childName : item.childInitial,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.parentName != null && item.parentName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2.0),
                        child: Text(
                          l10n.parentLabel(item.parentName!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          timeString,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              // Badge de proximité et distance en direct
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 8.0,
                      vertical: 3.0,
                    ),
                    decoration: BoxDecoration(
                      color: proximityBadgeColor,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      proximityText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: proximityTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (item.liveDistanceMeters != null) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      '${item.liveDistanceMeters} m', // hardcoded-ok
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8.0),
              // Bouton "Parti" (B1)
              ElevatedButton(
                key: Key('bouton_parti_${item.id}'),
                onPressed: (_isLoading || _isDeparted) ? null : _handleDepart,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.boutonParti),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
