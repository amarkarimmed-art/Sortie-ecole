# Feuille de route : Sortie d'école

L'ordre suit la logique du guide de conception : rendre utile 
d'abord le poste qui supprime le micro, en commençant par le 
canal qui n'exige rien des parents. L'application parent arrive 
ensuite, sur un socle déjà éprouvé au portail.

| F | Contenu | Dépend de | Point sensible |
|---|---|---|---|
| **F00 Socle** | Monorepo, CI, verify.sh, .agents/, multi-école | — | Le multi-école ne se rajoute pas après coup : scope global et test d'isolation dès F00. |
| **F01 Comptes et données** | Authentification SMS, import CSV des élèves, photos | F00 | Le CSV réel ne touche jamais le dépôt ; photos en stockage privé. |
| **F02 Tablette d'accueil** | File, carte numérotée, « Remis », journal | F01 | Alerte homonymes ; journal en ajout seul protégé en base. |
| **F02b Hors connexion** | Drift, file d'actions, resynchronisation | F02 | Conception sur papier obligatoire avant tout code. |
| **F04 Téléphone surveillant** | Appels, bouton « Parti », fin du micro | F02 | Notification sans nom ni photo. |
| **F03 « Je suis arrivé »** | App parent, fenêtre horaire, position | F01, F02, F04 | Fil rouge de ce guide. |
| **F06 Suivi temps réel** | Les quatre statuts côté parent | F03 | Canaux privés par école. |
| ━━━ FIN MVP PILOTE ━━━ | ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ | ━━━━━━━━━━━ | ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ |
| **F05 Code du jour** | Tiers : nounou, chauffeur | F02 | Dans le MVP si l'école pilote compte beaucoup de tiers : à mesurer avant. |
| **F07, F08 Historique, direction** | Tableaux de bord, export du journal | Quelques semaines de données | Indicateurs définis en A1. |

## À lancer en parallèle du code, dès maintenant

Ces chantiers ont des délais que le code ne rattrape pas :

* Déclaration du traitement à la CNDP
  (délais à confirmer avec la CNDP ou un juriste).
* Note d'information aux parents et consentements.
* Contrat avec l'hébergeur marocain.
* Choix de la passerelle SMS et test de délivrabilité
  sur les trois opérateurs.
* Matériel (tablette, support, Wi-Fi dédié, téléphones, batteries).
* Zones d'attente physiques.
* Formation d'une heure et procédure papier.
* Campagne de photos avec autorisation écrite.