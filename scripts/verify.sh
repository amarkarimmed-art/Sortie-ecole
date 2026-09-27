#!/usr/bin/env bash
# =============================================================================
# scripts/verify.sh — Script de vérification globale du monorepo Sortie d'école
# =============================================================================
#
# Référence : ADR 0001 (Structure Monorepo)
# Ce script valide l'intégralité du cycle avant chaque commit / en CI.
#
# Usage :
#   ./scripts/verify.sh              # Exécuter toutes les vérifications
#   ./scripts/verify.sh --api        # OpenAPI uniquement
#   ./scripts/verify.sh --backend    # Laravel uniquement
#   ./scripts/verify.sh --flutter    # Les deux apps Flutter
#   ./scripts/verify.sh --security   # Garde-fous sécurité / CNDP 09-08
#   ./scripts/verify.sh --i18n       # Complétude traductions ARB
#
# Codes de sortie :
#   0 = Toutes les vérifications ont réussi
#   1 = Au moins une vérification a échoué
# =============================================================================

set -euo pipefail

# ── Couleurs & Formatage ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${CYAN}ℹ${NC}"

ERRORS=0
WARNINGS=0
SKIPPED=0

# ── Racine du Monorepo ───────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ── Helpers ──────────────────────────────────────────────────────────────────

log_section() {
  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_pass() { echo -e "  ${PASS} $1"; }
log_fail() { echo -e "  ${FAIL} $1"; ERRORS=$((ERRORS + 1)); }
log_warn() { echo -e "  ${WARN} $1"; WARNINGS=$((WARNINGS + 1)); }
log_skip() { echo -e "  ${INFO} $1 (ignoré — répertoire absent)"; SKIPPED=$((SKIPPED + 1)); }

dir_exists() { [[ -d "$1" ]]; }
cmd_exists() { command -v "$1" &>/dev/null; }

# ── Sélection des étapes ─────────────────────────────────────────────────────
RUN_ALL=true
RUN_API=false
RUN_BACKEND=false
RUN_FLUTTER=false
RUN_SECURITY=false
RUN_I18N=false

for arg in "$@"; do
  case "$arg" in
    --api)      RUN_API=true;      RUN_ALL=false ;;
    --backend)  RUN_BACKEND=true;  RUN_ALL=false ;;
    --flutter)  RUN_FLUTTER=true;  RUN_ALL=false ;;
    --security) RUN_SECURITY=true; RUN_ALL=false ;;
    --i18n)     RUN_I18N=true;     RUN_ALL=false ;;
    --help|-h)
      head -n 18 "$0" | tail -n 12
      exit 0
      ;;
    *)
      echo -e "${RED}Option inconnue : $arg${NC}"
      echo "Utiliser --help pour la liste des options."
      exit 1
      ;;
  esac
done

# =============================================================================
# ÉTAPE 1 — Contrat API (OpenAPI)
# Réf. ADR 0001 : « Spécification OpenAPI rédigée et lintée avant tout code »
# =============================================================================
run_api_checks() {
  log_section "1/5 — Contrat API (OpenAPI)"

  if [[ ! -f "api/openapi.yaml" ]]; then
    log_skip "api/openapi.yaml introuvable"
    return
  fi

  # Lint avec Spectral (https://github.com/stoplightio/spectral)
  if cmd_exists npx; then
    echo -e "  ${INFO} Linting OpenAPI avec Spectral..."
    if npx --yes @stoplight/spectral-cli lint api/openapi.yaml \
        --fail-severity warn 2>&1 | tail -n 5; then
      log_pass "Spectral lint OK"
    else
      log_fail "Spectral lint a détecté des erreurs dans api/openapi.yaml"
    fi
  else
    log_warn "npx non trouvé — impossible de lancer Spectral"
  fi

  # Vérifier que le fichier n'est pas vide
  if [[ -s "api/openapi.yaml" ]]; then
    log_pass "api/openapi.yaml présent et non vide"
  else
    log_fail "api/openapi.yaml est vide"
  fi
}

