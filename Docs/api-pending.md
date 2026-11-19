# Fonctionnalités mobile en attente d'endpoints API

Document d'inventaire : fonctionnalités UX souhaitées côté mobile dont
l'implémentation est **bloquée** par l'absence d'un endpoint serveur.
Mis à jour après l'audit croisé API ↔ Mobile de la session courante.

Format : pour chaque entrée, on documente **l'usage attendu**, **l'endpoint
manquant**, et **l'estimation UI** côté mobile une fois l'API disponible.

---

## 1. Billing / Facturation — ✅ Livré 2026-11-14

Les trois endpoints sont livrés ; les factures sont synthétisées sur les
colis livrés groupés par mois (ID `synth-YYYY-MM`). Le PDF est généré en
mémoire via `src/utils/invoice-pdf.js` (pas de lib externe). Mobile : la
section "Facturation" télécharge le PDF via Dio puis le partage.

- `GET /business-shipper/invoices` (liste)
- `GET /business-shipper/invoices/:id` (détail + colis inclus)
- `GET /business-shipper/invoices/:id/pdf` (stream PDF)

---

## 2. API keys scoped au shipper — ✅ Livré 2026-11-14

UI mobile : `ApiKeysScreen(scope: ApiKeysScope.businessShipper)` sur
`/business/api-keys`. Backend : migration `20261120_api_key_owner` (colonne
`created_by_id` FK users, cascade delete) + 5 handlers dans
`mobile.controller.js` filtrant systématiquement par `createdById: req.user.id`
(404 sur clé tierce). Scopes limités à `parcel.read / parcel.write /
webhook.receive`. Couvert par `tests/business-shipper-api-keys.test.js` (7/7).

- `GET /business-shipper/api-keys`
- `POST /business-shipper/api-keys`
- `POST /business-shipper/api-keys/:keyId/rotate`
- `PATCH /business-shipper/api-keys/:keyId`
- `POST /business-shipper/api-keys/:keyId/deactivate`

Les webhooks sortants dédiés shipper (endpoint `/business-shipper/webhooks`
séparé) ne sont pas nécessaires : l'URL webhook est portée par la clé API
elle-même (`webhookUrl` + `webhookSecret`), comme pour les clés partenaires.

---

## 3. KYC : suppression + demande d'infos complémentaires — ✅ Livré 2026-11-14

UI mobile : boutons "Supprimer" + "Demander des infos" dans
`identity_verifications_screen`, dialogues de confirmation/motif branchés sur
`ApiService.deleteIdentity` / `requestInfoIdentity`.

- `DELETE /super-admin/identity-verifications/:id`
- `POST /super-admin/identity-verifications/:id/request-info` (body : message)

---

## 4. Dashboard SLA cross-tier admin — ✅ Livré 2026-11-14

UI mobile : `_SupportSlaCard` dans `support_admin_dashboard` affiche 4 pills
(tech à risque / tech dépassé / commercial en retard / chat dépassé) avec
raccourcis vers chaque écran de suivi. Le provider `supportAdminSlaProvider`
masque la carte tant que l'endpoint retourne null.

- `GET /support-admin/sla-overview`

---

## 5. Journey stop events pour les batches — ✅ Livré 2026-11-14

Endpoints opérationnels, persistés via `AuditLog`
(`entityType='shipment_batch'`, `action='stop_event'`). UI mobile : bottom-sheet
avec type (dropdown), libellés optionnels ; le provider des événements est
invalidé après création.

- `POST /shipment-batches/:batchId/stop-events` → body : `{ type, locationLat, locationLng, note }`
- `GET /shipment-batches/:batchId/stop-events`

**UI côté mobile (quand prêt)**
Ajouter une section "Événements du lot" dans `shipment_batch_detail_screen`
similaire au timeline parcel events.

---

## 6. Close conversation avec motif de résolution — ✅ Livré 2026-11-14

UI mobile : `_CloseConversationDialog` dans `support_inbox_screen` collecte
dropdown catégorie (resolved / duplicate / spam / no_answer) + motif libre
(validation min. 5 chars) avant d'envoyer `POST /conversations/:id/close`
avec `{ reason, category }`.

---

## 7. Parcel templates serveur (optionnel)

**Statut : implémenté en local-only pour l'instant**
(voir `lib/services/parcel_template_store.dart` côté mobile et
`src/lib/parcelTemplateStore.ts` côté web — clés localStorage cloisonnées par
utilisateur). Les deux implémentations partagent la même sérialisation ; une
éventuelle synchro serveur viendrait s'ajouter sans migration.

**Pour synchroniser entre appareils** il faudrait :
- `GET /me/parcel-templates` + create / update / delete

