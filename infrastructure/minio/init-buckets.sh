#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Initialisation des buckets MinIO
# Exécuter après le premier démarrage de MinIO.
# ──────────────────────────────────────────────────────────────

set -euo pipefail

MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-sortie-minio}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-sortie-minio-secret}"

echo "⏳ Attente de MinIO..."
until mc alias set sortie "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" 2>/dev/null; do
    sleep 2
done

echo "📦 Création du bucket privé 'photos'..."
mc mb --ignore-existing sortie/photos

echo "🔒 Politique : accès privé uniquement (URLs signées)"
mc anonymous set none sortie/photos

echo "✅ Buckets MinIO initialisés."
