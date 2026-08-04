// TO'YXONA moduli — SOF hisob qismi (offline, DB'siz). Yurgizish:
//   node --test src/routes/toyxona.test.js
//
// Qulflanadigan qoidalar:
//   - Pul: food = mehmon × narx, extras = Σ(narx × soni), left = total − paid.
//   - AQLLI STATUS: avans -> 'tasdiq', to'liq to'lov -> 'yakun', 'bekor' tirilmaydi,
//     to'lov o'chirilganda PASAYMAYDI (bu funksiya faqat to'lov QO'SHILGANDA chaqiriladi).
//   - Kalendar tartibi: slot ALIFBO bo'yicha emas, KUN tartibida (nahor->tushlik->kechki).
//   - Default oraliq Toshkent (UTC+5) vaqtida — server UTC'da oy chegarasi surilmasin.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  computeTotals, autoStatusAfterPayment, sortBookings, overMax, foldSummary,
  money, isUniqueViolation, readHallFilter,
  isDateStr, daysBetween, monthBounds, SLOTS, STATUSES,
} from './toyxona.js';

// ============================ Pul validatsiyasi ============================
// Bu blok 2026-08-04 review topilmasini QULFLAYDI: money() eksport qilinmagani
// uchun testsiz qolgan edi va JS'ning Number(null)===0 xatti-harakati tufayli
// PATCH {price_per_guest: null} kelishilgan narxni jimgina 0 ga tushirardi.

test('money — SOXTA NOL: null/bo\'sh/false/[] hech qachon 0 ga aylanmaydi', () => {
  // Number(null)===0, Number('')===0, Number(false)===0, Number([])===0 —
  // ilgari bularning HAMMASI jimgina 0 so'm bo'lib DB'ga yozilardi.
  for (const v of [null, '', '   ', false, true, [], {}, undefined, NaN, Infinity]) {
    assert.equal(money(v, { allowZero: true }), null, `money(${JSON.stringify(v)})`);
  }
});

test('money — chala/aralash satrlar rad etiladi', () => {
  for (const v of ['12abc', 'abc', '1e5', '0x10', '-5', '1,5', '1 000', '+7']) {
    assert.equal(money(v, { allowZero: true }), null, `money("${v}")`);
  }
});

test('money — haqiqiy qiymatlar o\'tadi (son va sof raqamli satr)', () => {
  assert.equal(money(150_000), 150_000);
  assert.equal(money('150000'), 150_000);
  assert.equal(money('150000.00'), 150_000);   // mobil ba'zan kasr bilan yuboradi
  assert.equal(money(150_000.4), 150_000);     // yaxlitlanadi
  assert.equal(money(150_000.6), 150_001);
});

test('money — nol faqat allowZero bilan; manfiy va chegaradan oshiq hech qachon', () => {
  assert.equal(money(0), null);                          // summa 0 bo'lolmaydi
  assert.equal(money(0, { allowZero: true }), 0);        // narx 0 bo'lishi mumkin
  assert.equal(money(-1, { allowZero: true }), null);
  assert.equal(money(1e13, { allowZero: true }), 1e13);  // chegara — o'tadi
  assert.equal(money(1e13 + 1, { allowZero: true }), null);
});

// ============================ Konflikt va filtr ============================

test('isUniqueViolation — 23505 va matn variantlari 409 ga aylanadi', () => {
  assert.equal(isUniqueViolation({ code: '23505' }), true);
  assert.equal(isUniqueViolation({ message: 'duplicate key value violates unique constraint' }), true);
  assert.equal(isUniqueViolation({ message: 'unique constraint "bookings_slot_uidx"' }), true);
  // Boshqa xatolar 409 EMAS — ular 500 bo'lib qolishi kerak
  assert.equal(isUniqueViolation({ code: '23503' }), false);   // foreign key
  assert.equal(isUniqueViolation({ message: 'connection reset' }), false);
  assert.equal(isUniqueViolation(null), false);
  assert.equal(isUniqueViolation(undefined), false);
});

