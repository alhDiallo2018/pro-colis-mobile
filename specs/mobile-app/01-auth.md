# Authentification

## Login PIN par telephone

Statut : `IMPLEMENTE`

```http
POST /auth/login
```

Payload :

```json
{
  "identifier": "+221770000101",
  "pin": "123456"
}
```

Notes Flutter :

- `identifier` accepte le telephone ou l'email.
- `pin` doit contenir exactement 6 chiffres.
- Stocker `accessToken` et `refreshToken` apres succes.

Reponse :

```json
{
  "success": true,
  "message": "Connexion effectuee",
  "user": {
    "id": "uuid",
    "email": "customer@procolis.test",
    "phone": "+221770000101",
    "fullName": "Customer Test",
    "role": "client",
    "status": "active",
    "garageId": null,
    "driverStatus": null
  },
  "accessToken": "jwt-access-token",
  "refreshToken": "jwt-refresh-token"
}
```

Alias compatible :

```http
POST /auth/login-with-pin
```

## Register

Statut : `IMPLEMENTE`

```http
POST /auth/register
```

Payload client :

```json
{
  "email": "client@example.com",
  "phone": "+221770000000",
  "fullName": "Client Test",
  "password": "Password123!",
  "pin": "123456",
  "role": "client",
  "address": "Dakar",
  "city": "Dakar",
  "region": "Dakar",
  "garageId": null
}
```

Payload driver :

```json
{
  "email": "driver@example.com",
  "phone": "+221770000111",
  "fullName": "Driver Test",
  "password": "Password123!",
  "pin": "123456",
  "role": "driver",
  "address": "Dakar",
  "city": "Dakar",
  "region": "Dakar",
  "garageId": "uuid-optionnel"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Compte cree",
  "user": {
    "id": "uuid",
    "phone": "+221770000000",
    "fullName": "Client Test",
    "role": "client",
    "status": "active"
  },
  "accessToken": "jwt-access-token",
  "refreshToken": "jwt-refresh-token"
}
```

## Refresh token

Statut : `IMPLEMENTE`

```http
POST /auth/refresh
```

Payload :

```json
{
  "refreshToken": "jwt-refresh-token"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Token renouvele",
  "user": {
    "id": "uuid",
    "role": "client",
    "status": "active"
  },
  "accessToken": "new-jwt-access-token"
}
```

## Utilisateur courant

Statut : `IMPLEMENTE`

```http
GET /auth/me
```

Headers :

```http
Authorization: Bearer <accessToken>
```

Reponse :

```json
{
  "success": true,
  "message": "Utilisateur courant",
  "user": {
    "id": "uuid",
    "phone": "+221770000101",
    "fullName": "Customer Test",
    "role": "client",
    "status": "active"
  }
}
```

## OTP et mot de passe

Statut : `SPEC`

| Methode | Endpoint | Payload |
| --- | --- | --- |
| POST | `/auth/send-otp` | `{ "identifier": "+221770000101", "type": "login" }` |
| POST | `/auth/verify-otp` | `{ "identifier": "+221770000101", "otpCode": "123456" }` |
| POST | `/auth/forgot-password` | `{ "identifier": "+221770000101" }` |
| POST | `/auth/reset-password` | `{ "identifier": "+221770000101", "otpCode": "123456", "newPassword": "Password123!" }` |
| POST | `/auth/change-password` | `{ "currentPassword": "Old123!", "newPassword": "Password123!" }` |
| POST | `/auth/verify-email` | `{ "email": "client@example.com", "otpCode": "123456" }` |
| POST | `/auth/resend-verification` | `{ "identifier": "client@example.com" }` |

Reponse standard :

```json
{
  "success": true,
  "message": "Operation effectuee",
  "data": {}
}
```