# =============================================================================
# ÉTAPE 2 — Backend Laravel
# Réf. ADR 0002, Règles Backend (40)
# =============================================================================
run_backend_checks() {
  log_section "2/5 — Backend Laravel"

  if ! dir_exists "backend"; then
    log_skip "backend/"
    return
  fi

  cd "$REPO_ROOT/backend"

  # 2a. Vérifier que les dépendances sont installées
  if [[ ! -d "vendor" ]]; then
    log_warn "vendor/ absent — exécuter 'composer install' d'abord"
    cd "$REPO_ROOT"
    return
  fi

  # 2b. Laravel Pint (formatage PSR-12 / Laravel)
  if [[ -f "vendor/bin/pint" ]]; then
    echo -e "  ${INFO} Vérification du formatage avec Laravel Pint..."
    if php vendor/bin/pint --test 2>&1 | tail -n 3; then
      log_pass "Laravel Pint — formatage conforme"
    else
      log_fail "Laravel Pint — fichiers non conformes (exécuter 'php vendor/bin/pint' pour corriger)"
    fi
  else
    log_warn "Laravel Pint non installé"
  fi

  # 2c. Larastan / PHPStan (analyse statique)
  if [[ -f "vendor/bin/phpstan" ]]; then
    echo -e "  ${INFO} Analyse statique avec Larastan (PHPStan)..."
    if php vendor/bin/phpstan analyse --memory-limit=512M 2>&1 | tail -n 5; then
      log_pass "Larastan — aucune erreur"
    else
      log_fail "Larastan — erreurs détectées"
    fi
  else
    log_warn "Larastan/PHPStan non installé"
  fi

  # 2d. Tests Pest (obligatoirement contre PostgreSQL — Règle Backend §5)
  if [[ -f "vendor/bin/pest" ]]; then
    echo -e "  ${INFO} Exécution des tests Pest..."

    # Vérifier que la config de test utilise bien pgsql (pas sqlite)
    if [[ -f "phpunit.xml" ]]; then
      if grep -qi "sqlite" phpunit.xml; then
        log_fail "phpunit.xml contient une référence à SQLite — interdit par ADR 0002 et Règle Backend §5"
      else
        log_pass "phpunit.xml ne référence pas SQLite"
      fi
    fi

    if php vendor/bin/pest --parallel 2>&1 | tail -n 10; then
      log_pass "Tests Pest OK"
    else
      log_fail "Tests Pest en échec"
    fi
  else
    log_warn "Pest non installé"
  fi

  # 2e. Vérifier la présence du trait BelongsToSchool (Règle Backend §2 / ADR 0005)
  if grep -rq "BelongsToSchoolTrait\|BelongsToSchool" app/Models/ 2>/dev/null ||
     grep -rq "BelongsToSchoolTrait\|BelongsToSchool" app/Traits/ 2>/dev/null; then
    log_pass "Trait BelongsToSchool détecté dans le code"
  else
    log_warn "Trait BelongsToSchool non trouvé — à implémenter (ADR 0005)"
  fi

  cd "$REPO_ROOT"
}

# =============================================================================
# ÉTAPE 3 — Applications Flutter (app_parent + app_ecole)
# Réf. ADR 0003, ADR 0007, Règles Flutter (41)
# =============================================================================
run_flutter_checks() {
  log_section "3/5 — Applications Flutter"

  for app_dir in app_parent app_ecole; do
    echo ""
    echo -e "  ${BOLD}── ${app_dir} ──${NC}"

    if ! dir_exists "$app_dir"; then
      log_skip "$app_dir/"
      continue
    fi

    cd "$REPO_ROOT/$app_dir"

    # 3a. flutter pub get
    if [[ ! -d ".dart_tool" ]] && [[ ! -f "pubspec.lock" ]]; then
      log_warn "Dépendances non résolues — exécuter 'flutter pub get' dans $app_dir/"
    fi

    if cmd_exists flutter; then
      # 3b. Analyse statique Dart
      echo -e "  ${INFO} Analyse statique Flutter ($app_dir)..."
      if flutter analyze --no-pub 2>&1 | tail -n 5; then
        log_pass "$app_dir — flutter analyze OK"
      else
        log_fail "$app_dir — flutter analyze a détecté des erreurs"
      fi

      # 3c. Tests unitaires et de widgets
      echo -e "  ${INFO} Tests Flutter ($app_dir)..."
      if flutter test 2>&1 | tail -n 5; then
        log_pass "$app_dir — flutter test OK"
      else
        log_fail "$app_dir — tests en échec"
      fi
    else
      log_warn "flutter CLI non trouvé dans le PATH"
    fi

    # 3d. Vérifier les fichiers ARB de localisation (Règle Flutter §1)
    if [[ -f "lib/l10n/app_fr.arb" ]] && [[ -f "lib/l10n/app_ar.arb" ]]; then
      log_pass "$app_dir — fichiers ARB (fr + ar) présents"
    else
      log_warn "$app_dir — fichiers ARB manquants (lib/l10n/app_fr.arb et/ou app_ar.arb)"
    fi

    # 3e. Vérifier la fraîcheur du codegen Drift (Règle Flutter §5 — app_ecole)
    if [[ "$app_dir" == "app_ecole" ]]; then
      drift_files=$(find lib -name "*.g.dart" 2>/dev/null | head -n 1)
      if [[ -n "$drift_files" ]]; then
        log_pass "$app_dir — fichiers Drift générés (*.g.dart) présents"
        echo -e "  ${INFO} Conseil : exécuter 'dart run build_runner build' si le schéma a changé"
      fi
    fi

    cd "$REPO_ROOT"
  done
}

