# UI Kit — Admin Console (Garage)

Recreation of the **PRO COLIS** web console used by garage admins (and, broadly, super admins) — the Flutter-web surface served by Nginx in the spec.

**Open `index.html`** — a desktop layout (~1280 wide):

- **Sidebar** — brand lockup + nav (Tableau de bord, Colis, Chauffeurs, Garages, Statistiques, Rapports, Paramètres) on the dark slate-900 rail, admin identity pinned to the bottom.
- **Top bar** — page title, global search, notifications, "Nouveau colis".
- **Dashboard** — 4 KPI tiles (colis ce mois, en transit, en attente, chauffeurs actifs), a recent-colis **table** with status badges + "Assigner" for unassigned parcels, a 12-month volume chart, and a **drivers** panel with live availability. The "Chauffeurs" nav item swaps to a full-width drivers view.

`mock.js` holds the fake parcels/drivers/KPIs. The view composes `window.ProcolisDesignSystem_1720b4` components (StatBox, StatusBadge, Badge, Avatar, Button, IconButton).

> Reconstruction from the cahier des charges + brand. The table/assignment flow reflects the documented garage-admin capabilities (suivi des colis, assignation des chauffeurs, rapports).
