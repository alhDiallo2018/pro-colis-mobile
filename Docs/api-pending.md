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
(voir `lib/services/parcel_template_store.dart`).

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

## Priorisation suggérée

Tout le lot « pending » est livré hors `§7 parcel templates serveur`
(volontairement reporté — local-only suffit).

Dernière mise à jour : 2026-11-14.
