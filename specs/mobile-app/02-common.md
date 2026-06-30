# Endpoints Communs

## Healthcheck

Statut : `IMPLEMENTE`

```http
GET /health
```

Reponse :

```json
{
  "success": true,
  "message": "API operationnelle",
  "data": {
    "service": "procolis-api",
    "status": "ok",
    "timestamp": "2026-06-28T12:41:19.310Z"
  }
}
```

## Garages publics

Statut : `IMPLEMENTE`

```http
GET /public/garages?page=1&limit=20
```

Reponse :

```json
{
  "success": true,
  "message": "Garages actifs",
  "data": [
    {
      "id": "uuid",
      "name": "Garage Dakar Test",
      "city": "Dakar",
      "region": "Dakar",
      "address": "Route de Rufisque",
      "phone": "+221338000000",
      "isActive": true
    }
  ],
  "garages": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 2,
    "totalPages": 1
  }
}
```

## Upload base64

Statut : `IMPLEMENTE`

```http
POST /upload/base64
```

Headers :

```http
Authorization: Bearer <accessToken>
```

Payload :

```json
{
  "file": "base64-content-or-data-url",
  "filename": "photo.jpg",
  "parcelId": "uuid-optionnel"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Fichier envoye",
  "url": "http://localhost:18081/uploads/photo/uuid.jpg",
  "media": {
    "id": "uuid",
    "parcelId": "uuid",
    "mediaType": "photo",
    "url": "http://localhost:18081/uploads/photo/uuid.jpg"
  }
}
```

Variantes :

```http
POST /upload/parcel-photo
POST /upload/parcel-video
POST /upload/parcel-audio
POST /upload/bid-audio
```

## Upload multipart

Statut : `IMPLEMENTE`

```http
POST /upload
```

Headers :

```http
Authorization: Bearer <accessToken>
Content-Type: multipart/form-data
```

Fields :

```text
file=<binary>
mediaType=photo
```

Reponse :

```json
{
  "success": true,
  "message": "Fichier envoye",
  "url": "http://localhost:18081/uploads/uuid.jpg"
}
```

## Notifications

Statut : `IMPLEMENTE`

### Lister

```http
GET /notifications?page=1&limit=20
```

Reponse :

```json
{
  "success": true,
  "message": "Notifications",
  "data": [
    {
      "id": "uuid",
      "userId": "uuid",
      "parcelId": "uuid",
      "type": "bid_created",
      "title": "Nouvelle offre chauffeur",
      "body": "Driver Test propose 4200 XOF pour votre colis.",
      "isRead": false,
      "priority": "high",
      "createdAt": "2026-06-28T13:00:00.000Z"
    }
  ],
  "notifications": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 3,
    "totalPages": 1
  }
}
```

### Nombre non lues

```http
GET /notifications/unread-count
```

Reponse :

```json
{
  "success": true,
  "message": "Nombre de notifications non lues",
  "count": 2,
  "unreadCount": 2
}
```

### Marquer une notification lue

```http
PATCH /notifications/:notificationId/read
```

Payload : aucun.

Reponse :

```json
{
  "success": true,
  "message": "Notification marquee comme lue",
  "updated": 1
}
```

### Tout marquer lu

```http
POST /notifications/read-all
```

Payload : aucun.

Reponse :

```json
{
  "success": true,
  "message": "Notifications marquees comme lues",
  "updated": 3
}
```

## Recherche et ressources communes

Statut : `SPEC`

| Methode | Endpoint | Payload ou query | Reponse |
| --- | --- | --- | --- |
| GET | `/public/drivers/search` | `?city=Dakar&garageId=uuid` | `{ "success": true, "drivers": [] }` |
| GET | `/public/drivers/:driverId` | aucun | `{ "success": true, "driver": {} }` |
| GET | `/public/drivers/garage/:garageId` | aucun | `{ "success": true, "drivers": [] }` |
| GET | `/ratings/driver/:driverId` | `?page=1&limit=20` | `{ "success": true, "ratings": [] }` |
| GET | `/coupons/available` | aucun | `{ "success": true, "coupons": [] }` |
| GET | `/search/parcels` | `?q=PC-20260628&status=delivered` | `{ "success": true, "parcels": [] }` |
