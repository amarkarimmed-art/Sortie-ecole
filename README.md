# 🏫 Sortie d'école

> Application de gestion sécurisée des sorties scolaires — Pilote Maroc

[![PHP 8.3](https://img.shields.io/badge/PHP-8.3-777BB4?logo=php)](https://php.net)
[![Laravel 11](https://img.shields.io/badge/Laravel-11-FF2D20?logo=laravel)](https://laravel.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.5+-02569B?logo=flutter)](https://flutter.dev)
[![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql)](https://postgresql.org)

---

## Architecture Monorepo (ADR 0001)

```
Sortie-ecole/
├── api/                    # Contrat OpenAPI — source de vérité
├── backend/                # API Laravel, logique métier, Filament admin
├── app_parent/             # App mobile tuteurs (Flutter iOS/Android)
├── app_ecole/              # App tablette accueil + surveillant (Flutter + Drift)
├── packages/
│   ├── sortie_models/      # DTOs générés depuis openapi.yaml
│   └── sortie_ui/          # Design system commun (thème, RTL, FR/AR)
├── infrastructure/         # Docker Compose, Nginx, MinIO, scripts
├── docs/                   # Vision, roadmap, ADR
└── .agents/                # Règles et skills IA
```

## Séparation stricte Backend / Frontend

- **Backend** = API pure JSON (jamais de HTML/Blade)
- **Frontend** = Deux apps Flutter indépendantes
- **Seul point de contact** : `api/openapi.yaml`
- Les apps Flutter ne connaissent pas la structure Laravel

## Prérequis

- **Docker** & **Docker Compose** v2+
- **PHP 8.3** (pour le développement local hors Docker)
- **Composer 2**
- **Flutter SDK** >= 3.5.0
- **PostgreSQL 16+** (pas de SQLite, même en test)

## Démarrage rapide

### 1. Backend (Docker)

```bash
# Copier l'environnement
cp backend/.env.example backend/.env

# Lancer tous les services
cd infrastructure
docker compose up -d --build

# Installer les dépendances
docker compose exec app composer install

# Générer la clé applicative
docker compose exec app php artisan key:generate

# Exécuter les migrations
docker compose exec app php artisan migrate

# Initialiser MinIO
bash minio/init-buckets.sh
```

Ou utilisez le script tout-en-un :

```bash
bash infrastructure/scripts/setup.sh
```

### 2. Apps Flutter

```bash
# App Parent
cd app_parent
flutter pub get
flutter run

# App École
cd app_ecole
flutter pub get
flutter run
```

### 3. Packages partagés

```bash
# Modèles (après mise à jour de openapi.yaml)
cd packages/sortie_models
dart run build_runner build

# Design system
cd packages/sortie_ui
flutter pub get
```

## Services Docker

| Service | Port | Description |
|---------|------|-------------|
| **API Laravel** | `8000` | `http://localhost:8000/api/v1` |
| **PostgreSQL** | `5432` | Base de données |
| **Redis** | `6379` | Cache, queues, sessions |
| **Reverb** | `8080` | WebSockets temps réel |
| **MinIO** | `9000` / `9001` | Stockage privé photos |
| **Filament** | — | `http://admin.sortie-ecole.ma` |

## Design Patterns

```
Request → Controller → Action → Service → Repository → Model → DB
```

- **Contrôleurs minces** : injectent les Actions, retournent du JSON
- **Actions** : une intention métier = une classe
- **Services** : logique réutilisable
- **Repositories** : accès données avec filtre `school_id` automatique
- **Policies** : vérification école → 404 (jamais 403)

## Contraintes Non Négociables

| Règle | Détail |
|-------|--------|
| **PostgreSQL obligatoire** | Jamais SQLite, même en test |
| **Multi-école hermétique** | `school_id` sur toute table, scope global, 404 jamais 403 |
| **Fuseau Africa/Casablanca** | Jamais de décalage fixe `+01:00` |
| **Loi 09-08 / CNDP** | Zéro GPS en base, photos MinIO signées, notifs opaques |
| **Bilingue FR/AR** | RTL complet, `EdgeInsetsDirectional`, `start`/`end` |
| **Journal inaltérable** | `handover_logs` append-only (trigger PostgreSQL) |
| **Offline-First** | `app_ecole` avec Drift, sync idempotente |

## Tests

```bash
# Backend (PostgreSQL obligatoire)
docker compose exec app php artisan test

# Flutter
cd app_parent && flutter test
cd app_ecole && flutter test
```

## Documentation

- [Vision produit](docs/vision.md)
- [Architecture Decisions (ADR)](docs/adr/0001-a-0008-architecture-decisions.md)
- [Feuille de route MVP](docs/feuille_de_route_priorisee_mvp..md)
- [Contrat API](api/openapi.yaml)

## Licence

Projet privé — Tous droits réservés.
