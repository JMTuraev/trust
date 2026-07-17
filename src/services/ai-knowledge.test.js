// Trust AI bilim kutubxonasi — deterministik kunlik rotatsiya testi (tarmoqsiz, DB'siz).
// Yurgizish (repo ildizidan):  node --test src/services/ai-knowledge.test.js
//
// Eng muhim tekshiruv: KESH SHARTNOMASI — bir kun (Toshkent) ichida bir user uchun
// natija BAYT-BARQAROR bo'lishi shart (Anthropic prompt-cache shunga tayanadi).
import test from 'node:test';
import assert from 'node:assert/strict';
import { KNOWLEDGE, pickKnowledge } from './ai-knowledge.js';
import { contextBlock } from './ai-persona.js';

const USER_A = 'a3f1c9d2-1111-4a5b-8c2d-000000000001';
const USER_B = 'b7e2d0c3-2222-4f6a-9d3e-000000000002';
const DAY_MS = 24 * 3600_000;
const NOW = new Date('2026-07-17T10:00:00Z'); // Toshkentda 17-iyul 15:00

const ids = (list) => list.map((k) => k.id);

// ============ Kutubxona shakli ============
test('KNOWLEDGE — kamida 40 element, to\'g\'ri shakl, unikal id, 4 tag ham bor', () => {
  assert.ok(KNOWLEDGE.length >= 40, `kamida 40 kerak, bor: ${KNOWLEDGE.length}`);
  const validTags = new Set(['method', 'fact', 'habit', 'uz']);
  const seen = new Set();
  for (const k of KNOWLEDGE) {
    assert.ok(k.id && typeof k.id === 'string', 'id bo\'lishi shart');
    assert.ok(!seen.has(k.id), `takror id: ${k.id}`);
    seen.add(k.id);
    assert.ok(validTags.has(k.tag), `noto'g'ri tag: ${k.tag} (${k.id})`);
    assert.ok(typeof k.text === 'string' && k.text.trim().length > 20, `text juda qisqa: ${k.id}`);
  }
  // Har tag turidan kamida bittadan bor (mavzular xilma-xilligi)
  const tags = new Set(KNOWLEDGE.map((k) => k.tag));
  for (const t of validTags) assert.ok(tags.has(t), `tag yo'q: ${t}`);
});

// ============ Determinizm (kesh shartnomasi) ============
test('pickKnowledge — bir kun + bir user -> BIR XIL natija (bayt-barqaror)', () => {
  assert.deepEqual(pickKnowledge(USER_A, NOW), pickKnowledge(USER_A, NOW));
  // Kun ichidagi TURLI soatlar ham bir xil to'plam beradi (Toshkent kuni bir xil):
  // 00:00Z = Toshkent 05:00, 18:00Z = Toshkent 23:00 — ikkalasi 17-iyul.
  assert.deepEqual(
    pickKnowledge(USER_A, new Date('2026-07-17T00:00:00Z')),
    pickKnowledge(USER_A, new Date('2026-07-17T18:00:00Z')),
  );
});

test('pickKnowledge — kun chegarasi TOSHKENT bo\'yicha (UTC emas)', () => {
  // 18:59Z = Toshkent 23:59 (17-iyul), 19:01Z = Toshkent 00:01 (18-iyul) -> boshqa to'plam
  const before = pickKnowledge(USER_A, new Date('2026-07-17T18:59:00Z'));
  const after = pickKnowledge(USER_A, new Date('2026-07-17T19:01:00Z'));
  assert.notDeepEqual(ids(before), ids(after));
});

test('pickKnowledge — boshqa kun -> boshqa to\'plam (rotatsiya yuradi)', () => {
  const d1 = pickKnowledge(USER_A, NOW);
  const d2 = pickKnowledge(USER_A, new Date(NOW.getTime() + DAY_MS));
  assert.notDeepEqual(ids(d1), ids(d2));
});

test('pickKnowledge — boshqa user -> boshqa to\'plam (bir kunda)', () => {
  const a = pickKnowledge(USER_A, NOW);
  const b = pickKnowledge(USER_B, NOW);
  assert.notDeepEqual(ids(a), ids(b));
});

// ============ n va element sifati ============
test('pickKnowledge — default n=3, elementlar unikal va kutubxonadan', () => {
  const picked = pickKnowledge(USER_A, NOW);
  assert.equal(picked.length, 3);
  assert.equal(new Set(ids(picked)).size, 3, 'takror element bo\'lmasin');
  const all = new Set(ids(KNOWLEDGE));
  for (const k of picked) assert.ok(all.has(k.id), `kutubxonada yo'q id: ${k.id}`);
  // n boshqa qiymatlar: 5 -> 5 ta; haddan katta -> kutubxona hajmi bilan cheklanadi
  assert.equal(pickKnowledge(USER_A, NOW, 5).length, 5);
  assert.equal(pickKnowledge(USER_A, NOW, 10_000).length, KNOWLEDGE.length);
});

// ============ To'liq aylanish ============
test('pickKnowledge — LEN kun ichida BUTUN kutubxona aylanib chiqadi', () => {
  const covered = new Set();
  for (let d = 0; d < KNOWLEDGE.length; d++) {
    for (const k of pickKnowledge(USER_A, new Date(NOW.getTime() + d * DAY_MS))) covered.add(k.id);
  }
  assert.equal(covered.size, KNOWLEDGE.length, 'har karta kamida bir marta chiqishi kerak');
});

// ============ contextBlock integratsiyasi ============
test('contextBlock — kartalar blokini qo\'shadi va bayt-barqaror', () => {
  const knowledge = pickKnowledge(USER_A, NOW);
  const args = { name: 'Jafar', date: '17-iyul, 2026', summary: 'Joriy oy: xarajat 1 mln.', knowledge };
  const out = contextBlock(args);
  assert.match(out, /BUGUNGI BILIM KARTALARI/);
  for (const k of knowledge) assert.ok(out.includes(`- ${k.text}`), `karta matni yo'q: ${k.id}`);
  assert.equal(out, contextBlock(args), 'bir xil kirish -> bir xil bayt (prompt-cache)');
  // knowledge berilmasa — blok umuman chiqmaydi (eski xatti-harakat buzilmaydi)
  const plain = contextBlock({ name: 'Jafar', date: '17-iyul, 2026', summary: 'X' });
  assert.doesNotMatch(plain, /BUGUNGI BILIM KARTALARI/);
});
