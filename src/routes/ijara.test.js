// IJARADAGI UYLAR moduli — SOF hisob qismi (offline, DB'siz). Yurgizish:
//   node --test src/routes/ijara.test.js
//
// Qulflanadigan qoidalar:
//   - Pul: charged = hisoblangan summa, paid = Σ to'lovlar, left = charged − paid.
//   - 'bekor' yozuv PULGA UMUMAN kirmaydi (unga biriktirilgan to'lov ham).
//   - Taqsimlanmagan to'lov (charge_id null) HAR DOIM tushumga kiradi.
//   - Status to'lov o'zgarganda deterministik: to'liq -> 'tolangan', aks holda
//     'kutilmoqda'; 'bekor' tirilmaydi. (To'yxonadan farqli o'laroq PASAYADI ham.)
//   - 5 TA UY — QAT'IY chegara, MODULES.ijarachi.max_units dan keladi.
//   - Default oraliq Toshkent (UTC+5) vaqtida — server UTC'da oy chegarasi surilmasin.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  money, isDateStr, isPeriodStr, periodOf, currentPeriod, daysBetween, monthBounds,
  readHouseFilter, chargeTotals, autoChargeStatus, foldCharges, foldHouses,
  sortCharges, isHouseLimitError, MAX_HOUSES, KINDS, STATUSES, DEDUP_MS,
} from './ijara.js';

// ============================ Chegara va katalog ============================

test("QAT'IY chegara — 5 ta uy (MODULES.ijarachi.max_units bilan bir xil)", () => {
  // Chegara subscription.js katalogidan keladi: route va mobil karta ajralib ketmasin.
  assert.equal(MAX_HOUSES, 5);
});

test('turlar va holatlar — 022 dagi CHECK bilan bir xil ro\'yxat', () => {
  assert.deepEqual(KINDS, ['ijara', 'kommunal', 'boshqa']);
  assert.deepEqual(STATUSES, ['kutilmoqda', 'tolangan', 'bekor']);
});

test('isHouseLimitError — 022 triggeri 403 ga aylanadi, boshqa xatolar YO\'Q', () => {
  assert.equal(isHouseLimitError({ message: 'IJARA_HOUSE_LIMIT: bitta hisobda...' }), true);
  assert.equal(isHouseLimitError({ code: '23514', details: 'IJARA_HOUSE_LIMIT' }), true);
  // Boshqa xatolar 403 EMAS — ular 500 bo'lib qolishi kerak
  assert.equal(isHouseLimitError({ code: '23514', message: 'amount > 0 buzildi' }), false);
  assert.equal(isHouseLimitError({ message: 'connection reset' }), false);
  assert.equal(isHouseLimitError(null), false);
  assert.equal(isHouseLimitError(undefined), false);
});

// ============================ Pul validatsiyasi ============================
// toyxona.js dagi bilan AYNAN bir xil semantika (nusxa funksiya — izohga qarang).

test('money — SOXTA NOL: null/bo\'sh/false/[] hech qachon 0 ga aylanmaydi', () => {
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
  assert.equal(money(2_500_000), 2_500_000);
  assert.equal(money('2500000'), 2_500_000);
  assert.equal(money('2500000.00'), 2_500_000);
  assert.equal(money(2_500_000.4), 2_500_000);
  assert.equal(money(2_500_000.6), 2_500_001);
});

test('money — nol faqat allowZero bilan; manfiy va chegaradan oshiq hech qachon', () => {
  assert.equal(money(0), null);                          // hisob-kitob summasi 0 bo'lolmaydi
  assert.equal(money(0, { allowZero: true }), 0);        // uyning ijara haqi 0 bo'lishi mumkin
  assert.equal(money(-1, { allowZero: true }), null);
  assert.equal(money(1e13, { allowZero: true }), 1e13);  // chegara — o'tadi
  assert.equal(money(1e13 + 1, { allowZero: true }), null);
});

// ============================ Sana va oy ============================

test('isDateStr — haqiqiy sanalar', () => {
  for (const d of ['2026-09-01', '2026-12-31', '2028-02-29']) {
    assert.equal(isDateStr(d), true, d);
  }
});

test('isDateStr — mavjud bo\'lmagan/buzuq sanalar rad etiladi', () => {
  for (const d of ['2026-02-31', '2027-02-29', '2026-13-01', '2026-00-10',
    '2026-9-1', '2026/09/01', '', 'bugun', null, undefined, 20260901]) {
    assert.equal(isDateStr(d), false, String(d));
  }
});

