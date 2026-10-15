// Seeds the LOCAL emulators (never the live project) with throwaway test
// accounts and a verified stall, for clicking through the app by hand:
//
//   firebase emulators:start --only "auth,firestore" --project demo-foodrush
//   node seed-emulator.mjs
//   flutter run -d web-server --dart-define=USE_EMULATORS=true \
//     --dart-define=FIREBASE_PROJECT_ID=demo-foodrush
//
// Test logins (emulator only): see ACCOUNTS below.
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, Timestamp } from 'firebase/firestore';

const PROJECT = 'demo-foodrush';
const AUTH = 'http://127.0.0.1:9099';
const PASSWORD = 'emulator-only-pass-1';

export const ACCOUNTS = {
  admin: { email: 'admin@foodrush.test', name: 'Test Admin', role: 'admin' },
  owner: { email: 'owner@foodrush.test', name: 'Test Owner', role: 'vendor' },
  student: { email: 'student@lpunetwork.edu.ph', name: 'Test Student', role: 'customer' },
};

async function signUp(email) {
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: PASSWORD, returnSecureToken: true }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`${email}: ${JSON.stringify(body)}`);
  return body.localId;
}

// Start clean so the script can be re-run.
await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
const env = await initializeTestEnvironment({
  projectId: PROJECT,
  firestore: { host: '127.0.0.1', port: 8085 },
});
await env.clearFirestore();

const uid = {};
for (const [key, a] of Object.entries(ACCOUNTS)) uid[key] = await signUp(a.email);

await env.withSecurityRulesDisabled(async (ctx) => {
  const f = ctx.firestore();
  for (const [key, a] of Object.entries(ACCOUNTS)) {
    await setDoc(doc(f, 'users', uid[key]), {
      email: a.email, role: a.role, fullName: a.name, isActive: true, createdAt: Timestamp.now(),
    });
  }
  await setDoc(doc(f, 'settings/app_bootstrapped'), { bootstrappedAt: Timestamp.now() });
  await setDoc(doc(f, 'vendors/teststall'), {
    ownerId: uid.owner, name: 'Test Kusina', description: 'Emulator stall',
    isVerified: true, isOpen: true, prepMinutes: 10, createdAt: Timestamp.now(),
  });
  const items = [
    ['adobo', 'Chicken Adobo', 85, 5],
    ['sisig', 'Pork Sisig', 95, null],
    ['iced-tea', 'Iced Tea', 25, 40],
  ];
  for (const [id, name, price, stockQty] of items) {
    await setDoc(doc(f, `vendors/teststall/products/${id}`), {
      vendorId: 'teststall', name, price, stockQty, isAvailable: true, createdAt: Timestamp.now(),
    });
  }
});
await env.cleanup();
console.log('Seeded emulator accounts:', Object.values(ACCOUNTS).map((a) => a.email).join(', '));
