# PRO COLIS API - Vue d'ensemble

## Objectif

Ce dossier définit les specifications fonctionnelles et techniques du backend Node.js/Express a implementer pour l'application mobile PRO COLIS.

L'application Flutter existante couvre plusieurs profils et workflows :

- client : inscription, creation de colis, suivi, paiement, offres recues, notifications.
- chauffeur : disponibilite, annonces de trajet, offres, prise en charge, livraison, geolocalisation.
- admin garage : gestion des colis de son garage, chauffeurs, assignations, rapports.
- super admin : gestion globale des utilisateurs, garages, colis, configuration, audit, sauvegarde.

Le backend doit exposer une API REST stable, securisee et compatible avec les routes deja consommees par `lib/services/api_service.dart`.

## Stack cible

- Runtime : Node.js LTS.
- Framework HTTP : Express.
- Base de donnees : PostgreSQL.
- ORM recommande : Prisma ou Knex. Prisma est preferable pour accelerer le schema, les migrations et le typage.
- Validation : Zod ou Joi.
- Authentification : JWT access token + refresh token.
- Uploads : stockage disque local en dev, S3 compatible en production.
- Logs : Pino ou Winston.
- Tests : Jest + Supertest.

## Principes de conception

- Tous les endpoints doivent retourner un format JSON homogene.
- Les donnees sensibles ne doivent jamais etre retournees : mot de passe, hash PIN, tokens, OTP.
- Tous les traitements critiques en controlleur doivent etre encapsules dans un `try/catch`.
- Chaque `catch` doit logger une erreur propre avec contexte minimal : controller, action, userId si disponible, requestId.
- Les workflows colis, paiement, score et admin doivent utiliser des transactions PostgreSQL quand plusieurs tables sont modifiees.
- Les roles doivent etre controles cote API, pas seulement cote mobile.
- Les modifications importantes doivent produire un `audit_log`.

## Format de reponse standard

Succes :

```json
{
  "success": true,
  "message": "Operation effectuee",
  "data": {}
}
```

Erreur :

```json
{
  "success": false,
  "message": "Message lisible par l'utilisateur",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": []
  }
}
```

Pour compatibilite mobile, certains endpoints peuvent aussi exposer directement les cles deja attendues, par exemple `user`, `parcel`, `parcels`, `accessToken`, `refreshToken`, `url`.

## Versioning

Le backend doit exposer les routes sous `/api/v1`. Une compatibilite temporaire peut etre gardee sans prefixe pour l'app existante :

- route canonique : `/api/v1/auth/me`
- alias compatible : `/auth/me`

La migration Flutter vers `/api/v1` devra etre planifiee apres stabilisation backend.

## Variables d'environnement

```env
NODE_ENV=development
PORT=8080
DATABASE_URL=postgresql://user:password@localhost:5432/procolis
JWT_ACCESS_SECRET=change-me
JWT_REFRESH_SECRET=change-me
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d
OTP_EXPIRES_MINUTES=10
UPLOAD_STORAGE=local
UPLOAD_LOCAL_DIR=uploads
PUBLIC_BASE_URL=http://localhost:8080
LOG_LEVEL=info
```

## Definition du MVP backend

Le MVP backend doit prioriser :

1. Authentification OTP/PIN/JWT.
2. Gestion utilisateurs et roles.
3. Garages, chauffeurs et vehicules.
4. Creation, suivi et cycle de vie des colis.
5. Upload medias colis.
6. Offres sur colis libre service.
7. Paiements et score.
8. Notifications.
9. Administration, stats et audit logs.

