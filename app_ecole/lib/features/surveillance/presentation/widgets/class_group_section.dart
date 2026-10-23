import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/surveillance_repository.dart';
import '../../domain/surveillance_item.dart';
import 'child_call_card.dart';

/// Section regroupant les élèves appelés d'une classe (CA11).
///
/// Affiche le nom de la classe en en-tête et les élèves triés chronologiquement.
class ClassGroupSection extends StatelessWidget {
  final String className;
  final List<SurveillanceItem> items;
  final SurveillanceRepository? repository;
  final Future<void> Function(String requestId)? onDepart;
  final Future<void> Function(String requestId, {String? parentUserId})? onHandover;
  final String? token;

  const ClassGroupSection({
    super.key,
    required this.className,
    required this.items,
    this.repository,
    this.onDepart,
    this.onHandover,
    this.token,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de classe
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8.0,
              vertical: 6.0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.school,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                Text(
                  className.isNotEmpty ? className : (l10n?.sansClasse ?? 'Sans classe'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4.0),
          // Liste des élèves de cette classe
          ...items.map((item) => ChildCallCard(
                key: ValueKey(item.requestId),
                item: item,
                repository: repository,
                onDepart: onDepart,
                onHandover: onHandover,
                token: token,
              )),
        ],
      ),
    );
  }
}
