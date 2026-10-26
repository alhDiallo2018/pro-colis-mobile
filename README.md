# sendprocolis

Application Flutter PRO COLIS.

## Lancement avec Docker

Le conteneur compile l'application Flutter en web puis la sert avec Nginx.

```bash
docker compose up --build
```

Avec Docker Compose local :

- App web : http://localhost:8081
- API backend : http://localhost:18081/api/v1

Sans `API_BASE_URL`, un build mobile utilise
`https://sendprocolis.com/api/v1`. Pour le développement sur émulateur ou
téléphone, injecter explicitement l'adresse joignable du backend avec
`--dart-define=API_BASE_URL=...` (ne pas utiliser `localhost` sur un appareil).

Variables utiles :

```bash
APP_PORT=3000 API_BASE_URL=https://example.com/api/v1 APP_BASE_URL=https://app.example.com GOOGLE_MAPS_API_KEY=AIza... docker compose up --build
```

`API_BASE_URL`, `APP_BASE_URL` et `GOOGLE_MAPS_API_KEY` sont injectées dans
Flutter au moment du build avec `--dart-define`. Si `APP_BASE_URL` est omise
sur le web, l'origine courante du navigateur est utilisée pour les liens de
suivi. `GOOGLE_MAPS_API_KEY` sert aussi au SDK Google Maps JS chargé par
`web/index.html` : le placeholder `__GOOGLE_MAPS_API_KEY__` y est remplacé au
build (Dockerfile), et le build échoue si la clé manque.

## Build web sans Docker

