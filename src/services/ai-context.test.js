// Trust AI kontekst qatlamining SOF funksiyalari uchun offline tekshiruv (tarmoqsiz, DB'siz).
// Yurgizish (repo ildizidan):  node --test src/services/ai-context.test.js
// Node ichki test runner'i (node:test) — qo'shimcha bog'liqlik yo'q.
//
// Eng muhim tekshiruv: MAXFIYLIK — real hamkor ismi modelga ketadigan matnda
// (kontekst + foydalanuvchi xabari) HECH QACHON bo'lmasligi kerak.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  fmtMoney, fmtSigned, pctDelta, monthAgg, streakDays, aggregateDebts,
  composeContext, pseudonymizeText, restoreText, restoreBlocks, uzDate,
} from './ai-context.js';
import { validateBlocks } from '../lib/anthropic.js';
import { alternating } from '../routes/ai.js';

const NOW = new Date('2026-07-17T10:00:00Z'); // Toshkentda 17-iyul 15:00
const USER = 'user-1';
const ANVAR = 'p-anvar';
const DONIYOR = 'p-doniyor';
const EXP1 = 'e-1111';

// ---- Namunaviy ma'lumot: docs/ai-character.md §7 dagi misolga yaqin ----
const expenses = [
  { id: 'i1', income: true, amount: 8_000_000, category: 'Daromad', note: 'Oylik', occurred_at: '2026-07-05T09:00:00Z' },
  { id: 'e1', income: false, amount: 2_100_000, category: 'Oziq-ovqat', note: 'Bozor', occurred_at: '2026-07-06T09:00:00Z' },
  { id: 'e2', income: false, amount: 600_000, category: 'Transport', note: 'Taksi', occurred_at: '2026-07-07T09:00:00Z' },
  { id: 'e3', income: false, amount: 600_000, category: 'Transport', note: 'Taksi ertalab', occurred_at: '2026-07-08T09:00:00Z' },
  { id: EXP1, income: false, amount: 30_000, category: 'Boshqa', note: 'taksi ertalab', occurred_at: '2026-07-12T09:00:00Z' },
  // O'tgan oy (iyun)
  { id: 'j1', income: true, amount: 7_500_000, category: 'Daromad', note: 'Oylik', occurred_at: '2026-06-05T09:00:00Z' },
  { id: 'j2', income: false, amount: 2_000_000, category: 'Oziq-ovqat', note: 'Bozor', occurred_at: '2026-06-06T09:00:00Z' },
  { id: 'j3', income: false, amount: 960_000, category: 'Transport', note: 'Taksi', occurred_at: '2026-06-07T09:00:00Z' },
  // May (jamg'arma trendi uchun)
  { id: 'm1', income: true, amount: 7_000_000, category: 'Daromad', note: 'Oylik', occurred_at: '2026-05-05T09:00:00Z' },
  { id: 'm2', income: false, amount: 6_000_000, category: 'Oziq-ovqat', note: 'Bozor', occurred_at: '2026-05-06T09:00:00Z' },
];

const partners = [
  { id: ANVAR, owner_id: USER, counterparty_id: 'cp-1', name: 'Anvar', client_alias: null, link_status: 'accepted' },
  { id: DONIYOR, owner_id: USER, counterparty_id: null, name: 'Doniyor', client_alias: null, link_status: 'pending' },
];
const debts = [
  { id: 'd1', partner_id: ANVAR, kind: 'debt', direction: 'toMe', created_by: USER, amount: 2_000_000, paid: 0, currency: 'UZS', acted_at: '2026-04-21', due: null, status: 'active' },
  { id: 'd2', partner_id: DONIYOR, kind: 'debt', direction: 'fromMe', created_by: USER, amount: 1_500_000, paid: 0, currency: 'UZS', acted_at: '2026-07-01', due: '2026-07-22', status: 'active' },
];

