# sendprocolis

Application Flutter PRO COLIS.

## Lancement avec Docker

Le conteneur compile l'application Flutter en web puis la sert avec Nginx.

```bash
docker compose up --build
```

Par défaut :

- App web : http://localhost:8081
- API backend : http://localhost:18081/api/v1

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