test('readHallFilter — berilmagan = HAMMASI (NULL bandlar ham kiradi)', () => {
  for (const q of [{}, { hall_id: '' }, { hall_id: undefined }, { hall_id: null }]) {
    assert.deepEqual(readHallFilter(q), { hallId: null, nullOnly: false });
  }
});

test('readHallFilter — uuid, "none" va buzuq qiymat', () => {
  const id = '11111111-2222-3333-4444-555555555555';
  assert.deepEqual(readHallFilter({ hall_id: id }), { hallId: id, nullOnly: false });
  // 'none' — FAQAT to'yxonasiz bandlar (hall_id IS NULL)
  assert.deepEqual(readHallFilter({ hall_id: 'none' }), { hallId: null, nullOnly: true });
  // Buzuq qiymat 400 beradi — jimgina "hammasi"ga aylanib ketmaydi
  for (const bad of ['salom', '123', 'null', `${id}x`]) {
    assert.ok(readHallFilter({ hall_id: bad }).error, `hall_id=${bad}`);
  }
});

// ============================ Pul ============================

test('computeTotals — food + extras − to\'lovlar', () => {
  const booking = { guests: 200, price_per_guest: 150_000 };
  const items = [
    { amount: 3_000_000, qty: 1 },   // musiqa
    { amount: 500_000, qty: 2 },     // fotograf ×2
  ];
  const payments = [{ amount: 10_000_000 }];
  assert.deepEqual(computeTotals(booking, items, payments), {
    food: 30_000_000,      // 200 × 150 000
    extras: 4_000_000,     // 3 000 000 + 2 × 500 000
    total: 34_000_000,
    paid: 10_000_000,
    left: 24_000_000,
  });
});

test('computeTotals — bo\'sh band (xizmat/to\'lov yo\'q)', () => {
  assert.deepEqual(computeTotals({ guests: 100, price_per_guest: 100_000 }, [], []), {
    food: 10_000_000, extras: 0, total: 10_000_000, paid: 0, left: 10_000_000,
  });
});

test('computeTotals — ortiqcha to\'lov left ni MANFIY qiladi (qaytarim ko\'rinadi)', () => {
  const t = computeTotals({ guests: 10, price_per_guest: 100_000 }, [], [{ amount: 1_500_000 }]);
  assert.equal(t.total, 1_000_000);
  assert.equal(t.left, -500_000);
});

test('computeTotals — narx 0 (kelishilmagan) yiqilmaydi, NaN chiqmaydi', () => {
  const t = computeTotals({ guests: 300, price_per_guest: 0 }, [{ amount: 200_000, qty: 1 }], []);
  assert.deepEqual(t, { food: 0, extras: 200_000, total: 200_000, paid: 0, left: 200_000 });
});

test('computeTotals — buzuq qatorlar (null/undefined) NaN tarqatmaydi', () => {
  const t = computeTotals({}, [{ amount: null, qty: 2 }, {}], [{ amount: undefined }]);
  assert.deepEqual(t, { food: 0, extras: 0, total: 0, paid: 0, left: 0 });
});

test('overMax — KO\'PAYTMA chegarasi (har omil alohida chegarada bo\'lsa ham)', () => {
  // Haqiqiy to'y: 500 mehmon × 200 000 = 100 mln — o'tadi
  assert.equal(overMax(500, 200_000), false);
  // Chegaraviy: aynan 1e13 o'tadi, undan bittasi ko'p — yo'q
  assert.equal(overMax(1e13, 1), false);
  assert.equal(overMax(1e13, 1) === false && overMax(1e13 + 1, 1), true);
  // Alohida tekshiruvlardan o'tadigan, lekin MAX_SAFE_INTEGER dan oshadigan juftlik:
  // 100 000 mehmon × 1e13 = 1e18 — float arifmetikasi jimgina buzilardi
  assert.equal(overMax(100_000, 1e13), true);
  assert.equal(overMax(10_000, 1e13), true);   // xizmat: qty × amount
});

