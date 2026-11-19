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
| Google Sign-In | ✅ | ✅ 2026-11-14 (code + `GOOGLE_WEB_CLIENT_ID` dans `.env` dev API) | ✅ |
| Déverrouillage biométrique | ✅ | ↩️ WebAuthn à évaluer | ↩️ |
| Notifications in-app | ✅ | ✅ | ✅ |
| Notifications push temps réel | ✅ FCM | ✅ Web Push VAPID | ✅ Web Push (SW + badge + routing) |
| Chat support | ✅ | ✅ | ✅ |
| Profil + préférences notifications | ✅ | ✅ | ✅ |
| Pages légales (CGU, confidentialité…) | ✅ | ✅ | ✅ |
| Localisation (fr / en / wo) | ✅ 3 locales | ✅ 2026-11-14 i18next + 3 locales (shell nav + settings + language picker) ; écrans métier historiques en fr littéral — migration progressive | ✅ |
| Mode sombre | ✅ | ✅ 2026-11-14 (audit) — toggle `SettingsScreen` + `[data-theme=dark]` | ✅ |
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
| Import CSV bulk | ✅ bulk-create | ✅ 2026-11-14 (`CsvBulkImportDialog` dans `/client/outils`) | ✅ |
| Modèles de colis (templates) | ✅ local-only | ✅ local-only (`localStorage`) | ✅ local-only |
| Self-service clés API | ✅ `/business/api-keys` | ✅ `/client/api-keys` | ✅ |
| Carnet d'adresses enregistré | ✅ | ✅ | ✅ |
| Dettes client / soldes dus | ✅ | ✅ | ✅ |
| Public tracking (sans login) | N/A | ✅ | ✅ |
| Fiches publiques drivers | ✅ | ✅ | ✅ |
| Assistant IA (création colis via NL) | ✅ 2026-11-19 (chat + voix, dégrisé via `/ai/assistant/config`) | ✅ 2026-11-19 `/client/assistant` (chat + voix MediaRecorder, draft → wizard via sessionStorage) | ✅ |

---

## Driver / Chauffeur

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Dashboard chauffeur | ✅ | ✅ | ✅ |
| Toggle disponibilité | ✅ | ✅ | ✅ |
| Création d'annonces / voyages | ✅ | ✅ | ✅ |
| Import de routes (fichier) | ✅ | ✅ 2026-11-14 (nav `Importer des trajets` → `#route-import` ouvre `RouteCsvImport`) | ✅ |
| Catalogue colis libres | ✅ | ✅ | ✅ |
| Proposer offre + négociation chat | ✅ | ✅ | ✅ |
| Confirmation ramassage (scan QR + photo) | ✅ | ↩️ photo via file input | ↩️ |
| GPS continu partage position | ✅ background | 🚫 impossible web | 🚫 |
| Carte itinéraire client | ✅ | ✅ | ✅ |
| Confirmation livraison (signature + photo) | ✅ photo | ✅ 2026-11-14 photo via `<input capture="environment">` + upload `/uploads/parcel-photo` ; signature canvas reste ↩️ | ✅ |
| Manifeste navette (shuttle) | ✅ | ✅ 2026-11-14 (`AdvertisementManifestScreen` route `/driver/annonces/:id/manifest`) | ✅ |
| Handover colis chauffeur→chauffeur | ✅ | ✅ 2026-11-14 | ✅ |
| Arrêts atteints / tracking intermédiaire | ✅ | ✅ 2026-11-14 (`AdvertisementReachedStopsScreen` route `/driver/annonces/:id/arrets-atteints`) | ✅ |
| Suggestions backhaul (colis compatibles sur route) | ✅ 2026-11-19 `backhaul_suggestions_screen` (bouton « Suggestions de colis » sur chaque annonce ouverte) | ✅ 2026-11-19 `BackhaulSuggestionsDialog` (bouton « Suggestions » sur chaque annonce ouverte, proposer offre inline) | ✅ |
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
| Hub opérationnel | ✅ | ✅ 2026-11-14 `/admin/operations` (4 onglets : intégrations, webhooks récents, arrêts GPS, transferts) | ✅ |
| Fraude — scores + alertes persistées | ✅ 2026-11-19 6ᵉ onglet `admin_operations_hub_screen` (SegmentedButton scores/ouvertes/résolues, bouton rafraîchir, dialog résolution) | ✅ 2026-11-19 5ᵉ tab `/admin/operations` (scores live, alertes ouvertes/résolues, dialog résolution) | ✅ |

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
| Gestion flotte (CRUD véhicules opérateur) | ❌ non livré | ✅ 2026-11-14 `/shuttle/vehicules` | ✅ | API livrée |
| Gestion des horaires (CRUD schedules) | ❌ non livré | ✅ 2026-11-14 `/shuttle/horaires` | ✅ | API livrée |
| CRUD lignes de transit | ❌ non livré | ✅ 2026-11-14 `/shuttle/lignes` | ✅ | API livrée |
| Dashboard overview opérateur | ❌ non livré | ✅ 2026-11-14 `/shuttle` (overview) | ✅ | — |

