# Synchronisation Web ↔ Mobile — spécification d'exécution

> Statut : implémentation terminée, validation manuelle restante · Créé le 2026-07-26
> Portée : alignement de l'application Flutter sur l'application web, correction du contrat de données contre l'API, et construction du domaine « paiement espèces » de bout en bout.

---

## 1. Contexte

Trois dépôts composent le produit :

| Rôle | Chemin | Stack |
|---|---|---|
| **Web** — référence UX / pages | `/Volumes/Oracle/Web/ProColis-Web` | React 19 + Vite + TS, react-router 7, TanStack Query, zustand |
| **API** — référence contrat de données | `/Volumes/Oracle/Web/ProColis-Api` | Node/Express + Prisma/PostgreSQL |
| **Mobile** — à aligner | `/Volumes/Oracle/Mobile/ProColis` | Flutter, go_router, Riverpod, Dio |

Le web est plus avancé sur les pages, la navigation et la couverture d'endpoints ; le mobile a dérivé. Cette dérive produit des **bugs silencieux** : des enums qui ne correspondent jamais à la réponse serveur, des statistiques fabriquées côté client alors que l'endpoint existe, des écrans morts, et une fonctionnalité entière qui appelle des routes inexistantes.

### Hiérarchie de référence

Elle n'est **pas uniforme**, et c'est le point le plus important de cette spec :

- **Pages, navigation, découpage des espaces par rôle → le web fait foi.**
- **Enums, noms de champs, formes de réponse → l'API / Prisma fait foi**, y compris contre le web (voir §9 : le web se trompe sur `PaymentMethod`).

### Méthode

Comparaison des arbres de travail, pas des derniers commits — les trois dépôts ont du travail non commité (mobile 72 fichiers, web 33, api 19).

---

## 2. Tableau de synthèse des écarts

| # | Écart | Impact | Lot |
|---|---|---|---|
| 1 | `WalletTransactionType` en MAJUSCULES côté mobile, l'API écrit en minuscules | **Aucune** transaction de portefeuille correctement typée | WS1 |
| 2 | `Zone.radius` : l'API sérialise des **km**, le mobile déclarait `int` avec défaut `5000` (mètres) | Rayon faux d'un facteur 1000 + troncature des décimales | WS1 |
| 3 | Rôle `support` absent de `UserRole`, mappé vers `superAdmin` | Un compte support obtenait l'UI super-admin complète | WS1 |
| 4 | `NotificationType` mobile connaît 4 valeurs sur ~34 réellement émises | Quasi-totalité des notifications retombe sur `info` | WS1 |
| 5 | `toJson` en snake_case sur `Bid`, `Notification`, `Garage`, `Zone` | Champs silencieusement ignorés à l'écriture | WS1 |
| 6 | Stats de profil fabriquées par `RoleMockData` alors que les endpoints existent | Chiffres inventés affichés en production, tous rôles | WS3 |
| 7 | Carnet d'adresses + garages favoris absents du mobile | Fonctionnalité web entière manquante | WS3 |
| 8 | Écran config admin : 13 clés sur 27 | Seuils de score, plafonds de retrait, règle de commission, PayDunya disburse non pilotables | WS4 |
| 9 | Routes manquantes / non deep-linkables / écrans morts | Navigation divergente, code mort | WS2 |
| 10 | `clientParcels` ignore le filtre expéditeur/destinataire | « Mes colis reçus » cassé sur **les deux** clients | WS6 |
| 11 | Paiement espèces : 6 endpoints appelés, 0 implémenté | Fonctionnalité non fonctionnelle de bout en bout | WS5 |

---

## 3. WS1 — Contrat de données mobile

Corrige des bugs silencieux : aucune UI ne signale ces erreurs aujourd'hui.

### 1.1 `WalletTransactionType` — `lib/models/wallet.dart` ✅

Les valeurs de transport étaient en majuscules (`'DEPOSIT'`, `'COMMISSION'`…). L'API écrit en minuscules (`ProColis-Api/src/modules/admin-finance.controller.js:124,128,215-216`) et l'enum Prisma est `deposit, commission, bonus, adjustment, refund, correction, penalty, withdrawal`.

