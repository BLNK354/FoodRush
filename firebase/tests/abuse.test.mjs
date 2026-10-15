// "Hacker" suite: every test is an attack made by calling Firestore directly
// (bypassing the app, as anyone can from browser dev tools). Each one MUST be
// blocked by firestore.rules; a failing test here is a security hole.
//
//   cd firebase/tests && npm run test:abuse
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails, assertSucceeds, initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, increment, setDoc,
  serverTimestamp, Timestamp, updateDoc, writeBatch,
} from 'firebase/firestore';

let env;
const as = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const HUGE = 'x'.repeat(200_000);
const today = Timestamp.fromDate(new Date());

// Like the app's placeOrder: extra writes + the anti-spam lastOrderAt stamp,
// so each attack below is refused for its OWN reason, not a missing stamp.
function inOrderTxn(f, uid, writes) {
  const b = writeBatch(f);
  writes(b, f);
  b.update(doc(f, 'users', uid), { lastOrderAt: serverTimestamp() });
  return b.commit();
}
const order = (uid, id, o) => inOrderTxn(as(uid), uid, (b, f) => b.set(doc(f, 'orders', id), goodOrder(o)));

const goodOrder = (o = {}) => ({
  customerId: 'stu', vendorId: 'v1', vendorName: 'Kusina',
  status: 'accepted', paymentMethod: 'cash', paymentStatus: 'paid',
  items: [{ productId: 'adobo', name: 'Adobo', unitPrice: 50, qty: 1, lineTotal: 50 }],
  subtotal: 50, discount: 0, total: 50, receiptUrl: null, ...o,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-foodrush',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const users = {
      stu: { role: 'customer', email: 'stu@lpunetwork.edu.ph', fullName: 'Stu', isActive: true },
      stu2: { role: 'customer', email: 'stu2@lpunetwork.edu.ph', fullName: 'Stu Two', isActive: true },
      own: { role: 'vendor', email: 'own@x.com', fullName: 'Owner', isActive: true },
      own2: { role: 'vendor', email: 'own2@x.com', fullName: 'Owner Two', isActive: true },
      adm: { role: 'admin', email: 'adm@x.com', fullName: 'Admin', isActive: true },
    };
    for (const [id, u] of Object.entries(users)) await setDoc(doc(f, 'users', id), u);
    await setDoc(doc(f, 'settings/app_bootstrapped'), { at: today });
    await setDoc(doc(f, 'vendors/v1'), { ownerId: 'own', name: 'Kusina', isVerified: true, isOpen: true, ratingSum: 8, ratingCount: 2 });
    await setDoc(doc(f, 'vendors/v2'), { ownerId: 'own2', name: 'Other', isVerified: true, isOpen: true });
    await setDoc(doc(f, 'vendors/closed'), { ownerId: 'own2', name: 'Closed', isVerified: true, isOpen: false });
    await setDoc(doc(f, 'vendors/pending'), { ownerId: 'own', name: 'Pending', isVerified: false, isOpen: false });
    await setDoc(doc(f, 'vendors/v1/products/adobo'), { vendorId: 'v1', name: 'Adobo', price: 50, stockQty: 20, isAvailable: true });
    await setDoc(doc(f, 'orders/mine'), goodOrder());
    await setDoc(doc(f, 'orders/mine_gcash'), goodOrder({ status: 'awaiting_payment', paymentMethod: 'gcash', paymentStatus: 'unpaid' }));
    await setDoc(doc(f, 'orders/done'), goodOrder({ status: 'completed' }));
    await setDoc(doc(f, 'promotions/p1'), { vendorId: 'v1', code: 'KUSINA10', discountType: 'percent', discountValue: 10, isActive: true });
  });
});

// ----------------------------------------------------------------- strangers
describe('signed-out visitor', () => {
  test('cannot read stalls', () => assertFails(getDocs(collection(as(null), 'vendors'))));
  test('cannot read orders', () => assertFails(getDoc(doc(as(null), 'orders/mine'))));
  test('cannot write anything', () => assertFails(setDoc(doc(as(null), 'vendors/hack'), { ownerId: 'x' })));
});

