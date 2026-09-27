trigger: glob
globs: backend/**

# 40 — Règles de Développement Backend (Laravel)

---

## 1. Organisation du Code et Actions

* **Logique Métier Unique :** Toute la logique réside dans des Actions situées dans `app/Actions`.
* **Principe d'Action Unique :** Une classe d'action représente une intention métier et ne comprend qu'une seule méthode publique : `handle()`.
* **Contrôleurs Minces :** Les contrôleurs HTTP injectent les Actions et leur transmettent les DTO ou FormRequests validées. Aucun calcul métier dans les contrôleurs.

---

## 2. Multi-Établissement et Politiques de Sécurité

* Tous les modèles rattachés à une école doivent appliquer un scope global vérifiant `school_id`.
* Chaque route d'API protégée doit cumuler :
  1. Authentification Sanctum.
  2. Une Laravel Policy vérifiant les rôles et l'accès à l'école.
* Tout appel dérogatoire via `withoutGlobalScopes()` doit obligatoirement être précédé d'un commentaire justifiant l'absence de fuite inter-écoles.

---

## 3. Gestion Horaires et Fuseau Marocain

* **Fuseau Obligatoire :** Toute manipulation de dates s'effectue avec **Carbon** configuré explicitement sur le fuseau `'Africa/Casablanca'`.
* **Bannissement des décalages fixes :** Ne jamais coder de décalage statique en dur (`+01:00`). L'heure marocaine recule sur UTC+0 pendant le mois de Ramadan.
* **Fenêtres de sortie :** Comparaison effectuée entre des instances absolues reçues et converties correctement avec le fuseau de référence.

---

## 4. Diffusion Temps Réel (Laravel Reverb)

* Événements diffusés via `PrivateChannel` nommé selon le pattern :
  `school.{schoolId}.queue`
* Les canaux privés exigent une vérification stricte dans `routes/channels.php` : l'agent connecté doit avoir le rôle requis et son `school_id` doit correspondre exactement au canal.

---

## 5. Base de Données et Stratégie de Tests

* **PostgreSQL Obligatoire :** Tous les tests Pest s'exécutent contre une véritable base de données PostgreSQL de test (interdiction de basculer sur SQLite).
* **Immutabilité des Migrations :** Une migration déjà fusionnée sur la branche principale ne doit jamais être modifiée. Tout changement de structure passe par une nouvelle migration incrémentale.
* **Idempotence :** Toutes les actions d'écriture critiques (création d'arrivées, remises) vérifient l'en-tête `Idempotency-Key` via la table `idempotency_keys` en stockant le hash SHA-256 de la requête, sans jamais stocker les coordonnées GPS.