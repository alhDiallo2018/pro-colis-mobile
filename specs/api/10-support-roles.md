# Roles support technique et support commercial

**Etat : livre et fonctionnel.** Migration appliquee, endpoints implementes,
application mobile branchee dessus. Ce document decrit ce qui existe.

Depot backend : `/Volumes/Oracle/Web/ProColis-Api` (Express + Prisma).
Depot mobile : `/Volumes/Oracle/Mobile/ProColis` (Flutter).

## 1. Schema et migration

Le projet utilise **Prisma** : la source de verite est `prisma/schema.prisma`,
pas du SQL ecrit a la main. La migration correspondante est
`prisma/migrations/20260726150000_support_roles/`.

### Enum des roles

```prisma
enum UserRole {
  client
  driver
  admin
  super_admin
  support              // compte partage historique, co-equivalent de super_admin
  support_technique    // ajoute
  support_commercial   // ajoute
}
```

Deux points releves lors de la migration :

- `support` figurait dans `schema.prisma` mais **n'avait jamais ete migre** :
  l'enum en base ne contenait que `client / driver / admin / super_admin`. La
  migration le rattrape, sinon chaque `prisma migrate diff` continuerait de le
  reclamer. Aucun compte ne l'utilise (0 ligne).
- `support` reste en place car ~40 gardes de routes le referencent comme
  co-equivalent de `super_admin`. Le retirer est un refactoring distinct.
  Cote mobile, `UserRole.fromString('support')` le mappe donc sur `superAdmin`,
  ce qui correspond a ses droits reels.

### Tables

Quatre modeles ajoutes : `SupportTicket`, `PlatformIncident`, `CommercialLead`,
`CommercialObjective` (tables `support_tickets`, `platform_incidents`,
`commercial_leads`, `commercial_objectives`).

Points de conception :

- `support_tickets.sla_due_at` porte l'echeance de premiere reponse. C'est elle
  qui pilote l'alerte SLA : une duree calculee cote client derivrait selon
  l'horloge du telephone. Le budget par priorite est
  `critical 60 min · high 240 · normal 720 · low 2880`, defini dans
  `SLA_MINUTES` (support.controller.js) et duplique dans
  `TicketPriority.slaMinutes` cote Dart — **garder les deux alignes**.
- `commercial_objectives.period` est un `DATE` cale sur le 1er du mois, en UTC.
  Un minuit local sous fuseau negatif basculerait sur le mois precedent et
  l'objectif ne serait jamais retrouve.

### Appliquer

```bash
cd /Volumes/Oracle/Web/ProColis-Api
npx prisma migrate deploy   # et non `migrate dev`, qui peut reinitialiser la base
npx prisma generate
```

> La migration a ete generee via `prisma migrate diff` puis **elaguee** : le
> diff embarquait aussi 7 `ALTER COLUMN "updated_at" DROP DEFAULT` relevant
> d'une derive pre-existante et sans rapport (assistances, wallets, zones…).
> Cette derive subsiste et reapparaitra dans les prochains diffs.

## 2. Endpoints

Implementes dans `src/modules/support/` (controller + routes), montes dans
`app.js` avant `mobileRouter`. Les prefixes suivent la convention existante
(`/client`, `/driver`, `/garage-admin`, `/super-admin`) et sont portes cote
mobile par `UserRole.apiScope` et `UserRole.profileEndpoint`.

Consommation cote Flutter : `lib/services/api/support_roles_api.dart`, exposee
via `lib/providers/support_provider.dart`.

### Profil

| Methode | Route | Roles | Description |
| --- | --- | --- | --- |
| PUT | `/support-technique/profile` | support_technique | Modifier son profil. |
| PUT | `/support-commercial/profile` | support_commercial | Modifier son profil. |

Meme charge utile que les autres profils : `fullName`, `email`, `phone`,
`address`, `city`, `region`.

### Support technique

| Methode | Route | Roles | Description |
| --- | --- | --- | --- |
| GET | `/support-technique/stats` | support_technique, super_admin | KPI du dashboard. |
| GET | `/support-technique/tickets` | support_technique, super_admin | File de tickets (filtres `status`, `priority`, `assignee`). |
| GET | `/support-technique/tickets/:id` | support_technique, super_admin | Detail d'un ticket. |
| PATCH | `/support-technique/tickets/:id` | support_technique, super_admin | Changer statut, priorite, assignation. |
| GET | `/support-technique/incidents` | support_technique, super_admin | Incidents ouverts. |
| POST | `/support-technique/incidents` | support_technique, super_admin | Declarer un incident. |
| PATCH | `/support-technique/incidents/:id` | support_technique, super_admin | Mettre a jour / cloturer. |

Reponse attendue de `GET /support-technique/stats` (alimente
`SupportTechniqueSummary`) :

```json
{
  "success": true,
  "stats": {
    "openTickets": 14,
    "resolvedToday": 6,
    "resolvedThisMonth": 132,
    "firstResponseMinutes": 22,
    "resolutionHours": 4.5,
    "satisfactionPercent": 93,
    "slaAtRisk": 2,
    "openIncidents": 1,
    "tierLabel": "Niveau 2",
    "scopeLabel": "Application mobile & paiements",
    "shiftLabel": "Lun-Ven · 08 h - 17 h",
    "channels": ["Chat in-app", "Telephone", "Email"],
    "weeklySeries": { "values": [8, 11, 9, 14, 12, 6, 4], "unit": "tickets" },
    "categories": [
      { "label": "Paiement", "count": 28 },
      { "label": "Suivi colis", "count": 22 },
      { "label": "Compte / PIN", "count": 15 },
      { "label": "Bug appli", "count": 9 }
    ]
  }
}
```

