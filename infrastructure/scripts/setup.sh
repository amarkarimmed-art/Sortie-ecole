#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Setup développement — Sortie d'école
# ──────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$INFRA_DIR")"

echo "🚀 Sortie d'école — Setup développement"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Copier .env si absent
if [ ! -f "$ROOT_DIR/backend/.env" ]; then
    echo "📋 Copie de .env.example → .env"
    cp "$ROOT_DIR/backend/.env.example" "$ROOT_DIR/backend/.env"
fi

# 2. Démarrer les services Docker
echo "🐳 Démarrage des services Docker..."
cd "$INFRA_DIR"
docker compose up -d --build

# 3. Installer les dépendances Composer
echo "📦 Installation des dépendances Composer..."
docker compose exec app composer install

# 4. Générer la clé Laravel
echo "🔑 Génération de la clé applicative..."
docker compose exec app php artisan key:generate

# 5. Exécuter les migrations
echo "🗄️  Exécution des migrations..."
docker compose exec app php artisan migrate --seed

# 6. Initialiser MinIO
echo "📦 Initialisation des buckets MinIO..."
bash "$INFRA_DIR/minio/init-buckets.sh"

echo ""
echo "✅ Environnement prêt !"
echo "   API     : http://localhost:8000/api/v1"
echo "   Admin   : http://admin.sortie-ecole.ma:8000"
echo "   MinIO   : http://localhost:9001"
echo "   Reverb  : ws://localhost:8080"
