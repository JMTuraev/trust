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

// ============================================================
// MODUL OBUNALARI (PO 2026-08-04) — har modul alohida oylik obuna.
// Qulflanadigan qoida:
//   - Eski $9 premium = BARCHA modullarga kirish (grandfather, muddati tugaguncha).
//   - Modul obunasi FAQAT o'z modulini ochadi (qarz obunasi xarajatni ochmaydi).
//   - 020 migratsiya qo'llanmagan bo'lsa (module_subs jadvali yo'q) — backend
//     yiqilmaydi, "obuna yo'q" deb ishlaydi (deploy tartibi: kod avval, migratsiya keyin).
//   - 402 javobida `module` bo'ladi — mobil AYNAN o'sha modul paywall'ini ochadi.
// ============================================================
import { isModuleActive, getModulesStatus, requireExpenseQuota, MODULES } from './subscription.js';

const PAST = new Date(Date.now() - 86400000).toISOString();

/** Modul stsenariysi: legacy premium + module_subs qatorlari (yoki jadval yo'qligi). */
function modScenario({ premiumUntil = null, rows = [], missingTable = false, expenses = 0, debts = 0, bookings = 0, missingBookings = false } = {}) {
  return fakeDb((q) => {
    if (q.table === 'module_subs') {
      if (missingTable) {
        return { data: null, error: { code: '42P01', message: 'relation "module_subs" does not exist' } };
      }
      return { data: rows };
    }
    if (q.table === 'profiles') {
      return { data: { id: OWNER, premium_until: premiumUntil, deleted_at: null, created_at: '2026-01-01' } };
    }
    if (q.table === 'partners') {
      // scenario() bilan bir xil: id bo'yicha so'rov -> daftar egasi; aks holda egasining daftarlari
      const byId = q.filters.find((f) => f[0] === 'eq' && f[1] === 'id');
      if (byId) return byId[2] === PARTNER ? { data: { id: PARTNER, owner_id: OWNER } } : { data: null };
      return { data: [{ id: PARTNER }] };
    }
    if (q.table === 'debts') return { count: debts, data: null };
    if (q.table === 'operations') return { count: 0, data: null };
    if (q.table === 'expenses') return { count: expenses, data: null };
    if (q.table === 'bookings') {
      return missingBookings
        ? { count: null, error: { code: '42P01', message: 'relation "bookings" does not exist' } }
        : { count: bookings, data: null };
    }
    return { data: null };
  });
}

test('MODUL — eski premium BARCHA modullarni ochadi (grandfather)', async () => {
  __setDbForTests(modScenario({ premiumUntil: FUTURE }));
  for (const m of Object.keys(MODULES)) {
    assert.equal(await isModuleActive(OWNER, m), true, `${m} premium bilan ochilmadi`);
  }
});

test('MODUL — obuna FAQAT o\'z modulini ochadi', async () => {
  __setDbForTests(modScenario({ rows: [{ module: 'qarz', active_until: FUTURE }] }));
  assert.equal(await isModuleActive(OWNER, 'qarz'), true);
  assert.equal(await isModuleActive(OWNER, 'xarajat'), false, 'qarz obunasi xarajatni ochib yubordi!');
});

test('MODUL — muddati o\'tgan obuna faol emas', async () => {
  __setDbForTests(modScenario({ rows: [{ module: 'xarajat', active_until: PAST }] }));
  assert.equal(await isModuleActive(OWNER, 'xarajat'), false);
});

test('MODUL — 020 migratsiya yo\'q: backend yiqilmaydi, "obuna yo\'q" deb ishlaydi', async () => {
  __setDbForTests(modScenario({ missingTable: true }));
  assert.equal(await isModuleActive(OWNER, 'qarz'), false);
  const st = await getModulesStatus(OWNER);
  assert.equal(st.length, 4);
  assert.ok(st.every((m) => m.active === false));
});

test('MODUL — getModulesStatus shakli (mobil kontrakt) va narxlar', async () => {
  __setDbForTests(modScenario({ rows: [{ module: 'xarajat', active_until: FUTURE }], expenses: 2, debts: 7 }));
  const st = await getModulesStatus(OWNER);
  const by = Object.fromEntries(st.map((m) => [m.module, m]));
  assert.deepEqual(Object.keys(by).sort(), ['ijarachi', 'qarz', 'toyxona', 'xarajat']);
  for (const m of st) {
    for (const k of ['module', 'active', 'active_until', 'soon', 'price_usd', 'product_id', 'used', 'free_limit']) {
      assert.ok(k in m, `${m.module} javobida '${k}' yo'q — mobil kontrakt buzildi`);
    }
  }
  assert.equal(by.xarajat.price_usd, 5);
  assert.equal(by.qarz.price_usd, 8);
  assert.equal(by.ijarachi.price_usd, 13);
  assert.equal(by.toyxona.price_usd, 24);
  // Kelajak modullar "soon", sotib olinmagan
  // PO 2026-08-04: Ijaradagi uylar va To'yxona ham OCHIQ menyu (soon YO'Q) — xarajat/qarz kabi
  assert.equal(by.ijarachi.soon, false);
  assert.equal(by.toyxona.soon, false);
  assert.equal(by.xarajat.soon, false);
  // Obuna qoplaydigan obyektlar soni QAT'IY: to'yxona 1 ta zal, ijara 5 ta uy.
  // (Ko'proq kerak bo'lsa — alohida raqamga alohida ro'yxatdan o'tish; PO qarori.)
  assert.equal(MODS.toyxona.max_units, 1);
  assert.equal(MODS.ijarachi.max_units, 5);
  // Ishlatilgan: xarajat -> expenses, qarz -> daftar egasi bo'yicha debts+operations
  assert.equal(by.xarajat.used, 2);
  assert.equal(by.qarz.used, 7);
  assert.equal(by.xarajat.active, true);
  assert.ok(by.xarajat.active_until, 'faol modulda active_until bo\'lishi kerak');
  assert.equal(by.qarz.active, false);
  assert.equal(by.qarz.active_until, null);
});

