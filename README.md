# FoodRush 🍔⚡

Campus food pre-ordering for LPU — order ahead from campus stalls, **skip the line**, and pick up when your queue number is called. No deliveries. Pay by **GCash** (upload your receipt, stall verifies) or **cash at pickup**.

## Stack

| Layer | Tech |
|---|---|
| Frontend | Flutter web (Material 3, responsive) |
| Backend | Firebase — Auth + Cloud Firestore (native realtime) + Storage |
| Routing / state | go_router + flutter_riverpod |
| Hosting | Vercel |

## Roles

- **Student (customer)** — browse verified stalls, order ahead, pay via GCash (receipt upload) or cash, live order tracking with queue number, favorites, order history.
- **Stall owner (vendor)** — live order queue, GCash receipt verification, menu & stock management, own GCash + pickup point settings, own promo codes.
- **Admin** — platform stats, verify stalls, manage users, platform-wide promos, platform GCash fallback number.

## Quick start (local)

1. **Set up Firebase** — follow [`firebase/SETUP.md`](firebase/SETUP.md): create a project + web app, enable Email/Password auth, create Firestore, publish the two rules files.
2. **Run the app:**

```bash
flutter pub get
flutter run -d web-server \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

3. **Make yourself admin** — register in the app, then in Firestore set that user's `role` to `admin` (users collection). Sign out/in and you land on the admin dashboard.

## Deploying to Vercel

The app is a static Flutter web build, so Vercel hosts it natively.

### Option A — GitHub (recommended)

1. Push this repo to GitHub.
2. In Vercel: **Add New → Project** → import the repo.
3. Framework preset: **Other** (the `vercel.json` handles everything).
4. Add **Environment Variables** (all six): `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`.
5. Deploy. Every push to the main branch redeploys automatically.

### Option B — Vercel CLI

```bash
npm i -g vercel
vercel login
export FIREBASE_API_KEY=...
export FIREBASE_PROJECT_ID=...
export FIREBASE_APP_ID=...
export FIREBASE_MESSAGING_SENDER_ID=...
export FIREBASE_AUTH_DOMAIN=...
export FIREBASE_STORAGE_BUCKET=...
vercel --prod
```

## Demo data

See `firebase/SETUP.md` § 8: register `demostall@lpunetwork.edu.ph` as a stall owner, flip `isVerified`/`isOpen` in the Firestore console, add products from the app, and optionally create the `WELCOME10` platform promo doc.

## Project layout

```
lib/
  core/          constants, FirebaseOptions, theme, router
  models/        profile, vendor, product, order, promo models
  providers/     auth controller, repository (all Firebase access), cart
  shared/        responsive shells, reusable widgets
  features/
    auth/        login, register (LPU email gate)
    customer/    shop, stall menu, cart, checkout, tracking, history
    vendor/      dashboard, orders (GCash verification), menu, promos, settings
    admin/       overview, users, stalls, orders, promotions
firebase/        firestore.rules, storage.rules, SETUP.md
scripts/         build.sh (used by Vercel)
vercel.json      SPA rewrites + caching + build config
```

## How the backend is shaped

- **Firestore collections**: `users/{uid}`, `vendors/{id}` (with `products/` and `categories/` subcollections), `orders/{id}` (line items embedded in the order doc), `favorites`, `promotions`, `reviews`, `settings/platform_gcash`, `counters/vendor_{id}` (per-stall daily queue counter).
- **Realtime**: order lists and the tracking page use Firestore snapshots — vendor queue and customer status update live with zero extra plumbing.
- **Atomic ordering**: `placeOrder` runs in a transaction that re-validates every product, decrements stock, and assigns the per-stall daily queue number from a counter doc.

## Security notes

- Access is governed by `firebase/firestore.rules`: customers read verified stalls and only their own orders; vendors manage only their stall's menu and orders; admins (role on the user doc) manage the platform. The role field cannot be self-modified.
- The LPU email gate is enforced in the signup form **and** the Firestore rules on user creation.
- GCash receipts live under `payment-proofs/{uid}/` in Storage — signed-in users (stall staff verifying payments) can read; only the uploader writes into their own folder.
- Passwords are handled entirely by Firebase Auth.
