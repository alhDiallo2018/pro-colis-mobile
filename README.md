# pro_colis_clean

Application Flutter PRO COLIS.

## Lancement avec Docker

Le conteneur compile l'application Flutter en web puis la sert avec Nginx.

```bash
docker compose up --build
```

Par défaut :

- App web : http://localhost:8081
- API backend attendue par l'app : http://localhost:8080

Variables utiles :

```bash
APP_PORT=3000 API_BASE_URL=https://example.com docker compose up --build
```

`API_BASE_URL` est injectée dans Flutter au moment du build avec `--dart-define`.