**Fait** — valeurs passées en minuscules, ajout des trois manquantes (`correction`, `penalty`, `withdrawal`), ordre aligné sur Prisma, `fromString` normalise désormais la casse.

### 1.2 `Zone.radius` → `Zone.radiusKm` — `lib/models/zone.dart` ✅

`serializeZone` (`src/modules/zones/zone.controller.js:97-98`) émet `radius` **et** `radiusKm`, tous deux dérivés de `zones.radius_km` — donc en kilomètres, avec `DEFAULT_RADIUS_KM = 30`. Le mobile déclarait `final int radius = 5000` et le renvoyait en écriture.

**Fait :**
- `double radiusKm`, défaut `kDefaultZoneRadiusKm = 30` exporté par le modèle.
- Lecture `radiusKm` avec repli sur `radius`.
- Ajout du champ `region` (accepté par `zonePayload`, absent du modèle).
- `toJson` passé en camelCase (voir 1.5).
- Consommateurs corrigés dans `lib/screens/super-admin/zones_management_screen.dart` : libellé « Rayon (km) », défaut `30`, parsing `double`, payload `radiusKm`.
- Transmission de `placeId` à la création : `zones.place_id` est unique côté API, ce qui rend la création idempotente pour un même lieu Google.

### 1.3 Rôle `support` — `lib/models/user.dart` / `lib/providers/auth_provider.dart` ✅

`UserRole.fromString` mappait explicitement `'support'` → `superAdmin`. Or `support` est un rôle à part entière dans l'enum Prisma `UserRole`, et le web lui donne l'espace `/support-admin` (`ProColis-Web/src/routes/paths.ts`, `ROLE_HOME`), pas `/admin`.