// ------------------------------------------------------------------- student
describe('student: privilege escalation', () => {
  test('cannot make themself admin', () => assertFails(updateDoc(doc(as('stu'), 'users/stu'), { role: 'admin' })));
  test('cannot reactivate/deactivate themself', () => assertFails(updateDoc(doc(as('stu'), 'users/stu'), { isActive: false })));
  test('cannot sign up as admin after bootstrap', () =>
    assertFails(setDoc(doc(as('newbie'), 'users/newbie'), { role: 'admin', email: 'n@lpunetwork.edu.ph', fullName: 'N', isActive: true })));
  test('cannot sign up as a student with a non-LPU email', () =>
    assertFails(setDoc(doc(as('newbie'), 'users/newbie'), { role: 'customer', email: 'n@gmail.com', fullName: 'N', isActive: true })));
  test('cannot change their email field to a non-LPU one', () =>
    assertFails(updateDoc(doc(as('stu'), 'users/stu'), { email: 'evil@gmail.com' })));
  test('cannot write someone else\'s profile', () => assertFails(updateDoc(doc(as('stu'), 'users/stu2'), { fullName: 'pwned' })));
  test('cannot create a stall', () => assertFails(setDoc(doc(as('stu'), 'vendors/mine'), { ownerId: 'stu', name: 'x', isVerified: false })));
  test('cannot create promos', () => assertFails(setDoc(doc(as('stu'), 'promotions/free'), { code: 'FREE', discountType: 'percent', discountValue: 100, isActive: true })));
  test('cannot post announcements', () => assertFails(setDoc(doc(as('stu'), 'settings/announcement'), { message: 'hacked', active: true })));
  test('cannot change the platform GCash number', () => assertFails(setDoc(doc(as('stu'), 'settings/platform_gcash'), { number: '0999' })));
});

describe('student: junk data', () => {
  test('cannot save a 200 KB name', () => assertFails(updateDoc(doc(as('stu'), 'users/stu'), { fullName: HUGE })));
  test('cannot save a 200 KB phone', () => assertFails(updateDoc(doc(as('stu'), 'users/stu'), { phone: HUGE })));
  test('cannot add random fields to their profile', () => assertFails(updateDoc(doc(as('stu'), 'users/stu'), { isVerified: true, junk: HUGE })));
  test('cannot write a 200 KB order note', () => assertFails(order('stu', 'new', { note: HUGE })));
  test('cannot write a 200 KB review', () =>
    assertFails(setDoc(doc(as('stu'), 'reviews/done'), { orderId: 'done', customerId: 'stu', vendorId: 'v1', rating: 5, comment: HUGE })));
  test('cannot spam favorites with random ids', async () => {
    const f = as('stu');
    await assertFails(setDoc(doc(f, 'favorites/spam1'), { customerId: 'stu', vendorId: 'v1' }));
  });
});

describe('student: money & stock', () => {
  test('cannot order from a closed stall', () => assertFails(order('stu', 'new', { vendorId: 'closed' })));
  test('can place one normal order', () => assertSucceeds(order('stu', 'ok1')));
  test('cannot place orders back-to-back (spam)', async () => {
    await assertSucceeds(order('stu', 'spam1'));
    await assertFails(order('stu', 'spam2'));
  });
  test('cannot fake the stamp to skip the wait', async () => {
    await assertSucceeds(order('stu', 'spam1'));
    await assertFails(updateDoc(doc(as('stu'), 'users/stu'), { lastOrderAt: Timestamp.fromMillis(0) }));
  });
  test('cannot take stock from a stall with a fake order', () =>
    assertFails(inOrderTxn(as('stu'), 'stu', (b, f) => {
      b.set(doc(f, 'orders/fake'), goodOrder({ stockTaken: { adobo: 1 } }));
      b.update(doc(f, 'vendors/v1/products/adobo'), { stockQty: 0, lastStockOrder: 'fake' });
    })));
  test('cannot order without the anti-spam stamp', () => assertFails(setDoc(doc(as('stu'), 'orders/new'), goodOrder())));
  test('cannot raise a stall\'s stock', () => assertFails(updateDoc(doc(as('stu'), 'vendors/v1/products/adobo'), { stockQty: 99999 })));
  test('cannot zero out a stall\'s stock without an order', () =>
    assertFails(updateDoc(doc(as('stu'), 'vendors/v1/products/adobo'), { stockQty: 0 })));
  test('cannot change their order while cancelling it', () =>
    assertFails(updateDoc(doc(as('stu'), 'orders/mine_gcash'), { status: 'cancelled', total: 0, vendorId: 'v2' })));
  test('cannot mark their own order completed', () => assertFails(updateDoc(doc(as('stu'), 'orders/mine'), { status: 'completed' })));
  test('cannot upload a 900 KB "receipt"', () =>
    assertFails(updateDoc(doc(as('stu'), 'orders/mine_gcash'), {
      status: 'proof_submitted', receiptUrl: 'data:' + 'x'.repeat(900_000), receiptStatus: 'pending', paymentStatus: 'pending_verification' })));
  test('cannot delete orders', () => assertFails(deleteDoc(doc(as('stu'), 'orders/mine'))));
});

