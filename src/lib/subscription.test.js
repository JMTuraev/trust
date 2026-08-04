// SUBSCRIPTION REGRESSION LOCK (PRODUCT RULE, PO 2026-07-28) — offline, DB'siz.
// Yurgizish (repo ildizidan):  node --test src/lib/subscription.test.js
//
// Qulflanadigan qoida:
//   - Qarzdor/kontragent HECH QACHON paket olmaydi: ko'rish, confirm/reject,
//     repay/settle — hammaga bepul.
//   - YANGI qarz yozuvi kvotasi faqat DAFTAR EGASIga hisoblanadi (egasi premium
//     bo'lsa kontragent bepul yozadi; egasi kvotadan chiqsa 402 OWNER_SUB_EXPIRED).
//   - Pul qaytishi (repay/settle/confirm) HECH QACHON obuna bilan bloklanmaydi.
// Middleware'lar stub DB bilan tekshiriladi (__setDbForTests) — jonli Supabase yo'q.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  computeSubscription, requireActiveSub, requireNewDebtQuota,
  FREE_DEBT_ENTRIES, __setDbForTests,
} from './subscription.js';
import debtsRouter from '../routes/debts.js';

const OWNER = 'owner-1';
const CP = 'cp-1';
const PARTNER = 'partner-1';
const FUTURE = new Date(Date.now() + 30 * 86400000).toISOString();

// ---- Stub supabase: chainable builder, thenable — respond(q) natijasini qaytaradi ----
function fakeDb(respond) {
  return {
    from(tableName) {
      const q = { table: tableName, filters: [] };
      const b = {
        select(cols, opts) { q.cols = cols; q.opts = opts; return b; },
        eq(col, val) { q.filters.push(['eq', col, val]); return b; },
        neq(col, val) { q.filters.push(['neq', col, val]); return b; },
        in(col, val) { q.filters.push(['in', col, val]); return b; },
        not(col, op, val) { q.filters.push(['not', col, op, val]); return b; },
        gte(col, val) { q.filters.push(['gte', col, val]); return b; },
        lt(col, val) { q.filters.push(['lt', col, val]); return b; },
        limit(n) { q.limit = n; return b; },
        order() { return b; },
        maybeSingle() { return Promise.resolve(respond(q)); },
        then(ok, err) { return Promise.resolve(respond(q)).then(ok, err); },
      };
      return b;
    },
  };
}

/** Tipik stsenariy: bitta daftar (PARTNER, egasi OWNER), egasining premium/kvota holati. */
function scenario({ premiumUntil = null, deletedAt = null, debtCount = 0, opCount = 0 } = {}) {
  return fakeDb((q) => {
    if (q.table === 'partners') {
      const byId = q.filters.find((f) => f[0] === 'eq' && f[1] === 'id');
      if (byId) return byId[2] === PARTNER ? { data: { id: PARTNER, owner_id: OWNER } } : { data: null };
      return { data: [{ id: PARTNER }] }; // countOwnerDebts: egasining daftarlari
    }
    if (q.table === 'profiles') {
      return { data: { id: OWNER, premium_until: premiumUntil, deleted_at: deletedAt, created_at: '2026-01-01' } };
    }
    if (q.table === 'debts') return { count: debtCount, data: null };
    if (q.table === 'operations') return { count: opCount, data: null };
    if (q.table === 'expenses') return { count: 0, data: null };
    return { data: null };
  });
}

/** Middleware'ni oxirigacha yugurtiradi: next chaqirildimi yoki res.json yozildimi. */
function runMw(mw, req) {
  return new Promise((resolve, reject) => {
    const res = {
      statusCode: 200,
      status(c) { res.statusCode = c; return res; },
      json(b) { res.body = b; resolve({ res, nextCalled: false }); return res; },
    };
    mw(req, res, (err) => (err ? reject(err) : resolve({ res, nextCalled: true })));
  });
}

const asOwner = { user: { id: OWNER }, params: { partnerId: PARTNER }, method: 'POST' };
const asCp = { user: { id: CP }, params: { partnerId: PARTNER }, method: 'POST' };

test.afterEach(() => __setDbForTests(null)); // har testdan keyin real db qaytadi

// ============ computeSubscription — vaqt bo'yicha blok YO'Q ============
test('computeSubscription — free ham, premium ham can_write=true (vaqt-gate olib tashlangan)', () => {
  const free = computeSubscription({ premium_until: null });
  assert.equal(free.status, 'free');
  assert.equal(free.can_write, true);
  const prem = computeSubscription({ premium_until: FUTURE });
  assert.equal(prem.status, 'premium');
  assert.equal(prem.can_write, true);
});

// ============ requireNewDebtQuota — kvota faqat DAFTAR EGASIga ============
test('egasi premium -> KONTRAGENT bepul yozadi (next)', async () => {
  __setDbForTests(scenario({ premiumUntil: FUTURE, debtCount: 999999 }));
  const { nextCalled } = await runMw(requireNewDebtQuota, asCp);
  assert.equal(nextCalled, true);
});

