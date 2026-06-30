# Procolis Design System

> The brand & UI system for **PRO COLIS** — a Flutter platform for interurban parcel ("colis") delivery across West/Central-African cities. This system encodes Procolis's brand, foundations, components and product screens so any agent can design on-brand interfaces and assets.

---

## 1. Product context

**Procolis** ("Pro Colis") is a multi-sided logistics marketplace that moves parcels **between cities** (interurbain). Four roles share one app:

| Role | What they do | Key screens |
|---|---|---|
| **Client** | Declare a parcel, set the route & price, publish to *libre service*, accept/refuse driver offers, track delivery. | ClientDashboard, NewParcelScreen, TrackParcelScreen, FreeParcelsScreen, ProfileScreen |
| **Chauffeur** (driver) | Browse free parcels, bid (price + message + voice note), run delivery steps, update statuses with location. | DriverDashboard, FreeParcelsForDriversScreen, ParcelDetailScreen |
| **Admin Garage** | Oversee one garage's parcels & drivers, assign missions, read reports. | GarageAdminDashboard, GarageAdminDriversScreen |
| **Super Admin** | Govern users, garages, parcels, stats, system health, config. | SuperAdminDashboard, UsersManagementScreen, StatsScreen |

The product centers on the **parcel lifecycle**:
`en attente → libre service → confirmé → ramassé → en transit → arrivé → en livraison → livré` (or `annulé`). This lifecycle drives the **status color palette** (see Visual Foundations) — it is the most important domain concept in the whole UI.

Distinctive mechanics: **OTP + PIN** auth, a **bidding / libre-service** marketplace, **voice messages** attached to offers, **proof-of-delivery** media, and a **points/score** wallet.

### Sources given
- `uploads/Cahier_des_charges_PRO_COLIS_existant.docx` — functional & technical spec reverse-engineered from the existing Flutter codebase (extracted to `uploads/cahier_des_charges_text.txt`).
- `uploads/logo-procolis-carre.png` — the square brand mark (copied to `assets/logo-procolis.png`).
- **No source code or Figma was provided.** The original UI is a Flutter app (Material, flutter_riverpod, Dio). These foundations and screens are therefore an *on-brand, domain-faithful reconstruction* derived from the documented screens + the brand mark — **not** a pixel copy of the live app. See CAVEATS at the bottom.

Language: the product UI is **French**. Default all copy to French.

---

## 2. Content fundamentals — how Procolis writes

