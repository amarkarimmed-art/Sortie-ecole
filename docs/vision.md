# Vision Produit — Sortie d'école

> **Document de référence v1.0**  
> *Statut : Validé par la Direction de l'École Pilote*  
> *Règle agent : Ce document fait foi. Il doit être lu au démarrage
> de chaque session pour cadrer l'ensemble des arbitrages
> d'architecture, de design et de code.*

---

## 1. Raison d'être & Objectif Stratégique

L'application **Sortie d'école** a pour mission de transformer
l'expérience critique de 15h30 au portail de l'établissement :

- **Supprimer le chaos sonore et l'attente prolongée** en éliminant
  les appels au mégaphone/micro.
- **Séparer strictement les deux temps de la sortie** : dissocier
  l'annonce anticipée (*« Je suis arrivé dans la zone »*) du contact
  physique au portail (*« Je suis devant l'assistante »*).
- **Garantir la sécurité physique et juridique absolue des élèves**
  tout en fluidifiant le flux d'évacuation grâce à une file
  numérique unique et orchestrée.

---

## 2. Acteurs du Système

| Acteur | Rôle & Modalité d'accès | Objectif principal |
|:---|:---|:---|
| **Parent** | Application mobile Flutter (iOS / Android) authentifiée par SMS | Déclencher son arrivée à distance, suivre la progression de l'enfant en temps réel. |
| **Tiers autorisé (Nounou / Chauffeur)** | Aucun compte requis ; muni du **Code du jour** (4 chiffres) communiqué par le parent | Se présenter au portail de façon sécurisée sans installation requise. |
| **Parent sans smartphone** | Muni d'une **Carte numérotée physique** attribuée par l'école | Intégration immédiate dans la même file prioritaire par l'agent d'accueil. |
| **Agent d'accueil (Portail)** | Tablette tactile Flutter (opérant en mode *Offline-First* avec Drift) | Visualiser la file unifiée, confronter la photo/identité, valider la remise physique. |
| **Surveillant (Cour / Étages)** | Téléphone mobile Flutter dédié | Recevoir les ordres d'appel silencieux, libérer l'élève et appuyer sur *« Parti »*. |
| **Direction de l'école** | Back-office Filament (Laravel) | Paramétrer les fenêtres horaires, auditer le journal des remises, suivre les indicateurs. |

---

## 3. Cas d'Utilisation Fondamentaux (UC)

- **UC1 — Signaler son arrivée (`Arrival`)** : Le parent notifie
  son arrivée via l'application pendant la fenêtre autorisée et
  dans le rayon géolocalisé défini.
- **UC2 — Suivre la sortie (`PickupRequest`)** : Le parent suit
  l'évolution du statut en 4 étapes transparentes :
  `requested` → `class_notified` → `on_the_way` → `handed_over`.
- **UC3 — Générer un code du jour (`DailyCode`)** : Génération
  d'un code temporaire à 4 chiffres pour déléguer la sortie
  d'un ou plusieurs enfants à un tiers ponctuel.
- **UC4 — Gérer les personnes autorisées (`AuthorizedPerson`)** :
  Whitelist nominative des accompagnateurs permanents avec photos
  validées par l'école.
- **UC5 — Traiter la file et remettre l'enfant (`Handover`)** :
  L'agent d'accueil vérifie l'identité visuelle de l'accompagnateur,
  traite les alertes homonymes et valide la remise définitive
  sur la tablette.
- **UC6 — Appeler et libérer l'élève** : Réception d'appels ciblés
  par classe/salle sur le terminal du surveillant, qui confirme
  le départ de l'élève.
- **UC7 — Suivre l'activité et auditer** : Tableaux de bord en temps
  réel et extraction du journal inaltérable des remises pour
  résoudre tout litige.

---

## 4. Contraintes Non Négociables

### A. Primauté de la Décision Humaine

- Le logiciel ordonne, calcule les files et trace les étapes, mais
  **la vérification finale reste strictement humaine**.
- Aucune remise d'enfant ne s'effectue sans confirmation active de
  l'agent au portail via le bouton physique/tactile *« Remis »*
  après confrontation visuelle (photo + identité).

### B. Égalité d'Accès & Inclusion Dès le MVP

**Trois canaux d'entrée convergents vers une file unique**
dès la première version :

1. Application mobile parent (géolocalisée).
2. Code du jour à 4 chiffres (tiers ponctuels).
3. Carte numérotée physique (parents non équipés de smartphone
   ou sans batterie).

Aucun parent ni enfant ne doit être pénalisé par son équipement
technologique.

### C. Bilinguisme Intégral & Ergonomie Locale

- Interface nativement bilingue : **Arabe et Français**, avec gestion
  parfaite du sens de lecture droite-à-gauche (RTL via
  `EdgeInsetsDirectional` et `start`/`end`).
- Traduction arabe relue obligatoirement par un locuteur natif.
- Cibles tactiles d'au moins 48dp, fort contraste pour écran
  en plein soleil à 15h30, utilisable à une seule main.

### D. Souveraineté & Conformité Loi CNDP 09-08

- **Hébergement localisé au Maroc** (VPS dédié, orchestré par Docker).
- **Minimisation stricte des données personnelles** :
  - Zéro coordonnée GPS brute stockée en base (uniquement le booléen
    `in_radius` et la distance arrondie à 10 m).
  - Aucune donnée nominative, photo ou classe ne transite par les
    services tiers situés hors du Maroc (FCM / APNs) : notifications
    par identifiant opaque et texte générique.
  - Photos des élèves et des tuteurs stockées sur volume privé MinIO,
    accessibles uniquement par URLs signées à durée éphémère.
  - Journal des remises (`handover_logs`) monté en **ajout seul
    strict**, verrouillé au niveau du moteur PostgreSQL (trigger
    interdisant `UPDATE` et `DELETE`).

### E. Résilience Réseau & Heure Légale Marocaine

- **Tablette d'accueil Offline-First** : La tablette du portail doit
  pouvoir continuer à enregistrer les remises même lors d'une coupure
  totale 4G/Wi-Fi à 15h30 (base locale Drift, réconciliation
  idempotente à la reconnexion).
- **Fuseau horaire `Africa/Casablanca`** : Gestion explicite et
  dynamique des changements d'heures (notamment le retour à UTC+0
  durant le Ramadan). Aucun décalage horaire fixe dans le code.