# =============================================================================
# ÉTAPE 4 — Garde-fous Sécurité & Conformité CNDP 09-08
# Réf. Règles Sécurité (30), ADR 0004, ADR 0005
# =============================================================================
run_security_checks() {
  log_section "4/5 — Sécurité & Conformité CNDP 09-08"

  # 4a. Aucune coordonnée GPS brute dans le code (Règle Sécurité §2)
  echo -e "  ${INFO} Recherche de colonnes GPS interdites dans les migrations..."
  gps_violations=$(grep -rn \
    --include="*.php" \
    --include="*.yaml" \
    --include="*.yml" \
    -E "(latitude|longitude|->decimal\('lat|->decimal\('lng|->float\('lat|->float\('lng)" \
    backend/ api/ 2>/dev/null || true)

  if [[ -z "$gps_violations" ]]; then
    log_pass "Aucune colonne GPS brute (lat/lng/latitude/longitude) détectée"
  else
    log_fail "Colonnes GPS brutes détectées — interdit par Règle Sécurité §2 :"
    echo "$gps_violations" | head -n 10 | while IFS= read -r line; do
      echo -e "    ${RED}→ $line${NC}"
    done
  fi

  # 4b. Pas de DateTime.now() direct dans Flutter (Règle Flutter §4)
  echo -e "  ${INFO} Recherche de DateTime.now() direct dans Flutter..."
  datetime_violations=$(grep -rn \
    --include="*.dart" \
    "DateTime\.now()" \
    app_parent/ app_ecole/ 2>/dev/null \
    | grep -v "\.g\.dart" \
    | grep -v "test/" \
    | grep -v "_test\.dart" || true)

  if [[ -z "$datetime_violations" ]]; then
    log_pass "Aucun appel direct à DateTime.now() dans le code Flutter (hors tests)"
  else
    log_fail "Appels directs à DateTime.now() détectés — utiliser clock.now() (Règle Flutter §4) :"
    echo "$datetime_violations" | head -n 10 | while IFS= read -r line; do
      echo -e "    ${RED}→ $line${NC}"
    done
  fi

  # 4c. Pas de décalage horaire fixe en dur (Règle Backend §3)
  echo -e "  ${INFO} Recherche de décalages horaires fixes en dur..."
  tz_violations=$(grep -rn \
    --include="*.php" \
    --include="*.dart" \
    -E "([\'\"][\+\-]0[01]:00[\'\"]|UTC[\+\-][01])" \
    backend/ app_parent/ app_ecole/ 2>/dev/null || true)

  if [[ -z "$tz_violations" ]]; then
    log_pass "Aucun décalage horaire fixe en dur (+01:00 / UTC+1)"
  else
    log_fail "Décalages horaires fixes détectés — utiliser Africa/Casablanca (Règle Backend §3) :"
    echo "$tz_violations" | head -n 10 | while IFS= read -r line; do
      echo -e "    ${RED}→ $line${NC}"
    done
  fi

  # 4d. Pas de withoutGlobalScopes() sans commentaire justificatif (Règle Backend §2)
  echo -e "  ${INFO} Recherche de withoutGlobalScopes() non justifiés..."
  if dir_exists "backend"; then
    scope_calls=$(grep -rn --include="*.php" "withoutGlobalScopes" backend/ 2>/dev/null || true)
    if [[ -n "$scope_calls" ]]; then
      # Vérifier que chaque occurrence est précédée d'un commentaire
      unjustified=0
      while IFS=: read -r file line_num content; do
        prev_line=$((line_num - 1))
        if ! sed -n "${prev_line}p" "$file" | grep -q "//\|/\*\|#"; then
          log_fail "withoutGlobalScopes() sans commentaire justificatif — $file:$line_num"
          unjustified=$((unjustified + 1))
        fi
      done <<< "$scope_calls"
      if [[ $unjustified -eq 0 ]]; then
        log_pass "Tous les appels withoutGlobalScopes() sont justifiés par un commentaire"
      fi
    else
      log_pass "Aucun appel à withoutGlobalScopes() dans le backend"
    fi
  fi

  # 4e. Pas de données personnelles réelles dans les fixtures/tests (Règle Sécurité §1)
  echo -e "  ${INFO} Recherche de patterns de données personnelles dans le code..."
  # Recherche de numéros de téléphone marocains réalistes (06/07 + 8 chiffres)
  pii_phone=$(grep -rn \
    --include="*.php" \
    --include="*.dart" \
    --include="*.json" \
    --include="*.csv" \
    -E "0[67][0-9]{8}" \
    backend/ app_parent/ app_ecole/ docs/ 2>/dev/null \
    | grep -v "node_modules" \
    | grep -v "vendor" \
    | grep -v "\.lock" || true)

  if [[ -z "$pii_phone" ]]; then
    log_pass "Aucun numéro de téléphone marocain réaliste détecté dans le code"
  else
    log_warn "Patterns ressemblant à des numéros marocains détectés — vérifier qu'il s'agit de données fictives :"
    echo "$pii_phone" | head -n 5 | while IFS= read -r line; do
      echo -e "    ${YELLOW}→ $line${NC}"
    done
  fi

  # 4f. Vérifier que .env de production n'est pas versionné
  if [[ -f "backend/.env" ]] && git ls-files --error-unmatch "backend/.env" &>/dev/null; then
    log_fail "backend/.env est suivi par Git — l'ajouter dans .gitignore immédiatement"
  else
    log_pass "backend/.env n'est pas versionné"
  fi

  # 4g. Vérifier le trigger append-only sur handover_logs (Règle Sécurité §4)
  if dir_exists "backend/database/migrations"; then
    if grep -rq "handover_logs_ajout_seul\|interdire_modif_journal" backend/database/migrations/ 2>/dev/null; then
      log_pass "Trigger append-only sur handover_logs détecté dans les migrations"
    else
      log_warn "Trigger append-only handover_logs non trouvé dans les migrations — à implémenter (Règle Sécurité §4)"
    fi
  fi
}