describe('student: fake ratings', () => {
  test('cannot bump a stall\'s rating without writing a review', () =>
    assertFails(updateDoc(doc(as('stu'), 'vendors/v1'), { ratingSum: increment(5), ratingCount: increment(1) })));
  test('cannot pair a 1-star review with +5 on the average', async () => {
    const f = as('stu');
    const b = writeBatch(f);
    b.set(doc(f, 'reviews/done'), { orderId: 'done', customerId: 'stu', vendorId: 'v1', rating: 1 });
    b.update(doc(f, 'vendors/v1'), { ratingSum: increment(5), ratingCount: increment(1), lastReviewId: 'done' });
    await assertFails(b.commit());
  });
  test('a genuine review still works', async () => {
    const f = as('stu');
    const b = writeBatch(f);
    b.set(doc(f, 'reviews/done'), { orderId: 'done', customerId: 'stu', vendorId: 'v1', rating: 4 });
    b.update(doc(f, 'vendors/v1'), { ratingSum: increment(4), ratingCount: increment(1), lastReviewId: 'done' });
    await assertSucceeds(b.commit());
  });
  test('cannot reuse an old review to bump again', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'reviews/done'), { orderId: 'done', customerId: 'stu', vendorId: 'v1', rating: 5 }));
    await assertFails(updateDoc(doc(as('stu'), 'vendors/v1'), { ratingSum: increment(5), ratingCount: increment(1), lastReviewId: 'done' }));
  });
});

// --------------------------------------------------------------- stall owner
describe('stall owner', () => {
  const product = (f, d) => setDoc(doc(f, 'vendors/v1/products/new'), { vendorId: 'v1', name: 'Item', price: 10, stockQty: 5, isAvailable: true, ...d });
  test('cannot verify their own stall', () => assertFails(updateDoc(doc(as('own'), 'vendors/pending'), { isVerified: true })));
  test('cannot take over another stall', () => assertFails(updateDoc(doc(as('own'), 'vendors/v2'), { name: 'mine now' })));
  test('cannot set a negative price', () => assertFails(product(as('own'), { price: -50 })));
  test('cannot set a zero price', () => assertFails(product(as('own'), { price: 0 })));
  test('cannot set an absurd price', () => assertFails(product(as('own'), { price: 1e12 })));
  test('cannot set negative stock', () => assertFails(product(as('own'), { stockQty: -5 })));
  test('cannot save a 200 KB product name', () => assertFails(product(as('own'), { name: HUGE })));
  test('a normal product still saves', () => assertSucceeds(product(as('own'), {})));
  test('cannot write a 200 KB stall description', () => assertFails(updateDoc(doc(as('own'), 'vendors/v1'), { description: HUGE })));
  test('cannot turn their promo into a platform-wide one', () =>
    assertFails(updateDoc(doc(as('own'), 'promotions/p1'), { vendorId: null })));
  test('cannot move their promo to another stall', () =>
    assertFails(updateDoc(doc(as('own'), 'promotions/p1'), { vendorId: 'v2' })));
  test('cannot create a 1000% promo', () =>
    assertFails(setDoc(doc(as('own'), 'promotions/big'), { vendorId: 'v1', code: 'BIG', discountType: 'percent', discountValue: 1000, isActive: true })));
  test('cannot create a negative promo', () =>
    assertFails(setDoc(doc(as('own'), 'promotions/neg'), { vendorId: 'v1', code: 'NEG', discountType: 'fixed', discountValue: -100, isActive: true })));
  test('cannot rewrite who placed an order', () => assertFails(updateDoc(doc(as('own'), 'orders/mine'), { customerId: 'stu2' })));
  test('cannot rewrite an order\'s total', () => assertFails(updateDoc(doc(as('own'), 'orders/mine'), { total: 9999 })));
  test('can still move an order along', () => assertSucceeds(updateDoc(doc(as('own'), 'orders/mine'), { status: 'preparing' })));
  test('cannot read student profiles', () => assertFails(getDoc(doc(as('own'), 'users/stu'))));
  test('cannot write a 200 KB review reply', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'reviews/done'), { orderId: 'done', customerId: 'stu', vendorId: 'v1', rating: 5 }));
    await assertFails(updateDoc(doc(as('own'), 'reviews/done'), { reply: HUGE }));
  });
});

// --------------------------------------------------------------------- admin
describe('admin', () => {
  test('cannot reopen the first-admin bootstrap', () => assertFails(deleteDoc(doc(as('adm'), 'settings/app_bootstrapped'))));
  test('cannot post a 200 KB announcement', () => assertFails(setDoc(doc(as('adm'), 'settings/announcement'), { message: HUGE, active: true })));
  test('can still post a normal announcement', () => assertSucceeds(setDoc(doc(as('adm'), 'settings/announcement'), { message: 'Closed Friday', active: true, level: 'info' })));
});