test('MODUL — xarajat kvotasi: obuna bo\'lsa o\'tadi, bo\'lmasa 402 + module maydoni', async () => {
  // Obuna bor -> kvota tugagan bo'lsa ham o'tadi
  __setDbForTests(modScenario({ rows: [{ module: 'xarajat', active_until: FUTURE }], expenses: 9999 }));
  const ok = await runMw(requireExpenseQuota, { user: { id: OWNER }, method: 'POST' });
  assert.equal(ok.nextCalled, true, 'xarajat obunasi bilan yozuv bloklandi!');

  // Obuna yo'q va kvota tugagan -> 402, mobil uchun module maydoni bilan
  __setDbForTests(modScenario({ expenses: 9999 }));
  const no = await runMw(requireExpenseQuota, { user: { id: OWNER }, method: 'POST' });
  assert.equal(no.nextCalled, false);
  assert.equal(no.res.statusCode, 402);
  assert.equal(no.res.body.code, 'SUB_EXPIRED');
  assert.equal(no.res.body.module, 'xarajat', '402 javobida module yo\'q — mobil qaysi paywallni ochishni bilmaydi');
  assert.match(no.res.body.error, /\$5\/oy/, 'xabarda modul narxi ($5) ko\'rsatilmagan');
});

test('MODUL — qarz kvotasi 402 javobi module:qarz va $8 narx bilan', async () => {
  __setDbForTests(modScenario({ debts: 9999 }));
  const r = await runMw(requireNewDebtQuota, { user: { id: OWNER }, params: { partnerId: PARTNER } });
  assert.equal(r.res.statusCode, 402);
  assert.equal(r.res.body.module, 'qarz');
  assert.match(r.res.body.error, /\$8\/oy/);
});

// ---- 020 QO'LLANMAGAN: kvota MAJBURLANMAYDI (xavfsizlik klapani, review 2026-08-04 #4) ----
// Sabab: jadval yo'q -> grantModule 409 -> obunani SOTIB BO'LMAYDI. Agar kvota baribir
// majburlansa (FREE_*=5 bilan), foydalanuvchilar to'lash imkoniyatisiz qulflanib qolardi.
import { __resetModuleSubsReady } from './subscription.js';

test('MODUL — 020 yo\'q va kvota tugagan: yozuv BLOKLANMAYDI (to\'lash yo\'li yo\'q ekan)', async () => {
  __resetModuleSubsReady();
  __setDbForTests(modScenario({ missingTable: true, expenses: 9999, debts: 9999 }));
  const x = await runMw(requireExpenseQuota, { user: { id: OWNER }, method: 'POST' });
  assert.equal(x.nextCalled, true, '020 yo\'q, lekin xarajat bloklandi — foydalanuvchi qulfda qoladi!');
  const d = await runMw(requireNewDebtQuota, { user: { id: OWNER }, params: { partnerId: PARTNER } });
  assert.equal(d.nextCalled, true, '020 yo\'q, lekin qarz bloklandi — foydalanuvchi qulfda qoladi!');
  __resetModuleSubsReady();
});

test('MODUL — 020 BOR va kvota tugagan: odatdagidek 402 (klapan faqat jadval yo\'qligida)', async () => {
  __resetModuleSubsReady();
  __setDbForTests(modScenario({ expenses: 9999 }));
  const r = await runMw(requireExpenseQuota, { user: { id: OWNER }, method: 'POST' });
  assert.equal(r.res.statusCode, 402);
  assert.equal(r.res.body.module, 'xarajat');
  __resetModuleSubsReady();
});

// ---- Xarid marshrutlash: product_id KLIENTDAN OLINMAYDI (review 2026-08-04 #1) ----
// Mobil faqat `module` kalitini yuboradi; SKU serverdagi katalogdan olinadi. Shu sabab
// arzon modul cheki bilan qimmat modulni ochib bo'lmaydi (chek AYNAN shu SKU bo'yicha
// tekshiriladi). Bo'sh modul = eski $9 premium yo'li (orqaga moslik).
import { productIdForModule, PREMIUM_PRODUCT_ID, MODULES as MODS } from './subscription.js';

