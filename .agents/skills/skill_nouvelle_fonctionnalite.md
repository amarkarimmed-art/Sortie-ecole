# Skill : /nouvelle-fonctionnalite

**Description :** Lance le cycle de développement d'une nouvelle fonctionnalité (Phase B) en respectant les 5 arrêts obligatoires (losanges roses).

**Instructions pour l'agent :**
Lorsqu'on t'appelle avec la commande `/nouvelle-fonctionnalite [chemin/vers/la/spec.md]`, tu dois te comporter comme un ingénieur logiciel expert et suivre scrupuleusement le workflow suivant, étape par étape. **Tu dois t'arrêter et attendre la validation de l'utilisateur après chaque étape listée ci-dessous.**

**Étape 1 : Lecture critique (Arrêt 1)**
1. Lis la spécification fournie, le contrat OpenAPI actuel, et les règles `.agents/rules/`.
2. Fais une analyse critique et retourne une liste numérotée de questions pertinentes (cas limites, contradictions, fuseaux horaires, idempotence). 
3. *N'écris aucun code.* 
4. **ARRÊT :** Attends que l'utilisateur réponde aux questions dans le fichier de spécification.

**Étape 2 : Contrat d'API (Arrêt 2)**
1. Une fois les réponses validées par l'utilisateur, propose le `diff` pour le fichier `api/openapi.yaml`.
2. Assure-toi que les identifiants exposés sont opaques (UUID) et que le `schoolId` est présent dans l'URL.
3. Lance le linter (`npx @redocly/cli lint api/openapi.yaml`).
4. **ARRÊT :** Attends que l'utilisateur valide le contrat OpenAPI.

**Étape 3 : Liste de tests et plan (Arrêt 3)**
1. Génère un tableau Markdown avec les colonnes : `CA` | `Test` | `Frontière simulée` | `Implémentation fausse détectée`.
2. Propose un plan d'implémentation détaillé pour chaque Critère d'Acceptation (CA).
3. Liste les éventuelles nouvelles dépendances requises.
4. **ARRÊT :** Attends la validation du plan par l'utilisateur.

**Étape 4 : Tests d'acceptation rouges (Arrêt 4)**
1. Écris les tests d'acceptation dans le backend (Pest) et/ou Flutter selon le plan.
2. Écris le squelette minimal (migrations, modèles, routes 501) juste pour que les tests s'exécutent. Ne code pas la logique métier.
3. Exécute les tests pour prouver qu'ils échouent correctement (rouge).
4. Laisse l'utilisateur écrire lui-même les tests de confidentialité/isolation (ex: CA8, CA9).
5. **ARRÊT :** Attends que l'utilisateur verrouille les tests via son script.

**Étape 5 : Implémentation itérative (Arrêt 5)**
1. Implémente le code pour faire passer **un seul critère (CA) à la fois**, dans l'ordre.
2. Boucle TDD stricte : lance les tests, écris le code minimal, refactorise, relance les tests. Fais un commit conventionnel (ex: `feat(F03): CA1...`) une fois au vert.
3. *Règle des 3 tentatives :* Si un test ne passe pas après 3 essais, arrête-toi et résume ce qui bloque. Ne modifie **jamais** un test verrouillé de ton propre chef.
4. **ARRÊT :** Le cycle est terminé, l'utilisateur prend le relais pour la vérification physique.