Non prioritaire : un utilisateur qui change d'appareil peut recréer ses
modèles manuellement, et l'implémentation locale évite une consommation
serveur pour un usage essentiellement personnel.

---

## 8. CSV bulk import endpoint bulk-create — ✅ Livré 2026-11-14

UI mobile : le sheet appelle d'abord `POST /client/parcels/bulk-create` et
remonte le rapport ligne-par-ligne depuis `results[]` (ordre préservé). En cas
de 404 (vieux serveur), fallback automatique sur les créations séquentielles.

---

## 9. Shuttle Operator — CRUD lignes / flotte / horaires — ✅ Livré 2026-11-14

**Statut : API livrée, UI web livrée, mobile non prioritaire.**

Migration SQL : `20261122000000_shuttle_operator_crud` — ajoute
`transit_lines.operator_user_id` + crée `shuttle_vehicles` et
`shuttle_schedules`. Endpoints montés sous `/shuttle-operator/*` dans
`app.js`, RBAC `shuttle_operator`, ownership isolée (404 sur ressource
d'un autre opérateur). Tests `tests/shuttle-operator.test.js` couvrent
RBAC + ownership + validation + CRUD + soft delete + unicité plaque.

- `GET /shuttle-operator/overview`
- `GET/POST/PATCH/DELETE /shuttle-operator/lines[/:lineId]` — CRUD atomique
  avec stops (deleteMany + createMany dans la même transaction pour les
  mises à jour).
- `GET/POST/PATCH/DELETE /shuttle-operator/vehicles[/:vehicleId]` — soft
  delete via `deletedAt + status='retired'` ; unicité plaque *par* opérateur.
- `GET/POST/PATCH/DELETE /shuttle-operator/schedules[/:scheduleId]` —
  validation HH:MM, jours 0-6, plage `activeFrom`/`activeUntil`.

Web : espace `/shuttle` avec `ShuttleOverviewPage`, `ShuttleLinesPage`,
`ShuttleVehiclesPage`, `ShuttleSchedulesPage` ; wrapper
`src/lib/api/shuttle-operator.ts` ; précache PWA inclus.

**Non livré** (contenu originel) :

Le rôle `shuttle_operator` a été introduit par la migration
`20261117_shuttle_operator_role`. Les lignes de transit existent (modèle
`TransitLine` + `TransitLineStop`) mais sont **alimentées par seed**
(`seed-transit.js`) et uniquement exposées en lecture via :

- `GET /transit/lines` (catalogue public)
- `GET /transit/lines/:lineId`
- `GET /transit/lines/:lineId/live` (voyages actifs)
- `GET /transit/stops/search`
- `GET /transit/lines/:lineId/draft` (pré-remplissage annonce chauffeur)

Les 3 endpoints partagés avec le driver (`POST /advertisements`,
`POST /parcels/:id/handovers`, `POST /parcels/:id/handovers/:handoverId/confirm`)
sont accessibles au shuttle_operator mais passent par l'UI driver.

**Endpoints manquants pour un espace shuttle_operator complet :**

- Gestion des lignes de l'opérateur (CRUD restreint à l'opérateur) :
  - `GET /shuttle-operator/lines` (mes lignes)
  - `POST /shuttle-operator/lines`
  - `PATCH /shuttle-operator/lines/:lineId`
  - `DELETE /shuttle-operator/lines/:lineId`
- Gestion de la flotte (véhicules collectifs) :
  - `GET/POST/PATCH/DELETE /shuttle-operator/vehicles`
- Gestion des horaires et plages de service :
  - `GET/POST/PATCH/DELETE /shuttle-operator/schedules`
- Dashboard opérationnel :
  - `GET /shuttle-operator/overview` (lignes actives, départs du jour, flotte
    disponible)

**UI mobile / web (quand prêt)** — ni le mobile ni le web n'exposent d'écran
dédié. Les deux clients consomment déjà les 3 endpoints partagés via les
écrans driver. Un espace dédié sera construit une fois les endpoints ci-dessus
livrés.

---

## Priorisation suggérée

Tout le lot « pending » 1-8 est livré hors `§7 parcel templates serveur`
(volontairement reporté — local-only suffit).

`§9 Shuttle Operator CRUD` est la seule dépendance backend nouvelle issue
de l'audit final 2026-11-14 : pas urgente tant qu'aucun opérateur n'est
contractualisé.

**Statut au 2026-11-19 (clôture parité stricte)** : plus aucun endpoint
manquant côté mobile. Les 3 items encore ❌ dans la matrice parité
(Assistant IA web/pwa, UI backhaul driver, onglet Fraude mobile) étaient
des manques **côté client** (UI non livrée), pas des endpoints absents —
tous livrés ce jour, pas d'API nouvelle.

Dernière mise à jour : 2026-11-19 (vérif post-clôture : zéro endpoint pending).
