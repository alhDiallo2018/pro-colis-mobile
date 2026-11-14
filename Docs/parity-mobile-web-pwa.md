# Suivi de parité Mobile ↔ Web ↔ PWA

Document de suivi des fonctionnalités mobile à répliquer côté web et PWA.

**Codebases concernés**
- Mobile (Flutter) : `Mobile/Procolis-App/pro-colis-mobile/`
- Web (React/Vite) : `Web/Procolis-Web/site/pro-colis-web/`
- API (Node/Express/Prisma) : `Web/Procolis-Api/pro-colis-api/`

**Réalité mobile vs web** — tout ne doit pas être répliqué à l'identique :
- certaines capacités (caméra, GPS continu, carnet d'adresses, biométrie,
  secure storage natif, Share sheet, FCM) sont **natives** et imposent
  des **compromis** côté web (dégradation UX documentée, pas copie 1:1) ;
- à l'inverse, la landing marketing, le SEO et l'installer iOS sont
  **web-only** et n'ont pas à remonter côté mobile.

Le but du doc est de **tracker la parité fonctionnelle** (le quoi) plutôt
que l'équivalence pixel-perfect (le comment).

## Légende statuts

| Symbole | Sens |
|---|---|
| ✅ | Livré avec parité fonctionnelle |
| ⚠️ | Partiel (manque UX, actions, cas limites) |
| ❌ | À implémenter |
| 🚫 | Non applicable (capacité native sans équivalent web raisonnable) |
| ↩️ | Dégradation acceptée (compromis UX documenté, pas équivalence 1:1) |
| N/A | Hors scope de ce rôle |

---

## Fonctionnalités partagées (tous rôles authentifiés)

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Login / PIN 6 chiffres | ✅ | ✅ | ✅ |
| Récupération de PIN | ✅ | ✅ | ✅ |
| Google Sign-In | ✅ | ⚠️ (dépend config API) | ⚠️ |
| Déverrouillage biométrique | ✅ | ↩️ WebAuthn à évaluer | ↩️ |
| Notifications in-app | ✅ | ✅ | ✅ |
| Notifications push temps réel | ✅ FCM | ✅ Web Push VAPID | ✅ Web Push (SW + badge + routing) |
| Chat support | ✅ | ✅ | ✅ |
| Profil + préférences notifications | ✅ | ✅ | ✅ |
| Pages légales (CGU, confidentialité…) | ✅ | ✅ | ✅ |
| Localisation (fr / en / wo) | ✅ | ⚠️ (vérifier wo) | ⚠️ |
| Mode sombre | ✅ | ⚠️ à vérifier | ⚠️ |
| Historique hors ligne (lecture) | ✅ cache local | ✅ SW + IndexedDB (TTL 14j) | ✅ |
| Référral / parrainages | ✅ | ✅ | ✅ |
| App update gate (version mini) | ✅ | N/A (PWA se met à jour auto) | ✅ via SW |
| Partage (Share sheet) | ✅ natif | ↩️ Web Share API | ↩️ |

---

## Client / Business Shipper

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Wizard création colis 4 étapes | ✅ | ✅ | ✅ |
| Picker destinataire depuis contacts | ✅ | 🚫 Contacts API non dispo | 🚫 |
| Note vocale sur colis | ✅ | ↩️ MediaRecorder (session) | ↩️ |
| Scanner QR / Datamatrix | ✅ | ↩️ saisie manuelle | ↩️ caméra via getUserMedia |
| Live tracking carte | ✅ | ✅ | ✅ |
| Historique colis | ✅ | ✅ | ✅ |
| Dispute / litige | ✅ | ✅ | ✅ |
| Dashboard B2B shipper | ✅ | ✅ | ✅ |
| Facturation PDF | ✅ download+share | ✅ download | ✅ |
| Import CSV bulk | ✅ bulk-create | ⚠️ à vérifier | ⚠️ |
| Modèles de colis (templates) | ✅ local-only | ✅ local-only (`localStorage`) | ✅ local-only |
| Self-service clés API | ✅ `/business/api-keys` | ✅ `/client/api-keys` | ✅ |
| Carnet d'adresses enregistré | ✅ | ✅ | ✅ |
| Dettes client / soldes dus | ✅ | ✅ | ✅ |
| Public tracking (sans login) | N/A | ✅ | ✅ |
| Fiches publiques drivers | ✅ | ✅ | ✅ |

---