### F. Isolation Multi-Établissement Absolue

- Partitionnement des données avec `school_id` obligatoire sur
  chaque modèle.
- Scope global systématique : toute requête visant une ressource
  d'une autre école renvoie immédiatement un statut HTTP
  `404 Not Found`.
- Canaux WebSockets temps réel (Laravel Reverb) strictement
  étanches (`private-school.{id}.queue`).

---

## 5. Hors Périmètre Version 1 (MVP)

Pour garantir la date de livraison du pilote et la robustesse
de l'essentiel, les domaines suivants sont expressément exclus
de la v1 :

- Gestion des absences et retards scolaires.
- Gestion de la cantine et des repas.
- Transport scolaire et circuits d'autobus.
- Messagerie bilatérale ou communication pédagogique
  parents-enseignants.

---

## 6. Indicateurs Clés de Succès du Pilote (KPIs)

| Indicateur | Cible Direction | Mode de mesure |
|:---|:---|:---|
| **Temps d'attente médian** | Réduction de plus de 60 % par rapport au système historique. | Mesure chronométrée avant déploiement vs horodatages réels du journal. |
| **Suppression du mégaphone** | > 95 % des sorties réalisées sans aucun appel vocal. | Suivi des sorties initiées via l'application et la carte. |
| **Fiabilité des remises** | 0 erreur d'aiguillage d'élève / 100 % d'auditabilité. | Registre `handover_logs` exhaustif et non modifiable. |
| **Disponibilité portail** | 100 % des remises assurées, même en cas de panne réseau. | Validation des réconciliations Drift hors ligne lors du pilote. |

---

## 7. Règle Agent

Ce document fait foi sur tous les arbitrages.
En cas de contradiction entre une spec et ce document,
ce document prime. Toute décision qui contredit une contrainte
de la section 4 est bloquante et doit être signalée avant
tout code.