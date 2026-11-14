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

## 2. API keys & webhooks scoped au shipper

**Usage attendu**
Un expéditeur pro souhaite gérer ses propres clés API et webhooks sans
dépendre du super_admin.

**Endpoints manquants**
- `GET /business-shipper/api-keys` + create / rotate / deactivate
- `GET /business-shipper/webhooks` + create / update / delete
- Middleware : authent de type shipper, scope limité à son propre compte

**UI côté mobile (quand prêt)**
Réutiliser `api_keys_screen.dart` en passant un `scope` différent, ou dupliquer
sous `/business-shipper/*`.

---

## 3. KYC : suppression + demande d'infos complémentaires

**Usage attendu**
L'équipe KYC doit pouvoir :
- Supprimer une soumission invalide (pièce illisible, doublon)
- Demander des infos supplémentaires sans rejeter (ex. nouvelle photo)

**Endpoints manquants**
- `DELETE /super-admin/identity-verifications/:id`
- `POST /super-admin/identity-verifications/:id/request-info` (body : message)

**UI côté mobile (quand prêt)**
Boutons "Supprimer" + "Demander des infos" dans `identity_verifications_screen`
à côté des actions approve/reject existantes.

---

## 4. Dashboard SLA cross-tier admin

**Usage attendu**
Un admin a besoin d'une vue consolidée des SLA techniques, commerciaux et
chat sur un seul écran (plutôt que de passer d'un onglet à l'autre).

**Endpoints manquants**
- `GET /support-admin/sla-overview` → métriques combinées :
  - tickets techniques en risque (par priorité)
  - leads commerciaux en retard
  - conversations chat SLA dépassé

**UI côté mobile (quand prêt)**
Nouvel onglet dans `support_admin_dashboard` avec 3 compteurs + raccourcis
vers chaque tier.

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

## 6. Close conversation avec motif de résolution

**Usage attendu**
À la clôture d'une demande support, l'agent doit préciser le motif pour
alimenter les stats et la base de connaissance.

**Endpoint manquant**
Modification : `POST /support/chat/conversations/:id/close` accepte un body
`{ reason: string, category: 'resolved' | 'duplicate' | 'spam' | 'no_answer' }`.

**UI côté mobile (quand prêt)**
Modifier `support_inbox_screen._action` pour appeler un dialogue de motif
avant close, puis envoyer le body.

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

## 8. CSV bulk import endpoint bulk-create

**Statut : implémenté en local-only pour l'instant**
(voir `lib/screens/client/csv_bulk_import_sheet.dart`).

Actuellement N appels séquentiels à `POST /client/parcels/create`. Un
endpoint `POST /client/parcels/bulk-create` (body : `{ parcels: [...] }`)
permettrait :
- Transaction atomique (soit tous, soit aucun)
- 1 round-trip au lieu de N
- Validation en un seul passage

**UI côté mobile (quand prêt)**
Remplacer la boucle `for` du sheet par un seul appel bulk, garder le
rapport ligne-par-ligne grâce à la réponse structurée du serveur.

---

## Priorisation suggérée

1. **Close with reason** (déjà déployable côté API, UX immédiate pour les agents)
2. **Bulk-create** (gain de perf significatif pour les shippers pro)
3. **KYC delete + request info** (ergonomie équipe compliance)
4. **Billing/invoicing** (nécessaire pour les shippers B2B à terme)
5. **SLA cross-tier dashboard** (nice-to-have pour l'admin)
6. **Shipper-scoped API keys/webhooks** (self-service shipper pro)
7. **Batch stop events** (traçabilité flotte)

Dernière mise à jour : 2026-11-12.
