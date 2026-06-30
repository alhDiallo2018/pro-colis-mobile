# Architecture Node.js/Express

## Structure recommandee

```text
backend/
  src/
    app.js
    server.js
    config/
      env.js
      database.js
      logger.js
    modules/
      auth/
      users/
      garages/
      vehicles/
      parcels/
      bids/
      advertisements/
      payments/
      score/
      notifications/
      uploads/
      admin/
      support/
      identity/
      webhooks/
    middlewares/
      auth.middleware.js
      rbac.middleware.js
      validate.middleware.js
      error.middleware.js
      request-id.middleware.js
      rate-limit.middleware.js
    utils/
      api-response.js
      async-handler.js
      pagination.js
      tracking-number.js
      audit.js
    prisma/
      schema.prisma
      migrations/
    tests/
```

## Separation des responsabilites

- Routes : declarent les endpoints et middlewares.
- Controllers : lisent la requete, appellent les services, retournent la reponse.
- Services : contiennent les regles metier et transactions.
- Repositories : acces base de donnees si Prisma n'est pas utilise directement dans les services.
- Validators : schemas Zod/Joi pour body, params et query.
- Middlewares : authentification, autorisation, validation, erreurs, logs.

## Regle obligatoire pour les controlleurs critiques

Les methodes qui modifient la base, declenchent un paiement, changent un statut colis, manipulent les roles ou les fichiers doivent avoir un `try/catch`.

Exemple :

```js
async function createParcel(req, res) {
  try {
    // Creation du colis, de son evenement initial et notification dans une transaction.
    const parcel = await parcelService.createParcel(req.user, req.body);
    return res.status(201).json({ success: true, parcel });
  } catch (error) {
    req.log.error({
      error,
      userId: req.user?.id,
      action: 'parcel.create'
    }, 'Failed to create parcel');

    return res.status(500).json({
      success: false,
      message: 'Impossible de creer le colis'
    });
  }
}
```

## Gestion globale des erreurs

Les erreurs connues doivent etre mappees :

- `ValidationError` -> 422.
- `UnauthorizedError` -> 401.
- `ForbiddenError` -> 403.
- `NotFoundError` -> 404.
- `ConflictError` -> 409.
- erreur inconnue -> 500.

Le middleware global ne remplace pas les `try/catch` obligatoires des methodes critiques. Il sert de filet de securite.

## Transactions

Utiliser une transaction pour :

- creation colis + evenement + paiement initial + notification.
- acceptation d'offre + rejet des autres offres + assignation chauffeur + notification.
- changement de statut colis + evenement + mise a jour chauffeur + notification.
- paiement confirme + wallet/score + notification.
- suppression admin avec cascade logique.

## Pagination

Tous les endpoints liste doivent accepter :

- `page`, defaut `1`.
- `limit`, defaut `20`, maximum `100`.
- `sortBy`, optionnel.
- `sortOrder`, `asc` ou `desc`.

Reponse recommandee :

```json
{
  "success": true,
  "data": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 120,
    "totalPages": 6
  }
}
```

## Logs

Chaque requete doit avoir un `requestId`. Les logs doivent inclure :

- requestId.
- method.
- path.
- statusCode.
- durationMs.
- userId si authentifie.
- role si authentifie.

Ne jamais logger :

- mot de passe.
- PIN.
- OTP.
- token JWT complet.
- contenu base64 complet des fichiers.