**Language:** French, throughout. Métier vocabulary is fixed and should never be translated or invented around:
- *colis* (parcel), *chauffeur* (driver), *garage* (the local hub/depot a driver belongs to), *expéditeur* / *destinataire* (sender / recipient), *trajet* (route), *libre service* (the open-bidding pool), *offre* (a driver's bid), *suivi* (tracking), *points* (the wallet currency).

**Tone:** clear, operational, reassuring. This is a logistics tool people rely on to move things that matter — copy is **plain and action-first**, never playful or salesy. Think "Suivi en temps réel", not "Watch the magic happen ✨".

**Voice / person:**
- Address the user with **vous** (formal-neutral) in instructions and buttons: *"Suivez votre colis"*, *"Confirmez l'offre"*.
- Refer to the user's own things with possessives: *"Mes colis"*, *"Mes offres"*, *"Mon garage"*.

**Casing:** Sentence case for everything — headings, buttons, labels. *"Nouveau colis"*, not "Nouveau Colis". The ONLY uppercase is small overline/eyebrow labels and status chips (e.g. `EN TRANSIT`, `LIBRE SERVICE`), tracked wide.

**Buttons:** imperative verb first — *"Créer le colis"*, *"Faire une offre"*, *"Mettre en libre service"*, *"Marquer comme livré"*. Avoid bare nouns on primary CTAs.

**Numbers & codes:**
- Tracking numbers, prices, weights and PINs are **monospace** (JetBrains Mono). Tracking format reads like `PC-7F3K-2291`.
- Currency: amounts shown as `12 500 FCFA` (space thousands separator, currency after). Points shown as `+150 pts`.

**Emoji:** none in product UI. (Material icons carry all iconographic meaning.)

**Empty / error states:** always offer a next action. Per the spec, the app must show explicit empty/error/loading states and never loop — so empty states read e.g. *"Aucun colis en libre service pour le moment"* + a primary action.

---

## 3. Visual foundations

The mark is an isometric **parcel cube** whose faces sweep from **green → teal → deep blue-teal**, wrapping an amber **"C"** pierced by **red express chevrons** (»). That mark dictates everything:

**Color**
- **Primary = teal `#018982`.** It owns primary buttons, active nav, links, focus rings, selected states.
- **Green `#0FA958`** = motion / "en route" / success-of-progress. **Amber `#FCA202`** = the points wallet, highlights, secondary emphasis. **Red `#E5240F`** = *express/urgent* and destructive only — used sparingly, like the chevrons.
- The **signature gradient** `linear-gradient(135deg, green → teal → deep-blue)` appears on hero headers, the balance/score card, the splash, and large brand surfaces — never behind body text.
- Neutrals are a **cool slate** ramp (tuned slightly teal), not pure gray. Page background is `--slate-50` (#F6F8F8), cards are white.
- **Parcel-status palette** is a first-class system: each lifecycle state has `-fg / -bg / -dot` tokens (amber pending, blue libre-service, teal confirmed, violet pickup, green transit, cyan arrived, orange delivering, green delivered, red cancelled). Use `StatusBadge` — never hand-roll status colors.

**Type** — Display **Plus Jakarta Sans** (headings, numbers, buttons, overlines), Body **Manrope** (paragraphs, list rows), Mono **JetBrains Mono** (tracking/prices/PIN). Headings are bold/extrabold with slightly tight tracking; overlines are uppercase, tracked `0.08em`.

**Shape & depth**
- Corner radii are generous and friendly: inputs/cards `14px` (`--radius-md`), feature cards & sheets `20px`, chips/avatars/pills fully round. Nothing is sharp-cornered.
- **Cards** = white, `--radius-md/lg`, hairline `--border-subtle` *or* a soft shadow (not both heavy). Shadows are **soft, low-spread, cool-tinted** (`rgba(11,70,79,…)`) — clean logistics, not heavy material elevation. Primary buttons and the FAB carry a colored teal glow (`--shadow-brand`).
- Borders are `1px` hairlines in `--slate-200`; `2px` only for focus/selected.

**Backgrounds** — flat slate page, white cards, and the brand gradient for hero/score surfaces. No photographic backgrounds, no noise/grain, no decorative patterns. Optional faint `--gradient-brand-soft` tint behind a hero section is the most decoration we use.

**Motion** — purposeful and quick. `--dur-base 200ms` with `--ease-standard` for most; `--ease-out` for sheets/entrances. Status changes can pulse the status dot. No bounces on content, no infinite decorative loops. Respect `prefers-reduced-motion`.

**Interaction states**
- **Hover** (web/admin): primary darkens one step (`--color-primary-hover`); ghost/secondary get a `--surface-sunken` wash.
- **Press** (mobile): subtle scale-down (`transform: scale(0.97)`) + darken. Tap targets ≥ `44px`.
- **Focus:** 3px teal ring (`--ring-focus`), always visible for keyboard/admin.
- **Selected:** teal `2px` border + `--teal-50` fill.
- **Disabled:** `--slate-200` surface, `--slate-400` text, no shadow.

**Layout** — mobile-first, single column, side gutters `16px`, content capped at `440px` for the app frame. Fixed top header `56px` and bottom tab bar `64px`; a circular FAB for "Nouveau colis". Admin surfaces are wide multi-column dashboards on the same tokens.

---

## 4. Iconography

The live product is a **Flutter / Material app**, so the authentic icon set is **Material Icons**. This system standardizes on **Material Symbols Rounded** (Google Fonts) — the rounded optical match to Flutter's default Material icons, consistent with our generous corner radii.

- **Load:** `<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,400,0,0&display=swap" rel="stylesheet">`
- **Use:** `<span class="material-symbols-rounded">local_shipping</span>`; add class `fill` for the filled/active variant. Default weight 400, 24px; nav-active and emphasis use FILL 1.
- **Common glyphs:** `local_shipping` (transit), `inventory_2` / `package_2` (colis), `pin_drop` / `route` (trajet), `gavel` / `sell` (offre/bid), `mic` (voice message), `verified` (proof), `account_balance_wallet` (points), `qr_code_2` (tracking), `notifications`, `person`, `garage`, `directions_car` (vehicle).
- **Emoji / unicode:** not used as icons. The only non-Material glyph is the brand **»** express chevron motif, which may appear as a typographic accent (e.g. on the "Express/Urgent" tag) echoing the logo.
- **Substitution flag:** Material Symbols is a faithful stand-in for Flutter's Material Icons; if the production app uses custom SVGs, drop them into `assets/icons/` and document here.

---

## 5. Index / manifest

**Root**
- `styles.css` — global entry (imports only). Consumers link this.
- `readme.md` — this file.
- `SKILL.md` — Agent-Skill wrapper.

**`tokens/`** — `fonts.css`, `colors.css`, `typography.css`, `spacing.css`, `base.css` (all reached via `styles.css`).

**`assets/`** — `logo-procolis.png` (square brand mark).

**`guidelines/`** — foundation specimen cards (Colors, Type, Spacing, Brand) shown in the Design System tab.

**`components/core/`** — reusable React primitives, namespace `window.ProcolisDesignSystem_1720b4`:
`Button`, `IconButton`, `Icon`, `Input`, `Select`, `Textarea`, `Checkbox`, `Switch`, `SegmentedControl`, `Card`, `StatBox`, `Badge`, `StatusBadge`, `Tag`, `Avatar`, `Tabs`, `ListRow`, `ParcelCard`, `Stepper`, `Dialog`, `Toast`, `EmptyState`, `AppBar`, `TabBar`, `Fab`.

**`ui_kits/`**
- `mobile-app/` — client/driver mobile screens (dashboard, new parcel, track, libre service, profile).
- `admin/` — garage / super-admin dashboard.

**`templates/`** — seedable starting frames for consuming projects (DC format).
- `colis-screen/` — "Mes colis" phone screen (brand hero + ParcelCards + FAB).

---

## CAVEATS
- **No codebase or Figma was provided** — only the spec doc + logo. Screens are an on-brand reconstruction of the *documented* views, not a pixel copy of the live Flutter UI. If you can share the Flutter repo or a Figma, I'll align the kits exactly.
- **Fonts** (Plus Jakarta Sans / Manrope / JetBrains Mono) are loaded from Google Fonts CDN, not self-hosted binaries. These are my best-match picks for the brand's geometric, modern feel — confirm or send the real brand fonts and I'll swap them in.
- **Logo:** only a square raster mark was supplied; there's no horizontal wordmark or vector. A proper SVG logo + wordmark lockup would sharpen every header.