test('isPeriodStr — 022 dagi CHECK bilan bir xil (YYYY-MM, 01..12)', () => {
  for (const p of ['2026-01', '2026-08', '2026-12', '2100-12']) {
    assert.equal(isPeriodStr(p), true, p);
  }
  for (const p of ['2026-13', '2026-00', '2026-8', '2026-08-01', '26-08',
    '1999-12', '2101-01', '', null, undefined, 202608]) {
    assert.equal(isPeriodStr(p), false, String(p));
  }
});

test('periodOf — sanadan oy ajratiladi (oraliq filtri OY aniqligida)', () => {
  assert.equal(periodOf('2026-08-31'), '2026-08');
  assert.equal(periodOf('2026-01-01'), '2026-01');
});

test('daysBetween — inklyuziv oraliq hisobi', () => {
  assert.equal(daysBetween('2026-08-01', '2026-08-31'), 30);
  assert.equal(daysBetween('2026-08-01', '2026-08-01'), 0);
  assert.equal(daysBetween('2026-08-10', '2026-08-01'), -9);   // teskari oraliq -> manfiy
});

test('monthBounds — TOSHKENT chegarasi: UTC 31-avgust 20:00 = 1-sentyabr 01:00 (+5)', () => {
  // Server UTC'da bu hali AVGUST, lekin ega uchun allaqachon SENTYABR —
  // "bu oy" ko'rinishi o'tgan oyni ko'rsatib qolmasligi kerak.
  assert.deepEqual(monthBounds(new Date('2026-08-31T20:00:00Z')), {
    from: '2026-09-01', to: '2026-09-30',
  });
  assert.equal(currentPeriod(new Date('2026-08-31T20:00:00Z')), '2026-09');
});

test('monthBounds — oddiy holat, oy boshi va kabisa fevral', () => {
  assert.deepEqual(monthBounds(new Date('2026-08-15T10:00:00Z')), {
    from: '2026-08-01', to: '2026-08-31',
  });
  assert.deepEqual(monthBounds(new Date('2026-08-01T00:00:00Z')), {
    from: '2026-08-01', to: '2026-08-31',
  });
  assert.deepEqual(monthBounds(new Date('2028-02-10T00:00:00Z')), {
    from: '2028-02-01', to: '2028-02-29',
  });
  assert.equal(currentPeriod(new Date('2026-12-20T00:00:00Z')), '2026-12');
});

// ============================ Uy filtri ============================

test('readHouseFilter — berilmagan = BARCHA uylar', () => {
  for (const q of [{}, { house_id: '' }, { house_id: undefined }, { house_id: null }]) {
    assert.deepEqual(readHouseFilter(q), { houseId: null });
  }
});

test('readHouseFilter — uuid o\'tadi, buzuq qiymat 400 beradi', () => {
  const id = '11111111-2222-3333-4444-555555555555';
  assert.deepEqual(readHouseFilter({ house_id: id }), { houseId: id });
  // Buzuq qiymat jimgina "hammasi"ga aylanib ketmaydi
  for (const bad of ['salom', '123', 'none', 'null', `${id}x`]) {
    assert.ok(readHouseFilter({ house_id: bad }).error, `house_id=${bad}`);
  }
});

// ============================ Bitta yozuv yakuni ============================

test('chargeTotals — hisoblangan − to\'langan', () => {
  const c = { id: 'a', amount: 3_000_000, status: 'kutilmoqda' };
  assert.deepEqual(chargeTotals(c, [{ amount: 1_000_000 }, { amount: 500_000 }]), {
    charged: 3_000_000, paid: 1_500_000, left: 1_500_000,
  });
});

test('chargeTotals — BEKOR yozuv pulga umuman kirmaydi (to\'lovi bilan birga)', () => {
  const c = { id: 'a', amount: 3_000_000, status: 'bekor' };
  assert.deepEqual(chargeTotals(c, [{ amount: 3_000_000 }]), { charged: 0, paid: 0, left: 0 });
});

test('chargeTotals — ortiqcha to\'lov left ni MANFIY qiladi (qaytarim ko\'rinadi)', () => {
  const t = chargeTotals({ amount: 1_000_000, status: 'kutilmoqda' }, [{ amount: 1_200_000 }]);
  assert.equal(t.left, -200_000);
});

test('chargeTotals — buzuq qatorlar (null/undefined) NaN tarqatmaydi', () => {
  assert.deepEqual(chargeTotals({}, [{ amount: null }, {}]), { charged: 0, paid: 0, left: 0 });
  assert.deepEqual(chargeTotals(null), { charged: 0, paid: 0, left: 0 });
});

// ============================ Status qoidalari ============================

test("to'liq to'landi -> 'tolangan' (ortiqcha to'lov ham)", () => {
  assert.equal(autoChargeStatus('kutilmoqda', 0), 'tolangan');
  assert.equal(autoChargeStatus('kutilmoqda', -50_000), 'tolangan');
});

