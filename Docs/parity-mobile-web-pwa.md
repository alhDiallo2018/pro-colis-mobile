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
| Notifications push temps réel | ✅ FCM | ❌ | ❌ Web Push à ajouter |
| Chat support | ✅ | ✅ | ✅ |
| Profil + préférences notifications | ✅ | ✅ | ✅ |
| Pages légales (CGU, confidentialité…) | ✅ | ✅ | ✅ |
| Localisation (fr / en / wo) | ✅ | ⚠️ (vérifier wo) | ⚠️ |
| Mode sombre | ✅ | ⚠️ à vérifier | ⚠️ |
| Historique hors ligne (lecture) | ✅ cache local | ⚠️ partiel SW | ⚠️ |
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
| Modèles de colis (templates) | ✅ local-only | ❌ | ❌ |
| Self-service clés API | ✅ `/business/api-keys` | ❌ | ❌ |
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
| Handover colis chauffeur→chauffeur | ✅ | ❌ | ❌ |
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
| Broadcast groupe garage | ⚠️ | ⚠️ | ⚠️ |

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
| Vérifications identité (KYC) | ✅ (+ delete + request-info) | ⚠️ sans delete/request-info | ⚠️ |
| Audit logs | ✅ | ✅ | ✅ |
| Backups | ✅ | ✅ | ✅ |
| Système / health check | ✅ | ✅ | ✅ |
| Broadcasts mass users | ✅ | ✅ | ✅ |
| Réputation + scores + classement | ✅ | ✅ | ✅ |
| Pilot metrics | ✅ | ⚠️ à vérifier | ⚠️ |
| Hub opérationnel | ✅ | ⚠️ à vérifier | ⚠️ |

---

## Support (support, support_technique, support_commercial)

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Inbox support partagée | ✅ | ✅ | ✅ |
| Close conversation avec motif | ✅ reason+category | ⚠️ à vérifier | ⚠️ |
| Transfert conversation à agent | ✅ | ✅ | ✅ |
| Présence agents | ✅ | ✅ | ✅ |
| Gestion assistances | ✅ | ✅ | ✅ |
| Tickets techniques | ✅ (tech) | ✅ (tech) | ✅ |
| Leads commerciaux | ✅ (com) | ✅ (com) | ✅ |
| Couverture réseau | ✅ (com) | ✅ (com) | ✅ |
| Qualité de service | ✅ (tech) | ✅ (tech) | ✅ |
| Incidents temps réel | ✅ | ✅ | ✅ |
| **Dashboard SLA cross-tier** | ✅ 4 pills | ❌ | ❌ |

---

## Shuttle Operator (opérateur Tata/AFTU/DDD)

| Fonctionnalité | Mobile | Web | PWA |
|---|---|---|---|
| Lignes de transit | ✅ | ⚠️ à vérifier | ⚠️ |
| Gestion flotte | ✅ | ⚠️ à vérifier | ⚠️ |
| Horaires et arrêts | ✅ | ⚠️ à vérifier | ⚠️ |

*(Rôle récemment ajouté côté backend `20261117_shuttle_operator_role` — parité web à auditer.)*

---

## Capacités natives — stratégie web/PWA

Capacités mobiles qui demandent un compromis web. Chaque ligne documente
la dégradation acceptée.

| Capacité native | Mobile | Web / PWA | Décision |
|---|---|---|---|
| Caméra (scan QR, photos) | caméra persistante | `getUserMedia` (session) | ↩️ scan fallback saisie manuelle |
| GPS continu arrière-plan | FusedLocation background | 🚫 bloqué par navigateur | 🚫 pas d'équivalent ; drivers restent mobile-only pour le tracking |
| Carnet d'adresses OS | `contacts_service` | 🚫 Contacts API non dispo | 🚫 saisie manuelle + autocomplete carnet serveur |
| Push notifications | FCM | Web Push + VAPID | ❌ à livrer (voir backlog PWA) |
| Biométrie | empreinte / Face ID | WebAuthn | ↩️ à évaluer (support Safari + Chrome iOS inconsistant) |
| Enregistrement audio | microphone persistant | `MediaRecorder` session | ↩️ enregistrement en page uniquement, pas en arrière-plan |
| OCR on-device | ML Kit | 🚫 trop coûteux web | ↩️ fallback saisie ou OCR serveur |
| Secure Storage | iOS Keychain / Keystore | ↩️ IndexedDB + crypto.subtle | ↩️ tokens en httpOnly cookie recommandé |
| Share sheet | natif iOS/Android | Web Share API (mobile only) | ↩️ fallback copier le lien |
| Deep links | iOS Universal / Android App Links | URL standard | ✅ cohérent (route-based) |
| File save-as | `path_provider` | `<a download>` + Blob | ✅ équivalent pour PDF/export |

---

## Backlog PWA

État actuel : **installable + shell offline** (manifest + SW cache-first
sur bundles, network-first sur navigation, offline.html fallback).

À livrer pour rapprocher la PWA du mobile, par ordre de valeur :

1. **Web Push + VAPID**
   - Service Worker : `push` + `notificationclick` handlers
   - Côté API : endpoint d'abonnement PushSubscription, dispatcher parallèle à FCM
   - Cibles : missions driver, offres reçues client, broadcasts admin
2. **Background Sync** (uploads retryables)
   - File d'upload photos preuve livraison si connexion perdue
   - API : endpoint idempotent avec requestId (déjà convention projet)
3. **Précache des shells par rôle**
   - Actuellement l'admin shell n'est pas précaché → première visite offline = page blanche
   - Stratégie : lazy precache après login selon rôle du user
4. **IndexedDB pour historique hors ligne durable**
   - Aujourd'hui : SW cache les bundles mais pas les listes de colis/missions
   - Cible : derniers 50 colis / missions lus accessibles hors ligne
5. **Badging API** (nombre de notifs non lues sur l'icône installée)
6. **Splash screens iOS** (couvre tous les tailles d'écran)
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

| Priorité | Item | Rôle | Impact |
|---|---|---|---|
| P1 | Dashboard SLA cross-tier dans support_admin | support, super_admin | Alignement supervision |
| P1 | KYC : actions delete + request-info | super_admin | Ergonomie compliance |
| P2 | Self-service clés API côté business-shipper | client | Autonomie shipper pro |
| P2 | Close conversation avec motif structuré (dropdown resolved/duplicate/spam/no_answer) | support* | Stats et base de connaissance |
| P2 | Handover colis chauffeur↔chauffeur | driver | Rare mais critique quand utilisé |
| P3 | Modèles de colis réutilisables (local-only côté mobile, inexistant web) | client | Optionnel |
| P3 | Dashboard pilot metrics | super_admin | Reporting interne |

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

Dernière mise à jour : 2026-11-14 (audit initial).