test('egasi kvota ichida (free) -> egasi ham, kontragent ham yozadi', async () => {
  __setDbForTests(scenario({ debtCount: 0, opCount: 0 }));
  assert.equal((await runMw(requireNewDebtQuota, asOwner)).nextCalled, true);
  assert.equal((await runMw(requireNewDebtQuota, asCp)).nextCalled, true);
});

test('egasi kvotadan chiqqan, EGASI yozmoqchi -> 402 SUB_EXPIRED', async () => {
  __setDbForTests(scenario({ debtCount: FREE_DEBT_ENTRIES }));
  const { res, nextCalled } = await runMw(requireNewDebtQuota, asOwner);
  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 402);
  assert.equal(res.body.code, 'SUB_EXPIRED');
});

test('egasi kvotadan chiqqan, KONTRAGENT yozmoqchi -> 402 OWNER_SUB_EXPIRED (SUB_EXPIRED emas!)', async () => {
  __setDbForTests(scenario({ debtCount: FREE_DEBT_ENTRIES }));
  const { res, nextCalled } = await runMw(requireNewDebtQuota, asCp);
  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 402);
  assert.equal(res.body.code, 'OWNER_SUB_EXPIRED'); // mobil "MENING obunam tugadi" demasin
});

test('kvota debts+operations YIG\'INDISI bo\'yicha (audit 2026-08-02)', async () => {
  __setDbForTests(scenario({ debtCount: FREE_DEBT_ENTRIES - 1, opCount: 1 }));
  const { res, nextCalled } = await runMw(requireNewDebtQuota, asOwner);
  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 402);
});

test('hamkor topilmasa middleware bloklamaydi (handler 404 beradi)', async () => {
  __setDbForTests(scenario({}));
  const req = { user: { id: OWNER }, params: { partnerId: 'yo-q' }, method: 'POST' };
  assert.equal((await runMw(requireNewDebtQuota, req)).nextCalled, true);
});

// ============ requireActiveSub — pass-through (faqat o'chirilgan profil 403) ============
test('requireActiveSub GET -> DB\'ga tegmasdan next', async () => {
  __setDbForTests(fakeDb(() => { throw new Error('GET DB\'ga tegmasligi kerak'); }));
  const { nextCalled } = await runMw(requireActiveSub, { user: { id: CP }, method: 'GET' });
  assert.equal(nextCalled, true);
});

test('requireActiveSub — kvotasi TUGAGAN free foydalanuvchi ham o\'tadi (repay bloklanmasin)', async () => {
  // debtCount ulkan — baribir next: bu middleware kvotaga umuman qaramaydi
  __setDbForTests(scenario({ debtCount: 10_000_000 }));
  const { nextCalled } = await runMw(requireActiveSub, asCp);
  assert.equal(nextCalled, true);
});

test('requireActiveSub — o\'chirilgan profil 403', async () => {
  __setDbForTests(scenario({ deletedAt: new Date().toISOString() }));
  const { res, nextCalled } = await runMw(requireActiveSub, asOwner);
  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 403);
});

// ============ ROUTE WIRING LOCK — debts routeri qaysi middleware bilan ulangan ============
function mwNames(path, method = 'post') {
  return debtsRouter.stack
    .filter((l) => l.route && l.route.path === path && l.route.methods[method])
    .flatMap((l) => l.route.stack.map((s) => s.handle.name));
}

test('YANGI qarz yozuvi requireNewDebtQuota bilan gate qilinadi', () => {
  assert.ok(mwNames('/:partnerId').includes('requireNewDebtQuota'),
    'POST /api/debts/:partnerId kvotasiz qoldi — paywall ishlamaydi!');
});

test('repay/settle KVOTA bilan gate qilinMAYDI (pul qaytishi hech qachon bloklanmaydi)', () => {
  for (const path of ['/:partnerId/repay', '/:partnerId/settle']) {
    const names = mwNames(path);
    assert.ok(!names.includes('requireNewDebtQuota'), `${path} kvota bilan bloklangan!`);
    assert.ok(!names.includes('requireNewOpQuota'), `${path} kvota bilan bloklangan!`);
    assert.ok(!names.includes('requireExpenseQuota'), `${path} kvota bilan bloklangan!`);
  }
});

test('confirm/reject/cancel va op/edit/review tasdiqlari obuna middleware\'siz OCHIQ', () => {
  const paths = ['/:id/confirm', '/:id/reject', '/:id/cancel', '/:id/confirm-op',
    '/:id/reject-op', '/:id/edit-confirm', '/:id/edit-reject',
    '/:partnerId/review-confirm', '/:id/review-reject'];
  for (const path of paths) {
    const names = mwNames(path);
    assert.ok(names.length > 0, `${path} topilmadi — route ko'chirilganmi?`);
    for (const banned of ['requireActiveSub', 'requireNewDebtQuota', 'requireNewOpQuota', 'requireExpenseQuota']) {
      assert.ok(!names.includes(banned), `${path} '${banned}' bilan gate qilingan — tasdiq/rad bepul bo'lishi SHART`);
    }
  }
});
