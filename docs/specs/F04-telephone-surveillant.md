# F04 : « Téléphone surveillant »
Statut : brouillon
Dépend de : F01 (comptes, élèves), F02 (file de la tablette)
Cas d'utilisation : UC6 (« Appeler et libérer l'élève »)

## Objectif
Le surveillant reçoit sur son terminal dédié l'ordre d'appel d'un enfant
(classe prévenue). Il libère l'élève et appuie sur « Parti » : la demande
passe à on_the_way, l'agent au portail peut remettre. Le micro est supprimé.

## Règles métier

- R1 L'agent d'accueil (concierge ou director) déclenche l'appel d'une
  demande active depuis la tablette F02 : requested → class_notified.
- R2 Le surveillant (surveillant ou director, même école) déclenche le
  départ depuis son terminal : class_notified → on_the_way.
- R3 Toute transition passe par un lock pessimiste sur pickup_requests
  (SELECT ... FOR UPDATE), puis par la machine à états B2.
- R4 Raccourcis B2 autorisés : depuis requested ou class_notified, l'agent
  au portail peut appeler directement handover (déjà implémenté en F02).
  Le surveillant ne peut PAS court-circuiter : il doit passer par on_the_way.
- R5 Chaque appel et chaque départ est idempotent : un rejeu avec la même
  Idempotency-Key renvoie la même réponse, sans nouvelle transition.
- R6 Une demande terminale (handed_over, cancelled, expired) refuse tout
  appel ou départ : 409 conflict.
- R7 Le surveillant ne voit que les demandes actives de son école, groupées
  par classe côté UI. Aucun filtre serveur par classe en v1.
- R8 Le terminal surveillant reçoit les événements en temps réel via Reverb,
  canal privé school.{id}.queue, événements pickup.called et pickup.departed.
- R9 Aucune notification hors ligne dans cette version : Reverb seul. FCM
  est une dette post-pilote (traçée dans cette spec).
- R10 Une demande d'une autre école renvoie 404 (jamais 403), cohérent avec
  la règle multi-école globale.
- R11 Horodatage systématique en Africa/Casablanca explicite.
- R12 Aucune donnée personnelle dans les payloads Reverb : identifiants
  opaques + prénom tronqué (première lettre + « . ») + nom de classe.

## Critères d'acceptation

- CA1  Étant donné une demande en requested à 15h20, quand l'agent appelle,
       alors la demande passe à class_notified et un event pickup.called
       est diffusé sur le canal de l'école.
- CA2  Un surveillant d'une autre école appelle POST .../call : 404,
       aucune transition, aucun event.
- CA3  Un parent (rôle parent) appelle POST .../call : 403.
- CA4  Un surveillant d'une autre école appelle POST .../depart : 404.
- CA5  Un concierge tente POST .../depart : 403 (seul surveillant ou
       director peut libérer).
- CA6  Un surveillant appelle POST .../depart sur une demande en
       class_notified : la demande passe à on_the_way, event
       pickup.departed diffusé.
- CA7  Deux appels simultanés à POST .../depart avec des Idempotency-Key
       différentes : une seule transition effective, la seconde reçoit
       409 conflict.
- CA8  Deux appels simultanés à POST .../depart avec la même
       Idempotency-Key : une seule transition effective, les deux
       réponses sont identiques (200).
- CA9  Un appel ou départ sur une demande handed_over, cancelled ou
       expired renvoie 409 conflict.
- CA10 Un appel sur une demande déjà class_notified renvoie 200 sans
       nouvelle transition (idempotence).
- CA11 L'écran surveillant affiche les demandes class_notified groupées
       par classe, triées par heure d'appel croissante.
- CA12 L'écran surveillant ne montre AUCUNE demande hors école, ni
       handed_over / cancelled / expired.
- CA13 Le payload Reverb de pickup.called ne contient ni nom complet, ni
       photo, ni téléphone : uniquement request_id, school_id,
       classroom_name, child_initial.
- CA14 L'écran surveillant se met à jour à la réception d'un event
       pickup.called, sans polling.
- CA15 À la reconnexion WebSocket après une coupure, l'écran recharge
       l'état complet depuis GET /queue (pas de perte silencieuse).
- CA16 Le test d'isolation (école A vs école B) est écrit par le PO,
       pas par l'agent, et verrouillé après fusion.
- CA17 Le test de confidentialité (payload Reverb sans donnée personnelle)
       est écrit par le PO et verrouillé après fusion.
- CA18 Toute transition est testée avec un cas où le lock pessimiste
       provoque une attente, pour valider le comportement sous concurrence.

## Données personnelles

Stocké : identifiants, statuts, horodatages, agent_id (appel), surveillant_id
(départ), classroom_id au moment de l'appel.

Jamais stocké : positions GPS, nom complet dans les payloads Reverb,
téléphone du surveillant en clair dans les logs, photo.

## Hors périmètre

- Push FCM en arrière-plan (dette post-pilote, ticket à créer).
- Filtre par zone / étage / classe côté serveur (v1 : UI groupe, serveur
  renvoie tout).
- Notifications push vers l'agent d'accueil (il regarde la tablette F02).
- Vue « performance surveillant » ou statistiques individuelles.

## Questions de la lecture critique

(à compléter après étape 2)