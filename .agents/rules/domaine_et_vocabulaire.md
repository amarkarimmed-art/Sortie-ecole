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

## Machine à États : `PickupRequest`

L'état d'une demande de sortie (`PickupRequest`) suit strictement le graphe de transition ci-dessous. **Toute autre transition est interdite** et doit lever une exception `TransitionInterdite`.

```
                    ┌───────────────────────────────┐
                    │  pending_agent_confirmation   │ (Hors rayon / GPS refusé)
                    └───────────────┬───────────────┘
                                    │ (Validation manuelle par agent)
                                    ▼
┌──────────────┐             ┌──────────────┐
│  cancelled   │◄────────────┤  requested   │ (Parent signale son arrivée dans la zone)
└──────────────┘             └──────┬───────┘
                                    │ (L'agent du portail valide l'appel)
                                    ▼
                             ┌──────────────┐
                             │class_notified│ (Surveillant reçoit l'alerte de sortie)
                             └──────┬───────┘
                                    │ (Le surveillant clique « Parti »)
                                    ▼
                             ┌──────────────┐
                             │  on_the_way  │ (L'élève est en transit vers le portail)
                             └──────┬───────┘
                                    │ (L'assistante vérifie et clique « Remis »)
                                    ▼
                             ┌──────────────┐
                             │ handed_over  │ (Sortie actée, enregistrée dans HandoverLog)
                             └──────────────┘
```

*Transitions secondaires de terminaison :*
* `requested` → `expired` : À la clôture de la fenêtre horaire si non traitée.
* `requested` → `cancelled` : Annulation explicite par le parent avant prise en charge.

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