# =============================================================================
# ÉTAPE 5 — Complétude des Traductions (i18n)
# Réf. Règles Flutter (41) §1
# =============================================================================
run_i18n_checks() {
  log_section "5/5 — Complétude des Traductions (i18n)"

  for app_dir in app_parent app_ecole; do
    local arb_fr="$app_dir/lib/l10n/app_fr.arb"
    local arb_ar="$app_dir/lib/l10n/app_ar.arb"

    if [[ ! -f "$arb_fr" ]] || [[ ! -f "$arb_ar" ]]; then
      log_skip "$app_dir — fichiers ARB non encore créés"
      continue
    fi

    # Extraire les clés (lignes commençant par " suivi d'un mot, excluant les @-metadata)
    keys_fr=$(grep -oP '^\s*"\K[^@"][^"]*' "$arb_fr" | sort)
    keys_ar=$(grep -oP '^\s*"\K[^@"][^"]*' "$arb_ar" | sort)

    # Clés présentes en FR mais absentes en AR
    missing_in_ar=$(comm -23 <(echo "$keys_fr") <(echo "$keys_ar") || true)
    # Clés présentes en AR mais absentes en FR
    missing_in_fr=$(comm -13 <(echo "$keys_fr") <(echo "$keys_ar") || true)

    if [[ -z "$missing_in_ar" ]] && [[ -z "$missing_in_fr" ]]; then
      log_pass "$app_dir — traductions FR ↔ AR synchronisées ($(echo "$keys_fr" | wc -l | tr -d ' ') clés)"
    else
      if [[ -n "$missing_in_ar" ]]; then
        count=$(echo "$missing_in_ar" | wc -l | tr -d ' ')
        log_fail "$app_dir — $count clé(s) présente(s) en FR mais absente(s) en AR :"
        echo "$missing_in_ar" | head -n 5 | while IFS= read -r key; do
          echo -e "    ${RED}→ \"$key\"${NC}"
        done
      fi
      if [[ -n "$missing_in_fr" ]]; then
        count=$(echo "$missing_in_fr" | wc -l | tr -d ' ')
        log_fail "$app_dir — $count clé(s) présente(s) en AR mais absente(s) en FR :"
        echo "$missing_in_fr" | head -n 5 | while IFS= read -r key; do
          echo -e "    ${RED}→ \"$key\"${NC}"
        done
      fi
    fi

    # Vérifier que chaque clé arabe a un @description (Règle Flutter §1)
    if [[ -f "$arb_ar" ]]; then
      ar_keys=$(grep -oP '^\s*"\K[^@"][^"]*' "$arb_ar" || true)
      missing_desc=0
      while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! grep -q "\"@$key\"" "$arb_ar" 2>/dev/null; then
          missing_desc=$((missing_desc + 1))
        fi
      done <<< "$ar_keys"
      if [[ $missing_desc -eq 0 ]]; then
        log_pass "$app_dir — toutes les clés AR ont un @description"
      else
        log_warn "$app_dir — $missing_desc clé(s) AR sans @description associée"
      fi
    fi
  done

  # Recherche de textes en dur dans le code Dart (Règle Flutter §1 : zéro texte en dur)
  echo ""
  echo -e "  ${INFO} Recherche de textes en dur dans les widgets Flutter..."
  for app_dir in app_parent app_ecole; do
    if ! dir_exists "$app_dir/lib"; then
      continue
    fi

    # Chercher les Text('...') ou Text("...") avec du contenu non-vide
    hardcoded=$(grep -rn \
      --include="*.dart" \
      -E "Text\(\s*['\"][^'\"]+['\"]" \
      "$app_dir/lib/" 2>/dev/null \
      | grep -v "\.g\.dart" \
      | grep -v "_test\.dart" \
      | grep -v "// hardcoded-ok" || true)

    if [[ -z "$hardcoded" ]]; then
      log_pass "$app_dir — aucun texte en dur détecté dans les widgets"
    else
      count=$(echo "$hardcoded" | wc -l | tr -d ' ')
      log_fail "$app_dir — $count occurrence(s) de texte en dur dans les widgets (utiliser les fichiers ARB) :"
      echo "$hardcoded" | head -n 5 | while IFS= read -r line; do
        echo -e "    ${RED}→ $line${NC}"
      done
    fi
  done
}

