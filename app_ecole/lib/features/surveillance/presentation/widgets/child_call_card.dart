import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/surveillance_item.dart';

/// Carte représentant un élève appelé.
///
/// Respecte les règles d'accessibilité (cible tactile ≥ 48dp, fort contraste)
/// et RTL natif (EdgeInsetsDirectional).
class ChildCallCard extends StatelessWidget {
  final SurveillanceItem item;

  const ChildCallCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormatter = DateFormat.Hm();
    final timeString = timeFormatter.format(item.calledAt);

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
              const SizedBox(width: 16.0),
              // Classe et heure
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
              // Badge de statut class_notified
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Prévenu',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
