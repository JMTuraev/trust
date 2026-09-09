// 025 — SERVIS KATEGORIYALARI: sof (DB'siz) qoidalarni qulflaydi.
//   node --test src/lib/toyxonaCategories.test.js
//
// Nega test kerak: ro'yxat IKKI joyda takrorlanadi (bu fayl va Flutter'dagi
// kToyServiceCats). Slug'lar mos kelmasa server 400 qaytarardi va ega
// "kategoriya noto'g'ri" xabarini KO'RIB, sababini tushunmasdi.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  TOY_SERVICE_CATEGORIES, TOY_DEFAULT_CATEGORY, TOY_CATEGORY_NAMES,
  isToyCategory, normToyCategory, toyCategoryOrder,
} from './toyxonaCategories.js';

test('ro\'yxat — 18 ta, slug\'lar TAKRORLANMAYDI, "boshqa" OXIRGI', () => {
  assert.equal(TOY_SERVICE_CATEGORIES.length, 18);
  const slugs = TOY_SERVICE_CATEGORIES.map((c) => c.slug);
  assert.equal(new Set(slugs).size, slugs.length, 'takrorlangan slug bor');
  // Zaxira kategoriya oxirida turishi SHART: mobil grid shu tartibda chiziladi
  // va "Boshqa" o'rtada paydo bo'lsa ro'yxat tasodifiy ko'rinardi.
  assert.equal(slugs[slugs.length - 1], TOY_DEFAULT_CATEGORY);
});

test('slug formati — DB cheklovi (^[a-z][a-z0-9_]{0,23}$) bilan mos', () => {
  for (const c of TOY_SERVICE_CATEGORIES) {
    assert.match(c.slug, /^[a-z][a-z0-9_]{0,23}$/, c.slug);
  }
});

test('har kategoriyada unit va NOM (uz/ru/en) bor', () => {
  const units = new Set(['guest', 'piece', 'set', 'hour', 'once']);
  for (const c of TOY_SERVICE_CATEGORIES) {
    assert.ok(units.has(c.unit), `${c.slug}: noma'lum unit ${c.unit}`);
    const n = TOY_CATEGORY_NAMES[c.slug];
    assert.ok(n && n.uz && n.ru && n.en, `${c.slug}: nom yetishmayapti`);
  }
});

test('normToyCategory — BO\'SH qiymat "boshqa", NOMA\'LUM esa null (400)', () => {
  // Bo'sh -> default: eski mobil ilova category yubormaydi, uning yozuvi
  // YIQILMASLIGI kerak (400 bo'lsa yangilanmagan ega servis qo'sholmasdi).
  for (const v of [null, undefined, '']) {
    assert.equal(normToyCategory(v), TOY_DEFAULT_CATEGORY, JSON.stringify(v));
  }
  // Noma'lum -> null: JIMGINA 'boshqa' ga tushirmaymiz, aks holda mobildagi
  // xato slug sezilmay qolib, hamma item 'Boshqa' ga to'planardi.
  for (const v of ['musiqa_2', 'MUSIQA!', 'yoq', 'drop table', 42, {}, []]) {
    assert.equal(normToyCategory(v), null, JSON.stringify(v));
  }
  // Katta harf / bo'shliq — kechiriladi
  assert.equal(normToyCategory('  Musiqa '), 'musiqa');
});

test('isToyCategory — faqat ro\'yxatdagilar', () => {
  assert.ok(isToyCategory('taomnoma'));
  assert.ok(isToyCategory('boshqa'));
  assert.ok(!isToyCategory('Taomnoma'));   // normalizatsiya normToyCategory'da
  assert.ok(!isToyCategory(''));
  assert.ok(!isToyCategory(null));
});

test('toyCategoryOrder — ro\'yxat tartibi; noma\'lum ENG OXIRIDA', () => {
  assert.equal(toyCategoryOrder('taomnoma'), 0);
  assert.equal(toyCategoryOrder('boshqa'), 17);
  // Saralashda noma'lum slug ro'yxatning boshiga sakrab chiqmasin
  assert.ok(toyCategoryOrder('yoq-bunday') > toyCategoryOrder('boshqa'));
});

test('saralash BARQAROR: bir kategoriya ichida kiritilgan tartib buzilmaydi', () => {
  const rows = [
    { id: 'a', category: 'musiqa' },
    { id: 'b', category: 'taomnoma' },
    { id: 'c', category: 'musiqa' },
    { id: 'd', category: 'boshqa' },
  ];
  const out = [...rows].sort((x, y) => toyCategoryOrder(x.category) - toyCategoryOrder(y.category));
  assert.deepEqual(out.map((r) => r.id), ['b', 'a', 'c', 'd']);
});
