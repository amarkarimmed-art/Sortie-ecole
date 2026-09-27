trigger: glob
globs: app_*/**

# 41 — Règles de Développement Frontend (Flutter)

---

## 1. Bilinguisme et Localisation

* **Zéro Texte en Dur :** Tout libellé visible doit provenir des fichiers ARB :
  * `lib/l10n/app_fr.arb` (Français)
  * `lib/l10n/app_ar.arb` (Arabe)
* Toute nouvelle chaîne ajoutée en arabe doit comporter le commentaire `@description` et être signalée à l'équipe pour validation par un locuteur natif.

---

## 2. Sens de Lecture et Ergonomie RTL (Right-to-Left)

* Les interfaces doivent s'adapter automatiquement au sens de lecture arabe :
  * Utiliser obligatoirement `EdgeInsetsDirectional` au lieu de `EdgeInsets.only(left/right)`.
  * Utiliser `AlignmentDirectional` au lieu de `Alignment.topLeft/topRight`.
  * Remplacer systématiquement les notions `left`/`right` par `start`/`end`.

---

## 3. Ergonomie Terrain et Écrans Tactiles

* **Conditions Lumineuses Extérieures :** Contraste élevé obligatoire pour garantir la lisibilité en plein soleil à 15h30.
* **Cibles Tactiles :** Boutons d'action et éléments cliquables dotés d'une surface minimale de $48 \times 48\,\text{dp}$.
* **Usage à une Main :** Placer les boutons d'action critiques (ex. : bouton « Je suis arrivé » ou « Remis ») dans la moitié inférieure de l'écran.

---

## 4. Gestion Temporelle et Injection d'Horloge

* **Injection d'Horloge Obligatoire :** Ne jamais appeler `DateTime.now()` directement dans les composants fonctionnels ou la gestion d'état.
* Utiliser systématiquement l'utilitaire `clock.now()` issu du package `clock`. Cela permet de figer et tester précisément le comportement des fenêtres de sortie dans les tests de widgets.
* Les comparaisons d'horaires d'ouverture/fermeture s'opèrent sur des timestamps UTC absolus reçus de l'API.

---

## 5. Mode Déconnecté et Tablette d'Accueil (`app_ecole`)

* **Base Locale Drift :** Les modèles générés par Drift (`*.g.dart`) ne doivent jamais être édités à la main ; ils sont mis à jour via `build_runner`.
* Toute action de remise enregistrée hors ligne génère un identifiant unique (UUID v4) constituant sa clé d'idempotence pour la future réconciliation avec le backend.
* Affichage transparent de l'indicateur de statut de synchronisation : date du dernier échange réseau et décompte des actions en attente d'envoi.