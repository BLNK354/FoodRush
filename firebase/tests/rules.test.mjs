// Firestore security-rules tests for FoodRush.
//
//   cd firebase/tests && npm install && npm test
//
// Runs against the local emulator (needs Java 21+), never the real project.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, increment, query, serverTimestamp, setDoc,
  Timestamp, updateDoc, where, writeBatch,
} from 'firebase/firestore';

// Like the app's placeOrder: extra writes + the anti-spam lastOrderAt stamp.
function inOrderTxn(f, uid, writes) {
  const b = writeBatch(f);
  writes(b, f);
  b.update(doc(f, 'users', uid), { lastOrderAt: serverTimestamp() });
  return b.commit();
}

let env;
// Signed-in test users have confirmed their email unless a test says so.
const db = (uid, token = { email_verified: true }) =>
  (uid ? env.authenticatedContext(uid, token) : env.unauthenticatedContext()).firestore();
const student = () => db('student1');
const otherStudent = () => db('student2');
const owner = () => db('owner1');
const otherOwner = () => db('owner2');
const admin = () => db('admin1');

const yesterday = Timestamp.fromDate(new Date(Date.now() - 86400000));
const today = Timestamp.fromDate(new Date());

function order(overrides = {}) {
  return {
    customerId: 'student1', vendorId: 'v1', vendorName: 'Kusina',
    status: 'accepted', paymentMethod: 'cash', paymentStatus: 'paid',
    items: [{ productId: 'adobo', name: 'Adobo', unitPrice: 50, qty: 2, lineTotal: 100 }],
    subtotal: 100, discount: 0, total: 100, receiptUrl: null,
    ...overrides,
  };
}

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
      student1: { role: 'customer', email: 's1@lpunetwork.edu.ph', isActive: true },
      student2: { role: 'customer', email: 's2@lpunetwork.edu.ph', isActive: true },
      owner1: { role: 'vendor', email: 'o1@x.com', isActive: true },
      owner2: { role: 'vendor', email: 'o2@x.com', isActive: true },
      admin1: { role: 'admin', email: 'a@x.com', isActive: true },
      banned: { role: 'customer', email: 'b@lpunetwork.edu.ph', isActive: false },
      staffer: { role: 'staff', email: 'staff@x.com', isActive: true },
      stranger: { role: 'staff', email: 'stranger@x.com', isActive: true },
    };
    for (const [id, u] of Object.entries(users)) await setDoc(doc(f, 'users', id), u);
    await setDoc(doc(f, 'vendors/v1'), { ownerId: 'owner1', name: 'Kusina', isVerified: true, isOpen: true, ratingSum: 8, ratingCount: 2,
      staffEmails: ['staff@x.com'], loyaltyEnabled: true, loyaltyStamps: 5, loyaltyReward: 'Free iced tea' });
    await setDoc(doc(f, 'vendors/v2'), { ownerId: 'owner2', name: 'Other', isVerified: true, isOpen: true });
    await setDoc(doc(f, 'vendors/v1/products/adobo'), { name: 'Adobo', price: 50, stockQty: 5, isAvailable: true });
    await setDoc(doc(f, 'orders/o1'), order());
    await setDoc(doc(f, 'orders/o2'), order({ customerId: 'student2', vendorId: 'v2' }));
    await setDoc(doc(f, 'orders/done1'), order({ status: 'completed' }));
    await setDoc(doc(f, 'counters/vendor_v1'), { count: 4, day: today });
  });
});

describe('user profiles', () => {
  test('a student reads their own profile', () => assertSucceeds(getDoc(doc(student(), 'users/student1'))));
  test('...but not someone else\'s', () => assertFails(getDoc(doc(student(), 'users/student2'))));
  test('admins read any profile', () => assertSucceeds(getDoc(doc(admin(), 'users/student2'))));
  test('a deactivated user can still read their own flag', () => assertSucceeds(getDoc(doc(db('banned'), 'users/banned'))));
});