test('overMax — buzuq kirish 0 deb qaraladi (NaN "true" bermaydi)', () => {
  assert.equal(overMax(null, 5), false);
  assert.equal(overMax(undefined, undefined), false);
  assert.equal(overMax('salom', 10), false);
});

// ============================ Aqlli status ============================

test('avans olindi: band -> tasdiq (sana tasdiqlandi)', () => {
  assert.equal(autoStatusAfterPayment('band', 24_000_000), 'tasdiq');
});

test('to\'liq to\'landi: tasdiq -> yakun', () => {
  assert.equal(autoStatusAfterPayment('tasdiq', 0), 'yakun');
  assert.equal(autoStatusAfterPayment('tasdiq', -50_000), 'yakun'); // ortiqcha to'lov ham yakun
});

test('bir to\'lovda to\'liq summa: band -> yakun (band->tasdiq->yakun bir qadamda)', () => {
  assert.equal(autoStatusAfterPayment('band', 0), 'yakun');
});

test('qisman to\'lov tasdiq holatini o\'zgartirmaydi', () => {
  assert.equal(autoStatusAfterPayment('tasdiq', 1), 'tasdiq');
});

test('bekor qilingan band to\'lovdan TIRILMAYDI (qaytarim/jarima yozuvi bo\'lishi mumkin)', () => {
  assert.equal(autoStatusAfterPayment('bekor', 0), 'bekor');
  assert.equal(autoStatusAfterPayment('bekor', 5_000_000), 'bekor');
});

test('yakunlangan band ortga qaytmaydi', () => {
  assert.equal(autoStatusAfterPayment('yakun', 1_000_000), 'yakun');
});

test('barcha statuslar funksiyadan HAQIQIY status bilan qaytadi (kutilmagan qiymat yo\'q)', () => {
  for (const s of STATUSES) {
    for (const left of [-1, 0, 1_000_000]) {
      assert.ok(STATUSES.includes(autoStatusAfterPayment(s, left)), `${s}/${left}`);
    }
  }
});

// ============================ Davr yakuni ============================

test('foldSummary — bekor band PULGA kirmaydi, count ga kiradi, countActive ga kirmaydi', () => {
  const rows = [
    { id: 'a', guests: 100, price_per_guest: 100_000, status: 'tasdiq' },  // 10 mln
    { id: 'b', guests: 200, price_per_guest: 100_000, status: 'yakun' },   // 20 mln
    { id: 'c', guests: 500, price_per_guest: 900_000, status: 'bekor' },   // hisobga KIRMAYDI
  ];
  const paysBy = new Map([['a', [{ amount: 3_000_000 }]], ['c', [{ amount: 99_000_000 }]]]);
  const s = foldSummary(rows, new Map(), paysBy);

  assert.equal(s.total, 30_000_000);          // bekor bandning 450 mln'i kirmadi
  assert.equal(s.paid, 3_000_000);            // bekor bandning to'lovi ham kirmadi
  assert.equal(s.left, 27_000_000);
  assert.equal(s.count, 3);                   // BARCHA qatorlar
  assert.equal(s.countActive, 2);             // pul yig'indisi qamragan bandlar
  assert.deepEqual(s.byStatus, { band: 0, tasdiq: 1, yakun: 1, bekor: 1 });
});

test('foldSummary — countActive HAR DOIM byStatus bilan mos (mijoz ayirmasin)', () => {
  const rows = [
    { id: 'a', guests: 1, price_per_guest: 1, status: 'band' },
    { id: 'b', guests: 1, price_per_guest: 1, status: 'bekor' },
    { id: 'c', guests: 1, price_per_guest: 1, status: 'bekor' },
  ];
  const s = foldSummary(rows);
  assert.equal(s.countActive, s.count - s.byStatus.bekor);
  assert.equal(s.countActive, 1);
});

