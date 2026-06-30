# Notifications

## Objectif

Le backend doit produire des notifications persistantes en base. Les notifications push peuvent etre ajoutees ensuite, mais la base `notifications` est obligatoire des le MVP.

## Types

- `bid_created`
- `bid_accepted`
- `bid_rejected`
- `parcel_status`
- `parcel_created`
- `driver_assigned`
- `delivery_confirmed`
- `message`
- `system`
- `info`

## Evenements generateurs

Creation colis :

- notifier client si colis cree par chauffeur/admin.
- notifier garage de depart si utile.

Assignation chauffeur :

- notifier chauffeur.
- notifier client.

Offre creee :

- notifier client proprietaire du colis.

Offre acceptee/rejetee :

- notifier chauffeur.

Changement statut colis :

- notifier client.
- notifier admin garage selon statut.

Livraison confirmee :

- notifier client.
- notifier admin garage.
- notifier chauffeur si score/recompense.

Paiement confirme :

- notifier utilisateur.

Message support :

- notifier admins concernes.

## Payload notification

```json
{
  "id": "uuid",
  "userId": "uuid",
  "parcelId": "uuid",
  "bidId": "uuid",
  "senderId": "uuid",
  "senderName": "PRO COLIS",
  "type": "parcel_status",
  "title": "Colis en transit",
  "body": "Votre colis PC-20260628-A8F2K9 est en transit.",
  "data": {
    "trackingNumber": "PC-20260628-A8F2K9",
    "status": "in_transit"
  },
  "isRead": false,
  "priority": "normal",
  "createdAt": "2026-06-28T12:00:00.000Z"
}
```

## Endpoints

- `GET /notifications?page=1&limit=20`
- `GET /notifications/unread-count`
- `PATCH /notifications/:notificationId/read`
- `POST /notifications/read-all`
- `DELETE /notifications/:notificationId`
- `DELETE /notifications/all`

## Autorisations

Un utilisateur ne peut manipuler que ses propres notifications.

Un `super_admin` peut consulter les notifications systeme si un endpoint admin dedie est ajoute.