describe('orders: privacy', () => {
  test('a student reads their own order', () => assertSucceeds(getDoc(doc(student(), 'orders/o1'))));
  test('...but not another student\'s', () => assertFails(getDoc(doc(student(), 'orders/o2'))));
  test('a student lists their own orders', () =>
    assertSucceeds(getDocs(query(collection(student(), 'orders'), where('customerId', '==', 'student1')))));
  test('a student cannot list every order', () => assertFails(getDocs(collection(student(), 'orders'))));
  test('a stall reads its own orders', () => assertSucceeds(getDoc(doc(owner(), 'orders/o1'))));
  test('...but not another stall\'s', () => assertFails(getDoc(doc(otherOwner(), 'orders/o1'))));
  test('a stall lists its orders by vendorId', () =>
    assertSucceeds(getDocs(query(collection(owner(), 'orders'), where('vendorId', '==', 'v1')))));
  test('a stall cannot list another stall\'s orders', () =>
    assertFails(getDocs(query(collection(owner(), 'orders'), where('vendorId', '==', 'v2')))));
  test('admins list everything', () => assertSucceeds(getDocs(collection(admin(), 'orders'))));
});

describe('orders: tampering on create', () => {
  const create = (o) => inOrderTxn(student(), 'student1', (b, f) => b.set(doc(f, 'orders/new'), o));
  test('a consistent order is accepted', () => assertSucceeds(create(order())));
  test('a total that does not add up is refused', () => assertFails(create(order({ total: 0 }))));
  test('a discount bigger than the subtotal is refused', () => assertFails(create(order({ discount: 150, total: -50 }))));
  test('placing an order for someone else is refused', () => assertFails(create(order({ customerId: 'student2' }))));
  test('a GCash order cannot start as accepted', () => assertFails(create(order({ paymentMethod: 'gcash' }))));
  test('an empty order is refused', () => assertFails(create(order({ items: [] }))));
  test('a deactivated account cannot order', () =>
    assertFails(inOrderTxn(db('banned'), 'banned', (b, f) => b.set(doc(f, 'orders/new'), order({ customerId: 'banned' })))));
  test('an order without the anti-spam stamp is refused', () =>
    assertFails(setDoc(doc(student(), 'orders/new'), order())));
});

describe('email verification', () => {
  const unverified = () => db('student1', { email_verified: false });
  test('an unverified student cannot order', () =>
    assertFails(inOrderTxn(unverified(), 'student1', (b, f) => b.set(doc(f, 'orders/new'), order()))));
  test('an unverified student cannot review', () =>
    assertFails(setDoc(doc(unverified(), 'reviews/done1'),
      { orderId: 'done1', customerId: 'student1', vendorId: 'v1', rating: 5 })));
  test('a verified student can order', () =>
    assertSucceeds(inOrderTxn(student(), 'student1', (b, f) => b.set(doc(f, 'orders/new'), order()))));
});

describe('student number', () => {
  const fresh = (uid, email) => db(uid, { email, email_verified: true });
  const profile = (email, extra = {}) => ({
    email, role: 'customer', fullName: 'New Student', isActive: true,
    createdAt: serverTimestamp(), ...extra,
  });
  test('a student signs up with a student number', () =>
    assertSucceeds(setDoc(doc(fresh('n1', 'n1@lpunetwork.edu.ph'), 'users/n1'),
      profile('n1@lpunetwork.edu.ph', { studentNumber: '2024-12345' }))));
  test('...but not without one', () =>
    assertFails(setDoc(doc(fresh('n2', 'n2@lpunetwork.edu.ph'), 'users/n2'),
      profile('n2@lpunetwork.edu.ph'))));
  test('...nor with letters in it', () =>
    assertFails(setDoc(doc(fresh('n3', 'n3@lpunetwork.edu.ph'), 'users/n3'),
      profile('n3@lpunetwork.edu.ph', { studentNumber: 'abc-123' }))));
  test('a stall owner signs up without one', () =>
    assertSucceeds(setDoc(doc(fresh('n4', 'n4@stall.com'), 'users/n4'),
      profile('n4@stall.com', { role: 'vendor' }))));
  test('a student cannot blank their student number later', () =>
    assertFails(updateDoc(doc(student(), 'users/student1'), { studentNumber: null })));
  test('...but can correct it', () =>
    assertSucceeds(updateDoc(doc(student(), 'users/student1'), { studentNumber: '2023-00001' })));
});

