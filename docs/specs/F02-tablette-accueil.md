# F02 : Tablette d'accueil (Gestion de la file d'attente)
Statut : Brouillon  
Dépend de : F00 (Socle, Multi-école), F01 (Comptes et élèves), F03 (Signalement d'arrivée)  
Cas d'utilisation : UC5 (Traiter la file et remettre l'enfant)

## Objectif
Permettre au personnel de l'école (agents d'accueil / directeurs) de visualiser en temps réel sur une tablette la file d'attente ordonnée des parents arrivés et de marquer les élèves comme « Remis ».

## Règles métier
- **R1 Accès restreint** : L'accès à la file d'attente est strictement restreint aux utilisateurs authentifiés ayant le rôle `concierge` ou `director` de l'école concernée.
- **R2 Isolation multi-école** : L'isolation par école est absolue : un agent de l'école A ne peut jamais voir ou interagir avec la file de l'école B (filtrage strict via `school_id` avec retour HTTP 404).
- **R3 Périmètre actif du jour** : La file ne renvoie que les demandes d'arrivée actives du jour (statuts `requested`, `class_notified`, `on_the_way`, `pending_agent_confirmation`) sur le fuseau `Africa/Casablanca`. Les demandes archivées, annulées ou remises (`handed_over`, `cancelled`, `expired`) n'apparaissent plus.
- **R4 Ordre de la file** : L'ordre de la file d'attente est chronologique, basé sur l'heure de signalement de l'arrivée (`created_at` ascendant).
- **R5 Inaltérabilité du journal** : Toute action de mise à jour de statut de remise (passage à `handed_over`) doit alimenter le journal des remises (`handover_logs`) en ajout seul strict (trigger PostgreSQL).

## Critères d'acceptation
- **CA1** : Étant donné un utilisateur authentifié avec le rôle `parent` (ou non autorisé), quand il tente d'accéder à l'endpoint de la file `/v1/schools/{id}/queue`, alors le serveur refuse avec une erreur HTTP 403 Forbidden.
- **CA2** : Étant donné un agent de l'école A, quand il demande la file de l'école B, alors le serveur renvoie une erreur HTTP 404 Not Found (minimisation et étanchéité).
- **CA3** : Étant donné plusieurs parents signalés aujourd'hui à l'école A, quand l'agent consulte la file, alors il reçoit la liste exacte et triée des élèves associés aux arrivées actives, sans aucun élève des jours précédents.
- **CA4** : Étant donné une demande dans la file, quand l'agent valide la remise de l'élève, alors le statut passe à `handed_over`, une ligne immuable est écrite dans `handover_logs` et l'élève disparaît instantanément de la file active.
- **CA5** : L'interface de l'application Tablette (`app_ecole`) affiche les informations sous forme de cartes à fort contraste (utilisables au soleil) avec des cibles tactiles de validation d'au moins 48 dp et conformité RTL (arabe/français).

## Données personnelles et logs (Loi 09-08)
- Masquage des numéros de téléphone et minimisation des données dans la réponse API (uniquement les UUIDs, nom/prénom des enfants, leur classe, la zone d'attente et URL temporaire signée de la photo si nécessaire).
- Pas de stockage ni d'exposition de coordonnées GPS brutes.
- Triggers d'interdiction UPDATE/DELETE sur `handover_logs`.

## Questions de la lecture critique — Réponses validées

- **Q1 (DTO QueueItem)** ✅ Création d'un schéma dédié `QueueItem` enrichi contenant : `id`, `child_id`, `child_name`, `class_name`, `status`, `waiting_zone`, `photo_url` (URL MinIO signée ≤ 5 min), `created_at`.
- **Q2 (Granularité d'affichage)** ✅ Une carte individuelle par élève (`PickupRequest`). Les enfants d'une même fratrie avancent à leur propre rythme.
- **Q3 (Raccourci « Remis »)** ✅ L'agent peut forcer « Remis » depuis n'importe quel statut actif (`requested`, `class_notified`, `on_the_way`, `pending_agent_confirmation`).
- **Q4 (`pending_agent_confirmation`)** ✅ Badge spécial avec bouton « Valider présence » (→ `requested`) ET bouton « Remis » (→ `handed_over` directement si l'élève est là).
- **Q5 (Journée active)** ✅ Filtrage sur `00:00:00` à `Africa/Casablanca` du jour courant (pas uniquement sur les fenêtres actives).
- **Q6 (Idempotence)** ✅ `Idempotency-Key` (UUIDv4) **obligatoire** sur l'action de remise pour sécuriser Drift et éviter les doublons dans le journal immuable.
- **Q7 (`handover_logs`)** ✅ Le journal enregistre en plus les colonnes optionnelles `parent_user_id`, `authorized_person_id` et le type de récupérateur (`parent` / `authorized_person` / `daily_code` / `pickup_card`).
- **Q8 (Temps réel)** ✅ Polling court toutes les **10 secondes** pour ce premier jalon. Couche Reverb différée au jalon F06.