### Support commercial

| Methode | Route | Roles | Description |
| --- | --- | --- | --- |
| GET | `/support-commercial/stats` | support_commercial, super_admin | KPI et objectif du mois. |
| GET | `/support-commercial/leads` | support_commercial, super_admin | Pipeline (filtre `stage`). |
| POST | `/support-commercial/leads` | support_commercial, super_admin | Creer un prospect. |
| PATCH | `/support-commercial/leads/:id` | support_commercial, super_admin | Faire avancer une etape, planifier une relance. |
| GET | `/support-commercial/coverage` | support_commercial, super_admin | Zones a ouvrir ou densifier. |

Reponse attendue de `GET /support-commercial/stats` (alimente
`SupportCommercialSummary`) :

```json
{
  "success": true,
  "stats": {
    "activeLeads": 17,
    "signedThisMonth": 5,
    "managedAccounts": 42,
    "monthlyRevenue": 3750000,
    "monthlyObjective": 4000000,
    "conversionPercent": 29,
    "overdueFollowUps": 3,
    "newZonesSigned": 2,
    "territory": "Thies · Diourbel · Mbour",
    "monthlySeries": { "values": [2, 3, 4, 3, 5, 6, 5, 7, 8, 6, 9, 5], "unit": "contrats" },
    "sources": [
      { "label": "Terrain", "count": 18 },
      { "label": "Recommandation", "count": 11 },
      { "label": "Entrant", "count": 7 }
    ]
  }
}
```

### Lecture des colis

Le support instruit des reclamations : il peut **lire** les colis, sans les
modifier. Cote mobile, cette distinction est portee par
`User.canViewAllParcels` (support inclus) et `User.canManageParcels` (support
exclu). Cote API, `parcelAccessWhere` (mobile.controller.js) accorde la lecture
aux roles support ; **aucune route d'ecriture n'est exposee** sous les prefixes
`/support-technique` et `/support-commercial`.

> `parcelAccessWhere` refuse par defaut tout role non traite explicitement
> (`senderId: '__none__'`). Sans l'ajout des roles support, ces routes auraient
> renvoye 404 en permanence.

| Methode | Route | Roles | Description |
| --- | --- | --- | --- |
| GET | `/support-technique/parcels/:parcelId` | support_technique, super_admin | Detail colis, lecture seule. |
| GET | `/support-commercial/parcels/:parcelId` | support_commercial, super_admin | Detail colis, lecture seule. |

## 3. Permissions

| Capacite | client | driver | admin | support_technique | support_commercial | super_admin |
| --- | --- | --- | --- | --- | --- | --- |
| Creer un colis | oui | non | non | non | non | non |
| Livrer un colis | non | oui | non | non | non | non |
| Lire tous les colis | non | non | oui | oui | oui | oui |
| Modifier / assigner un colis | non | non | oui | non | non | oui |
| Gerer les chauffeurs | non | non | oui | non | non | oui |
| Traiter les tickets support | non | non | non | oui | non | oui |
| Gerer le pipeline commercial | non | non | non | non | oui | oui |
| Gerer les utilisateurs et les zones | non | non | non | non | non | oui |

## 4. Diffusions (broadcasts)

`broadcasts.target_roles` doit accepter `support_technique` et
`support_commercial`. Cote mobile la liste des cibles est desormais derivee de
l'enum (`lib/screens/super-admin/broadcasts_page.dart`), donc aucune retouche
client ne sera necessaire.

## 5. Creation des comptes support

Ces roles ne sont pas ouverts a l'inscription publique : le schema zod de
`POST /auth/register` (`auth.validators.js`) n'accepte que
`client / driver / admin / super_admin`, donc les valeurs support sont rejetees
sans modification supplementaire. Seul `PATCH /super-admin/users/:id/role` peut
les attribuer. L'ecran mobile d'inscription ne propose que `client` et `driver`.

## 6. Comptes de demonstration

### Base reelle — `npm run seed:support`

Idempotent (upsert sur identifiants fixes). PIN `123456`,
mot de passe `Password123!`.

| Role | Identifiant | Nom |
| --- | --- | --- |
| support_technique | `support.tech@procolis.test` | Awa Ndoye |
| support_commercial | `support.com@procolis.test` | Seydou Kane |

Le seed cree 10 tickets (dont 5 actifs et plusieurs en depassement de SLA),
3 incidents (dont 1 resolu, masque par defaut), 8 prospects et un objectif
mensuel calibre pour afficher une jauge lisible (~79 %). Un seed « tout propre »
afficherait des ecrans vides et ne prouverait rien.

### Mode hors-ligne — `MOCK_API=true`

`lib/services/mock_data.dart` conserve deux comptes support en
`@sendprocolis.test` pour le mode sans backend. Ils sont **distincts** des
comptes seedes ci-dessus.

## 7. Ce qui reste en donnees de demonstration

Les espaces support lisent l'API. En revanche, les statistiques de profil des
roles **client**, **admin de zone** et **super admin** sont encore generees
localement par `lib/services/role_mock_data.dart`, faute d'endpoints
`GET /client/stats` et `GET /garage-admin/stats`. Ces blocs portent une mention
« Chiffres de demonstration » a l'ecran. Le chauffeur utilise le vrai
`GET /driver/stats`, complete par le mock sur les champs non couverts.