describe('verification email links (expiry + send counter)', () => {
  const EMAIL = 'v1@lpunetwork.edu.ph';
  const id = (e) => createHash('sha256').update(e.toLowerCase()).digest('hex');
  const me = () => db('vuser', { email: EMAIL, email_verified: false });
  const ref = (f, e = EMAIL) => doc(f, 'verifyLinks', id(e));
  const first = () => ({ sentAt: serverTimestamp(), windowStart: serverTimestamp(), count: 1 });
  const seed = (data) => env.withSecurityRulesDisabled((ctx) => setDoc(ref(ctx.firestore()), data));
  const ago = (s) => Timestamp.fromMillis(Date.now() - s * 1000);

  test('the first send is recorded with the server time', () =>
    assertSucceeds(setDoc(ref(me()), first())));
  test("...but not for someone else's email", () =>
    assertFails(setDoc(ref(me(), 's9@lpunetwork.edu.ph'), first())));
  test('...nor with a made-up send time (to stretch the expiry)', () =>
    assertFails(setDoc(ref(me()), { sentAt: Timestamp.now(), windowStart: serverTimestamp(), count: 1 })));
  test('...nor starting the counter above 1', () =>
    assertFails(setDoc(ref(me()), { ...first(), count: 3 })));
  test('a second send within 60 seconds is refused', async () => {
    await seed({ sentAt: ago(20), windowStart: ago(20), count: 1 });
    await assertFails(setDoc(ref(me()), { sentAt: serverTimestamp(), windowStart: ago(20), count: 2 }));
  });
  test('a later send in the same hour counts up', async () => {
    const w = ago(600);
    await seed({ sentAt: ago(120), windowStart: w, count: 2 });
    await assertSucceeds(setDoc(ref(me()), { sentAt: serverTimestamp(), windowStart: w, count: 3 }));
  });
  test('...but cannot reset the counter mid-hour', async () => {
    const w = ago(600);
    await seed({ sentAt: ago(120), windowStart: w, count: 4 });
    await assertFails(setDoc(ref(me()), { sentAt: serverTimestamp(), windowStart: w, count: 1 }));
  });
  test('a sixth send in one hour is refused', async () => {
    const w = ago(600);
    await seed({ sentAt: ago(120), windowStart: w, count: 5 });
    await assertFails(setDoc(ref(me()), { sentAt: serverTimestamp(), windowStart: w, count: 6 }));
  });
  test('after an hour the counter starts again', async () => {
    await seed({ sentAt: ago(3000), windowStart: ago(3700), count: 5 });
    await assertSucceeds(setDoc(ref(me()), first()));
  });
  test('the email-link page can read the send time while signed out', async () => {
    await seed({ sentAt: ago(30), windowStart: ago(30), count: 1 });
    await assertSucceeds(getDoc(ref(db(null))));
  });
  test('...but nobody can list every record', () =>
    assertFails(getDocs(collection(db(null), 'verifyLinks'))));
  test('nobody signed out can write one', () =>
    assertFails(setDoc(ref(db(null)), first())));
});

