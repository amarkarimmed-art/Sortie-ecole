# Skill : /verification

**Description :** Lance la suite de tests et de validation complète du projet.

**Instructions pour l'agent :**
Lorsqu'on t'appelle avec la commande `/verification` :
1. N'essaie pas de deviner les commandes à lancer.
2. Exécute simplement et directement le script bash suivant : `./scripts/verify.sh tout`
3. Affiche la sortie standard et la sortie d'erreur à l'utilisateur.
4. Si le script échoue (code de sortie différent de 0), analyse l'erreur et propose une piste de résolution basée sur les règles du dossier `.agents/rules/`.
5. Si l'erreur concerne un test verrouillé qui échoue,
   ne propose jamais de modifier ce test.
   Signale-le à l'utilisateur comme un point bloquant
   à résoudre dans le code, pas dans le test.