API `/shuttle-operator/*` livrée : lignes (CRUD atomique avec stops), flotte
(CRUD + soft delete sur `deletedAt`), horaires (CRUD avec validation HH:MM
et jours 0-6), overview (compteurs). Migration SQL
`20261122000000_shuttle_operator_crud`. RBAC : `shuttle_operator` uniquement,
ownership isolée (404 sur ressource d'un autre opérateur, pas 403, pour ne
pas divulguer l'existence). Mobile : pas d'UI — l'opérateur passe par le web
(écrans desktop-first, saisie formulaire riche).

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

6. ✅ **Précache des shells par rôle** — livré 2026-11-14 : `features/pwa/precacheByRole.ts` déclenche les `import()` dynamiques des écrans du rôle courant via `requestIdleCallback` après connexion. Le SW capture au vol les bundles `/assets/*-hash.{js,css}` → la navigation hors ligne fonctionne pour toutes les pages du rôle, pas seulement celles déjà visitées. Branché depuis `PwaProvider` sur `useAuthStore(user.role, sessionId)`.
7. ✅ **Capture photo dans le flow livraison** — livré 2026-11-14 : fix API
   `driverDeliver` (`signature→signatureUrl`, `proofImage→photoUrl` dans
   `changeParcelStatus`) + bouton « Ajouter une photo (optionnel) » dans
   `ConfirmDeliveryScreen` qui utilise
   `<input type="file" accept="image/*" capture="environment">` et upload
   via `uploadParcelPhoto` avant l'OTP. Côté mobile,
   `DeliveryProofScreen._submit` reste un `Navigator.pop` — à câbler lors
   d'un futur chantier mobile.
8. ✅ **Web Share Target** — livré 2026-11-14 : `share_target` dans `manifest.webmanifest`, handler `extractTrackingFromShared` dans `SuiviScreen` extrait les tokens `PC-XXXX-XXXX` depuis `title/text/url`

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

Dernière mise à jour : 2026-11-19 (clôture parité stricte — Assistant IA web/pwa, UI backhaul driver sur mobile + web, onglet Fraude mobile).

## Journal des livraisons

### 2026-11-19 — Clôture parité stricte (Assistant IA web/pwa, backhaul UI, fraude mobile)

Suite à une consigne explicite « tout ce qui est au mobile doit être identique et
implémenté sur le web et pwa » : les 3 items encore ❌ laissés en « mobile-only »
ou « web-only » par choix produit sont livrés. Zéro régression, pas d'API nouvelle.

**Assistant IA Web/PWA** (client) :
- API wrapper `src/lib/api/ai-assistant.ts` : `askAssistant`, `transcribeAudio`,
  `isAssistantConfigured`. Fallback silencieux sur erreur réseau (parité mobile).
- Écran `src/features/shared/AiAssistantScreen.tsx` route `/client/assistant` :
  chat vertical (bulles), enregistrement vocal via `MediaRecorder` (upload
  `/upload` → `/ai/assistant/transcribe`), action « Pré-remplir le formulaire »
  quand `intent=create_parcel`, action « Suivre » quand `intent=track_parcel`.
- Persistance du draft via `src/features/shared/aiDraftStore.ts`
  (sessionStorage, usage unique). `NewParcelScreen` consomme le draft au mount
  si `?from=ai` et applique receiverName/Phone, weight, type, isUrgent,
  description/notes, et matche senderCity/receiverCity contre les zones chargées.
- CTA depuis `ClientDashboard` (nouvelle tuile violette « Assistant IA »).
- Précache rôle `client` étendu (`features/pwa/precacheByRole.ts`).

**UI Backhaul suggestions** (driver web + mobile) :
- Web : wrapper `src/lib/api/consolidation.ts` + `BackhaulSuggestionsDialog`
  intégré dans `MesAnnoncesScreen` (bouton « Suggestions » sur chaque annonce
  ouverte). Liste triée par score, badges score/détour, action « Proposer une
  offre » inline avec input prix → `POST /driver/bids`. Section rejetés
  dépliable avec libellés UX (`BACKHAUL_REASON_LABELS`).
- Mobile : wrapper `lib/services/api/consolidation_api.dart` +
  `backhaul_suggestions_screen.dart` (plein écran, même UX : liste triée,
  cards avec score/détour/poids/prix, dialog de prix, SnackBar feedback).
  Bouton « Suggestions de colis » ajouté à `_buildAdCard` dans
  `mes_annonces_screen.dart` (visible uniquement si annonce ouverte).

**Fraude UI Mobile** (super_admin) :
- Wrapper `lib/services/api/fraud_api.dart` (scores, alertes, résolution,
  refresh).
- 6ᵉ onglet « Fraude » ajouté à `admin_operations_hub_screen.dart` :
  `SegmentedButton` Scores / Alertes ouvertes / Résolues, bouton
  « Rafraîchir les alertes » (icône toolbar), dialog résolution avec TextField
  multiline (max 2000 chars). Code couleur par niveau (high red, medium/low
  amber, safe slate).

**Vérifications** : `npm run typecheck` web OK, `npm run lint` web OK
(seulement warnings pré-existants), `flutter analyze` 0 issues sur fichiers
modifiés. Tests web non impactés — les 2 échecs sur `experience.test.tsx`
existaient avant ce chantier (indépendants).

**Reste hors-code** (inchangé depuis 2026-11-19) :
- Poser `ANTHROPIC_API_KEY` en `.env` prod pour que l'Assistant IA se dégrise
  côté web comme côté mobile.
- Appliquer la migration `20261124_fraud_alerts` (`npx prisma migrate deploy`
  avec backup).

### 2026-11-19 — Assistant IA mobile + consolidation backhaul + fraude admin

Trois chantiers livrés en parallèle, plus de ⚠️ sauf nouveaux items (Assistant
IA web/pwa, UI backhaul, UI fraude mobile) qui restent ❌ par choix produit.

**Assistant IA mobile** (client + business_shipper) :
- API : `GET /ai/assistant/config` → `{ configured: bool }` basé sur
  `isAiAssistantConfigured()`. Le frontend consulte ce flag avant de dégriser.
- Mobile : `AiAssistantApi.isConfigured()` + `aiAssistantConfiguredProvider`
  (FutureProvider.autoDispose + keepAlive). Deux CTAs basculent via `Consumer`
  local :
  - `new_parcel_wizard_screen` : IconButton actif ; au retour d'`AiAssistantScreen`,
    `_openAiAssistant` applique le draft (receiverName/Phone, weight, type,
    isUrgent, notes, senderCity→zoneId, receiverCity→zoneId).
  - `client_dashboard` : OutlinedButton navigue vers l'écran ; badge « Bientôt »
    retiré quand configured.
- Fallback silencieux : erreur réseau ou `configured=false` → UI reste grisée.
- Web / PWA : pas d'écran dédié — l'Assistant IA reste mobile-only pour la V1
  (interaction conversationnelle + voix mieux servie sur mobile ; le web a déjà
  wizard + import CSV + templates).

**Consolidation backhaul** (driver / shuttle_operator) :
- API : `GET /drivers/backhaul-matches/:advertisementId` dans un nouveau module
  `src/modules/consolidation/`. Consomme `matchCompatibleParcels()` pur sur les
  colis `pending`/`free` ≤14j. Capacité restante = `availableWeight - Σ(weight
  des offres acceptées non annulées/livrées)`. RBAC `driver` ou `shuttle_operator`,
  ownership vérifiée.
- 5 tests contractuels (401, 403 client, 403 driver tiers, 404, 200 avec tri).
- Pas d'UI mobile ni web — le service est disponible pour quand une surface
  « suggestions de colis à adopter » sera ajoutée aux dashboards drivers.

**Fraude — scores + alertes persistées** (super_admin) :
- API : nouveau modèle `FraudAlert` + migration `20261124_fraud_alerts`
  (IF NOT EXISTS, FK via DO $$ idempotent). Service `buildSignalsForUser`
  agrège 6 signaux via Prisma (âge compte, ratio annulations, dette via
  `ClientPenaltyDebt`, OTP échouées heuristique, devices via `DeviceToken`,
  annulations récentes), combine avec `scoreFraud()` → score+flags+level.
  `refreshFraudAlerts()` scanne les users actifs 30j et crée/déduplique.
- 4 endpoints super_admin : `GET /super-admin/fraud/scores?limit=50&level=`,
  `GET /super-admin/fraud/alerts?status=`, `POST /super-admin/fraud/alerts/:id/resolve`,
  `POST /super-admin/fraud/refresh`.
- 5 tests contractuels.
- Web : 5ᵉ tab « Fraude » dans `OperationsHubPage` (`/admin/operations`).
  SegmentedControl Scores / Alertes ouvertes / Alertes résolues, bouton
  « Rafraîchir les alertes » global, dialog Textarea de résolution.
- Mobile : pas d'UI — l'écran `AdminOperationsHubScreen` mobile reste à 5
  onglets (Pilot 14j, Health, Webhooks, Stop events, Handovers) ; la fraude
  est volontairement laissée desktop-first (tableaux riches, traitement en
  lot plus ergonomique en desktop).

**Vérifications** : `node --check` sur tous les fichiers API, `npx prisma
generate` OK, `flutter analyze` 0 issue, `npm run typecheck` web OK. Tests API
non re-exécutés en local post-merge (DB procolis dans un container sans
bind-mount du code source — à valider en CI).

**Reste hors-code** : poser `ANTHROPIC_API_KEY` en `.env` prod pour que le flag
Assistant IA passe à `true` en live ; appliquer la migration
`20261124_fraud_alerts` via `npx prisma migrate deploy` avec sauvegarde
préalable.

**Externalisation config (addendum même jour)** : tous les knobs de policy des
3 chantiers sont désormais pilotables depuis l'espace super-admin
(`/admin/finance/configuration`, panneau « Paramètres système »), sans
redéploiement :
- Assistant IA : `ai.enabled` (kill-switch), `ai.maxPromptChars`,
  `ai.maxOutputTokens`, `ai.model`, `ai.systemPrompt`.
- Consolidation : `consolidation.enabled`, `consolidation.onRouteToleranceKm`,
  `consolidation.parcelLookbackDays`, `consolidation.parcelLimit`,
  `consolidation.rejectedPreviewLimit`, `consolidation.weightPickupDistance`,
  `consolidation.weightDropoffDistance`, `consolidation.weightWeightFit`,
  `consolidation.adoptableStatuses`.
- Fraude : `fraud.enabled`, `fraud.activeLookbackDays`, 5 seuils (new account,
  cancellation ratio, OTP, multi-devices, recent cancellations), 6 pondérations
  de points, 3 seuils de niveau (low/medium/high).

Pattern backend : 3 readers (`ai-assistant-config.js`, `consolidation-config.js`,
`fraud-config.js`) suivant le pattern `anomaly-config.js` (cache 10 s + fallback
sur defaults + invalidation par prefix dans `updateSystemConfig`). Valeurs
invalides en base silencieusement ignorées au profit du défaut.

### 2026-11-14 — Chantier parité mission (lot ⚠️→✅)

### 2026-11-14 — Chantier parité mission (lot ⚠️→✅)

Clôture des items encore marqués ⚠️ dans la matrice après audit croisé des 4
codebases par 5 agents parallèles. Changements Web uniquement, additifs, sans
toucher à l'API.

- **Import CSV bulk client** : `CsvBulkImportDialog` + wrapper
  `parcels.bulkCreate()` (`POST /client/parcels/bulk-create`) câblé depuis
  `WorkspaceScreen` (`/client/outils`). Parsing CSV séparateur `;`, header
  toléré, validation ligne-par-ligne, rapport succès/échec ordonné, fallback
  séquentiel si endpoint 404. Jumelle `csv_bulk_import_sheet.dart` côté mobile.
- **Manifeste navette** : `AdvertisementManifestScreen` sur
  `/driver/annonces/:advertisementId/manifest` + wrapper
  `advertisements.fetchManifest()`. Boutons d'entrée ajoutés à `AdCard` dans
  `MesAnnoncesScreen` (visibles si l'annonce a des arrêts).
- **Arrêts atteints** : `AdvertisementReachedStopsScreen` sur
  `/driver/annonces/:advertisementId/arrets-atteints` + wrapper
  `advertisements.fetchReachedStops()`.
- **Hub opérationnel super_admin** : `OperationsHubPage` sur
  `/admin/operations` avec 4 onglets (Intégrations, Webhooks récents, Arrêts
  GPS récents, Transferts récents). Nouveau wrapper `lib/api/admin-operations.ts`
  couvrant `GET /health/integrations`, `/super-admin/webhooks/recent`,
  `/super-admin/stop-events/recent`, `/super-admin/handovers/recent`. Entrée
  nav « Hub opérationnel » ajoutée dans la section Supervision.
- **Import routes driver** : entrée nav « Importer des trajets » qui pointe
  vers `/driver/annonces#route-import` ; `RouteCsvImport` s'ouvre
  automatiquement si le hash est présent. Label du summary renommé
  « Importer mes trajets (CSV) » pour la découvrabilité.

**Audits confirmant un ✅ (pas de code requis)** :
- Mode sombre web : toggle fonctionnel dans `SettingsScreen`, CSS
  `[data-theme="dark"]` dans `ds/tokens/colors.css`, persistance
  `localStorage.procolis-theme`, respect `prefers-color-scheme`.

**Audits qui restent ⚠️ (décisions explicites non livrées dans ce chantier)** :
- Google Sign-In web : code 100 % identique au mobile (`idToken` envoyé,
  même endpoint `/auth/google`). Seul gap : `GOOGLE_WEB_CLIENT_ID` vide dans
  `.env` prod. Action : valoriser l'env côté infra, pas de patch code.
- Localisation `wo` (wolof) web : aucun framework i18n installé, strings
  françaises codées en dur. Introduction d'un pipeline i18n (extraction
  ~2000+ chaînes, i18next ou équivalent) = chantier dédié, hors scope parité
  additive.

**Audit vérifié ✅ dans la matrice** : Routes import endpoint identique au
mobile (`POST /driver/route-templates/import{,/preview}`) ; le seul écart
était la découvrabilité, corrigé par nav + hash anchor.

### 2026-11-14 — Shuttle Operator CRUD (dernier item bloquant clôturé)

Dernier ❌ de la matrice ; la section « Shuttle Operator » passe en ✅.

**API** (`sendprocolis-api`) :
- Migration SQL `20261122000000_shuttle_operator_crud` :
  - `transit_lines.operator_user_id UUID NULL FK users ON DELETE SET NULL` →
    les lignes seedées publiques restent avec operator null, non modifiables
    depuis l'espace opérateur.
  - Nouvelles tables `shuttle_vehicles` (plaque unique par opérateur, soft
    delete via `deleted_at`) et `shuttle_schedules` (jours 0-6, HH:MM,
    plage activeFrom/activeUntil).
- Module `src/modules/shuttle/` : routes + controllers.
  - 13 endpoints : overview + CRUD lignes + CRUD vehicles + CRUD schedules.
  - RBAC `shuttle_operator` sur le routeur entier.
  - Ownership strict : chaque handler filtre par `operatorUserId = req.user.id`,
    404 (pas 403) sur ressource d'un autre opérateur.
- Tests `tests/shuttle-operator.test.js` (5 cas) : RBAC, isolation ownership,
  unicité plaque par opérateur, validation HH:MM, cascade delete.

**Web** (`sendprocolis-web`) :
- Wrapper `src/lib/api/shuttle-operator.ts` (overview, lines, vehicles,
  schedules) + types `ShuttleLine`, `ShuttleVehicle`, `ShuttleSchedule`.
- Nouvel espace `/shuttle` avec RBAC guard `shuttle_operator`.
  - `ShuttleOverviewPage` — compteurs rafraîchis 60 s.
  - `ShuttleLinesPage` — CRUD atomique avec composition d'arrêts (min 2).
  - `ShuttleVehiclesPage` — CRUD + soft delete, tableau filtré.
  - `ShuttleSchedulesPage` — toggles jours de la semaine, dates actives.
- Nav SHUTTLE_NAV ajoutée, redirection `ROLE_HOME.shuttle_operator = /shuttle`.
- Précache par rôle étendu aux 4 écrans.
- Types `Role` et toutes les cartes `Record<Role, string>` étendus à
  `shuttle_operator`.

**Mobile** : hors scope (aucune UI à migrer — pas de régression). Le mobile
reste cantonné aux endpoints partagés avec driver (annonces + handovers).

### 2026-11-14 — Validation finale, clôture de la parité

**Correctif fonctionnel** :
- `DeliveryProofScreen._submit` (mobile) ne faisait qu'un `Navigator.pop`
  silencieux : aucune preuve n'atteignait le serveur. Implémenté :
  - Nouvel endpoint API `POST /driver/parcels/:parcelId/proof`
    (`driverAttachDeliveryProof` dans `mobile.controller.js`). Guards :
    statut `delivered` + driver assigné. Persiste `signatureUrl`, crée un
    `parcelEvent` traçable + attache `ParcelMedia` via `saveMedia`.
    Idempotent par `requestId`.
  - Mobile `ApiService.submitDeliveryProof(...)` wrapper + câblage complet
    dans `_DeliveryProofScreenState._submit` : upload photo via
    `/upload`, consolidation note + signature, feedback utilisateur
    (SnackBar + état d'erreur inline), état `_submitting` qui bloque le
    double-tap. Si l'utilisateur ferme sans remplir, pop silencieux.

**Décision produit — Shuttle Operator / Mobile** :
- Les opérations de gestion (CRUD lignes / flotte / horaires) restent
  **web-only** par décision produit : il s'agit d'opérations
  administratives *desktop-first* (formulaires riches avec composition
  d'arrêts, tableaux de flotte, édition de plages de dates). Ce n'est pas
  un oubli.
- Les chauffeurs qui travaillent *pour* un opérateur continuent à utiliser
  l'app driver mobile sans changement (annonces, missions, handovers).
- Le rôle `shuttle_operator` existe côté mobile uniquement comme cible
  dans l'écran super-admin de promotion.

**Audit déploiement** :
- Migration `20261122000000_shuttle_operator_crud` présente, non appliquée
  (DB injoignable depuis l'environnement d'édition — normal). À appliquer
  via `npx prisma migrate deploy` sur dev + prod avec sauvegarde préalable.
- `GOOGLE_WEB_CLIENT_ID` valorisée en `.env` dev API ; prod = responsabilité
  ops (valeur non secrète mais hors scope édition).
- OAuth : mobile `google_auth_service.dart` lit `serverClientId` (aligné),
  web `GoogleAuth` lit `/auth/google/config` (aligné), API vérifie l'audience
  `GOOGLE_WEB_CLIENT_ID` (unique client ID).

**Audit capacités natives — fallbacks confirmés** :
- Photo via `<input type="file" capture="environment">` → upload
  `/uploads/parcel-photo`.
- Audio session via `MediaRecorder` (VoiceRecorder, chat, note vocale).
- Share sheet → `navigator.clipboard.writeText` par défaut.
- Scan QR → saisie manuelle UUID avec regex validation.
- Contacts OS → carnet serveur `/experience/recipients` + autocomplete.
- Secure storage → `offlineDb.ts` IndexedDB + zustand persist.
- FCM → Web Push VAPID (livré).
- Biométrie → fallback = PIN existant (WebAuthn documenté à évaluer).
- OCR, GPS background, Contacts API → 🚫 impossibilités absolues du
  navigateur, pas des gaps.

**Tests finaux exécutés** :
- API : `node --check` syntaxe OK sur controllers + routes modifiés. Suite
  d'intégration non exécutée (DB injoignable localement).
- Web : `npm run typecheck` ✅ · `npm run lint` ✅ (10 warnings pré-existants,
  aucun nouveau) · `npm test` **281/281** ✅ · `npm run build` ✅ 1.6 s.
- Mobile : `flutter analyze` sur les fichiers modifiés ✅ 0 issues.

**Parcours métier vérifiés statiquement** (pas de staging accessible) :
authentification, création de colis, livraison, preuve, suivi, paiement,
notifications — chaînes d'appels tracées depuis les screens → API, pas de
reference cassée ni d'endpoint manquant.

### 2026-11-14 — Vérification finale « ce qui reste »

Après re-lecture complète de la matrice et croisement avec les mobiles, les
items non ✅ encore ouverts se répartissent ainsi :

**Fermés dans ce complément** :
- **Web Share Target (PWA #8)** : `share_target` ajouté au
  `manifest.webmanifest` (action `/track`, méthode `GET`, params
  `title/text/url`). `SuiviScreen` extrait un token `PC-XXXX-XXXX` depuis
  ces trois paramètres via une regex et renseigne la recherche
  automatiquement. Aucun endpoint nouveau.

**Fermé dans ce complément (suite)** :
- **Précache PWA par rôle (PWA #6)** : `precacheByRole.ts` + hook dans
  `PwaProvider`. Déclenche en `requestIdleCallback` les `import()` dynamiques
  des écrans du rôle dès que `user.role` + `sessionId` sont présents.
  Mémorisation par clé `${role}:${sessionId}` pour éviter les re-précache
  après refetch du profil. Erreurs silencieuses — un échec de précache ne
  casse pas l'UX.

**Fermés dans ce lot final** :
- **Google Sign-In (shared)** : `GOOGLE_WEB_CLIENT_ID` ajouté au `.env` API
  local depuis `.env.example` (gitignored). Le composant web `GoogleAuth` lit
  `/auth/google/config` et bascule `enabled: true` dès que l'env est valorisée.
  Pour la prod : l'ops team doit faire de même (variable non secrète, c'est
  un client ID OAuth public).
- **Localisation i18n framework** : `i18next` + `react-i18next` +
  `i18next-browser-languagedetector` installés. 3 locales créées dans
  `src/i18n/locales/{fr,en,wo}.ts` couvrant `common`, `settings`, `nav`.
  Picker de langue ajouté dans `SettingsScreen`. Détection localStorage →
  navigator, synchro automatique de `<html lang>`. Les écrans métier
  historiques restent en français littéral — leur migration progressive se
  fera en remplaçant les littéraux par `t('…')` au fil des touches.
- **Capture photo livraison (PWA #7)** :
  - **API** : `driverDeliver` corrigé pour traduire `signature`→`signatureUrl`
    et `proofImage`→`photoUrl` avant de passer à `changeParcelStatus`. Avant
    ce fix, ces fichiers étaient silencieusement perdus (mapping incohérent,
    code mort depuis l'introduction du module).
  - **Web** : `ConfirmDeliveryScreen` offre désormais un bouton
    « Ajouter une photo (optionnel) » qui utilise
    `<input type="file" accept="image/*" capture="environment">` + upload
    `uploadParcelPhoto(…)` → inclusion de l'URL dans `proofImage` du payload
    `driverDeliver`.
  - **Mobile** : `DeliveryProofScreen._submit` reste à câbler (dead
    `Navigator.pop`) — à faire dans un futur chantier mobile.
  - La signature canvas reste ↩️ (compromis UX documenté, pas de besoin
    bloquant identifié).

**↩️ fallbacks documentés (pas d'action attendue)** :
- Biométrie WebAuthn (support iOS inconsistant)
- Caméra scan QR persistante (session-only via `getUserMedia`)
- Share sheet (Web Share API mobile only)
- Enregistrement audio (session MediaRecorder uniquement)
- Signature canvas livraison (compromis accepté)
- Secure Storage (IndexedDB + crypto.subtle)
- OCR on-device (coûteux côté web)

**🚫 non applicable** :
- GPS continu arrière-plan
- Carnet d'adresses OS

**❌ bloqué côté API** (voir `api-pending.md` §9) :
- Shuttle Operator : CRUD flotte / horaires / lignes de transit

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
