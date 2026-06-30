# UI Kit — Mobile App (Client)

Interactive recreation of the **PRO COLIS** client mobile app, built from the components in this design system.

**Open `index.html`** — a 390×800 phone frame with a working click-through:

- **LoginScreen** — phone → OTP (4-digit) → or PIN keypad. Any digits advance to Home.
- **HomeScreen** — brand-gradient hero with the points wallet, quick actions, KPIs, recent parcels.
- **MesColisScreen** — parcel list with En cours / Livrés / Annulés tabs.
- **NewParcelScreen** — colis creation form (trajet, destinataire, colis, options, price summary).
- **TrackScreen** — tracking hero, driver card, lifecycle Stepper, actions.
- **LibreServiceScreen** — segmented: *Mes offres reçues* (client, with voice-note offers) / *Colis à prendre* (driver pool, "Faire une offre").
- **NotificationsScreen**, **ProfileScreen**.

Files: `mock.js` (fake data), `screens-main.jsx` (Login, Home, MesColis, NewParcel), `screens-detail.jsx` (Track, LibreService, Notifications, Profile). All compose `window.ProcolisDesignSystem_1720b4` components — they don't re-implement primitives.

> Reconstruction from the cahier des charges + brand, **not** a pixel copy of the live Flutter UI. Language: French. The lifecycle and libre-service bidding are the documented mechanics.