test('foldSummary — xizmatlar yakunga qo\'shiladi, bo\'sh oraliq nol beradi', () => {
  const rows = [{ id: 'a', guests: 10, price_per_guest: 100_000, status: 'band' }];
  const itemsBy = new Map([['a', [{ amount: 500_000, qty: 2 }]]]);
  assert.equal(foldSummary(rows, itemsBy).total, 2_000_000);   // 1 mln + 1 mln

  assert.deepEqual(foldSummary([]), {
    count: 0, countActive: 0, total: 0, paid: 0, left: 0, cancelledPaid: 0,
    byStatus: { band: 0, tasdiq: 0, yakun: 0, bekor: 0 },
  });
});

// --- cancelledPaid: bekor qilingan to'ydan qolgan real pul ko'rinib tursin ---

test('cancelledPaid — bekor qilingan bandning avansi YO\'QOLMAYDI, alohida chiqadi', () => {
  // Haqiqiy stsenariy: 5 mln avans olingan, mijoz to'yni bekor qildi, avans egada qoldi.
  const rows = [
    { id: 'a', guests: 100, price_per_guest: 100_000, status: 'tasdiq' },
    { id: 'x', guests: 300, price_per_guest: 200_000, status: 'bekor' },
  ];
  const paysBy = new Map([
    ['a', [{ amount: 4_000_000 }]],
    ['x', [{ amount: 5_000_000 }]],   // bekor qilingan to'yning avansi
  ]);
  const s = foldSummary(rows, new Map(), paysBy);

  assert.equal(s.cancelledPaid, 5_000_000);   // pul KO'RINADI
  // ...lekin faol hisob-kitobga TEGMAYDI (mavjud semantika o'zgarmadi):
  assert.equal(s.paid, 4_000_000);
  assert.equal(s.total, 10_000_000);          // bekor bandning 60 mln'i kirmadi
  assert.equal(s.left, 6_000_000);
  assert.equal(s.countActive, 1);
  assert.equal(s.count, 2);
  assert.equal(s.byStatus.bekor, 1);
});

test('cancelledPaid — TO\'LOVDAN KEYIN bekor qilingan band ham xuddi shunday', () => {
  // Status bekor bo'lgach yig'ish qoidasi bir xil — to'lov qatori bandda QOLADI
  // (FK uzilmaydi), shuning uchun pulni to'yga bog'lab kuzatish mumkin.
  const rows = [{ id: 'x', guests: 200, price_per_guest: 150_000, status: 'bekor' }];
  const itemsBy = new Map([['x', [{ amount: 2_000_000, qty: 1 }]]]);
  const paysBy = new Map([['x', [{ amount: 3_000_000 }, { amount: 1_500_000 }]]]);
  const s = foldSummary(rows, itemsBy, paysBy);

  assert.equal(s.cancelledPaid, 4_500_000);   // ikkala to'lov ham
  assert.equal(s.total, 0);
  assert.equal(s.paid, 0);
  assert.equal(s.left, 0);
  assert.equal(s.countActive, 0);
  assert.equal(s.count, 1);
});

test('cancelledPaid — bekor band bor, lekin to\'lovsiz -> 0', () => {
  const rows = [
    { id: 'a', guests: 10, price_per_guest: 100_000, status: 'band' },
    { id: 'x', guests: 10, price_per_guest: 100_000, status: 'bekor' },
  ];
  assert.equal(foldSummary(rows).cancelledPaid, 0);
  // Bekor band umuman yo'q bo'lsa ham 0
  assert.equal(foldSummary([rows[0]]).cancelledPaid, 0);
});

// ============================ Kalendar tartibi ============================

