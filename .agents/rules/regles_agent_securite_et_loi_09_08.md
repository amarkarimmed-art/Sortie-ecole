trigger: always_on

# 30 — Sécurité, Confidentialité et Conformité Loi 09-08 (CNDP)

Ce document consigne les impératifs de conformité légale et de sécurité applicables au contexte marocain. Aucune dérogation n'est tolérée.

---

## 1. Données Personnelles et Environnements

* **Aucune donnée réelle dans le dépôt :** Les commits, tests, fixtures, captures d'écran et prompts d'agents ne doivent contenir aucun prénom, nom, téléphone ou photo d'élèves/parents réels.
* **Factories et Jeux d'Essai :** Utiliser exclusivement des données fictives bilingues (ex. : `docs/exemples/eleves-fictifs.csv`).
* **Secrets de Configuration :** L'agent ne doit jamais lire, modifier ou afficher le fichier `.env` de production.

---

## 2. Géolocalisation et Respect de la Vie Privée

* **Pas de coordonnées brutes en base :**
  * La latitude et la longitude de l'appareil parent ne sont lues qu'une seule fois en mémoire au moment de l'appui sur « Je suis arrivé ».
  * Aucune colonne `lat`, `lng`, `latitude` ou `longitude` n'est admise dans les tables `arrivals`, `pickup_requests` ou `idempotency_keys`.
* **Minimisation :** Seuls sont conservés :
  1. Le booléen `in_radius` (présence dans le périmètre autorisé de 200 à 300 mètres).
  2. La distance par rapport au portail, **arrondie aux $10\,\text{m}$ supérieurs**.

---

## 3. Isolation Multi-Établissement (Multi-Tenancy)

* Chaque requête HTTP doit être filtrée par le `school_id` extrait de l'URL ou du jeton Sanctum authentifié.
* Si un utilisateur ou un élève n'appartient pas à l'école ciblée : **renvoyer immédiatement un code HTTP 404** (évite la fuite d'existence de profils).
* Interdiction d'utiliser `withoutGlobalScopes()` sauf dans le cadre d'un job système justifié explicitement en commentaire d'architecture.

---

## 4. Protection du Journal des Remises (`HandoverLog`)

Le journal des remises certifie légalement la responsabilité de l'établissement lors de la remise d'un mineur :
* **Ajout seul strict (Append-Only) :** Les opérations de mise à jour (`UPDATE`) et de suppression (`DELETE`) sont formellement bloquées au niveau du moteur PostgreSQL par un trigger :
```sql
CREATE TRIGGER handover_logs_ajout_seul
BEFORE UPDATE OR DELETE ON handover_logs
FOR EACH ROW EXECUTE FUNCTION interdire_modif_journal();
```

---

## 5. Stockage des Photographies

* Les clichés d'identité des élèves et des personnes autorisées sont conservés sur un bucket privé **MinIO hébergé au Maroc**.
* Les accès se font exclusivement par des URLs temporaires signées (`Storage::temporaryUrl()`), valides pendant une durée maximale de 5 minutes.
* Tout accès public direct doit être rejeté par une erreur 403.

---

## 6. Codes du Jour (`DailyCode`)

* Les codes secrets à 4 chiffres ne sont jamais enregistrés en clair : stockage par empreinte **HMAC-SHA256** calculée avec une clé secrète serveur.
* Limitations de sécurité obligatoires :
  * Expiration automatique le jour même à la fin de la fenêtre de sortie.
  * Blocage après 5 tentatives infructueuses consécutives.
  * Limitation de débit (*rate-limiting*) appliquée sur la tablette réceptrice.

---

## 7. Notifications Externes (Apple APNs / Google FCM)

* Les données transitant hors du territoire marocain vers les serveurs de Google ou Apple ne doivent contenir :
  * **Aucun nom d'élève ou de parent**.
  * **Aucune photographie**.
  * **Aucune désignation de classe ou d'enseignant**.
* Le payload se limite à un identifiant opaque générique. Le terminal mobile effectue ensuite un appel authentifié vers l'API marocaine pour afficher les détails.