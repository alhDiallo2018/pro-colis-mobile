Primary action control — use for every committed action; labels are imperative French verbs ("Créer le colis", "Faire une offre").

```jsx
<Button variant="primary" icon="add" onClick={createParcel}>Nouveau colis</Button>
<Button variant="secondary">Annuler</Button>
<Button variant="amber" icon="account_balance_wallet">Recharger</Button>
<Button variant="ghost" iconTrailing="chevron_right">Voir tout</Button>
<Button variant="danger" icon="cancel">Annuler le colis</Button>
<Button block loading>Envoi…</Button>
```

Variants: `primary` (teal, the default CTA), `secondary` (outline), `ghost` (text), `danger` (red, destructive), `amber` (points/recharge). Sizes `sm | md | lg`. Use `block` for full-width mobile CTAs. `icon` / `iconTrailing` take Material Symbols names.
