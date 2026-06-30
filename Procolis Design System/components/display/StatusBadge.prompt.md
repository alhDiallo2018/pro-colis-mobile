Canonical badge for a parcel's lifecycle status — never hand-roll status colors, always use this.

```jsx
<StatusBadge status="transit" />
<StatusBadge status="free" size="sm" />
<StatusBadge status="delivered" showIcon={false} />
```

Statuses: `pending` (En attente), `free` (Libre service), `confirmed` (Confirmé), `pickup` (Ramassé), `transit` (En transit), `arrived` (Arrivé), `delivering` (En livraison), `delivered` (Livré), `cancelled` (Annulé). Set `showIcon={false}` for a compact dot variant. `PARCEL_STATUS` exports the label/icon map.