**Fait :**
- `support('support', 'Support', …)` ajouté à l'enum.
- Mapping spécial retiré de `fromString`.
- `profileEndpoint` → `/super-admin/profile` et `apiScope` → `super-admin` (l'API autorise `super_admin` **et** `support` sur ces routes).
- `isSupportShared` ajouté ; `isSupport` élargi aux trois rôles support, équivalent de `SUPPORT_ROLES` côté web.

**Fait également :**
- `isSupportShared` / `isSupport` répercutés sur `AuthState`.
- Cas `support` traité dans le `switch (user.role)` exhaustif de `dashboard_screen.dart`.
- Identité visuelle, navigation basse et ton de la gestion des utilisateurs ajoutés.

> Le web durcit en plus deux identifiants de comptes support (`ProColis-Web/src/lib/support.ts`, `SUPPORT_USER_IDS` + `SupportAdminRedirect`). **Ne pas reproduire ce contournement** : le rôle suffit une fois l'enum corrigé.

### 1.4 Vocabulaire des notifications — `lib/models/notification.dart` ✅

`Notification.type` est une `String` libre côté Prisma, écrite par `notify()` / `notifyAdmins()` (`src/modules/mobile/mobile.controller.js:121,222`). Vocabulaire réellement émis, extrait de l'API (~34 valeurs) :

```
bid_created, bid_accepted, ad_offer, ad_offer_accepted, ad_offer_rejected,
parcel_delivered, driver_assigned, delivery_completed, delivery_paid,
payment_confirmed, payment_cash, message, support_reply, pin_reset,
deposit, commission, commission_paid, commission_deduction,
commitment_fee, commitment_refund, purchase, refund, score_credited,
wallet_recharged, wallet_debited, withdrawal, withdrawal_requested,
withdrawal_completed, withdrawal_failed, withdrawal_cancelled,
admin_credit, admin_debit, admin_driver_credited, admin_payment_confirmed
```

Le mobile n'en connaît que 4 (`bid_created`, `bid_accepted`, `driver_assigned`, `message`) ; tout le reste retombe sur `info`.

**Fait :** enum étendu à tout ce vocabulaire avec libellé / icône / couleur par famille (offre, colis, paiement, portefeuille, retrait, admin), en conservant `info` comme repli. Les anciennes valeurs mobiles restent lisibles pour les caches existants.

> **Ne pas prendre `NotificationEventType` du web comme source** (`ProColis-Web/src/lib/notifications/index.ts`) : c'est un catalogue de gabarits Brevo côté client, sans recouvrement avec les types réellement stockés.

### 1.5 Sérialisation asymétrique ✅

`Bid`, `Notification`, `Garage`, `Zone` lisent en camelCase **et** snake_case mais **écrivent en snake_case**, alors que les validateurs et sérialiseurs de l'API sont en camelCase (`src/utils/mobile-serializers.js`). Les clés snake_case sont silencieusement écartées par `cleanUndefined`.

- `Zone.toJson` ✅ corrigé.
- `Bid`, `Notification`, `Garage` ✅ écrivent désormais en camelCase. Les tests de round-trip vérifient l'absence des anciennes clés snake_case.

### 1.6 Source unique pour les bandeaux ✅

`lib/services/broadcast_service.dart` lit `GET /public/broadcasts` ; `lib/providers/broadcast_provider.dart` lit `GET /super-admin/config`. Deux sources pour la même donnée.

**Fait :**
- Lecture via `/public/broadcasts` et écriture via `PUT /super-admin/config` `{broadcasts}` ; provider et écran admin partagent `BroadcastService`.
- `startsAt` / `endsAt` sont des `DateTime?` et `filterActiveBroadcasts` effectue des comparaisons temporelles réelles.

---

## 4. WS2 — Pages & navigation

Fichier pivot : `lib/routes/app_router.dart` (606 l., `GoRouter` plat, un seul `redirect`).
Référence : `ProColis-Web/src/routes/index.tsx` + `guards.tsx`.

### 2.1 Landing inaccessible ✅
`/landing` → `LandingScreen` (`lib/screens/accueil/landing_screen.dart`, 572 l.) est déclarée mais **absente de la liste `isPublic`** : un visiteur non connecté est renvoyé sur `/login`. Le web sert cette page sur `/` sans garde.
→ Fait : `/` et `/landing` sont publics ; la sortie du splash anonyme mène à la landing.

### 2.2 `/help` public ✅
Le web sert `/help` sans authentification (`src/features/shared/HelpScreen.tsx`) ; le mobile l'exigeait. → Ajouté à `isPublic`.

### 2.3 Retour de paiement PayDunya ✅
L'API redirige en 302 vers `${CORS_ORIGIN}/client/colis?payment=success|pending|cancelled` (`src/modules/paydunya.controller.js`). Le web a `/payment-status` **et** `/payment-status.php`. Le mobile n'a ni route ni gestion de deep-link.
→ Routes `/payment-status` et `/payment-status.php` ajoutées, avec écran lisant le paramètre `payment`.

### 2.4 Routes exigeant un objet `extra` ✅
`/confirm-delivery`, `/trip/:tripId`, `/garage/parcel/:parcelId`, `/admin/garage/drivers` exigent un objet Dart passé en `extra` et cassent sur navigation directe, notification push ou restauration d'état. Le web les adresse toutes par identifiant d'URL.
→ Chargeurs par identifiant ajoutés pour les quatre ressources ; nouvelle route `/admin/garages/:garageId/drivers`, avec conservation temporaire de l'ancien alias.

### 2.5 Gestion des zones ✅
Le web a `/admin/zones` (`ZonesPage.tsx` + `ZoneFormDialog.tsx`). Le mobile gère les zones en ligne dans l'onglet « Zones » du dashboard super-admin, et `lib/screens/super-admin/zones_management_screen.dart` (450 l., avec un drapeau `embedded`) est **du code mort** — zéro référence dans `lib/`.
→ Câblé sur `/admin/zones` et utilisé par l'onglet « Zones » du dashboard en mode `embedded`.

### 2.6 Autres écrans morts / non routés ✅
- `garage_colis_screen.dart` est routé sur `/garage/colis`.
- `offer_dialog.dart` et `recharge_dialog.dart` ont été supprimés : leurs parcours sont déjà couverts par l'offre intégrée de `free_parcels_screen.dart` et la recharge de `points_screen.dart`.
- Les barils exportent `support_roles_api.dart`, `support_provider.dart` et `nav_provider.dart`.

### 2.7 Espace support ✅
Une fois le rôle `support` ajouté (§1.3), lui donner un préfixe et une garde alignés sur le web : `/support-admin` — conversations, assistances, colis, chauffeurs, utilisateurs, profil, notifications.
Les écrans existent déjà côté mobile (`admin_support_screen.dart`, `assistances_screen.dart`, `colis_management_screen.dart`, `chauffeurs_management_screen.dart`, `users_management_screen.dart`) : il s'agit de les exposer sous ce préfixe avec la garde `isSupport || isSuperAdmin`.

---

## 5. WS3 — Brancher les endpoints existants

### 3.1 Supprimer les statistiques fabriquées ✅

`lib/services/role_mock_data.dart` (675 l.) **n'est pas conditionné par un drapeau** — contrairement à `mock_data.dart`, protégé par `bool.fromEnvironment('MOCK_API')`. Il génère des KPI pseudo-aléatoires déterministes (graine = identifiant utilisateur) consommés **en production** par `lib/screens/profile/role_profile_sections.dart:96,231`.

Le fichier porte même ce commentaire : *« À remplacer par `GET /garage-admin/stats` quand l'endpoint existera »* (`role_mock_data.dart:511`). **L'endpoint existe** — ainsi que les autres :

| Endpoint API | Existe | Client web | Client mobile |
|---|---|---|---|
| `GET /users/stats` | ✅ | `stats.ts` `userStats()` | ❌ |
| `GET /client/bids/stats` | ✅ | `clientBidStats()` | ❌ |
| `GET /garage-admin/stats` | ✅ | `garageStats()` | ❌ |
| `GET /advertisements/stats` | ✅ | `advertisementStats()` | ❌ |
| `GET /driver/stats` | ✅ | `driverStats()` | ✅ |
| `GET /super-admin/stats` | ✅ | `globalStats()` | ✅ |

**Fait :**
1. `StatsApi` et les modèles typés couvrent les six endpoints, dont les quatre méthodes manquantes.
2. `role_profile_sections.dart` utilise des providers réels pour tous les rôles.
3. `role_mock_data.dart` et `MockDataNote` ont été supprimés.
4. `formatFcfa` / `formatAmount` vivent dans `lib/utils/format.dart`.

### 3.2 Carnet d'adresses & garages favoris ✅

Absents du mobile. Endpoints disponibles, déjà consommés par le web (`ProColis-Web/src/lib/api/addresses.ts`, rendu par `src/features/shared/profile/AddressBookCard.tsx`) :

```
GET/POST     /addresses
PUT/DELETE   /addresses/:addressId
PATCH        /addresses/:addressId/default
GET          /favorites/garages
POST/DELETE  /favorites/garages/:garageId
```

**Fait :** `addresses_api.dart`, modèle `Address`, providers et cartes de profil ajoutés. La saisie réutilise `LocationAutocomplete` et l'ajout de favori réutilise `GaragePickerSheet`.

### 3.3 Consolidation de la couche HTTP

Le mobile a **deux piles HTTP** : le monolithe `lib/services/api_service.dart` (2346 l.) et le plus récent `lib/services/api/client.dart` + classes modulaires. Les deux définissent `baseUrl`, la liste des routes publiques et le rafraîchissement de jeton, avec des logiques divergentes (`QueuedInterceptorsWrapper` contre `InterceptorsWrapper`).

**Décision :** les nouvelles API de cette spec vont dans `lib/services/api/`. **La migration complète du monolithe n'est pas entreprise ici** — dette assumée et documentée.

Un point est traité malgré tout : `ApiService` avale presque toutes les exceptions en renvoyant `[]` / `{success:false}`, ce qui masque exactement le genre de désynchronisation corrigé par cette spec. Faire remonter les erreurs sur les chemins touchés.

---

## 6. WS4 — Écran de configuration admin ✅

`lib/screens/super-admin/admin_parametres_screen.dart` couvre 13 clés ; `ProColis-Web/src/features/superAdmin/ConfigConsommationPage.tsx` (`CONFIG_SCHEMA`) en couvre 27. Manquent :

```
score.cfaPerPoint            score.commitmentFee
score.standardThreshold      score.premiumThreshold      score.eliteThreshold
withdrawal.minAmount         withdrawal.maxAmount
commission.insufficient_rule (block | warn | debt)
disbursement.mode            (manual | auto)
paydunya.disburse.masterKey  paydunya.disburse.privateKey
paydunya.disburse.publicKey  paydunya.disburse.token
paydunya.disburse.mode
```

Ces clés sont réellement lues côté serveur (`prisma/seed.js:738-748`, `src/utils/commission.js`, `src/modules/paydunya.controller.js`) — ce ne sont pas des réglages web-only.

**Fait :**
- Le formulaire est généré depuis un schéma Dart de 27 champs aligné sur `CONFIG_SCHEMA`.
- Les valeurs à choix fermé (`block|warn|debt`, `manual|auto`, `test|live`) utilisent des sélecteurs.
- Les clés PayDunya et Disburse sont masquées avec affichage explicite à la demande.
- `commission.insufficient_rule` configure `CommissionService` au chargement et après sauvegarde ; son défaut local est aligné sur `block`.

---

## 7. WS6 — Correctif « colis reçus » (les deux clients) ✅

`clientParcels` (`src/modules/mobile/mobile.controller.js:570`) filtre uniquement sur `senderId: req.user.id`. Il ignore **et** le `?filter=sent|received` du web **et** le `?role=sender|receiver` du mobile. Conséquence : « Mes colis reçus » renvoie les colis *envoyés*, sur les deux clients, sans erreur visible.

**Complication :** `Parcel` n'a pas de colonne `recipientUserId` en base — l'appariement destinataire ne peut se faire que par `receiverPhone`. Le modèle mobile déclare pourtant un champ `recipientUserId` qui n'existe nulle part côté serveur.

**Fait :**
1. Critère retenu : `receiverPhone = user.phone`.
2. `clientParcels` applique `filter=sent|received`; sans filtre, il renvoie les deux côtés.
3. Web et mobile utilisent tous deux `filter`.
4. `recipientUserId` a été retiré du modèle mobile.

---

## 8. WS5 — Paiement espèces : API + port web ✅

Constat initial : le mobile portait une fonctionnalité complète de paiement en espèces **sans aucun support serveur**. La migration, les contrôleurs, les routes et le port web sont maintenant implémentés.

**Existant côté mobile désormais branché :**
- `lib/services/api/cash_payments_api.dart` — 6 méthodes
- `lib/screens/super-admin/cash_declarations_screen.dart` + route `/admin/payments-cash`
- `lib/widgets/declare_cash_payment_sheet.dart`, `lib/widgets/payment_channel_selector.dart`
- `lib/models/payment.dart` — enums `PaymentChannel`, `CashCollectionPoint`, `PaymentStatus.cashLabel`
- `lib/models/parcel.dart` — `paymentChannel`, `acceptedPaymentChannels`, `cashCollectionPoint`, `cashCollectedAmount`, `cashCollectedAt` + getters
- `ApiService.driverCashDeclarations` et `pendingCashDeclarations` appellent les endpoints réels

Le mobile est ici la **spécification de fait**, puisqu'il porte déjà le modèle du domaine.

### Étapes

1. **Migration Prisma** — sur `Parcel` : `paymentChannel`, `acceptedPaymentChannels`, `cashCollectionPoint`, `cashCollectedAmount`, `cashCollectedAt`.
   Introduire les enums `PaymentChannel` (`cash`, `platform`) et `CashCollectionPoint` (`sender_pickup`, `receiver_delivery`) plutôt que des `String` libres — le schéma abuse déjà des statuts en texte libre (`Parcel.paymentStatus`), ne pas aggraver.

2. **Routes API** — dans `src/modules/mobile/mobile.routes.js`, en respectant les valeurs de transport de `cash_payments_api.dart` :

   | Verbe | Chemin | Rôles |
   |---|---|---|
   | POST | `/driver/parcels/:parcelId/declare-cash` | driver |
   | GET | `/driver/cash-declarations` | driver |
   | GET | `/super-admin/payments/cash-declarations` | super_admin, support |
   | POST | `/super-admin/payments/:paymentId/validate-cash` | super_admin, support |
   | POST | `/super-admin/payments/:paymentId/reject-cash` | super_admin, support |
   | PATCH | `/parcels/:parcelId/payment-channel` | authentifié, portée `parcelAccessWhere` |

   Réutiliser `ok()` / `fail()` (`src/utils/api-response.js`), le wrapper `handle()`, `getPagination()`, et étendre `serializePayment` — **ne pas introduire de nouvelle convention d'enveloppe**.

3. **Retirer les branches simulées** de `ApiService.driverCashDeclarations` et `pendingCashDeclarations`.

4. **Port web** — `src/lib/api/cash-payments.ts` + écran déclarations sous `/admin/finance/payments-cash`, dans le groupe Finance de la barre latérale (`DashboardLayout.tsx`). Réutiliser `ParcelsTable`, `QueryState`, `StatusBadge`.

**Séquencement :** après WS1 (le modèle `Payment` mobile évolue) ; livrable indépendamment de WS2–WS4.

**Fait :**
1. Migration `20260726190000_cash_payment_domain` avec les deux enums et les cinq colonnes `Parcel`.
2. Les six routes sont implémentées avec `handle()`, logs contextualisés, validation des jalons, audit et notifications.
3. La déclaration est idempotente ; la validation est atomique ; un rejet motivé laisse le colis dû.
4. `serializeParcel` et `serializePayment` exposent le contrat cash complet, y compris le colis lié.
5. Les branches de simulation mobile ont été retirées et les montants `Decimal` Prisma sont acceptés sous forme de chaînes.
6. Le web dispose de `/admin/finance/payments-cash`, de son client API et d'une file responsive utilisant `ParcelsTable`, `QueryState` et `StatusBadge`.
7. Le test d'intégration `tests/cash-payments.test.js` couvre le cycle déclaration → validation, le rejet et le changement de canal.

---

## 9. Constaté, hors périmètre d'exécution

### Le mobile devance le web — pas de modification web prévue

- Dashboards support technique / commercial (`lib/screens/dashboard/support_technique_dashboard.dart`, `support_commercial_dashboard.dart`, `lib/models/support.dart`, `lib/services/api/support_roles_api.dart`) : tickets, incidents, prospects, couverture réseau, branchés sur `/support-technique/*` et `/support-commercial/*`. Le web n'a qu'un espace support générique (`SupportDashboard.tsx`) et ne consomme aucun de ces endpoints.
- Écran de configuration des commissions `/admin/commissions` (le web redirige vers la page config).
- Suivi de position chauffeur (`POST /driver/location`) et jetons push FCM (`POST /notifications/device-token`) : mobile uniquement.

### Le web se trompe contre l'API — ne pas recopier

- `PaymentMethod` : le web déclare `wave | freeMoney | orangeMoney | card | cash`, l'enum Prisma est `wave | freemMoney | orange_money | card | cash`. **Le mobile est correct** ; le web enverra des valeurs rejetées. La faute de frappe `freemMoney` est dans le schéma de production — la corriger demanderait une migration, hors périmètre.

### Dette API constatée

- `DELETE /notifications/all` est enregistrée *après* `DELETE /:notificationId` : Express résout le paramètre en premier, `"all"` part en UUID dans `deleteMany` → erreur 500. Route morte.
- Tous les routeurs sont montés en double (`/api/v1` **et** racine) — dérive silencieuse possible entre clients.
- `GET /super-admin/stats/advanced` est un alias exact de `/super-admin/stats` ; `revenueLastMonth`, `parcelsByRegion`, `dailyStats`, `garagePerformance` sont des valeurs fixes. Le modèle `AdminStats` mobile les expose comme si elles étaient réelles.
- `estimateParcel` code en dur `baseFee 1000` / `pricePerKg 500` au lieu de lire `SystemConfig` — l'estimation de prix ignore donc les réglages de WS4.
- Si Brevo n'est pas configuré, `sendOtp` / `forgotPassword` renvoient le code OTP **en clair** dans la réponse (`auth.controller.js:110-115`). Risque en production.
- Les trois gestionnaires `adminSupport*` imbriquent sous `data` alors que `ok()` étale à la racine. Le mobile gère déjà ce cas (`api_service.dart:1038,1056`) — **ne pas « corriger »**.

---

## 10. Ordre d'exécution

| Ordre | Lot | Statut |
|---|---|---|
| 1 | **WS1** — contrat de données (prérequis de tout le reste) | ✅ |
| 2 | **WS3** — brancher les endpoints réels, supprimer `role_mock_data.dart` | ✅ |
| 3 | **WS2** — routes & navigation | ✅ |
| 4 | **WS4** — écran de configuration | ✅ |
| 5 | **WS6** — correctif colis reçus (API + deux clients) | ✅ |
| 6 | **WS5** — paiement espèces de bout en bout | ✅ |

---

## 11. Vérification

### Analyse statique
```bash
cd /Volumes/Oracle/Mobile/ProColis && flutter analyze && flutter test
cd /Volumes/Oracle/Web/ProColis-Api  && npm test
cd /Volumes/Oracle/Web/ProColis-Web  && npx tsc --noEmit && npm test
```

La suite mobile couvre désormais les round-trips `fromJson` / `toJson` des modèles touchés en WS1, les statistiques/adresses de WS3 et le domaine cash de WS5.

**Résultats automatisés du 2026-07-26 :**
- Flutter : **44 tests passants** ; `flutter analyze lib` ne remonte aucune erreur, mais 174 avertissements/informations historiques.
- Prisma : schéma valide, client régénéré et migration cash appliquée sur `procolis_test`.
- API cash : **3 tests d'intégration passants** seuls. Dans la suite API complète, le `beforeAll` dépasse parfois le timeout Jest de 5 s lorsque les trois inscriptions bcrypt sont exécutées avec les autres suites ; les 8 autres suites passent.
- Web : lint ciblé cash passant. Le typecheck global reste bloqué par quatre erreurs préexistantes dans `AdminSupportScreen.tsx` / un import `SupportChatScreen` inutilisé.
- Vitest web : 23 tests passent ; 6 tests `support.test.ts` échouent car l'environnement expose un `localStorage` sans méthode `clear`.

### Contrat contre serveur réel

Démarrer l'API (`docker-compose up` dans `ProColis-Api`, base seedée via `prisma/seed.js` + `seed-support.js`), puis comparer la réponse brute au modèle Dart :

```bash
curl -s localhost:18081/api/v1/super-admin/zones \
  -H "Authorization: Bearer $TOKEN" | jq '.data[0] | {radius, radiusKm}'

curl -s localhost:18081/api/v1/super-admin/wallets/$USER/transactions \
  -H "Authorization: Bearer $TOKEN" | jq '[.transactions[].type] | unique'

curl -s localhost:18081/api/v1/notifications \
  -H "Authorization: Bearer $TOKEN" | jq '[.notifications[].type] | unique'
```

Toutes les valeurs renvoyées doivent être reconnues par les enums Dart corrigés — **aucun repli** sur `info`, `adjustment` ou une valeur par défaut.

### Parcours applicatif

`flutter run --dart-define=API_BASE_URL=https://sendprocolis.com`, **sans** `MOCK_API` :

- Un compte par rôle, `support` inclus : vérifier l'espace d'atterrissage et la correspondance des gardes de préfixe avec `ROLE_HOME` du web.
- Visiteur anonyme : `/landing` et `/help` accessibles.
- Écran profil de chaque rôle : statistiques issues de l'API, plus aucun `MockDataNote`.
- Deep-links directs, application fermée : `/confirm-delivery`, `/trip/:id`, `/garage/parcel/:id`, `/admin/garages/:id/drivers`, `/payment-status`.
- Créer puis modifier une zone : relire en base que `radius_km` est bien en kilomètres.
- WS5 : cycle complet déclaration espèces chauffeur → validation super-admin, sur mobile **et** web.

### Parité côte à côte

La validation finale reste une revue écran par écran contre `ProColis-Web/src/routes/index.tsx`, rôle par rôle. Le tableau des routes du §4 sert de liste de contrôle.





<!-- Tous les rôles disposent maintenant d’un compte actif et leur connexion a été vérifiée.

   Rôle                  Téléphone        PIN
  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━  ━━━━━━━━
   Client                +221770000101    123456
  ────────────────────  ───────────────  ────────
   Chauffeur             +221770000202    123456
  ────────────────────  ───────────────  ────────
   Admin garage          +221770000002    123456
  ────────────────────  ───────────────  ────────
   Super admin           +221770000001    123456
  ────────────────────  ───────────────  ────────
   Support               +221770000503    123456
  ────────────────────  ───────────────  ────────
   Support technique     +221770000501    123456
  ────────────────────  ───────────────  ────────
   Support commercial    +221770000502    123456 -->
