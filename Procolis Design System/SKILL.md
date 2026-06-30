---
name: procolis-design
description: Use this skill to generate well-branded interfaces and assets for Procolis (PRO COLIS), the interurban parcel-delivery platform, either for production or throwaway prototypes/mocks. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the `readme.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick map
- `readme.md` — full brand guide: product context, content fundamentals (French, vous, métier vocabulary), visual foundations, iconography (Material Symbols Rounded), and a file index.
- `styles.css` — single global entry point (link this); imports `tokens/*` (colors, typography, spacing, fonts, base).
- `tokens/colors.css` — brand scales, semantic aliases, and the **parcel-status palette** (`--status-<state>-fg/bg/dot`), the most important domain system.
- `components/` — React primitives, exported on `window.ProcolisDesignSystem_1720b4` from the compiled `_ds_bundle.js`. Key ones: `Button`, `StatusBadge` + `PARCEL_STATUS`, `ParcelCard`, `Stepper`, `StatBox`, `AppBar`, `TabBar`, `Fab`, plus forms & feedback.
- `ui_kits/mobile-app/` — interactive client app (login/OTP/PIN, dashboard, new colis, suivi, libre service, profil).
- `ui_kits/admin/` — garage/super-admin web console (KPIs, colis table, assignations, chauffeurs).
- `guidelines/*.html` — foundation specimen cards.

## Non-negotiables
- **French** copy, **vous**, sentence case; imperative button verbs ("Créer le colis"). Keep métier terms: colis, chauffeur, garage, expéditeur/destinataire, trajet, libre service, offre, suivi, points.
- Primary = teal `#018982`. Use the signature green→teal→deep-blue gradient only on hero/score surfaces. Red = express/urgent + destructive, used sparingly (echoes the » chevrons).
- Tracking numbers, prices, weights, PIN in **JetBrains Mono**. Prices as `12 500 FCFA`, points as `+150 pts`.
- Parcel state → always `StatusBadge` / the `--status-*` tokens. Never hand-roll status colors.
- Icons = **Material Symbols Rounded** (matches the Flutter Material set). No emoji as icons.

## To render a component card / kit standalone
Link `styles.css` + the Material Symbols stylesheet, load React/Babel + `_ds_bundle.js`, then `const { X } = window.ProcolisDesignSystem_1720b4`. See any file under `components/*/*.card.html` for the exact pattern.