`flutter build web` seul ne remplace PAS le placeholder de `web/index.html`.
Passer par le script qui fait le build puis la substitution (clé lue depuis
l'environnement ou `.env`) :

```bash
GOOGLE_MAPS_API_KEY=AIza... tool/build_web.sh
```

## Vérification du contrat mobile/API

Lorsque les dépôts mobile et API sont présents dans leur arborescence habituelle :

```bash
node tool/verify_api_contract.mjs
```

Pour une autre arborescence, définir `PROCOLIS_API_DIR`. La commande compare les
verbes et routes réellement appelés par Flutter avec les routers Express, y
compris les endpoints calculés selon le rôle.

## Mises à jour de l’application Android

Le mobile lit `GET /api/v1/public/mobile-update` sur l’API choisie par
`API_BASE_URL`. L’endpoint est public, sans accès à la base ; `/public/app-update`
reste un alias. Les variables suivantes sont à définir dans le **`.env` de l’API** :

```dotenv
MOBILE_ANDROID_UPDATE_ENABLED=true
MOBILE_ANDROID_LATEST_VERSION=1.0.13
MOBILE_ANDROID_LATEST_VERSION_CODE=46
MOBILE_ANDROID_MIN_VERSION_CODE=40
MOBILE_ANDROID_RELEASE_NOTES_FR="Corrections de la carte et améliorations de stabilité."
MOBILE_ANDROID_RELEASE_NOTES_EN="Map fixes and stability improvements."
MOBILE_ANDROID_REMIND_AFTER_HOURS=24
MOBILE_ANDROID_UPDATE_URL=https://play.google.com/store/apps/details?id=com.sendprocolis.app
```

Seul le **code Android installé** détermine le comportement :

| Code installé | Comportement pour l’exemple ci-dessus |
| --- | --- |
| Moins de 40 | Écran plein écran obligatoire, sans « Plus tard » |
| De 40 à 45 | Popup optionnelle, report possible |
| 46 et plus | Aucune demande |

Fixer `MIN_VERSION_CODE=46` rend la dernière version obligatoire pour tous les
anciens builds. `LATEST_VERSION` est seulement un texte d’affichage.
`pubspec.yaml` définit la version réellement installée : `version: 1.0.13+46`
signifie nom `1.0.13`, code Android `46`. Il n’existe aucun seuil codé en dur dans
l’app. Les notes suivent la langue de l’appareil, avec repli français puis anglais.
Le report est mémorisé par code de version pour `REMIND_AFTER_HOURS` heures
(1 à 720). Paramètres → Mises à jour permet de rouvrir une proposition reportée.

La validation au démarrage de l’API refuse un minimum supérieur au dernier code,
les codes non entiers/négatifs et les URL sans HTTPS. Le mécanisme est désactivé
par défaut. `UPDATE_ENABLED=false` lève un blocage après la prochaine vérification
réussie. Une réponse réseau invalide ne désactive pas une obligation connue.

Après modification du `.env`, redémarrer le processus Node. Avec Docker Compose,
les variables `env_file` sont fixées à la création du conteneur : **recréer** le
service depuis le répertoire de l’API, un simple restart ne les recharge pas :

```bash
docker compose up -d --build --no-deps api
```

Publier d’abord la release sur le Play Store et vérifier sa disponibilité pour
tous les appareils concernés avant de relever le minimum. Une application déjà
publiée sans ce mécanisme ne pourra pas afficher le blocage rétroactivement.
Ce contrôle concerne le client officiel ; ce n’est pas une barrière de sécurité
de l’API et aucun endpoint métier n’est filtré sur un en-tête de version.

Le mobile vérifie au lancement, au retour au premier plan (limite d’une fois par
minute), toutes les 15 minutes au premier plan et systématiquement au retour du
store. Un écran opaque couvre l’app pendant la décision initiale. Sans réseau ni
politique connue, l’app reste utilisable après le délai de vérification ; une
obligation connue reste bloquante hors ligne. Le cache est séparé par URL d’API
(Docker/production). Ouvrir le store ne suffit pas : le code installé doit
atteindre le minimum ou l’API doit abaisser/désactiver la règle. iOS et le web
ne sont pas concernés par la politique Android.

Tests : `flutter test test/app_update_test.dart` côté mobile ;
`npm test -- --runTestsByPath tests/app-update.test.js` côté API.


## Connexion téléphone, email et Google (Android)

La connexion utilise deux onglets distincts ; le PIN reste à six chiffres.
Le dernier mode est mémorisé. Le lien « Code PIN oublié ? » reprend l'identifiant
sélectionné. Google apparaît uniquement sur Android dans l'onglet Email.

L'API expose `GET /api/v1/auth/google/config` et renvoie son identifiant OAuth
public de type **Web**. Le SDK reçoit ce `serverClientId` directement depuis
l'API : aucun secret Google ou Firebase Auth supplémentaire n'est nécessaire
sur le mobile. Tant que `GOOGLE_WEB_CLIENT_ID` est vide côté API, la connexion
Google explique son indisponibilité et laisse email/PIN utilisables.

Configuration dans le projet Google Cloud/Firebase **sendprocolis** :

1. Configurer l'écran de consentement OAuth et un client OAuth de type Web.
2. Renseigner son identifiant dans `GOOGLE_WEB_CLIENT_ID` côté API et redémarrer l'API.
3. Enregistrer le client OAuth Android `com.sendprocolis.app`, avec les SHA-1
   des clés debug, release et Play App Signing selon les builds distribués.
4. Ajouter les comptes test si l'application OAuth est en mode test.
5. Vérifier sur un appareil avec Google Play Services : nouveau compte,
   compte existant + PIN, reconnexion, annulation et déconnexion.

Empreinte SHA-1 de la clé debug locale vérifiée le 25/10/2026 :
`2E:8C:98:C0:42:F3:3C:C3:A1:70:C9:2E:CD:8C:2B:F0:86:40:17:F6`.
Cette empreinte publique n'est pas celle de la version Play Store.

Un nouvel utilisateur Google confirme son téléphone par SMS (Brevo configuré
côté API), choisit un PIN et son profil. Un compte existant exige son PIN avant
association ; l'email, le téléphone et le rôle existants ne sont pas remplacés.
Les demandes temporaires ne sont jamais persistées dans le stockage mobile.

Tests ciblés :

```sh
.flutter-sdk/bin/flutter test test/login_modes_test.dart test/google_auth_service_test.dart test/pin_recovery_test.dart test/auth_session_test.dart test/app_update_test.dart test/session_lock_provider_test.dart
.flutter-sdk/bin/flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:18081/api/v1
```

Le logo Google provient des [ressources officielles Google](https://developers.google.com/identity/branding-guidelines).
Voir aussi la [configuration officielle Android](https://pub.dev/packages/google_sign_in_android).


## Build Android de production

`bash tool/build_android_release.sh` génère un AAB Play Console et un APK
universel release avec les mêmes version et signature. Le script fixe
explicitement `API_BASE_URL=https://sendprocolis.com/api/v1` et
`APP_BASE_URL=https://sendprocolis.com`, sans reprendre une URL Docker du shell.
Il refuse une configuration de signature absente ou incomplète.
Passer `aab` ou `apk` en argument pour ne construire que ce format.

Avant chaque publication, incrémenter le code de version de `pubspec.yaml`
au-delà du dernier code utilisé dans Play Console. La version préparée ici est
`1.1.2+11`, après vérification dans Play Console de la version publiée
`1.1.1` (code 10), sur le compte développeur `6193041811945265589`.

La clé Maps doit être fournie via `GOOGLE_MAPS_API_KEY` dans l'environnement :
elle sera transmise à la compilation Dart et à Gradle pour le SDK natif.
Le client OAuth Google de connexion ne remplace pas cette clé Maps.

La clé release actuellement configurée a les empreintes publiques suivantes :

- SHA-1 : `A3:48:31:BF:2E:A7:DE:CE:3B:5B:1D:90:30:C3:31:83:FD:27:6A:58`.
- SHA-256 : `AE:FE:F8:B7:25:A0:64:E1:5E:22:22:E0:27:91:67:64:5E:08:EE:0C:2E:E3:AD:D0:51:DF:59:F1:CA:79:98:00`.

Pour Google Sign-In, enregistrer un client OAuth Android pour
`com.sendprocolis.app` et la signature utilisée. Pour les installations depuis
Google Play, utiliser également l'empreinte **Play App Signing**, si Google
resigne l'application avec une clé différente de la clé locale de téléversement.

Les sorties brutes se trouvent dans `build/app/outputs/bundle/release/` (AAB)
et `build/app/outputs/flutter-apk/` (APK). Les livrables vérifiés de cette
préparation sont conservés sous `releases/android/1.1.2+11/`, avec leurs sommes
SHA-256 et leur rapport de vérification.
