# Skill : /revue-de-code

**Description :** Effectue une revue de code experte 
et impitoyable de la branche en cours par rapport 
à la branche principale.

**Instructions pour l'agent :**
Lorsqu'on t'appelle avec la commande `/revue-de-code`, 
tu dois agir comme un Lead Tech spécialisé en sécurité 
et performance.

1. Analyse le diff complet de la branche courante 
   par rapport à la branche `main`.
2. Vérifie la conformité absolue avec :
   - La spécification fonctionnelle de la feature
     (ex: `docs/specs/F03-je-suis-arrive.md`).
   - Les impératifs de la loi 09-08
     (`.agents/rules/30-securite-loi-09-08.md`).
   - Le cloisonnement multi-école : absence de
     `withoutGlobalScopes()` non justifié, et toute
     violation de school_id renvoie 404 jamais 403.
   - Aucune notification push/SMS ne contient un nom,
     une photo ou une classe.
   - Toute comparaison d'heure utilise Africa/Casablanca,
     jamais un offset fixe (+01:00).
   - Les règles de style Laravel et Flutter
     (`.agents/rules/40-style-laravel.md` 
     et `41-style-flutter.md`).
3. Cherche activement toute tentative de contourner 
   ou d'affaiblir un test existant.
4. Rends ton rapport en trois catégories strictes :
   - 🔴 **Bloquant :** fuite de données entre écoles,
     log de données personnelles, comparaison d'heure 
     sans fuseau, 403 à la place d'un 404.
   - 🟠 **Important :** règle Flutter non respectée,
     test manquant de robustesse.
   - 🔵 **Mineur :** oubli de traduction, typo,
     optimisation locale.
5. Pour chaque point bloquant, explique pourquoi c'est
   dangereux et indique quel test écrire pour attraper
   ce type d'erreur à l'avenir.