test("qisman to'lov -> 'kutilmoqda' bo'lib qoladi", () => {
  assert.equal(autoChargeStatus('kutilmoqda', 1), 'kutilmoqda');
});

test("TO'LOV O'CHIRILGANDA status PASAYADI ('tolangan' -> 'kutilmoqda')", () => {
  // Bu to'yxonadan ATAYLAB farq qiladi: u yerda status ish oqimi, bu yerda
  // 'tolangan' so'zma-so'z "puli tushgan" degani — noto'g'ri to'lov o'chirilgach
  // yozuv 'tolangan' qolsa QARZ JIMGINA YASHIRINARDI.
  assert.equal(autoChargeStatus('tolangan', 2_000_000), 'kutilmoqda');
});

test("BEKOR qilingan yozuv to'lovdan TIRILMAYDI", () => {
  assert.equal(autoChargeStatus('bekor', 0), 'bekor');
  assert.equal(autoChargeStatus('bekor', 5_000_000), 'bekor');
});

test('barcha statuslar funksiyadan HAQIQIY status bilan qaytadi', () => {
  for (const s of STATUSES) {
    for (const left of [-1, 0, 1_000_000]) {
      assert.ok(STATUSES.includes(autoChargeStatus(s, left)), `${s}/${left}`);
    }
  }
});

// ============================ Davr yakuni ============================

test('foldCharges — bekor PULGA kirmaydi, count ga kiradi, countActive ga kirmaydi', () => {
  const rows = [
    { id: 'a', amount: 3_000_000, status: 'kutilmoqda' },
    { id: 'b', amount: 2_000_000, status: 'tolangan' },
    { id: 'c', amount: 9_000_000, status: 'bekor' },     // hisobga KIRMAYDI
  ];
  const paysBy = new Map([
    ['a', [{ amount: 1_000_000 }]],
    ['b', [{ amount: 2_000_000 }]],
    ['c', [{ amount: 9_000_000 }]],   // bekor yozuvning to'lovi ham kirmaydi
  ]);
  const s = foldCharges(rows, paysBy);
  assert.equal(s.charged, 5_000_000);
  assert.equal(s.paid, 3_000_000);
  assert.equal(s.left, 2_000_000);
  assert.equal(s.count, 3);
  assert.equal(s.countActive, 2);
  assert.deepEqual(s.byStatus, { kutilmoqda: 1, tolangan: 1, bekor: 1 });
});

test('foldCharges — TAQSIMLANMAGAN to\'lov tushumga kiradi (oy yakuni kam ko\'rsatmasin)', () => {
  const rows = [{ id: 'a', amount: 3_000_000, status: 'kutilmoqda' }];
  const s = foldCharges(rows, new Map(), [{ amount: 500_000 }, { amount: 500_000 }]);
  assert.equal(s.charged, 3_000_000);
  assert.equal(s.paid, 1_000_000);
  assert.equal(s.left, 2_000_000);
});

test('foldCharges — bo\'sh oraliq nol beradi', () => {
  assert.deepEqual(foldCharges([]), {
    count: 0, countActive: 0, charged: 0, paid: 0, left: 0,
    byStatus: { kutilmoqda: 0, tolangan: 0, bekor: 0 },
  });
});

// ============================ Uy bo'yicha yakun ============================

test('foldHouses — har uy alohida hisob (charged/paid/left)', () => {
  const houses = [{ id: 'h1' }, { id: 'h2' }];
  const charges = [
    { id: 'c1', house_id: 'h1', amount: 3_000_000, status: 'kutilmoqda' },
    { id: 'c2', house_id: 'h1', amount: 500_000, status: 'tolangan' },
    { id: 'c3', house_id: 'h2', amount: 2_000_000, status: 'kutilmoqda' },
  ];
  const payments = [
    { id: 'p1', house_id: 'h1', charge_id: 'c2', amount: 500_000 },
    { id: 'p2', house_id: 'h1', charge_id: null, amount: 1_000_000 },   // taqsimlanmagan
  ];
  const t = foldHouses(houses, charges, payments);
  assert.deepEqual(t.get('h1'), { charged: 3_500_000, paid: 1_500_000, left: 2_000_000 });
  assert.deepEqual(t.get('h2'), { charged: 2_000_000, paid: 0, left: 2_000_000 });
});

test('foldHouses — bekor yozuv VA unga biriktirilgan to\'lov ikkalasi ham chiqib ketadi', () => {
  const houses = [{ id: 'h1' }];
  const charges = [{ id: 'c1', house_id: 'h1', amount: 9_000_000, status: 'bekor' }];
  const payments = [{ id: 'p1', house_id: 'h1', charge_id: 'c1', amount: 9_000_000 }];
  assert.deepEqual(foldHouses(houses, charges, payments).get('h1'),
    { charged: 0, paid: 0, left: 0 });
});

