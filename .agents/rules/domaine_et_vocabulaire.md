# 10 — Domaine Métier et Vocabulaire Strict

Ce glossaire définit les seuls termes autorisés dans le code, la base de données, l'API et les tests. Les synonymes ou variantes sont formellement proscrits.

---

## Glossaire Conceptuel <-> Code

| Terme Métier (FR) | Classe / Entité Code | Définition & Règle d'implémentation |
| :--- | :--- | :--- |
| **École** | `School` | Établissement scolaire. Clé de partitionnement `school_id` sur toutes les tables métier. |
| **Arrivée** | `Arrival` | Événement généré par un appui unique du parent. Regroupe une ou plusieurs demandes de sortie (fratrie). |
| **Demande de sortie** | `PickupRequest` | Demande individuelle associée à un élève (`Student`) pour un appui donné. |
| **Personne autorisée** | `AuthorizedPerson` | Accompagnateur récurrent déclaré par la famille, soumis à validation visuelle de l'école. |
| **Code du jour** | `DailyCode` | Secret numérique à 4 chiffres généré pour un tiers ponctuel, à validité éphémère. |
| **Carte numérotée** | `PickupCard` | Carte d'identification physique attribuée aux familles sans terminal mobile. |
| **Journal des remises** | `HandoverLog` | Registre légal inaltérable enregistrant la remise physique de l'enfant (ajout seul). |

---

## Machine à états PickupRequest

### Transitions nominales (cycle complet)
requested                  → class_notified
class_notified             → on_the_way
on_the_way                 → handed_over

### Transitions de raccourci (agent d'accueil)
L'agent du portail peut remettre un enfant directement depuis n'importe quel statut actif, sans faire le cycle complet :
requested                  → handed_over
class_notified             → handed_over
pending_agent_confirmation → handed_over

Ces raccourcis sont tracés dans handover_logs (source_status, à ajouter en F02b si nécessaire).

### Transitions de confirmation
pending_agent_confirmation → requested

### Transitions de terminaison (hors file)
requested                  → cancelled
requested                  → expired

### Transitions INTERDITES (422)
Toute transition depuis cancelled, expired ou handed_over.
Toute autre paire non listée ci-dessus.

---

## Correspondance des Statuts vus par le Parent

| Statut Technique | Libellé Parent (Français) | Libellé Parent (Arabe) |
| :--- | :--- | :--- |
| `requested` | Demande envoyée | تم إرسال الطلب |
| `pending_agent_confirmation` | En attente de confirmation | في انتظار تأكيد الإدارة |
| `class_notified` | Classe prévenue | تم إشعار القسم |
| `on_the_way` | Votre enfant arrive | طفلكم في الطريق إلى البوابة |
| `handed_over` | Remis | تم التسليم |
| `cancelled` | Annulé | ملغى |
| `expired` | Expiré | منتهي الصلاحية |