describe('branding (admin look editor)', () => {
  const brand = (extra = {}) => ({
    appName: 'FoodRush', tagline: '', primary: '#E23744', accent: '#FF8A00',
    logo: null, loginImage: null, heroImage: null, corner: 'rounded',
    font: 'modern', effects3d: true, animatedBackground: true,
    defaultTheme: 'system', updatedAt: serverTimestamp(), ...extra,
  });
  const ref = (f) => doc(f, 'settings/branding');
  test('an admin saves the look', () => assertSucceeds(setDoc(ref(admin()), brand())));
  test('...with a logo photo', () =>
    assertSucceeds(setDoc(ref(admin()), brand({ logo: 'data:image/jpeg;base64,AAAA' }))));
  test('a student cannot change the look', () => assertFails(setDoc(ref(student()), brand())));
  test('a stall owner cannot either', () => assertFails(setDoc(ref(owner()), brand())));
  test('colours must be real hex colours', () =>
    assertFails(setDoc(ref(admin()), brand({ primary: 'red' }))));
  test('images must be photos, not links or scripts', () =>
    assertFails(setDoc(ref(admin()), brand({ heroImage: 'https://evil.example/x.jpg' }))));
  test('oversized images are refused', () =>
    assertFails(setDoc(ref(admin()), brand({ logo: 'data:image/jpeg;base64,' + 'A'.repeat(160000) }))));
  test('unknown fields are refused', () =>
    assertFails(setDoc(ref(admin()), brand({ css: 'body{display:none}' }))));
  test('only the known corner styles', () =>
    assertFails(setDoc(ref(admin()), brand({ corner: 'blob' }))));
  test('the signed-out login screen can read it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(ref(ctx.firestore()), brand()));
    await assertSucceeds(getDoc(ref(db(null))));
  });
  test('...but not other settings', () =>
    assertFails(getDoc(doc(db(null), 'settings/home'))));
});

describe('profile photos', () => {
  const pic = (extra = {}) => ({ photo: 'data:image/jpeg;base64,AAAA', updatedAt: serverTimestamp(), ...extra });
  const seed = () => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'avatars/student1'), { photo: 'data:image/jpeg;base64,AAAA' }));
  test('a student sets their own photo', () =>
    assertSucceeds(setDoc(doc(student(), 'avatars/student1'), pic())));
  test("...but not someone else's", () =>
    assertFails(setDoc(doc(student(), 'avatars/student2'), pic())));
  test('only JPEG photos, not links', () =>
    assertFails(setDoc(doc(student(), 'avatars/student1'), pic({ photo: 'https://evil.example/a.jpg' }))));
  test('oversized photos are refused', () =>
    assertFails(setDoc(doc(student(), 'avatars/student1'),
      pic({ photo: 'data:image/jpeg;base64,' + 'A'.repeat(100001) }))));
  test('a stall owner sees a customer photo', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(owner(), 'avatars/student1')));
  });
  test('an admin sees it too', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(admin(), 'avatars/student1')));
  });
  test('other students cannot see it', async () => {
    await seed();
    await assertFails(getDoc(doc(db('student2'), 'avatars/student1')));
  });
  test('signed-out visitors cannot see it', async () => {
    await seed();
    await assertFails(getDoc(doc(db(null), 'avatars/student1')));
  });
  test('a student removes their own photo', async () => {
    await seed();
    await assertSucceeds(deleteDoc(doc(student(), 'avatars/student1')));
  });
  test('an admin can remove an inappropriate photo', async () => {
    await seed();
    await assertSucceeds(deleteDoc(doc(admin(), 'avatars/student1')));
  });
  test('a stall owner cannot remove it', async () => {
    await seed();
    await assertFails(deleteDoc(doc(owner(), 'avatars/student1')));
  });
});

describe('account deletion', () => {
  test('a student deletes their own profile', () => assertSucceeds(deleteDoc(doc(student(), 'users/student1'))));
  test('...but not someone else\'s', () => assertFails(deleteDoc(doc(student(), 'users/student2'))));
  test('a student removes their name from their own order', () =>
    assertSucceeds(updateDoc(doc(student(), 'orders/o1'), { customerName: 'Deleted user' })));
  test('...only to "Deleted user"', () =>
    assertFails(updateDoc(doc(student(), 'orders/o1'), { customerName: 'Someone Else' })));
  test('...and nothing else at the same time', () =>
    assertFails(updateDoc(doc(student(), 'orders/o1'), { customerName: 'Deleted user', total: 0 })));
  test('...not on another student\'s order', () =>
    assertFails(updateDoc(doc(student(), 'orders/o2'), { customerName: 'Deleted user' })));
  test('a student removes their name from their own review', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reviews/done1'),
      { orderId: 'done1', customerId: 'student1', vendorId: 'v1', rating: 5, customerName: 'Ana' }));
    await assertSucceeds(updateDoc(doc(student(), 'reviews/done1'), { customerName: 'Deleted user' }));
    await assertFails(updateDoc(doc(student(), 'reviews/done1'), { rating: 1 }));
  });
});

