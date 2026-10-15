// Temporary end-to-end replay of the app's real write flows (mirrors
// Repository.placeOrder / cancelOrder / reviewPayment / submitReview).
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, increment, runTransaction, serverTimestamp, setDoc, Timestamp,
  updateDoc, writeBatch,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-foodrush',
  firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
});
const now = new Date();
const dayStart = Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth(), now.getDate()));
const rows = [];
const log = (step, ok, extra = '') => rows.push({ step, result: ok ? 'OK' : 'REFUSED', extra });

async function seed(counter) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    // A legacy-style profile (no lastOrderAt yet, odd empty name) must still work.
    await setDoc(doc(f, 'users/cust'), { role: 'customer', email: 'c@lpunetwork.edu.ph', fullName: '', isActive: true });
    await setDoc(doc(f, 'users/vend'), { role: 'vendor', email: 'v@x.com', fullName: 'V', isActive: true });
    await setDoc(doc(f, 'vendors/v1'), { ownerId: 'vend', name: 'Potato Corner', isVerified: true, isOpen: true, ratingSum: 0, ratingCount: 0 });
    await setDoc(doc(f, 'vendors/v1/products/fries'), { vendorId: 'v1', name: 'Fries', price: 100, stockQty: 10, isAvailable: true });
    await setDoc(doc(f, 'vendors/v1/products/drink'), { vendorId: 'v1', name: 'Drink', price: 50, stockQty: null, isAvailable: true });
    if (counter === 'sameDay') await setDoc(doc(f, 'counters/vendor_v1'), { count: 3, day: dayStart });
    if (counter === 'oldDay') await setDoc(doc(f, 'counters/vendor_v1'), { count: 9, day: Timestamp.fromMillis(dayStart.toMillis() - 864e5) });
    if (counter === 'activeOnly') await setDoc(doc(f, 'counters/vendor_v1'), { active: 2, activeAt: Timestamp.now() });
  });
}

async function placeOrder(id, lines, payment = 'cash') {
  const f = env.authenticatedContext('cust').firestore();
  await runTransaction(f, async (tx) => {
    const counterRef = doc(f, 'counters/vendor_v1');
    const c = await tx.get(counterRef);
    const userRef = doc(f, 'users/cust');
    await tx.get(userRef);
    const prods = [];
    for (const [pid, qty] of lines) {
      const ref = doc(f, `vendors/v1/products/${pid}`);
      prods.push([ref, pid, (await tx.get(ref)).data(), qty]);
    }
    const day = c.data()?.day;
    const sameDay = day && day.toMillis() === dayStart.toMillis();
    const queue = (sameDay ? (c.data().count ?? 0) : 0) + 1;
    const stockTaken = {};
    let subtotal = 0;
    const items = [];
    for (const [ref, pid, p, qty] of prods) {
      if (p.stockQty != null) {
        stockTaken[pid] = qty;
        tx.update(ref, { stockQty: p.stockQty - qty, lastStockOrder: id });
      }
      subtotal += p.price * qty;
      items.push({ productId: pid, name: p.name, unitPrice: p.price, qty, lineTotal: p.price * qty, stockTracked: p.stockQty != null });
    }
    tx.update(userRef, { lastOrderAt: serverTimestamp() });
    tx.set(counterRef, { count: queue, day: dayStart }, { merge: true });
    tx.set(doc(f, 'orders', id), {
      orderNumber: 'FR-1', customerId: 'cust', customerName: '', vendorId: 'v1', vendorName: 'Potato Corner',
      subtotal, discount: 0, total: subtotal,
      status: payment === 'cash' ? 'accepted' : 'awaiting_payment', paymentMethod: payment,
      paymentStatus: payment === 'cash' ? 'paid' : 'unpaid', promoCode: null, note: null,
      queueNumber: queue, pickupAt: null, receiptUrl: null, receiptStatus: null, receiptNote: null,
      createdAt: serverTimestamp(), items, stockTaken,
    });
  });
}