## Driver / Chauffeur

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Dashboard chauffeur | ✅ | ✅ | ✅ |
| Toggle disponibilité | ✅ | ✅ | ✅ |
| Création d'annonces / voyages | ✅ | ✅ | ✅ |
| Import de routes (fichier) | ✅ | ⚠️ à vérifier | ⚠️ |
| Catalogue colis libres | ✅ | ✅ | ✅ |
| Proposer offre + négociation chat | ✅ | ✅ | ✅ |
| Confirmation ramassage (scan QR + photo) | ✅ | ↩️ photo via file input | ↩️ |
| GPS continu partage position | ✅ background | 🚫 impossible web | 🚫 |
| Carte itinéraire client | ✅ | ✅ | ✅ |
| Confirmation livraison (signature + photo) | ✅ | ↩️ canvas signature | ↩️ |
| Manifeste navette (shuttle) | ✅ | ⚠️ à vérifier | ⚠️ |
| Handover colis chauffeur→chauffeur | ✅ | ✅ 2026-11-14 | ✅ |
| Arrêts atteints / tracking intermédiaire | ✅ | ⚠️ partiel | ⚠️ |
| Revenus + historique | ✅ | ✅ | ✅ |
| Documents véhicule | ✅ | ✅ | ✅ |
| Points fidélité | ✅ | ✅ | ✅ |
| Déclaration cash reçu | ✅ | ✅ | ✅ |
| Paiement commission directe | ✅ | ✅ | ✅ |

---

## Garage Admin / Zone Admin

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Dashboard zone/garage | ✅ | ✅ | ✅ |
| Gestion chauffeurs du garage | ✅ | ✅ | ✅ |
| Colis de la zone | ✅ | ✅ | ✅ |
| Rapports d'activité | ✅ | ✅ | ✅ |
| Assignation colis → chauffeur | ✅ | ✅ | ✅ |
| Broadcast groupe garage | ✅ (via `ManualMessagePanel`, scope auto `garageId`) | ✅ `/garage/envoyer-message` | ✅ |

---

## Super Admin

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Gestion utilisateurs (CRUD + rôles) | ✅ | ✅ | ✅ |
| Gestion chauffeurs | ✅ | ✅ | ✅ |
| Gestion colis (recherche globale) | ✅ | ✅ | ✅ |
| Gestion garages/zones | ✅ | ✅ | ✅ |
| Dashboard finance | ✅ | ✅ | ✅ |
| Wallets + transactions | ✅ | ✅ | ✅ |
| Retraits (approbation) | ✅ | ✅ | ✅ |
| Cash declarations (validation) | ✅ | ✅ | ✅ |
| Commissions config | ✅ | ✅ | ✅ |
| Dépenses opérationnelles | ✅ | ✅ | ✅ |
| Config Brevo (email) | ✅ | ✅ | ✅ |
| Config Paydunya | ✅ | ✅ | ✅ |
| Clés API partenaires | ✅ | ✅ | ✅ |
| Vérifications identité (KYC) | ✅ (+ delete + request-info) | ✅ (+ delete + request-info) | ✅ |
| Audit logs | ✅ | ✅ | ✅ |
| Backups | ✅ | ✅ | ✅ |
| Système / health check | ✅ | ✅ | ✅ |
| Broadcasts mass users | ✅ | ✅ | ✅ |
| Réputation + scores + classement | ✅ | ✅ | ✅ |
| Pilot metrics | ✅ | ✅ 2026-11-14 `/admin/pilot-metrics` | ✅ |
| Hub opérationnel | ✅ | ⚠️ à vérifier | ⚠️ |

---

## Support (support, support_technique, support_commercial)

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Inbox support partagée | ✅ | ✅ | ✅ |
| Close conversation avec motif | ✅ reason+category | ✅ 2026-11-14 dropdown + commentaire | ✅ |
| Transfert conversation à agent | ✅ | ✅ | ✅ |
| Présence agents | ✅ | ✅ | ✅ |
| Gestion assistances | ✅ | ✅ | ✅ |
| Tickets techniques | ✅ (tech) | ✅ (tech) | ✅ |
| Leads commerciaux | ✅ (com) | ✅ (com) | ✅ |
| Couverture réseau | ✅ (com) | ✅ (com) | ✅ |
| Qualité de service | ✅ (tech) | ✅ (tech) | ✅ |
| Incidents temps réel | ✅ | ✅ | ✅ |
| **Dashboard SLA cross-tier** | ✅ 4 pills | ✅ 4 pills + moyennes | ✅ 4 pills + moyennes |

