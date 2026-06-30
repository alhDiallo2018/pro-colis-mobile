# Conventions API Mobile

## Headers

Public :

```http
Content-Type: application/json
Accept: application/json
```

Authentifie :

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <accessToken>
```

## Format succes

```json
{
  "success": true,
  "message": "Operation effectuee",
  "data": {}
}
```

Pour compatibilite mobile, certains endpoints retournent aussi des cles directes :

```json
{
  "success": true,
  "message": "Connexion effectuee",
  "user": {},
  "accessToken": "jwt",
  "refreshToken": "jwt"
}
```

## Format erreur

```json
{
  "success": false,
  "message": "Donnees invalides",
  "error": {
    "code": "VALIDATION_ERROR",
    "details": [
      {
        "path": "body.pin",
        "message": "Le code PIN doit contenir exactement 6 chiffres"
      }
    ]
  }
}
```

## Codes erreur

| HTTP | Code API | Sens mobile |
| --- | --- | --- |
| 400 | `BAD_REQUEST` | Requete mal formee. |
| 401 | `UNAUTHORIZED` | Rediriger vers login ou refresh token. |
| 403 | `FORBIDDEN` | Afficher acces refuse. |
| 404 | `NOT_FOUND` | Ressource introuvable. |
| 409 | `CONFLICT` | Etat incompatible ou doublon. |
| 422 | `VALIDATION_ERROR` | Afficher erreurs de formulaire. |
| 429 | `RATE_LIMITED` | Trop de tentatives, attendre. |
| 500 | `INTERNAL_ERROR` | Erreur serveur generique. |

## Pagination

Query params :

```text
page=1&limit=20&sortBy=createdAt&sortOrder=desc
```

Format reponse :

```json
{
  "success": true,
  "message": "Liste chargee",
  "data": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 120,
    "totalPages": 6
  }
}
```

## Types principaux

Roles :

```text
client, driver, admin, super_admin
```

Statuts colis :

```text
pending, free, confirmed, picked_up, in_transit, arrived, out_for_delivery, delivered, cancelled
```

Types colis :

```text
document, package, fragile, perishable, valuable
```

Methodes paiement :

```text
wave, freemMoney, orange_money, card, cash
```
