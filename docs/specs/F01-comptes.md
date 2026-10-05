# F01 : Comptes et données
Statut : brouillon
Dépend de : F00 (Socle)

## Objectif
Permettre l'authentification sécurisée des parents par SMS et permettre à l'école de provisionner les élèves (import CSV) et leurs photos, en stricte conformité avec la Loi 09-08 (CNDP).

## Règles métier
- **R1 - Authentification SMS** : L'accès parent se fait via OTP (One-Time Password) envoyé par SMS. Un parent ne peut se connecter que si son numéro existe dans la base de l'école (créé lors de l'import).
- **R2 - Sécurité SMS** : Le code OTP expire après 5 minutes. Un mécanisme de limitation (rate limiting) est obligatoire pour éviter l'abus de la passerelle SMS.
- **R3 - Import CSV** : L'école importe les élèves (Nom, Classe) et les parents associés (Téléphone). Le vrai CSV ne touche jamais le dépôt Git (données fictives obligatoires pour les tests).
- **R4 - Multi-école** : L'importation ajoute obligatoirement le `school_id` de l'école. L'authentification SMS retourne le jeton (Sanctum) et associe le parent à l'école correspondante. 
- **R5 - Photos (Loi 09-08)** : Les photos des élèves sont stockées dans un espace privé (MinIO/S3). Elles ne sont jamais exposées publiquement. Le backend génère des URL signées temporaires (valides quelques minutes) pour l'application.

## Critères d'acceptation
- **CA1** : Étant donné un numéro existant, quand le parent demande un code, alors un SMS est envoyé et l'API renvoie 200 OK.
- **CA2** : Étant donné un numéro inconnu, quand on demande un code, alors l'API renvoie 404 (pour éviter les énumérations abusives).
- **CA3** : Étant donné un code valide, quand le parent le vérifie, un token d'authentification Sanctum est retourné avec les informations de base.
- **CA4** : Étant donné un code expiré ou invalide, la requête de vérification échoue avec 401 Unauthorized.
- **CA5** : Quand l'école téléverse un CSV bien formaté, les élèves et parents sont créés/mis à jour en base et associés à la bonne école.
- **CA6** : Étant donné un élève d'une autre école, ses données (y compris la photo) ne sont jamais retournées, même si le parent fait partie de deux écoles (Isolation 404).
- **CA7** : L'URL de la photo de l'élève est une URL temporaire signée et son accès direct public renvoie 403 Forbidden.

## Données personnelles (Rappels Loi 09-08)
Stocké en base : Noms des élèves, numéros de téléphone des parents.
Jamais stocké publiquement : Les photos. Le CSV réel de production ne passe jamais par le code.

## Hors périmètre
- Édition manuelle des élèves un par un (le MVP se concentre sur l'import CSV de masse).
- Application Surveillant (F04).

## Questions de la lecture critique
- Q1 : Que se passe-t-il si un parent est lié à deux écoles différentes avec le même numéro ?
- Q2 : Est-ce qu'on utilise un OTP fixe (ex: 1234) sur l'environnement de staging/local pour ne pas épuiser le forfait SMS ?
- Q3 : Quel est le format exact du CSV attendu ? (ex: `prenom_eleve, nom_eleve, classe, telephone_parent_1, telephone_parent_2`) ?
