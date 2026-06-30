# Regles metier

## Numerotation colis

Chaque colis doit avoir un `tracking_number` unique, lisible et court.

Format recommande :

```text
PC-YYYYMMDD-XXXXXX
```

Exemple : `PC-20260628-A8F2K9`.

## Statuts colis

Statuts supportes :

- `pending`
- `free`
- `confirmed`
- `picked_up`
- `in_transit`
- `arrived`
- `out_for_delivery`
- `delivered`
- `cancelled`

Transitions autorisees :

```text
pending -> confirmed
pending -> free
pending -> cancelled
free -> confirmed
free -> cancelled
confirmed -> picked_up
confirmed -> cancelled
picked_up -> in_transit
in_transit -> arrived
arrived -> out_for_delivery
out_for_delivery -> delivered
```

Un `super_admin` peut corriger un statut avec audit obligatoire.

## Creation colis

Regles :

- `senderName`, `senderPhone`, `receiverName`, `receiverPhone`, `description`, `weight`, `departureGarageId` sont obligatoires.
- `arrivalGarageId` est recommande pour les trajets inter-garages.
- Si `isFreeForBidding=true`, le statut initial doit etre `free`.
- Si `driverId` est fourni, le statut initial peut etre `confirmed`.
- Le prix final est calcule depuis `price`, `proposedPrice`, `negotiatedPrice`, frais urgence et assurance.
- Un evenement initial `pending` ou `free` doit etre cree.

## Assignation chauffeur

Un chauffeur peut etre assigne si :

- son role est `driver`.
- son statut utilisateur est `active`.
- son `driver_status` n'est pas `offline`, sauf decision admin.
- il appartient au garage concerne ou est autorise par le super admin.

Lors de l'assignation :

- `parcels.driver_id` est renseigne.
- statut colis passe a `confirmed` si necessaire.
- une notification est envoyee au chauffeur et au client.
- un audit log est cree.

## Colis libre service et offres

Un colis libre service :

- a `is_free_for_bidding=true`.
- a un statut `free`.
- peut recevoir plusieurs offres `bids`.

Une offre :

- est creee par un chauffeur.
- contient `price`, message optionnel et audio optionnel.
- demarre avec statut `pending`.

Acceptation :

- l'offre choisie passe a `accepted`.
- les autres offres passent a `rejected`.
- le chauffeur de l'offre devient `driver_id` du colis.
- le colis passe a `confirmed`.
- `selected_bid_id` et `negotiated_price` sont mis a jour.

Rejet :

- l'offre passe a `rejected`.
- une raison peut etre stockee dans `response_message`.

## Livraison

Chaque changement de statut doit :

- verifier la transition autorisee.
- verifier que l'utilisateur a le droit d'agir.
- creer un `parcel_event`.
- notifier les utilisateurs concernes.
- journaliser les changements sensibles.

Confirmation de livraison :

- requiert idealement photo ou signature.
- renseigne `delivery_date`.
- met le chauffeur `available` si aucun autre colis actif.
- peut crediter des points au client/chauffeur.

## Annulation

Annulation client autorisee seulement si :

- colis `pending`, `free` ou `confirmed` non ramasse.

Annulation admin/super_admin :

- possible plus largement avec raison obligatoire.

L'annulation doit renseigner :

- `cancelled_by`
- `cancellation_reason`
- `cancelled_at`

## Paiements

Methodes :

- `wave`
- `freemMoney` pour compatibilite mobile existante.
- `orange_money`
- `card`
- `cash`

Statuts :

- `pending`
- `processing`
- `completed`
- `failed`
- `refunded`

Regles :

- un paiement doit etre lie a un `user_id`.
- un paiement colis doit etre lie a `parcel_id`.
- confirmer un paiement doit etre idempotent.
- paiement confirme met a jour `payment_status` du colis si applicable.

## Score et wallet

Le score represente un systeme de points.

Regles :

- une transaction de score est append-only.
- le solde peut etre denormalise dans `scores.points`.
- les credits/debits doivent utiliser une transaction DB.
- un debit ne peut pas rendre le solde negatif sauf configuration explicite.

## Notifications

Types :

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

Priorites :

- `low`
- `normal`
- `high`
- `urgent`

## Rapports

Les rapports doivent pouvoir calculer :

- nombre total utilisateurs, clients, chauffeurs, garages, vehicules.
- colis par statut.
- colis livres aujourd'hui.
- revenus total/mois courant/mois precedent.
- performance garages : colis traites, livraisons a temps, note, revenu.
- statistiques journalieres : colis, revenu, chauffeurs actifs.

