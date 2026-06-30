# Profil Admin Garage

Tous les endpoints de ce fichier utilisent :

```http
Authorization: Bearer <adminAccessToken>
```

L'admin garage ne voit que les ressources liees a son `garageId`.

## Dashboard admin garage

Statut : `SPEC`

```http
GET /garage-admin/stats
```

Reponse :

```json
{
  "success": true,
  "message": "Stats garage",
  "stats": {
    "garageId": "uuid",
    "totalParcels": 25,
    "activeParcels": 8,
    "deliveredToday": 3,
    "activeDrivers": 4,
    "revenue": "250000.00",
    "parcelsByStatus": {
      "pending": 4,
      "in_transit": 2,
      "delivered": 10
    }
  }
}
```

## Profil admin garage

Statut : `SPEC`

```http
PUT /garage-admin/profile
```

Payload :

```json
{
  "fullName": "Admin Garage",
  "email": "admin-garage@example.test",
  "phone": "+221770000606"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Profil mis a jour",
  "user": {}
}
```

## Colis garage

### Lister colis du garage

Statut : `SPEC`

```http
GET /garage-admin/parcels?status=pending&page=1&limit=20
```

Reponse :

```json
{
  "success": true,
  "message": "Colis garage",
  "parcels": [
    {
      "id": "uuid",
      "trackingNumber": "PC-20260628-SEED03",
      "status": "in_transit",
      "departureGarageId": "uuid",
      "arrivalGarageId": "uuid",
      "driverId": "uuid"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 25,
    "totalPages": 2
  }
}
```

### Creer colis depuis garage

Statut : `SPEC`

```http
POST /garage-admin/parcels/create
```

Payload :

```json
{
  "senderName": "Awa Diop",
  "senderPhone": "+221770000001",
  "receiverName": "Mamadou Fall",
  "receiverPhone": "+221770000002",
  "receiverAddress": "Thies",
  "description": "Documents",
  "weight": 1.2,
  "type": "document",
  "departureGarageId": "uuid",
  "arrivalGarageId": "uuid",
  "driverId": "uuid-optionnel",
  "price": 2500,
  "isUrgent": false,
  "isInsured": false,
  "notes": "Cree par admin garage"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Colis cree",
  "parcel": {
    "id": "uuid",
    "trackingNumber": "PC-20260628-A8F2K9",
    "status": "pending"
  }
}
```

### Detail colis garage

Statut : `SPEC`

```http
GET /garage-admin/parcels/:parcelId
```

Reponse :

```json
{
  "success": true,
  "message": "Detail colis",
  "parcel": {
    "id": "uuid",
    "trackingNumber": "PC-20260628-SEED03",
    "status": "in_transit",
    "driver": {},
    "events": []
  }
}
```

### Changer statut colis

Statut : `SPEC`

```http
PUT /garage-admin/parcels/:parcelId/status
```

Payload :

```json
{
  "status": "confirmed",
  "reason": "Valide par le garage",
  "location": "Garage Dakar Test"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Statut mis a jour",
  "parcel": {
    "id": "uuid",
    "status": "confirmed"
  },
  "event": {}
}
```

### Assigner chauffeur

Statut : `SPEC`

```http
PUT /garage-admin/parcels/:parcelId/assign-driver
```

Payload :

```json
{
  "driverId": "uuid",
  "message": "Nouveau colis assigne"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Chauffeur assigne",
  "parcel": {
    "id": "uuid",
    "driverId": "uuid",
    "status": "confirmed"
  }
}
```

### Assignation en masse

Statut : `SPEC`

```http
POST /garage-admin/parcels/bulk-assign
```

Payload :

```json
{
  "driverId": "uuid",
  "parcelIds": ["uuid-1", "uuid-2"],
  "message": "Tournee du matin"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Colis assignes",
  "assigned": 2,
  "failed": []
}
```

### Annuler/supprimer colis garage

Statut : `SPEC`

```http
DELETE /garage-admin/parcels/:parcelId
```

Payload :

```json
{
  "reason": "Erreur de saisie"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Colis annule",
  "parcel": {
    "id": "uuid",
    "status": "cancelled"
  }
}
```

## Chauffeurs du garage

Statut : `SPEC`

```http
GET /garage-admin/drivers?page=1&limit=20&status=available
```

Reponse :

```json
{
  "success": true,
  "message": "Chauffeurs garage",
  "drivers": [
    {
      "id": "uuid",
      "fullName": "Driver Test",
      "phone": "+221770000202",
      "driverStatus": "available",
      "rating": "5.00",
      "totalDeliveries": 12
    }
  ]
}
```

## Vehicules

Statut : `SPEC`

### Creer vehicule

```http
POST /vehicles
```

Payload :

```json
{
  "plateNumber": "DK-2026-PC",
  "model": "Renault Master",
  "type": "van",
  "capacity": 1200,
  "garageId": "uuid",
  "driverId": "uuid-optionnel"
}
```

Reponse :

```json
{
  "success": true,
  "message": "Vehicule cree",
  "vehicle": {
    "id": "uuid",
    "plateNumber": "DK-2026-PC",
    "isAvailable": true
  }
}
```

### Lister vehicules

```http
GET /vehicles?page=1&limit=20
```

Reponse :

```json
{
  "success": true,
  "message": "Vehicules",
  "vehicles": []
}
```

### Changer disponibilite vehicule

```http
PATCH /vehicles/:vehicleId/status
```

Payload :

```json
{
  "isAvailable": false
}
```

Reponse :

```json
{
  "success": true,
  "message": "Vehicule mis a jour",
  "vehicle": {}
}
```

### Supprimer vehicule

```http
DELETE /vehicles/:vehicleId
```

Payload : aucun.

Reponse :

```json
{
  "success": true,
  "message": "Vehicule supprime"
}
```

## Rapports garage

Statut : `SPEC`

| Methode | Endpoint | Query | Reponse |
| --- | --- | --- | --- |
| GET | `/garage-admin/reports/daily` | `?date=2026-06-28` | `{ "success": true, "report": {} }` |
| GET | `/garage-admin/reports/monthly` | `?year=2026&month=6` | `{ "success": true, "report": {} }` |
| GET | `/garage-admin/reports/export` | `?format=json` | `{ "success": true, "data": [] }` |
