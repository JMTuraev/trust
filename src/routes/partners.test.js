// Davr agregatlari (GET /api/partners?period_from&period_to) SOF yig'ish qismi —
// offline, DB'siz. Yurgizish:  node --test src/routes/partners.test.js
//
// Qulflanadigan qoidalar (2026-08-04 review):
//   - VALYUTA ARALASHMAYDI: summalarga faqat UZS (yoki currency NULL) kiradi —
//     20 USD hech qachon "20 so'm" bo'lib UZS yig'indiga qo'shilmaydi.
//   - count esa BARCHA yozuvlar bo'yicha (valyutadan qat'i nazar).
//   - Yo'nalish SO'ROVCHIga nisbatan (canonicalDir): boshqa tomon yaratgan yozuv flip.
//   - repay/settle yo'nalishi BOG'LIQ (ref) qarzdan olinadi; ref yo'q — faqat count.
import test from 'node:test';
import assert from 'node:assert/strict';
import { foldPeriodRows } from './partners.js';

const USER = 'u-me';
const OTHER = 'u-other';
const P1 = 'partner-1';
const P2 = 'partner-2';

const fold = (over = {}) => foldPeriodRows({
  partnerIds: [P1, P2], userId: USER, debtRows: [], refRows: [], opRows: [], ...over,
});

test('bo\'sh kirish — har hamkorga nol agregat', () => {
  const m = fold();
  assert.deepEqual(m.get(P1), { to_me: 0, by_me: 0, repaid_to_me: 0, repaid_by_me: 0, count: 0 });
  assert.deepEqual(m.get(P2), { to_me: 0, by_me: 0, repaid_to_me: 0, repaid_by_me: 0, count: 0 });
});

test('UZS qarz — yo\'nalish SO\'ROVCHIga nisbatan (o\'zi yozgan: to\'g\'ri, boshqa yozgan: flip)', () => {
  const m = fold({
    debtRows: [
      { partner_id: P1, kind: 'debt', direction: 'toMe', created_by: USER, amount: 100_000, currency: 'UZS' },
      { partner_id: P1, kind: 'debt', direction: 'fromMe', created_by: USER, amount: 40_000, currency: 'UZS' },
      // Qarshi tomon yozgan 'toMe' — so'rovchi uchun 'fromMe' (canonicalDir flip)
      { partner_id: P1, kind: 'debt', direction: 'toMe', created_by: OTHER, amount: 25_000, currency: 'UZS' },
    ],
  });
  assert.deepEqual(m.get(P1), { to_me: 100_000, by_me: 65_000, repaid_to_me: 0, repaid_by_me: 0, count: 3 });
});

test('VALYUTA ARALASHMAYDI — USD summaga kirmaydi, count\'ga kiradi; NULL currency = UZS', () => {
  const m = fold({
    debtRows: [
      { partner_id: P1, kind: 'debt', direction: 'toMe', created_by: USER, amount: 20, currency: 'USD' },
      { partner_id: P1, kind: 'debt', direction: 'toMe', created_by: USER, amount: 50_000, currency: null },
    ],
  });
  // 20 USD "20 so'm" bo'lib qo'shilmadi; eski (currency NULL) qator UZS deb yig'ildi
  assert.deepEqual(m.get(P1), { to_me: 50_000, by_me: 0, repaid_to_me: 0, repaid_by_me: 0, count: 2 });
});

test('repay/settle — yo\'nalish REF qarzdan; ref yo\'q bo\'lsa faqat count', () => {
  const m = fold({
    debtRows: [
      { partner_id: P1, kind: 'repay', created_by: OTHER, amount: 30_000, currency: 'UZS', ref_id: 'd1' },
      // Qarshi tomon yozgan ref (toMe) — so'rovchi uchun fromMe -> repaid_by_me
      { partner_id: P1, kind: 'settle', created_by: USER, amount: 10_000, currency: 'UZS', ref_id: 'd2' },
      // ref topilmadi — yo'nalishsiz, faqat count
      { partner_id: P1, kind: 'repay', created_by: USER, amount: 999, currency: 'UZS', ref_id: 'yo-q' },
      // USD repay — faqat count
      { partner_id: P1, kind: 'repay', created_by: USER, amount: 5, currency: 'USD', ref_id: 'd1' },
    ],
    refRows: [
      { id: 'd1', direction: 'toMe', created_by: USER },   // men qarz berganman -> menga qaytdi
      { id: 'd2', direction: 'toMe', created_by: OTHER },  // u yozgan toMe -> men qarzdorman
    ],
  });
  assert.deepEqual(m.get(P1), { to_me: 0, by_me: 0, repaid_to_me: 30_000, repaid_by_me: 10_000, count: 4 });
});

test('operations — delta ishorasi (+ = menga), USD op summaga kirmaydi', () => {
  const m = fold({
    opRows: [
      { partner_id: P2, delta: 70_000, currency: 'UZS' },
      { partner_id: P2, delta: -15_000, currency: null }, // eski qator, default UZS
      { partner_id: P2, delta: 100, currency: 'USD' },    // faqat count
    ],
  });
  assert.deepEqual(m.get(P2), { to_me: 70_000, by_me: 15_000, repaid_to_me: 0, repaid_by_me: 0, count: 3 });
  assert.equal(m.get(P1).count, 0); // boshqa hamkorga tegmadi
});

test('ro\'yxatda yo\'q partner_id — butunlay e\'tiborsiz (count ham yo\'q)', () => {
  const m = fold({
    debtRows: [{ partner_id: 'begona', kind: 'debt', direction: 'toMe', created_by: USER, amount: 1, currency: 'UZS' }],
    opRows: [{ partner_id: 'begona', delta: 1, currency: 'UZS' }],
  });
  assert.equal(m.get(P1).count, 0);
  assert.equal(m.has('begona'), false);
});
