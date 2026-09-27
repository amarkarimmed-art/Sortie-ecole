# Architecture Decision Records (ADR 0001 à 0008)

> **Statut global :** Validé et Acquis  
> **Contexte :** Projet « Sortie d'école » — Déploiement pilote Maroc

---

## ADR 0001 : Structure Monorepo

* **Statut :** Acceptée
* **Contexte :** L'application repose sur un écosystème étroitement 
  couplé : un contrat d'API partagé, un backend unique, et deux 
  applications clientes (parents et personnel de l'école). Séparer 
  ces éléments en plusieurs dépôts entraînerait une désynchronisation 
  des versions et complexifierait le travail de l'agent.
* **Décision :** Adopter une structure en monorepo unique :
  * `api/` : Spécification OpenAPI (`openapi.yaml`), rédigée et 
    lintée avant tout code.
  * `backend/` : API Laravel, logique métier et back-office de gestion.
  * `app_parent/` : Application mobile Flutter (iOS / Android) 
    destinée aux tuteurs.
  * `app_ecole/` : Application Flutter pour la tablette d'accueil 
    (mode hors ligne) et le surveillant.
  * `docs/` : Vision, roadmap, spécifications fonctionnelles et ADRs.
  * `.agents/` : Règles d'automatisation, skills et garde-fous 
    de l'agent de développement.
* **Conséquences :**
  * Un script global de vérification (`scripts/verify.sh`) valide 
    l'intégralité du cycle.
  * La CI utilise des filtres de chemins pour cibler les tests 
    sans bloquer la fusion globale.

---

## ADR 0002 : Socle Backend Laravel, PostgreSQL et Actions

* **Statut :** Acceptée
* **Contexte :** Le backend doit assurer une robustesse 
  transactionnelle élevée, des politiques d'autorisations granulaires 
  et une maintenance prévisible.
* **Décision :**
  * Framework : **Laravel 11+** avec Sanctum (authentification) 
    et Filament (administration).
  * Base de données : **PostgreSQL 16+** (obligatoire en local, 
    test et production ; exclusion formelle de SQLite).
  * Cache & Files d'attente : **Redis**.
  * Organisation du code : Logique métier encapsulée dans des 
    classes dédiées `app/Actions` (une action = une responsabilité).
  * Signature imposée sur chaque Action :
```php
    public function handle(array $data): Model|array
```
  * Les contrôleurs restent minces et se limitent à invoquer 
    les Actions.
* **Conséquences :** Testabilité unitaire directe de la logique 
  métier sans dépendre du cycle HTTP.

---

## ADR 0003 : Applications Mobiles en Flutter

* **Statut :** Acceptée
* **Contexte :** Nécessité de livrer deux applications mobiles 
  fluides, nativement bilingues (Arabe/Français avec support RTL), 
  compatibles iOS et Android, et capables d'opérer en mode déconnecté.
* **Décision :** Utiliser **Flutter** pour `app_parent` et `app_ecole`.
* **Conséquences :** Unification des compétences front-end, 
  réutilisation des composants d'interface et des modèles de données 
  générés à partir du contrat OpenAPI.

---

## ADR 0004 : Hébergement Souverain VPS au Maroc et Déploiement Docker

* **Statut :** Acceptée
* **Contexte :** Les données traitées concernent des mineurs 
  (identités, photographies, liens de parenté). La loi marocaine 
  09-08 encadre strictement le transfert de données personnelles 
  hors du territoire national.
* **Décision :**
  * Hébergement de l'ensemble de l'infrastructure (serveur 
    applicatif, base PostgreSQL, stockage d'objets MinIO) sur un 
    **VPS situé physiquement au Maroc**, chez un hébergeur local déclaré.
  * Orchestration via des conteneurs **Docker**.
  * Seules les passerelles de notification push (Google FCM / 
    Apple APNs) et la passerelle SMS sortent du territoire, en 
    n'acheminant **aucun nom, aucune photo ni aucune classe**.
* **Conséquences :** Sauvegardes et infogérance sous contrôle 
  strict ; obligation d'une déclaration préalable de traitement 
  auprès de la CNDP.

---

## ADR 0005 : Multi-Établissement Hermétique (Multi-Tenant)

* **Statut :** Acceptée
* **Contexte :** Plusieurs établissements scolaires utilisent 
  l'infrastructure sans qu'aucune donnée ne puisse être partagée 
  ou consultée par erreur entre écoles.
* **Décision :**
  * Partitionnement logique strict : présence de la colonne 
    `school_id` sur chaque table de données métier.
  * Scope global automatique dans Laravel via le trait 
    `BelongsToSchool`.
    * Emplacement : `app/Models/Concerns/BelongsToSchool.php`
    * Appliqué sur : tous les modèles métier sans exception.
  * Toute tentative d'accès à une ressource associée à une autre 
    école lève une erreur **HTTP 404 Not Found** (et non une 403, 
    pour empêcher l'énumération de données).
* **Conséquences :** Tests d'acceptation dédiés vérifiant 
  systématiquement l'isolation entre écoles.

---

## ADR 0006 : Événements Temps Réel Cloisonnés (Laravel Reverb)

* **Statut :** Acceptée
* **Contexte :** La mise à jour de la file d'attente à 15h30 
  exige une latence inférieure à la seconde entre l'arrivée du 
  parent, l'appel du surveillant et l'écran de la tablette d'accueil.
* **Décision :** Intégration de **Laravel Reverb** (WebSockets 
  natifs). Chaque événement transite exclusivement par des canaux 
  privés isolés par identifiant d'école,
  nommés `private-school.{school_id}.queue`.
* **Conséquences :** L'authentification au canal vérifie
  strictement le rôle de l'agent et son appartenance
  à l'école `school_id`.
  
---

## ADR 0007 : Tablette d'Accueil Résiliente Hors Connexion (Offline-First)

* **Statut :** Acceptée
* **Contexte :** À 15h30, la saturation locale des réseaux 
  4G/Wi-Fi aux abords des portails peut provoquer des coupures 
  réseau partielles ou totales.
* **Décision :**
  * L'application tablette (`app_ecole`) intègre un stockage 
    local persistant via **Drift**.
  * Les actions de remise physique sont enregistrées localement 
    dans une file d'attente horodatée, dotée d'un identifiant 
    UUID unique (clé d'idempotence).
  * Lors du rétablissement de la connectivité, synchronisation 
    automatique idempotente avec le serveur backend.
  * Rétention locale maximale : **24 heures**. Au-delà, l'action 
    est marquée `expired` et signalée dans le back-office Filament.
* **Conséquences :** Le flux physique des sorties n'est jamais 
  interrompu, même en cas de panne réseau complète.

---

## ADR 0008 : Notifications Push & SMS Minimalistes

* **Statut :** Acceptée
* **Contexte :** Les plateformes push Apple et Google conservent 
  et transitent des métadonnées hors du Maroc.
* **Décision :** Le payload des notifications push est strictement 
  générique :
  * Identifiant opaque (UUID de la demande uniquement).
  * Texte standardisé sans aucune donnée personnelle 
    (ni nom, ni photo, ni classe, ni école).
  * L'application mobile interroge ensuite l'API sécurisée 
    marocaine pour récupérer les détails.
* **Conséquences :** Conformité totale avec les obligations 
  de la CNDP.

