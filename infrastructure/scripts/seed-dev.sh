#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Seed développement — Données fictives uniquement
# Aucune donnée réelle (conformité Loi 09-08 / CNDP).
# ──────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "🌱 Seed des données fictives de développement..."

cd "$INFRA_DIR"
docker compose exec app php artisan db:seed

echo "✅ Base de données peuplée avec les données fictives."
