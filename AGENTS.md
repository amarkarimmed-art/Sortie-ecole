# Règles Projet — Sortie d'école

> Ce fichier est automatiquement chargé par Antigravity pour tout fichier du projet.

## Architecture du monorepo

Ce projet est structuré en monorepo (ADR 0001) :

| Dossier | Contenu | Technologie |
| ------- | ------- | ----------- |
| `api/` | Contrat OpenAPI — source de vérité | OpenAPI 3.1 |
| `backend/` | API, logique métier, back-office | Laravel 11+, PostgreSQL 16+, Redis |
| `app_parent/` | App mobile tuteurs (iOS/Android) | Flutter |
| `app_ecole/` | App tablette d'accueil + surveillant | Flutter (Drift offline-first) |
| `docs/` | Vision, roadmap, ADR | Markdown |
| `.agents/` | Règles et skills pour l'agent IA | Antigravity |
| `scripts/` | Scripts de vérification | Bash |

## Règles fondamentales

1. **Contract-First** : Modifier `api/openapi.yaml` AVANT d'écrire du code backend ou frontend.
2. **Multi-école hermétique** : Toute table métier porte `school_id`. Scope global `BelongsToSchool` obligatoire. Accès inter-école = HTTP 404 (jamais 403).
3. **Fuseau `Africa/Casablanca`** : Jamais de décalage fixe `+01:00`. Utiliser Carbon (backend) ou `clock.now()` (Flutter).
4. **Zéro donnée personnelle hors Maroc** : Notifications push = UUID opaque + texte générique uniquement.
5. **PostgreSQL obligatoire** : Pas de SQLite, même en test.
6. **Bilinguisme FR/AR** : Tout texte visible passe par les fichiers ARB. Support RTL natif (`start`/`end`, `EdgeInsetsDirectional`).
7. **Journal des remises** : `HandoverLog` en append-only strict (trigger PostgreSQL).

## Références

- Vision produit : [`docs/vision.md`](docs/vision.md)
- Architecture : [`docs/adr/`](docs/adr/)
- Règles détaillées : [`.agents/rules/`](.agents/rules/)
- Skills agent : [`.agents/skills/`](.agents/skills/)