// ============ Formatlash ============
test('fmtMoney — o\'qishli raqam (§6: "2.4 mln", "480k")', () => {
  assert.equal(fmtMoney(2_400_000), '2.4 mln');
  assert.equal(fmtMoney(8_000_000), '8 mln');
  assert.equal(fmtMoney(1_200_000), '1.2 mln');
  assert.equal(fmtMoney(480_000), '480k');
  assert.equal(fmtMoney(900), '900');
  assert.equal(fmtMoney(-1_800_000), '-1.8 mln');
  assert.equal(fmtSigned(1_800_000), '+1.8 mln');
  assert.equal(fmtSigned(-400_000), '-400k');
});

test('pctDelta — o\'tgan oyga nisbatan; prev=0 bo\'lsa null (bo\'lish yo\'q)', () => {
  assert.equal(pctDelta(1_200_000, 960_000), 25);
  assert.equal(pctDelta(500, 1000), -50);
  assert.equal(pctDelta(1000, 0), null);
});

test('uzDate — {{SANA}} o\'zbekcha, Toshkent vaqtida', () => {
  assert.equal(uzDate(NOW), '17-iyul, 2026');
});

// ============ Agregat ============
test('monthAgg — daromad/xarajat/balans + toifalar', () => {
  const a = monthAgg(expenses.filter((e) => e.occurred_at.startsWith('2026-07')));
  assert.equal(a.income, 8_000_000);
  assert.equal(a.expense, 3_330_000);
  assert.equal(a.net, 4_670_000);
  assert.equal(a.cats.get('Transport'), 1_200_000);
  assert.equal(a.cats.get('Daromad'), undefined); // daromad toifaga tushmaydi
});

test('streakDays — kunlik byudjetda qolingan ketma-ket kunlar', () => {
  const rows = [
    { income: false, amount: 300_000, occurred_at: '2026-07-14T09:00:00Z' }, // byudjetdan oshgan
    { income: false, amount: 50_000, occurred_at: '2026-07-15T09:00:00Z' },
    { income: false, amount: 50_000, occurred_at: '2026-07-16T09:00:00Z' },
  ];
  assert.equal(streakDays(rows, 200_000, NOW), 3);  // 17, 16, 15 -> 14-da uziladi
  assert.equal(streakDays(rows, 0, NOW), 0);        // chegara yo'q -> streak yo'q
});

test('aggregateDebts — toMe/fromMe, kun va muddat', () => {
  const agg = aggregateDebts(partners, debts, USER, NOW);
  const anvar = agg.find((e) => e.id === ANVAR);
  const doniyor = agg.find((e) => e.id === DONIYOR);
  assert.equal(anvar.to_me, 2_000_000);
  assert.equal(anvar.days, 87);          // 21-aprel -> 17-iyul
  assert.equal(anvar.can_remind, true);  // ega + qabul qilingan link
  assert.equal(doniyor.from_me, 1_500_000);
  assert.equal(doniyor.due_in, 5);       // 22-iyulgacha 5 kun
  assert.equal(doniyor.can_remind, false); // link qabul qilinmagan -> tugma yo'q
});