# =============================================================================
# Exécution
# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Sortie d'école — Vérification Globale du Monorepo      ║${NC}"
echo -e "${BOLD}║     $(date '+%Y-%m-%d %H:%M:%S')                                    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

if $RUN_ALL || $RUN_API;      then run_api_checks;      fi
if $RUN_ALL || $RUN_BACKEND;  then run_backend_checks;  fi
if $RUN_ALL || $RUN_FLUTTER;  then run_flutter_checks;  fi
if $RUN_ALL || $RUN_SECURITY; then run_security_checks; fi
if $RUN_ALL || $RUN_I18N;     then run_i18n_checks;     fi

# =============================================================================
# Rapport Final
# =============================================================================
log_section "Rapport Final"

echo -e "  ${PASS} Réussites   : succès détectés"
echo -e "  ${FAIL} Échecs      : ${ERRORS}"
echo -e "  ${WARN} Avertissem. : ${WARNINGS}"
echo -e "  ${INFO} Ignorés     : ${SKIPPED}"
echo ""

if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}${BOLD}  ✗ VÉRIFICATION ÉCHOUÉE — $ERRORS erreur(s) à corriger avant de continuer.${NC}"
  echo ""
  exit 1
else
  if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}  ⚠ VÉRIFICATION RÉUSSIE avec $WARNINGS avertissement(s) à examiner.${NC}"
  else
    echo -e "${GREEN}${BOLD}  ✓ VÉRIFICATION RÉUSSIE — Tout est conforme.${NC}"
  fi
  echo ""
  exit 0
fi