describe('stall staff', () => {
  const staff = () => db('staffer', { email: 'Staff@X.com', email_verified: true });
  const stranger = () => db('stranger', { email: 'stranger@x.com', email_verified: true });
  const unverified = () => db('staffer', { email: 'staff@x.com', email_verified: false });
  test('listed staff see the stall\'s orders', () =>
    assertSucceeds(getDocs(query(collection(staff(), 'orders'), where('vendorId', '==', 'v1')))));
  test('...and move them along', () => assertSucceeds(updateDoc(doc(staff(), 'orders/o1'), { status: 'preparing' })));
  test('...but cannot change an order\'s total', () => assertFails(updateDoc(doc(staff(), 'orders/o1'), { total: 1 })));
  test('...can mark an item sold out', () =>
    assertSucceeds(updateDoc(doc(staff(), 'vendors/v1/products/adobo'), { isAvailable: false })));
  test('...cannot change prices', () => assertFails(updateDoc(doc(staff(), 'vendors/v1/products/adobo'), { price: 1 })));
  test('...cannot edit the stall or the staff list', () =>
    assertFails(updateDoc(doc(staff(), 'vendors/v1'), { staffEmails: ['staff@x.com', 'friend@x.com'] })));
  test('an unlisted staff account sees nothing', () =>
    assertFails(getDocs(query(collection(stranger(), 'orders'), where('vendorId', '==', 'v1')))));
  test('a listed but unverified staff account sees nothing', () =>
    assertFails(getDocs(query(collection(unverified(), 'orders'), where('vendorId', '==', 'v1')))));
  test('staff of one stall cannot touch another', () =>
    assertFails(updateDoc(doc(staff(), 'orders/o2'), { status: 'preparing' })));
});

describe('loyalty stamp cards', () => {
  const card = (f, id = 'v1_student1') => doc(f, 'loyalty', id);
  const stamp = (n) => ({ vendorId: 'v1', customerId: 'student1', stamps: n });
  test('the stall gives a stamp', () => assertSucceeds(setDoc(card(owner()), stamp(1))));
  test('staff can give a stamp too', () =>
    assertSucceeds(setDoc(card(db('staffer', { email: 'staff@x.com', email_verified: true })), stamp(1))));
  test('a student cannot stamp their own card', () => assertFails(setDoc(card(student()), stamp(99))));
  test('another stall cannot stamp this stall\'s card', () => assertFails(setDoc(card(otherOwner()), stamp(1))));
  test('the card id must match stall + student', () => assertFails(setDoc(card(owner(), 'v1_student2'), stamp(1))));
  test('negative stamps are refused', () => assertFails(setDoc(card(owner()), stamp(-3))));
  test('the student reads their own card, not others\'', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(card(ctx.firestore()), stamp(3)));
    await assertSucceeds(getDoc(card(student())));
    await assertFails(getDoc(card(db('student2'))));
  });
});

describe('product add-ons and tags', () => {
  const save = (d) => setDoc(doc(owner(), 'vendors/v1/products/new'), { name: 'Silog', price: 70, isAvailable: true, ...d });
  test('a product with add-ons and tags saves', () =>
    assertSucceeds(save({ addons: [{ name: 'Extra rice', price: 15 }], tags: ['halal', 'spicy'] })));
  test('more than 10 add-ons is refused', () =>
    assertFails(save({ addons: Array.from({ length: 11 }, (_, i) => ({ name: `a${i}`, price: 1 })) })));
});

