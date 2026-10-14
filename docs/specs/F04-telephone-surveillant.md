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
  appel ou départ : 422 unprocessable. Le code 409 est réservé aux
  conflits d'idempotence (même clé, corps différent).
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
       différentes : une seule transition effective. La seconde reçoit
       HTTP 200 avec l'état final on_the_way (idempotence au niveau de
       l'état, pas de 409 — le 409 est réservé au conflit de clé R5).
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
       class_name (snapshot de child.class_name), child_initial.
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
- CA19 Un POST .../depart sur une demande encore en requested est rejeté
       en HTTP 422 (R4 : le surveillant ne court-circuite pas l'appel).
- CA20 Après une transition on_the_way, le parent qui appelle
       GET /schools/{school}/arrivals/status voit le statut on_the_way
       pour son enfant.
- CA21 Un utilisateur de rôle parent ne peut PAS s'abonner au canal
       Reverb school.{id}.queue : HTTP 403 sur /broadcasting/auth.
- CA22 Le rôle surveillant peut appeler GET /queue et reçoit uniquement
       les demandes en class_notified de sa propre école, triées par
       heure d'appel croissante.

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

## Questions de la lecture critique — réponses

Décisions prises après la lecture critique du 2026-10-14.

### Q1 — Rôle autorisé sur POST .../call
Décision : 403 pour surveillant. Seuls concierge et director peuvent
appeler une classe. R1 confirmée.

### Q2 — Accès surveillant à GET /queue
Décision : étendre QueuePolicy::viewQueue au rôle surveillant, avec un
filtre serveur. concierge et director voient la file complète ; surveillant
ne voit que les demandes en class_notified de sa propre école. Pas de
route dédiée.

### Q3 — Sécurisation du canal Reverb
Décision : ajouter au check d'abonnement du canal school.{id}.queue une
vérification de rôle. Seuls concierge, surveillant, director peuvent s'y
abonner. Un parent reçoit 403 sur /broadcasting/auth. Correctif livré
dans F04, couvert par CA21.

### Q4 — Code HTTP des transitions invalides
Décision : 422 pour toute transition invalide depuis un statut donné.
409 est réservé aux conflits d'idempotence (même clé, corps différent).
Alignement avec la convention F02. R6 ajustée en conséquence.

### Q5 — /call sur pending_agent_confirmation
Décision : /call exige strictement le statut requested. La transition
pending_agent_confirmation -> requested (déjà en B2) est déclenchée par
/confirm-presence, existant en F02. Un /call sur pending_agent_confirmation
retourne 422.

### Q6 — Annulation d'un appel erroné
Décision : hors périmètre v1. B2 ne prévoit pas class_notified -> requested.
Procédure d'erreur : le surveillant appuie « Parti », l'agent remet au
portail en handover normal. Documenté ici pour traçabilité, ticket à
ouvrir pour v2.

### Q7 — Statuts visibles au surveillant
Décision : uniquement class_notified. Après l'appui « Parti », la demande
disparaît de l'écran surveillant. Aucun affichage de on_the_way.

### Q8 — Payload de pickup.departed
Décision : { request_id, school_id, child_initial, departed_at }.
Symétrique de pickup.called. Pas de class_name (l'enfant a quitté la
classe).

### Q9 — Destinataires de pickup.departed
Décision : canal école school.{id}.queue uniquement. La tablette F02
l'utilise pour rafraîchir son affichage. Le parent apprend le nouveau
statut via GET /arrivals/status (déjà existant). Le canal parent Reverb
est hors périmètre (F06).

### Q10 — Mode de diffusion Reverb
Décision : ShouldBroadcastNow pour pickup.called et pickup.departed.
Transitions peu fréquentes (quelques par minute), pas de saturation worker,
latence sub-seconde garantie sans passer par Redis queue.

### Q11 — Stockage des Idempotency-Key
Décision : réutiliser la table idempotency_keys créée en F02. Même
mécanisme (empreinte SHA-256 du corps, unique par utilisateur). Aucune
nouvelle table.

### Q12 — Double départ concurrent, deux clés
Décision : idempotence au niveau de l'état final. Le premier /depart
effectue la transition class_notified -> on_the_way. Le second, avec une
clé différente mais le même request_id, reçoit HTTP 200 avec l'état final
on_the_way. Pas de 409 dans ce cas. CA7 ajustée.

### Q13 — Confirmation de la route /call
Décision : oui, POST /schools/{schoolId}/pickup-requests/{requestId}/call.
Signée avec Idempotency-Key obligatoire, comme /depart.

### Q14 — Format des réponses /call et /depart
Décision : { id, status, updated_at }. Identique à la réponse de
confirm-presence.

### Q15 — Migration pickup_requests
Décision : nouvelle migration additive (jamais de modification d'une
migration existante). Colonnes nullable :
called_by_user_id, called_at, departed_by_user_id, departed_at.

### Q16 — class_name vs classroom_name
Décision : pas d'entité Classroom en v1. On utilise child.class_name
(string existante) comme snapshot au moment de l'appel. Le payload Reverb
expose class_name. CA13 ajustée.

### Q17 — Test /depart depuis requested
Décision : formalisé en CA19.

### Q18 — Test notification parent on_the_way
Décision : formalisé en CA20.