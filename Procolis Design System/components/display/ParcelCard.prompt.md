The product's signature card — shows one colis as a route with status, tracking number and price.

```jsx
<ParcelCard
  parcel={{ tracking: 'PC-7F3K-2291', from: 'Abidjan', to: 'Bouaké',
            status: 'transit', price: '12 500 FCFA', weight: '8 kg',
            type: 'Colis standard', eta: '~4 h', express: true }}
  onClick={openParcel}
  footer={<Button block variant="secondary">Suivre</Button>}
/>
```

Pass pre-formatted strings (price/weight) — the card doesn't format. `express` adds the red » chevron. Use the `footer` slot for a primary action or the offer count in libre-service lists.