describe('orders: refunds', () => {
  beforeEach(() => env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), 'orders/o1'), { status: 'proof_submitted', paymentMethod: 'gcash' })));
  test('a student cancelling a paid order may flag the refund owed', () =>
    assertSucceeds(updateDoc(doc(student(), 'orders/o1'), { status: 'cancelled', refundStatus: 'owed' })));
  test('...but never mark it refunded', () =>
    assertFails(updateDoc(doc(student(), 'orders/o1'), { status: 'cancelled', refundStatus: 'refunded' })));
  test('the stall marks it refunded', () =>
    assertSucceeds(updateDoc(doc(owner(), 'orders/o1'), { refundStatus: 'refunded' })));
});

describe('products: stock', () => {
  const adobo = (f) => doc(f, 'vendors/v1/products/adobo');
  // Checkout takes stock in the same transaction that creates the order.
  const checkout = (qty, newStock) => {
    const f = student();
    return inOrderTxn(f, 'student1', (b) => {
      b.set(doc(f, 'orders/new'), order({ stockTaken: { adobo: qty } }));
      b.update(adobo(f), { stockQty: newStock, lastStockOrder: 'new' });
    });
  };
  test('checkout takes exactly the ordered quantity', () => assertSucceeds(checkout(2, 3)));
  test('...not more than ordered', () => assertFails(checkout(2, 0)));
  test('...never below zero', () => assertFails(checkout(6, -1)));
  test('stock cannot change without an order', () => assertFails(updateDoc(adobo(student()), { stockQty: 3 })));
  test('a student cannot change the price', () => assertFails(updateDoc(adobo(student()), { price: 1 })));
  test('the owner changes the price', () => assertSucceeds(updateDoc(adobo(owner()), { price: 55 })));
});

describe('queue counters', () => {
  const counter = (f) => doc(f, 'counters/vendor_v1');
  // Queue numbers move only inside an order transaction (stamped).
  const bump = (data) => inOrderTxn(student(), 'student1', (b, f) => b.set(counter(f), data, { merge: true }));
  test('placing an order bumps the number by one', () => assertSucceeds(bump({ count: 5, day: today })));
  test('jumping the number is refused', () => assertFails(bump({ count: 9, day: today })));
  test('resetting mid-day is refused', () => assertFails(bump({ count: 1, day: today })));
  test('bumping outside an order is refused', () => assertFails(setDoc(counter(student()), { count: 5, day: today })));
  test('a new day restarts at 1', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(counter(ctx.firestore()), { count: 40, day: yesterday }));
    await assertSucceeds(bump({ count: 1, day: today }));
  });
  test('first order after the stall published its queue size', async () => {
    // Regression: the stall's app can create the counter with only
    // `active`; the first student order must still get queue number 1.
    await env.withSecurityRulesDisabled((ctx) => setDoc(counter(ctx.firestore()), { active: 0 }));
    await assertSucceeds(bump({ count: 1, day: today }));
  });
  test('...and that counter cannot jump either', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(counter(ctx.firestore()), { active: 0 }));
    await assertFails(bump({ count: 7, day: today }));
  });
  test('the stall publishes its queue size', () =>
    assertSucceeds(setDoc(counter(owner()), { active: 3 }, { merge: true })));
  test('a student cannot fake the queue size', () =>
    assertFails(setDoc(counter(student()), { active: 0 }, { merge: true })));
  test('another stall cannot either', () =>
    assertFails(setDoc(counter(otherOwner()), { active: 0 }, { merge: true })));
});