test('foldHouses — yozuvsiz uy nol beradi, begona uy qatorlari e\'tiborsiz qoladi', () => {
  const t = foldHouses(
    [{ id: 'h1' }],
    [{ id: 'c9', house_id: 'begona', amount: 5_000_000, status: 'kutilmoqda' }],
    [{ id: 'p9', house_id: 'begona', charge_id: null, amount: 5_000_000 }],
  );
  assert.deepEqual(t.get('h1'), { charged: 0, paid: 0, left: 0 });
  assert.equal(t.size, 1);
});

// ============================ Ro'yxat tartibi ============================

test('sortCharges — oy, keyin muddat; MUDDATSIZ yozuv oxirida', () => {
  const rows = [
    { id: 'x', period: '2026-09', due_date: null, created_at: '2026-09-01' },
    { id: 'b', period: '2026-08', due_date: '2026-08-20', created_at: '2026-08-02' },
    { id: 'c', period: '2026-08', due_date: null, created_at: '2026-08-03' },
    { id: 'a', period: '2026-08', due_date: '2026-08-05', created_at: '2026-08-01' },
  ];
  assert.deepEqual(sortCharges(rows).map((r) => r.id), ['a', 'b', 'c', 'x']);
});

test('sortCharges — kirish massivini O\'ZGARTIRMAYDI', () => {
  const rows = [
    { id: 'b', period: '2026-09', due_date: null },
    { id: 'a', period: '2026-08', due_date: null },
  ];
  sortCharges(rows);
  assert.equal(rows[0].id, 'b');
});

// ============================================================
// BEKOR QILISHDA PUL YO'QOLMASLIGI (review 2026-08-04, HIGH)
// Yuqoridagi test bekor yozuv + unga BIRIKTIRILGAN to'lov ikkalasi ham hisobdan
// chiqishini qulflaydi — bu fold mantig'i to'g'ri. Muammo ROUTE tomonida edi:
// yozuv bekor qilinganda to'lov unga biriktirilgan holicha qolar va egasi QO'LIGA
// OLGAN pul barcha yakunlardan yo'qolardi. Yechim: bekor qilishda to'lov UZILADI
// (charge_id -> null). Quyidagi test aynan shu holatdan keyingi ko'rinishni
// qulflaydi — uzilgan to'lov TAQSIMLANMAGAN tushum bo'lib yakunda QOLADI.
// ============================================================
test('BEKOR — uzilgan to\'lov (charge_id null) tushumda QOLADI, pul yo\'qolmaydi', () => {
  const houses = [{ id: 'h1' }];
  const charges = [{ id: 'c1', house_id: 'h1', amount: 3_000_000, status: 'bekor' }];
  // Route bekor qilishda charge_id ni null qiladi — pul taqsimlanmagan bo'lib qoladi
  const payments = [{ id: 'p1', house_id: 'h1', charge_id: null, amount: 3_000_000 }];
  assert.deepEqual(foldHouses(houses, charges, payments).get('h1'),
    { charged: 0, paid: 3_000_000, left: -3_000_000 });
  // Davr yakunida ham xuddi shunday: uzilgan to'lov `unallocated` bo'lib keladi va
  // tushumga kiradi — bekor qilingan yozuv esa hisoblangan summaga kirmaydi.
  const d = foldCharges(charges, new Map(), payments);
  assert.equal(d.charged, 0);
  assert.equal(d.paid, 3_000_000);
  assert.equal(d.left, -3_000_000);
  assert.equal(d.countActive, 0);
});

// ============================================================
// TAKROR TO'LOVDAN HIMOYA (review 2026-08-04, #10)
// Mobil timeout 20s, Render sovuq starti undan uzoqroq bo'lishi mumkin va mobil
// foydalanuvchiga ATAYLAB "qayta urinib ko'ring" deydi — ya'ni bir xil to'lov
// ikki marta yozilishi REAL stsenariy, nazariy emas. Dedup oynasi shuni to'sadi.
// ============================================================
test('DEDUP — oyna mobil timeout va sovuq startdan UZUNROQ', () => {
  // Mobil ijara_data.dart da so'rov timeouti 20s. Oyna undan sezilarli uzun
  // bo'lmasa, foydalanuvchi qayta urinib ulgurgan payt himoya ishlamay qoladi.
  assert.ok(DEDUP_MS >= 60_000, 'dedup oynasi juda qisqa — takror to\'lov o\'tib ketadi');
  // Cheksiz ham bo'lmasin: haqiqatan ikkita bir xil to'lovni kiritish imkoni qolsin.
  assert.ok(DEDUP_MS <= 10 * 60_000, 'dedup oynasi juda uzun — haqiqiy takror to\'lov bloklanadi');
});
