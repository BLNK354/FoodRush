# Firebase Setup Guide — FoodRush

## 1. Create the project
1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project**.
2. Name it (e.g. `foodrush`), disable Analytics if you like, **Create**.

## 2. Register a Web app (this gives you the config values)
1. Project overview → **</>** (Web) → nickname `foodrush-web` → **Register app**.
2. Firebase shows the `firebaseConfig` — copy these values:
   - `apiKey` → `FIREBASE_API_KEY`
   - `projectId` → `FIREBASE_PROJECT_ID`
   - `appId` → `FIREBASE_APP_ID`
   - `messagingSenderId` → `FIREBASE_MESSAGING_SENDER_ID`
   - `authDomain` → `FIREBASE_AUTH_DOMAIN`
   - `storageBucket` → `FIREBASE_STORAGE_BUCKET`

## 3. Enable Email/Password auth
**Build → Authentication → Get started → Email/Password → Enable → Save.**

## 4. Create Firestore
**Build → Firestore Database → Create database** → pick a location (e.g.
`asia-southeast1`) → start in **production mode** (our rules take over).

## 5. Publish the security rules
- **Firestore Database → Rules** → paste all of `firebase/firestore.rules` → **Publish**.

> Images (product photos, GCash receipts) are stored **directly in Firestore**
> as compressed data URLs — no Cloud Storage needed, so **no Blaze/billing
> account is required**. The `firebase/storage.rules` file is only relevant if
> you later upgrade to Blaze and want to move images to real Storage.

## 6. Wire the values into the app

### Local development
```bash
flutter run -d web-server \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

### On Vercel
Add all six `FIREBASE_*` variables as **Environment Variables** in the Vercel
project settings (see README → Deploying).

## 7. First admin (automatic)
The **first account ever registered** in the app automatically becomes the
admin — no console editing needed. The window closes permanently the moment
that first signup completes (a marker document in `settings/app_bootstrapped`
makes it impossible to claim admin afterwards, even from the client).

> ⚠️ Register YOUR OWN account first, before anyone else uses the app.

## 8. Demo stall (optional, for testing)
1. Register a **Stall owner** account in the app (any `@lpunetwork.edu.ph` email).
2. Sign in as **admin** → **Stalls** → **Verify** that stall, then open
   **Users** if you need to activate/deactivate accounts.
3. Sign back in as the stall owner → set the stall **Open**, and add
   categories + products under **Menu**. Set **Settings → GCash details**.

## 9. Ordering loop (how to test it end-to-end)
Use three browser profiles (or one normal + one incognito window each):
1. **Stall owner**: verify stall (as admin first), open stall, add products.
2. **Customer**: browse Shop → open stall → add to cart → checkout with
   **Cash** → order appears in the stall's queue with queue number `1`.
3. **Stall owner**: accept → preparing → ready → complete — the customer's
   tracking page updates live at every step.
4. **GCash path**: repeat with GCash checkout — upload a receipt on the
   tracking page, then verify it from the stall's order queue.

## Notes
- The LPU email gate is enforced in two places: the signup form and the
  Firestore rules (`users` create rejects non-campus customer emails).
- Realtime is native to Firestore: vendor order queue, customer tracking,
  and admin order list all update live without any extra setup.
- Composite indexes: none needed — all list queries are equality-only and
  sorted client-side, so the app works immediately after rules are published.