describe('reviews', () => {
  const review = (orderId, rating = 5) => ({
    orderId, customerId: 'student1', vendorId: 'v1', rating, comment: 'Sarap', customerName: 'Ana',
  });
  test('rate a completed order, bumping the average in the same batch', async () => {
    const f = student();
    const b = writeBatch(f);
    b.set(doc(f, 'reviews/done1'), review('done1', 4));
    b.update(doc(f, 'vendors/v1'), { ratingSum: increment(4), ratingCount: increment(1), lastReviewId: 'done1' });
    await assertSucceeds(b.commit());
  });
  test('an order not picked up yet cannot be rated', () =>
    assertFails(setDoc(doc(student(), 'reviews/o1'), review('o1'))));
  test('6 stars is refused', () => assertFails(setDoc(doc(student(), 'reviews/done1'), review('done1', 6))));
  test('someone else cannot rate my order', () =>
    assertFails(setDoc(doc(otherStudent(), 'reviews/done1'), { ...review('done1'), customerId: 'student2' })));
  test('the rating aggregates only move by one review', () =>
    assertFails(updateDoc(doc(student(), 'vendors/v1'), { ratingSum: increment(50), ratingCount: increment(1) })));
  test('the owner cannot edit their own rating', () =>
    assertFails(updateDoc(doc(owner(), 'vendors/v1'), { ratingSum: 50 })));

  describe('replies', () => {
    beforeEach(() => env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reviews/done1'), review('done1'))));
    test('the stall replies', () => assertSucceeds(updateDoc(doc(owner(), 'reviews/done1'), { reply: 'Salamat!' })));
    test('...but cannot change the stars', () => assertFails(updateDoc(doc(owner(), 'reviews/done1'), { rating: 1, reply: 'x' })));
    test('another stall cannot reply', () => assertFails(updateDoc(doc(otherOwner(), 'reviews/done1'), { reply: 'x' })));
  });
});

describe('announcements', () => {
  const ann = (f) => doc(f, 'settings/announcement');
  test('admins publish', () => assertSucceeds(setDoc(ann(admin()), { message: 'Closed Friday', active: true })));
  test('students cannot', () => assertFails(setDoc(ann(student()), { message: 'Free food!', active: true })));
  test('everyone signed in reads it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(ann(ctx.firestore()), { message: 'Hi', active: true }));
    await assertSucceeds(getDoc(ann(student())));
  });
});

describe('content (shop CMS)', () => {
  const home = (f) => doc(f, 'settings/home');
  const banner = (f, id = 'b1') => doc(f, 'banners', id);
  const b = (overrides = {}) => ({
    title: 'Silog week', body: '20% off', ctaLabel: 'Order now', link: '/stall/v1',
    imageUrl: null, style: 'ember', active: true, order: 0, ...overrides,
  });
  test('admins edit the hero', () =>
    assertSucceeds(setDoc(home(admin()), { heroTitle: 'Hi', heroSubtitle: '', updatedAt: serverTimestamp() })));
  test('...but not with a novel', () =>
    assertFails(setDoc(home(admin()), { heroTitle: 'x'.repeat(61), heroSubtitle: '' })));
  test('students cannot edit the hero', () =>
    assertFails(setDoc(home(student()), { heroTitle: 'Hacked', heroSubtitle: '' })));
  test('admins add a banner', () => assertSucceeds(setDoc(banner(admin()), b())));
  test('students cannot add banners', () => assertFails(setDoc(banner(student()), b())));
  test('stalls cannot add banners', () => assertFails(setDoc(banner(owner()), b())));
  test('a banner cannot link off-site', () =>
    assertFails(setDoc(banner(admin()), b({ link: 'https://evil.example' }))));
  test('...nor carry a non-image data URL', () =>
    assertFails(setDoc(banner(admin()), b({ imageUrl: 'data:text/html;base64,PHNjcmlwdD4=' }))));
  test('...nor an unknown style', () => assertFails(setDoc(banner(admin()), b({ style: 'neon' }))));
  test('...nor extra fields', () => assertFails(setDoc(banner(admin()), b({ isAdmin: true }))));
  test('a banner needs a title', () => assertFails(setDoc(banner(admin()), b({ title: '' }))));
  test('everyone signed in reads banners; admins reorder and delete', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(banner(ctx.firestore()), b()));
    await assertSucceeds(getDocs(collection(student(), 'banners')));
    await assertFails(getDocs(collection(db(null), 'banners')));
    await assertFails(updateDoc(banner(student()), { order: 3 }));
    await assertSucceeds(updateDoc(banner(admin()), { order: 3 }));
    await assertFails(deleteDoc(banner(student())));
    await assertSucceeds(deleteDoc(banner(admin())));
  });
});