test('sortBookings — slot ALIFBO emas, KUN tartibida (nahor -> tushlik -> kechki)', () => {
  const rows = [
    { id: 'c', event_date: '2026-09-01', slot: 'kechki' },
    { id: 'a', event_date: '2026-09-01', slot: 'nahor' },
    { id: 'b', event_date: '2026-09-01', slot: 'tushlik' },
    { id: 'd', event_date: '2026-08-31', slot: 'kechki' },
  ];
  assert.deepEqual(sortBookings(rows).map((r) => r.id), ['d', 'a', 'b', 'c']);
  // BIR KUN ichida: alifbo tartibi bo'lganda 'kechki' birinchi kelib qolardi
  // (kechki < nahor < tushlik), aslida u OXIRGI bo'lishi kerak.
  const sameDay = sortBookings(rows).filter((r) => r.event_date === '2026-09-01');
  assert.deepEqual(sameDay.map((r) => r.slot), ['nahor', 'tushlik', 'kechki']);
});

test('sortBookings — kirish massivini O\'ZGARTIRMAYDI', () => {
  const rows = [
    { id: 'b', event_date: '2026-09-02', slot: 'nahor' },
    { id: 'a', event_date: '2026-09-01', slot: 'nahor' },
  ];
  sortBookings(rows);
  assert.equal(rows[0].id, 'b');
});

test('SLOTS — kutilgan uchlik va tartib', () => {
  assert.deepEqual(SLOTS, ['nahor', 'tushlik', 'kechki']);
});

// ============================ Sana ============================

test('isDateStr — haqiqiy sanalar', () => {
  for (const d of ['2026-09-01', '2026-12-31', '2028-02-29']) { // 2028 kabisa yili
    assert.equal(isDateStr(d), true, d);
  }
});

test('isDateStr — mavjud bo\'lmagan/buzuq sanalar rad etiladi', () => {
  for (const d of [
    '2026-02-31',   // fevralda 31 yo'q
    '2027-02-29',   // kabisa emas
    '2026-13-01',   // 13-oy
    '2026-00-10',   // 0-oy
    '2026-9-1',     // nol bilan to'ldirilmagan
    '2026/09/01', '01-09-2026', '', 'bugun', null, undefined, 20260901,
  ]) {
    assert.equal(isDateStr(d), false, String(d));
  }
});

test('daysBetween — inklyuziv oraliq hisobi', () => {
  assert.equal(daysBetween('2026-09-01', '2026-09-30'), 29);
  assert.equal(daysBetween('2026-09-01', '2026-09-01'), 0);
  assert.equal(daysBetween('2026-09-10', '2026-09-01'), -9); // teskari oraliq -> manfiy
});

// ============================ Default oraliq (TZ) ============================

test('monthBounds — oddiy holat', () => {
  assert.deepEqual(monthBounds(new Date('2026-09-15T10:00:00Z')), {
    from: '2026-09-01', to: '2026-09-30',
  });
});

test('monthBounds — TOSHKENT chegarasi: UTC 31-avgust 20:00 = 1-sentyabr 01:00 (+5)', () => {
  // Server UTC'da bu hali AVGUST, lekin ega uchun allaqachon SENTYABR —
  // kalendar "o'tgan oy"ni ko'rsatib qolmasligi kerak.
  assert.deepEqual(monthBounds(new Date('2026-08-31T20:00:00Z')), {
    from: '2026-09-01', to: '2026-09-30',
  });
});

test('monthBounds — oy boshi UTC 00:00 hali o\'sha oyda qoladi', () => {
  assert.deepEqual(monthBounds(new Date('2026-08-01T00:00:00Z')), {
    from: '2026-08-01', to: '2026-08-31',
  });
});

test('monthBounds — fevral (kabisa) oxirgi kuni to\'g\'ri', () => {
  assert.deepEqual(monthBounds(new Date('2028-02-10T00:00:00Z')), {
    from: '2028-02-01', to: '2028-02-29',
  });
});

test('monthBounds — dekabr yil chegarasidan oshmaydi', () => {
  assert.deepEqual(monthBounds(new Date('2026-12-20T00:00:00Z')), {
    from: '2026-12-01', to: '2026-12-31',
  });
});