test('XARID — module yubormaydigan eski mobil premium yo\'liga tushadi', () => {
  assert.equal(productIdForModule(''), PREMIUM_PRODUCT_ID);
  assert.equal(productIdForModule(null), PREMIUM_PRODUCT_ID);
  assert.equal(productIdForModule(undefined), PREMIUM_PRODUCT_ID);
});

test('XARID — har modul O\'Z SKU\'si bilan tekshiriladi', () => {
  assert.equal(productIdForModule('xarajat'), 'trust_xarajat_monthly');
  assert.equal(productIdForModule('qarz'), 'trust_qarz_monthly');
  assert.equal(productIdForModule('ijarachi'), 'trust_ijarachi_monthly');
  assert.equal(productIdForModule('toyxona'), 'trust_toyxona_monthly');
  // Katalog bilan sinxron (yangi modul qo'shilsa shu test uni ushlaydi)
  for (const [m, cfg] of Object.entries(MODS)) {
    assert.equal(productIdForModule(m), cfg.product_id);
  }
});

test('XARID — noma\'lum modul null (chaqiruvchi 400 beradi), premiumga TUSHMAYDI', () => {
  assert.equal(productIdForModule('hack'), null);
  assert.equal(productIdForModule('__proto__'), null);
  assert.notEqual(productIdForModule('hack'), PREMIUM_PRODUCT_ID);
});

// ---- To'plamli xarajat kvotasi (review 2026-08-04 #12): "5 bepul" 9 ga aylanmasin ----
import { expenseQuotaBlock, FREE_EXPENSE_ENTRIES } from './subscription.js';

test('KVOTA — 4/5 da turgan user 5 ta amallik to\'plam yubora olmaydi (5 bepul = 5)', async () => {
  __resetModuleSubsReady();
  __setDbForTests(modScenario({ expenses: FREE_EXPENSE_ENTRIES - 1 }));
  // Bitta yozuv sig'adi
  assert.equal(await expenseQuotaBlock(OWNER, 1), null);
  // 2 ta esa limitdan oshadi -> 402 tanasi
  const block = await expenseQuotaBlock(OWNER, 2);
  assert.ok(block, 'to\'plam limitdan oshdi, lekin bloklanmadi — "5 bepul" buziladi');
  assert.equal(block.code, 'SUB_EXPIRED');
  assert.equal(block.module, 'xarajat');
  __resetModuleSubsReady();
});

test('KVOTA — obuna bo\'lsa to\'plam cheklanmaydi; n=0 hech qachon bloklanmaydi', async () => {
  __resetModuleSubsReady();
  __setDbForTests(modScenario({ rows: [{ module: 'xarajat', active_until: FUTURE }], expenses: 9999 }));
  assert.equal(await expenseQuotaBlock(OWNER, 5), null);
  __setDbForTests(modScenario({ expenses: 9999 }));
  assert.equal(await expenseQuotaBlock(OWNER, 0), null); // faqat qarz_* amallari
  __resetModuleSubsReady();
});

// ---- To'yxona kvotasi ko'rsatkichi (To'yxona sessiyasi bilan kelishuv 2026-08-04) ----
// Qoida: ko'rsatiladigan limit SERVER MAJBURLAYOTGAN limit bilan bir xil bo'lishi SHART.
// used = bekor qilinmagan bronlar (bekor qilingan bron kvotani yemaydi).
import { FREE_TOYXONA_BOOKINGS, FREE_IJARA_CHARGES } from './subscription.js';

test('TOYXONA — free_limit majburlanadigan limit bilan bir xil, used = bronlar', async () => {
  __resetModuleSubsReady();
  __setDbForTests(modScenario({ bookings: 3 }));
  const by = Object.fromEntries((await getModulesStatus(OWNER)).map((m) => [m.module, m]));
  assert.equal(by.toyxona.free_limit, FREE_TOYXONA_BOOKINGS);
  assert.equal(by.toyxona.free_limit, 5, 'kelishilgan bepul kvota 5 ta bron');
  assert.equal(by.toyxona.used, 3);
  // Ijarachi moduli hali qurilmagan — kvota yo'q
  // Ijara moduli ham ochiq: bepul kvota majburlanadigan limit bilan bir xil
  assert.equal(by.ijarachi.used, 0); // stub'da rent_charges yo'q -> 0
  assert.equal(by.ijarachi.free_limit, FREE_IJARA_CHARGES);
  __resetModuleSubsReady();
});

test('TOYXONA — 021 migratsiya yo\'q: used=0, /api/subs/status yiqilmaydi', async () => {
  __resetModuleSubsReady();
  __setDbForTests(modScenario({ missingBookings: true }));
  const by = Object.fromEntries((await getModulesStatus(OWNER)).map((m) => [m.module, m]));
  assert.equal(by.toyxona.used, 0);
  assert.equal(by.toyxona.free_limit, FREE_TOYXONA_BOOKINGS);
  __resetModuleSubsReady();
});