---

## Shuttle Operator (opérateur Tata/AFTU/DDD)

**Audit 2026-11-14** — Le rôle `shuttle_operator` a été ajouté en base
(migration `20261117_shuttle_operator_role`) et partage avec le driver 3
endpoints : `POST /advertisements`, `POST /parcels/:id/handovers`,
`POST /parcels/:id/handovers/:handoverId/confirm`. Les lignes de transit
(`TransitLine` + `TransitLineStop`) sont **lecture seule et alimentées par
seed** (`seed-transit.js`). Il n'existe **aucun endpoint de CRUD** pour les
lignes, la flotte ou les horaires. Le statut mobile précédemment ✅ reflétait
l'existence du rôle en base, pas une UI dédiée : ni le mobile ni le web
n'exposent d'écran "Shuttle Operator".

| Fonctionnalité | Mobile | Web | PWA | Dépendance |
|---|---|---|---|---|
| Consultation des lignes de transit (catalogue) | ✅ via `/transit/lines` | ✅ via `TransitLinePicker` + `/transit/lines` | ✅ | — |
| Création d'annonce (voyage) | ✅ écran chauffeur partagé | ✅ écran chauffeur partagé | ✅ | — |
| Handover colis (recevoir / transférer) | ✅ | ✅ 2026-11-14 | ✅ | — |
| Gestion flotte (CRUD véhicules opérateur) | ❌ non livré | ❌ non livré | ❌ | API absente |
| Gestion des horaires (CRUD schedules) | ❌ non livré | ❌ non livré | ❌ | API absente |
| CRUD lignes de transit | ❌ non livré | ❌ non livré | ❌ | API absente (lignes seedées) |

Les lignes "gestion" sont bloquées côté backend : voir `api-pending.md` §9.

---

## Capacités natives — stratégie web/PWA

Capacités mobiles qui demandent un compromis web. Chaque ligne documente
la dégradation acceptée.

| Capacité native | Mobile | Web / PWA | Décision |
|---|---|---|---|
| Caméra (scan QR, photos) | caméra persistante | `getUserMedia` (session) | ↩️ scan fallback saisie manuelle |
| GPS continu arrière-plan | FusedLocation background | 🚫 bloqué par navigateur | 🚫 pas d'équivalent ; drivers restent mobile-only pour le tracking |
| Carnet d'adresses OS | `contacts_service` | 🚫 Contacts API non dispo | 🚫 saisie manuelle + autocomplete carnet serveur |
| Push notifications | FCM | Web Push + VAPID | ✅ livré (`utils/web-push.js` + SW handlers + `useWebPush`) |
| Biométrie | empreinte / Face ID | WebAuthn | ↩️ à évaluer (support Safari + Chrome iOS inconsistant) |
| Enregistrement audio | microphone persistant | `MediaRecorder` session | ↩️ enregistrement en page uniquement, pas en arrière-plan |
| OCR on-device | ML Kit | 🚫 trop coûteux web | ↩️ fallback saisie ou OCR serveur |
| Secure Storage | iOS Keychain / Keystore | ↩️ IndexedDB + crypto.subtle | ↩️ tokens en httpOnly cookie recommandé |
| Share sheet | natif iOS/Android | Web Share API (mobile only) | ↩️ fallback copier le lien |
| Deep links | iOS Universal / Android App Links | URL standard | ✅ cohérent (route-based) |
| File save-as | `path_provider` | `<a download>` + Blob | ✅ équivalent pour PDF/export |

---

## Backlog PWA

État actuel (au 2026-11-14, après chantier P1→P5) : **Web Push + Background
Sync + IndexedDB durable + Badging + splash iOS**. Installable, shell offline,
historique durable, et push temps réel même onglet fermé.

Livrés dans le chantier PWA :

1. ✅ **Web Push + VAPID**
   - Backend : table `push_subscriptions`, `utils/web-push.js` (pont parallèle
     à FCM), endpoints `/notifications/web-push/{public-key,subscribe,unsubscribe}`
   - Service Worker : `push`, `notificationclick`, `notificationclose` handlers
     avec routage data-driven (parcelId, bidId, conversationId)
   - Frontend : `useWebPush()` hook (loading/denied/granted/subscribed/error),
     toggle dans `NotificationPreferences`, bridge SW↔React via
     `PUSH_NOTIFICATION_CLICK` message
   - Dépendance : `web-push@4` (backend). VAPID keys à générer avec
     `npx web-push generate-vapid-keys` et déposer dans `.env`