// ============ Kontekst matni ============
test('composeContext — §7 formatidagi agregat', () => {
  const { summary } = composeContext({
    now: NOW, expenses, debtAgg: aggregateDebts(partners, debts, USER, NOW),
    monthlyLimit: 6_000_000, categories: ['Oziq-ovqat', 'Transport', 'Boshqa'],
    uncategorized: [expenses.find((e) => e.id === EXP1)],
  });
  assert.match(summary, /Joriy oy \(iyul\): daromad 8 mln, xarajat 3\.3 mln, balans \+4\.7 mln\./);
  assert.match(summary, /O'tgan oy \(iyun\)/);
  assert.match(summary, /Transport 1\.2 mln \(36%, o'tgan oydan \+25%\)/);
  assert.match(summary, /Eng tez o'suvchi: Transport \(\+25%\), asosiy sabab: taksi \(2 marta, 1\.2 mln\)/);
  assert.match(summary, /Qarzlar \(menga qarzdorlar\): HAMKOR_1 2 mln \(87 kun\)/);
  assert.match(summary, /Mening qarzlarim: HAMKOR_2ga 1\.5 mln \(muddati 5 kun qoldi\)/);
  assert.match(summary, /Oylik chegara: 6 mln, sarflandi 3\.3 mln \(56%\)/);
  assert.match(summary, /Toifasiz yozuvlar .*YOZUV_1/);
  // Token byudjeti: ~600 token (~2600 belgi)
  assert.ok(summary.length < 2600, `kontekst juda uzun: ${summary.length} belgi`);
});

test('MAXFIYLIK — kontekstda real hamkor ismi YO\'Q (faqat HAMKOR_n)', () => {
  const { summary, tokens } = composeContext({
    now: NOW, expenses, debtAgg: aggregateDebts(partners, debts, USER, NOW),
    monthlyLimit: 0, categories: [], uncategorized: [],
  });
  assert.ok(!summary.includes('Anvar'), 'Anvar ismi modelga ketayotgan matnda!');
  assert.ok(!summary.includes('Doniyor'), 'Doniyor ismi modelga ketayotgan matnda!');
  assert.equal(tokens.HAMKOR_1.name, 'Anvar');   // xarita FAQAT serverda
  assert.equal(tokens.HAMKOR_1.id, ANVAR);
  assert.equal(tokens.HAMKOR_2.name, 'Doniyor');
});

test('composeContext — ma\'lumot yo\'q bo\'lsa modelga halol ayt (raqam to\'qimasin)', () => {
  const { summary } = composeContext({ now: NOW, expenses: [], debtAgg: [] });
  assert.match(summary, /Ma'lumot hali yo'q/);
  assert.match(summary, /Raqam to'qima/);
});

test('MAXFIYLIK — qarzsiz hamkor ham xaritada (summary\'ga tushmay, xabarni tozalash uchun)', () => {
  const other = [{ id: 'p-shirin', name: 'Shirin', can_remind: false, to_me: 0, from_me: 0, days: null, due_in: null }];
  // Qarzli hamkorlar past raqamlarni oladi, qarzsizi keyingisini
  const { summary, tokens } = composeContext({
    now: NOW, expenses, debtAgg: aggregateDebts(partners, debts, USER, NOW), otherPartners: other,
    monthlyLimit: 0, categories: [], uncategorized: [],
  });
  assert.ok(!summary.includes('Shirin'), 'qarzsiz hamkor summary\'da — token isrof!');
  assert.ok(!summary.includes('HAMKOR_3'), 'qarzsiz hamkor belgisi summary\'da ko\'rinmasligi kerak');
  assert.equal(tokens.HAMKOR_3.name, 'Shirin');
  // Asosiy maqsad: uning ismi ham foydalanuvchi xabaridan tozalanadi
  assert.equal(pseudonymizeText('Shiringa uy sotdim', tokens), 'HAMKOR_3ga uy sotdim');

  // Yozuv yo'q holatda ham xarita to'ladi (early-return yo'lida)
  const empty = composeContext({ now: NOW, expenses: [], debtAgg: [], otherPartners: other });
  assert.equal(empty.tokens.HAMKOR_1.name, 'Shirin');
});

// ============ Psevdonimlashtirish (oldinga) ============
test('pseudonymizeText — foydalanuvchi xabaridagi ism ham belgiga almashadi', () => {
  const tokens = { HAMKOR_1: { id: ANVAR, name: 'Anvar' }, HAMKOR_2: { id: DONIYOR, name: 'Doniyor' } };
  assert.equal(pseudonymizeText('Anvarga qachon aytay?', tokens), 'HAMKOR_1ga qachon aytay?');
  assert.equal(pseudonymizeText('anvar qarzini qaytardimi?', tokens), 'HAMKOR_1 qarzini qaytardimi?');
  assert.equal(pseudonymizeText('Doniyorning muddati?', tokens), 'HAMKOR_2ning muddati?');
});

test('pseudonymizeText — boshqa so\'z ichidagi ism TEGILMAYDI (Ali != Alisher)', () => {
  const tokens = { HAMKOR_1: { id: 'x', name: 'Ali' } };
  assert.equal(pseudonymizeText('Alisher bilan Aliga berdim', tokens), 'Alisher bilan HAMKOR_1ga berdim');
});

// ============ De-psevdonimlashtirish (orqaga) ============
test('restoreText — belgi + o\'zbek affiksi ("HAMKOR_2ga" -> "Doniyorga")', () => {
  const tokens = { HAMKOR_1: { name: 'Anvar' }, HAMKOR_2: { name: 'Doniyor' }, YOZUV_1: { note: 'taksi' } };
  assert.equal(restoreText('HAMKOR_1da 2 mln turibdi', tokens), 'Anvarda 2 mln turibdi');
  assert.equal(restoreText('HAMKOR_2ga qarzing bor', tokens), 'Doniyorga qarzing bor');
  assert.equal(restoreText('YOZUV_1 ni ko\'chiraymi?', tokens), '"taksi" ni ko\'chiraymi?');
  // To'qilgan belgi foydalanuvchiga XOM chiqmaydi
  assert.equal(restoreText('HAMKOR_9 qarzdor', tokens), 'hamkoring qarzdor');
});

test('ROUND-TRIP — ism -> belgi -> ism (o\'zgarishsiz qaytadi)', () => {
  const tokens = { HAMKOR_1: { id: ANVAR, name: 'Anvar' } };
  const original = 'Anvarga qachon eslatay?';
  const safe = pseudonymizeText(original, tokens);
  assert.ok(!safe.includes('Anvar'), 'ism modelga ketayotgan matnda qoldi!');
  assert.equal(restoreText(safe, tokens), original);
});

// ============ Bloklarni tiklash + server majburlashi ============
test('restoreBlocks — debt_card raqamlarini SERVER to\'ldiradi, to\'qilgan belgi tashlanadi', () => {
  const { tokens } = composeContext({
    now: NOW, expenses, debtAgg: aggregateDebts(partners, debts, USER, NOW),
    monthlyLimit: 0, categories: [], uncategorized: [expenses.find((e) => e.id === EXP1)],
  });
  const model = validateBlocks({
    blocks: [
      { type: 'text', text: 'HAMKOR_1da 3 oydan beri 2 mln turibdi.' },
      { type: 'debt_card', partner_id: 'HAMKOR_1' },
      { type: 'debt_card', partner_id: 'HAMKOR_9' },              // to'qilgan
      { type: 'category_move', expense_id: 'YOZUV_1', to: 'Transport' },
      { type: 'budget_set', amount: 5_000_000, label: 'Transport chegarasi' },
      { type: 'chips', items: ['Keyinroq', 'Boshqa qarzlarim?'] },
    ],
  });
  const out = restoreBlocks(model, tokens, { categories: ['Oziq-ovqat', 'Transport', 'Boshqa'] });

  assert.equal(out[0].text, 'Anvarda 3 oydan beri 2 mln turibdi.');
  const card = out.find((b) => b.type === 'debt_card');
  assert.equal(card.partner_id, ANVAR);       // real UUID
  assert.equal(card.name, 'Anvar');           // real ism
  assert.equal(card.amount, 2_000_000);       // model emas — server qo'ydi
  assert.equal(card.days, 87);
  assert.equal(card.direction, 'toMe');
  assert.deepEqual(card.actions, [{ label: 'Eslatma yuborish', action: 'remind', confirm: true }]);
  assert.equal(out.filter((b) => b.type === 'debt_card').length, 1, 'to\'qilgan HAMKOR_9 tashlanmadi!');

  const move = out.find((b) => b.type === 'category_move');
  assert.equal(move.expense_id, EXP1);
  assert.equal(move.from, 'Boshqa');
  assert.equal(move.to, 'Transport');
  assert.equal(move.actions[0].confirm, true);

  const budget = out.find((b) => b.type === 'budget_set');
  assert.equal(budget.scope, 'monthly');
  assert.equal(budget.category, undefined, 'toifa bo\'yicha chegara DB\'da yo\'q — tashlanishi shart!');
  assert.equal(budget.actions[0].confirm, true);
});

test('restoreBlocks — noma\'lum toifaga ko\'chirish taklifi tashlanadi', () => {
  const tokens = { YOZUV_1: { id: EXP1, note: 'taksi', amount: 30_000, category: 'Boshqa' } };
  const blocks = [{ type: 'category_move', expense_id: 'YOZUV_1', to: 'Kosmos' }];
  assert.equal(restoreBlocks(blocks, tokens, { categories: ['Transport'] }).length, 0);
});

// ============ Sxema validatsiyasi (xom model JSON'iga ishonch yo'q) ============
test('validateBlocks — yaroqsiz blok tashlanadi, javob buzilmaydi', () => {
  const out = validateBlocks({
    blocks: [
      { type: 'text', text: 'Yaxshi ketyapsan.' },
      { type: 'text' },                                   // matnsiz -> tashlanadi
      { type: 'hack', text: 'x' },                        // noma'lum tur -> tashlanadi
      { type: 'stat', label: 'Transport', value: '1.2 mln', delta: '+25%', tone: 'warn' },
      { type: 'stat', label: 'Yo\'q', tone: 'nuclear' },   // value yo'q -> tashlanadi
      { type: 'debt_card', partner_id: 'real-uuid-1234' }, // belgi emas -> tashlanadi
      { type: 'chart', kind: 'pie', title: 'T', data: [['Oziq-ovqat', 2_100_000], ['x', 'yomon']] },
    ],
  });
  assert.equal(out.length, 3);
  assert.equal(out[1].tone, 'warn');
  assert.equal(out[2].kind, 'bar');          // noma'lum kind -> xavfsiz default
  assert.deepEqual(out[2].data, [['Oziq-ovqat', 2_100_000]]); // buzuq nuqta tushib qoldi
});

test('validateBlocks — model bo\'sh/axlat qaytarsa bo\'sh massiv (matnli fallback\'ka tushadi)', () => {
  assert.deepEqual(validateBlocks(null), []);
  assert.deepEqual(validateBlocks({ blocks: 'salom' }), []);
  assert.deepEqual(validateBlocks({ blocks: [{ type: 'text', text: '   ' }] }), []);
});

// ============ Tarix navbatma-navbatligi (Anthropic 400 xatosining oldini oladi) ============
test('alternating — buzuq tarix tuzatiladi (user/assistant navbatma-navbat)', () => {
  const u = (c) => ({ role: 'user', content: c });
  const a = (c) => ({ role: 'assistant', content: c });
  // Normal holat: oxiri assistant -> o'zgarmaydi
  assert.deepEqual(alternating([u('1'), a('2'), u('3'), a('4')]), [u('1'), a('2'), u('3'), a('4')]);
  // Oxiri user (javob yozilmay qolgan) -> tashlanadi, aks holda 2 ta 'user' ketma-ket bo'lardi
  assert.deepEqual(alternating([u('1'), a('2'), u('3')]), [u('1'), a('2')]);
  // 'assistant' bilan boshlanmasin (limit juftlikni o'rtasidan kesgan)
  assert.deepEqual(alternating([a('0'), u('1'), a('2')]), [u('1'), a('2')]);
  // Ketma-ket bir xil rol -> so'nggisi qoladi
  assert.deepEqual(alternating([u('1'), u('2'), a('3')]), [u('2'), a('3')]);
  assert.deepEqual(alternating([]), []);
});
