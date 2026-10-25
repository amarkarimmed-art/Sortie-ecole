import 'package:flutter/material.dart';
import 'package:sortie_ui/sortie_ui.dart';

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
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de classe style Google Classroom / Contacts
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 4.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: SortieColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.school_rounded,
                        size: 18,
                        color: SortieColors.primary,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        className.isNotEmpty ? className : (l10n?.sansClasse ?? 'Sans classe'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: SortieColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD3E3FD),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Color(0xFF041E49),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4.0),
          // Liste des élèves de cette classe
          ...items.map((item) => ChildCallCard(
                key: ValueKey('${item.requestId}_${item.status}'),
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