// cancel/reject: release stockTaken with increment + lastStockOrder, same batch.
async function endOrder(uid, id, patch) {
  const f = env.authenticatedContext(uid).firestore();
  const o = (await getDoc(doc(f, 'orders', id))).data();
  const b = writeBatch(f);
  if (!o.stockReleased) {
    for (const [pid, qty] of Object.entries(o.stockTaken ?? {})) {
      b.update(doc(f, `vendors/v1/products/${pid}`), { stockQty: increment(qty), lastStockOrder: id });
    }
  }
  b.update(doc(f, 'orders', id), { ...patch, stockReleased: true });
  await b.commit();
}

const stock = async () => {
  let v;
  await env.withSecurityRulesDisabled(async (ctx) => {
    v = (await getDoc(doc(ctx.firestore(), 'vendors/v1/products/fries'))).data().stockQty;
  });
  return v;
};

async function attempt(step, fn, extra) {
  try { await fn(); log(step, true, extra ? await extra() : ''); }
  catch (e) { log(step, false, e.code ?? e.message); }
}

for (const counter of ['none', 'sameDay', 'oldDay', 'activeOnly']) {
  await seed(counter);
  await attempt(`[${counter}] checkout fries x2 + drink x1`, () => placeOrder('o1', [['fries', 2], ['drink', 1]]),
    async () => `fries stock now ${await stock()}`);
}

await seed('none');
await attempt('checkout drink only (unlimited)', () => placeOrder('o1', [['drink', 3]]));
await attempt('second order right away (should be REFUSED)', () => placeOrder('o2', [['drink', 1]]));

await seed('none');
await attempt('gcash checkout fries x3', () => placeOrder('g1', [['fries', 3]], 'gcash'), async () => `stock ${await stock()}`);
await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'orders/g1'), { status: 'proof_submitted' }));
await attempt('student cancels after paying (refund owed)', () => endOrder('cust', 'g1', { status: 'cancelled', refundStatus: 'owed' }),
  async () => `stock back to ${await stock()}`);
await attempt('student cancels again (should be REFUSED)', () => endOrder('cust', 'g1', { status: 'cancelled' }));

await seed('none');
await attempt('gcash checkout fries x4', () => placeOrder('g2', [['fries', 4]], 'gcash'), async () => `stock ${await stock()}`);
await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'orders/g2'), { status: 'proof_submitted' }));
await attempt('stall rejects the receipt', () => endOrder('vend', 'g2', {
  status: 'rejected', paymentStatus: 'unpaid', receiptStatus: 'rejected', receiptNote: 'Fake', rejectReason: 'Fake' }),
  async () => `stock back to ${await stock()}`);

await seed('none');
await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'orders/done'), {
  customerId: 'cust', vendorId: 'v1', status: 'completed', items: [], subtotal: 1, discount: 0, total: 1 }));
await attempt('student reviews a picked-up order', async () => {
  const f = env.authenticatedContext('cust').firestore();
  const b = writeBatch(f);
  b.set(doc(f, 'reviews/done'), { orderId: 'done', customerId: 'cust', vendorId: 'v1', rating: 4, comment: 'Masarap!',
    customerName: '', createdAt: serverTimestamp() });
  b.update(doc(f, 'vendors/v1'), { ratingSum: increment(4), ratingCount: increment(1), lastReviewId: 'done' });
  await b.commit();
});
await attempt('stall replies to it', () =>
  updateDoc(doc(env.authenticatedContext('vend').firestore(), 'reviews/done'), { reply: 'Salamat po!', repliedAt: serverTimestamp() }));
await attempt('stall publishes queue size', () =>
  setDoc(doc(env.authenticatedContext('vend').firestore(), 'counters/vendor_v1'), { active: 1, activeAt: serverTimestamp() }, { merge: true }));

console.table(rows);
await env.cleanup();