2. ✅ **Background Sync** (file retryable)
   - IndexedDB `procolis-sync` partagée SW ↔ UI, tag `procolis-sync`
   - Idempotence via `X-Request-Id` (convention projet déjà utilisée)
   - Fallback automatique au retour `online` pour Safari/Firefox (pas de
     SyncManager)
   - Abandon après 10 tentatives pour éviter de bloquer la file sur un
     payload invalide
3. ✅ **IndexedDB pour historique hors ligne durable**
   - `lib/offlineDb.ts` : get/put/delete avec TTL (14j pour l'historique)
   - `OfflineHistoryRecorder` écrit dans **localStorage ET IndexedDB**
     (dual-backend : LS pour la lecture synchrone au boot, IDB pour volume
     + durabilité + quota élargi)
   - Purge liée à la session : `clearOfflineDbForSession()` au logout
4. ✅ **Badging API**
   - Hook `useAppBadge(count)` + wiring automatique via
     `useUnreadNotificationsCount` (feature-detect, aucun fallback nécessaire)
   - Reset à la déconnexion (`clearAppBadge()` dans `authStore.clearSession`)
   - Payload push porte aussi le badge → le SW l'applique même app fermée
5. ✅ **Splash screens iOS**
   - 11 PNG générés par `scripts/generate-ios-splash.mjs` (pur Node, encodeur
     PNG inlined — pas de `sharp`/`jimp` ajouté)
   - `<link rel="apple-touch-startup-image">` par taille d'écran dans
     `index.html`, portrait uniquement (iOS n'applique la splash qu'en portrait)
   - Script `npm run splash` pour régénérer après changement de `theme_color`

Reste à livrer (hors chantier PWA actuel) :

6. **Précache des shells par rôle** (lazy precache post-login)
7. **Capture photo dans le flow livraison** via `<input capture>` ou `getUserMedia`
8. **Web Share Target** (recevoir un tracking number partagé depuis une autre app)

Ce qui NE sera pas livré côté PWA (compromis documenté) :
- GPS continu arrière-plan (impossible navigateur)
- Accès contacts OS (API non standard)
- Scan QR permanent avec notification résultat (session seulement)

---

## Backlog parité web (hors PWA)

Items où le web est en retard fonctionnel sur le mobile — non dépendants
de capacités natives.

| Priorité | Item | Rôle | Impact | Statut |
|---|---|---|---|---|
| P1 | Dashboard SLA cross-tier dans support_admin | support, super_admin | Alignement supervision | ✅ Livré 2026-11-14 |
| P1 | KYC : actions delete + request-info | super_admin | Ergonomie compliance | ✅ Livré 2026-11-14 |
| P2 | Self-service clés API côté business-shipper | client | Autonomie shipper pro | ✅ Livré 2026-11-14 (`/client/api-keys`) |
| P2 | Close conversation avec motif structuré (dropdown resolved/duplicate/spam/no_answer) | support* | Stats et base de connaissance | ✅ Livré 2026-11-14 |
| P2 | Handover colis chauffeur↔chauffeur | driver | Rare mais critique quand utilisé | ✅ Livré 2026-11-14 |
| P3 | Modèles de colis réutilisables (local-only côté mobile, inexistant web) | client | Optionnel | ✅ Livré 2026-11-14 (local-only `localStorage`) |
| P3 | Dashboard pilot metrics | super_admin | Reporting interne | ✅ Livré 2026-11-14 (`/admin/pilot-metrics`) |
| P4 | Broadcast groupe garage (scope auto `garageId`) | admin | Communication interne | ✅ Déjà en prod (`/garage/envoyer-message`, scope backend via `recipientScope`) |

---

## Gouvernance du document

- **Quand éditer** : à chaque livraison d'une nouvelle fonctionnalité
  (mobile OU web), relire la section du rôle concerné. Si la fonction est
  nouvelle, ajouter la ligne. Si elle complète une case ⚠️/❌, passer à ✅.
- **Audit de synchronisation** : chaque trimestre, relancer un audit
  croisé mobile/web via Explore agent (comme la session du 2026-11-14 qui
  a produit ce doc).
- **Lien avec `api-pending.md`** : ce doc couvre la parité **UI/produit**
  entre clients ; `api-pending.md` couvre les **endpoints manquants côté
  serveur**. Une case ❌ ici peut découler d'un endpoint absent — dans ce
  cas, pointer vers l'entrée d'`api-pending.md` correspondante.

Dernière mise à jour : 2026-11-14 (chantier PWA P1→P5 livré : Web Push + VAPID,
Background Sync, IndexedDB durable, Badging API, splash screens iOS).

Dernière mise à jour : 2026-11-14 (audit initial + lot P1–P3 Web livré + audit final P2/P3/P5 clôturé).

## Journal des livraisons

### 2026-11-14 — Mise à niveau fonctionnelle Web

- **KYC super_admin** : actions « Demander un complément » et « Supprimer »
  branchées sur `POST /super-admin/identity-verifications/:id/request-info` et
  `DELETE /super-admin/identity-verifications/:id`. Boutons ajoutés aux lignes
  (desktop + mobile) et à la fiche détaillée, avec dialogues de confirmation
  dédiés (`IdentityVerificationsPage.tsx`).
- **Supervision SLA cross-tier** : composant `SlaCrossTierCard` intégré au
  tableau de bord support partagé ; lit `GET /support-admin/sla-overview`,
  rafraîchi toutes les 60 s, masqué si l'API renvoie 404.
- **Clés API business-shipper** : page `/client/api-keys` accessible depuis la
  nav client ; liste, création (scopes + URL de webhook), rotation et
  désactivation. Secret affiché une seule fois dans une modale dédiée.
- **Modèles de colis** : stockage local par utilisateur
  (`localStorage[parcel_templates.<ownerId>]`) jumeau du mobile. Bouton
  « Mes modèles » dans le wizard `NewParcelScreen`, permet d'enregistrer la
  saisie courante et d'appliquer un modèle existant.

### 2026-11-14 — Audit final de parité (lot P2/P3/P5)

- **Handover chauffeur↔chauffeur** (P2 driver) :
  - `src/lib/api/handovers.ts` (wrappers `initiate/list/confirm/cancel` +
    `HANDOVERABLE_PARCEL_STATUSES`).
  - `features/driver/HandoverInitiateDialog.tsx` — ouvert depuis
    `MissionsScreen` via bouton « Transférer » (visible uniquement si le colis
    est en `picked_up/in_transit/arrived` ET assigné au driver connecté).
    Affiche PIN + jeton QR une seule fois, liste les transferts en attente
    avec action Annuler.
  - `features/driver/HandoverConfirmScreen.tsx` — route
    `/driver/handovers/confirmer`, saisie parcelId + handoverId + PIN + jeton.
  - Entrée « Recevoir un transfert » ajoutée à `DRIVER_NAV`.
- **Clôture support avec motif structuré** (P3 support) :
  - `features/shared/CloseConversationDialog.tsx` — dropdown
    (resolved/duplicate/spam/no_answer) + commentaire optionnel (min 5 chars
    si renseigné, max 2000).
  - `SupportInboxScreen.tsx` passe désormais `{category, reason}` à
    `closeSupportChat`.
- **Dashboard métriques pilote** (P5 super_admin) :
  - `features/superAdmin/PilotMetricsPage.tsx`, route `/admin/pilot-metrics`
    (sous SUPER_NAV > Pilotage). Fenêtre glissante configurable 7/14/30/90
    jours, rafraîchissement 60 s, StatBox (colis, livrés, handovers, arrêts
    GPS, offres acceptées, webhooks, lots, douanes) + panneaux par statut.
- **Rôle ShuttleOperator** (P1) : audit croisé → aucune UI dédiée côté mobile
  non plus, les besoins "flotte/horaires/CRUD lignes" sont bloqués par
  l'absence d'endpoints. Documenté en §9 de `api-pending.md`. Les 3
  endpoints partagés (annonces + handovers) restent couverts par les écrans
  driver.
- **Broadcast garage admin** (P4) : audit → déjà fonctionnel via
  `ManualMessagePanel` monté sous `/garage/envoyer-message` ; le backend
  limite automatiquement les destinataires au `garageId` du compte admin
  (`recipient-scope.js`). Aucune modification nécessaire ; doc remise à jour.
- **Hygiène tests** :
  - `fake-indexeddb/auto` ajouté au setup vitest pour couvrir les flux PWA
    offline.
  - Mock `@/store/auth` complété (expose `subscribe`/`getState`) dans
    `MissionsScreen.test.tsx` pour permettre le chargement du client HTTP.
  - `PwaProvider.test.tsx` enveloppé d'un `QueryClientProvider` pour que
    `InstallPage` → `MarketingFooter` puisse résoudre `usePublicConfig`.
  - Résultat : 281/281 tests verts.
