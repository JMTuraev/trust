// Trust AI — AGREGAT KONTEKST (docs/ai-character.md §7) + PSEVDONIMLASHTIRISH (maxfiylik).
//
// 1) AGREGAT, xom yozuv EMAS. Modelga "iyulda 2.1 mln oziq-ovqat" boradi, 300 ta qator emas.
//    Sabab: token narxi + xarakter (model umumlashtirilgan faktlar bilan gapiradi).
//    Byudjet: ~600 token (MAX_SUMMARY_CHARS bilan qattiq cheklangan).
//    Kesh: ai_profile (TTL config.ai.profileTtlMs, default 6 soat).
//
// 2) PSEVDONIMLASHTIRISH — MAJBURIY, muzokara qilinmaydi.
//    Hamkor ismi UCHINCHI SHAXS ma'lumoti: u Anthropic'ga ma'lumot yuborishga rozilik
//    bermagan (ilova disclosure'si faqat FOYDALANUVCHINI qamraydi). Shuning uchun:
//      - kontekstda va foydalanuvchi xabarida har real ism -> HAMKOR_1, HAMKOR_2...
//      - xarajat yozuvi id'lari (UUID) -> YOZUV_1, YOZUV_2... (token ham tejaladi)
//      - model javobidagi belgilar SERVERDA real ism/UUID'ga qaytariladi (restoreBlocks)
//    Model real ismni HECH QACHON ko'rmaydi. Belgi->real xarita har user uchun ai_profile
//    da saqlanadi (bizning DB — tashqariga chiqmaydi) va so'rov davomida ishlatiladi.
import { config } from '../config.js';
import { supabaseAdmin } from '../lib/supabase.js';
import { rem, canonicalDir } from '../lib/ledger.js';
import { ensureCategories } from '../lib/categories.js';
import { meaningfulWords } from './parse.js';

// O'zbekiston UTC+5, DST yo'q — oy/kun chegaralari MAHALLIY vaqtda hisoblanadi
// (aks holda 1-iyul 02:00 dagi xarajat "iyun"ga tushib qolardi).
const TZ_OFFSET_MS = 5 * 3600_000;
const DAY_MS = 24 * 3600_000;
const MAX_SUMMARY_CHARS = 3000; // ~700 token (o'zbekcha ~4 belgi/token) — 2b/2c/6b hosila signallarga joy

export const MONTHS_UZ = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul',
  'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];

// ---------- Sof yordamchilar (test qilinadi, DB'siz) ----------

/** Mahalliy (Toshkent) sana bo'laklari. getUTC* — siljitilgan sanada mahalliy qiymat beradi. */
export function localParts(input) {
  const d = new Date(new Date(input).getTime() + TZ_OFFSET_MS);
  return { y: d.getUTCFullYear(), m: d.getUTCMonth(), day: d.getUTCDate(), key: d.toISOString().slice(0, 10) };
}

/** Mahalliy oy boshining UTC instanti (DB so'rovi uchun). */
export function monthStartUtc(y, m) {
  return new Date(Date.UTC(y, m, 1) - TZ_OFFSET_MS);
}

/** Mahalliy kun boshining UTC instanti (kunlik limit hisobi uchun). */
export function dayStartUtc(y, m, day) {
  return new Date(Date.UTC(y, m, day) - TZ_OFFSET_MS);
}

/** Bugungi sana o'zbekcha: "17-iyul, 2026" ({{SANA}} uchun). */
export function uzDate(now = new Date()) {
  const p = localParts(now);
  return `${p.day}-${MONTHS_UZ[p.m]}, ${p.y}`;
}

/** Pul: 2400000 -> "2.4 mln", 480000 -> "480k", 900 -> "900" (§6 JAVOB FORMATI). */
export function fmtMoney(n) {
  const v = Math.round(Number(n) || 0);
  const a = Math.abs(v);
  if (a >= 1_000_000) return `${(v / 1_000_000).toFixed(1).replace(/\.0$/, '')} mln`;
  if (a >= 1_000) return `${Math.round(v / 1_000)}k`;
  return String(v);
}

/** Balans uchun ishorali: +1.8 mln / -400k */
export function fmtSigned(n) {
  const v = Math.round(Number(n) || 0);
  return (v > 0 ? '+' : '') + fmtMoney(v);
}

/** Foiz o'zgarish (o'tgan oyga nisbatan). prev<=0 -> null (bo'lish yo'q, "yangi" deymiz). */
export function pctDelta(cur, prev) {
  if (!prev || prev <= 0) return null;
  return Math.round(((cur - prev) / prev) * 100);
}

const fmtPct = (p) => `${p > 0 ? '+' : ''}${p}%`;

/** Yozuvlarni oy kalitiga guruhlash: "2026-6" (0-indeksli oy). */
export function monthKeyOf(input) {
  const { y, m } = localParts(input);
  return `${y}-${m}`;
}

/** Bir oylik agregat: daromad, xarajat, balans, toifalar. */
export function monthAgg(rows) {
  let income = 0; let expense = 0;
  const cats = new Map();
  for (const r of rows || []) {
    const amt = Number(r.amount) || 0;
    if (r.income) { income += amt; continue; }
    expense += amt;
    const c = r.category || 'Boshqa';
    cats.set(c, (cats.get(c) || 0) + amt);
  }
  return { income, expense, net: income - expense, cats };
}

/**
 * Streak: bugundan orqaga qarab, kunlik byudjetda qolingan ketma-ket kunlar.
 * dailyBudget<=0 -> 0 (chegara qo'yilmagan). Yozuvsiz kun — byudjetda hisoblanadi.
 */
export function streakDays(rows, dailyBudget, now = new Date()) {
  if (!(dailyBudget > 0)) return 0;
  const perDay = new Map();
  for (const r of rows || []) {
    if (r.income) continue;
    const k = localParts(r.occurred_at).key;
    perDay.set(k, (perDay.get(k) || 0) + (Number(r.amount) || 0));
  }
  let streak = 0;
  for (let i = 0; i < 60; i++) {
    const key = localParts(new Date(now.getTime() - i * DAY_MS)).key;
    if ((perDay.get(key) || 0) > dailyBudget) break;
    streak++;
  }
  return streak;
}

/**
 * Eng tez o'suvchi toifa + ehtimoliy sabab.
 * Shovqinni kesish: o'tgan oyda >= 100k va o'sish >= 10% bo'lgan toifalargina.
 * Sabab: shu oyda o'sha toifadagi izohlarda eng ko'p uchragan ma'noli so'z.
 */
export function fastestGrowing(curCats, prevCats, curRows) {
  let best = null;
  for (const [name, cur] of curCats) {
    const prev = prevCats.get(name) || 0;
    if (prev < 100_000) continue;
    const d = pctDelta(cur, prev);
    if (d === null || d < 10) continue;
    if (!best || d > best.delta) best = { name, delta: d, cur, prev };
  }
  if (!best) return null;
  const words = new Map(); // so'z -> {count, sum}
  for (const r of curRows || []) {
    if (r.income || (r.category || 'Boshqa') !== best.name) continue;
    for (const w of meaningfulWords(r.note || '')) {
      const e = words.get(w) || { count: 0, sum: 0 };
      e.count++; e.sum += Number(r.amount) || 0;
      words.set(w, e);
    }
  }
  const top = [...words.entries()].sort((a, b) => b[1].count - a[1].count || b[1].sum - a[1].sum)[0];
  best.cause = top && top[1].count >= 2 ? { word: top[0], count: top[1].count, sum: top[1].sum } : null;
  return best;
}

/**
 * Hamkor bo'yicha ochiq qarzlar agregati (foydalanuvchi nuqtai nazarida).
 * partners: partners qatorlari; debts: shu hamkorlarning 'debt' yozuvlari.
 * Faqat UZS (v1 — kontekst so'mda gapiradi; boshqa valyuta hisobga olinmaydi).
 */
export function partnerEntry(p, userId) {
  const isOwner = p.owner_id === userId;
  const name = (isOwner ? p.name : p.client_alias) || 'Hamkor';
  return {
    id: p.id,
    name: String(name).trim(),
    // POST /api/partners/:id/remind shartlari (routes/partners.js): ega + qabul qilingan link
    can_remind: isOwner && !!p.counterparty_id && p.link_status === 'accepted',
    to_me: 0, from_me: 0, days: null, due_in: null,
  };
}

export function aggregateDebts(partners, debts, userId, now = new Date()) {
  const byPartner = new Map();
  for (const p of partners || []) byPartner.set(p.id, partnerEntry(p, userId));
  const today = localParts(now).key;
  for (const d of debts || []) {
    if (d.kind !== 'debt' || d.status !== 'active') continue;
    if ((d.currency || 'UZS') !== 'UZS') continue;
    const left = rem(d);
    if (left <= 0) continue;
    const e = byPartner.get(d.partner_id);
    if (!e) continue;
    const dir = canonicalDir(d, userId); // 'toMe' = u menga qarzdor
    if (dir === 'toMe') {
      e.to_me += left;
      const days = Math.max(0, Math.round((Date.parse(`${today}T00:00:00Z`) - Date.parse(`${d.acted_at}T00:00:00Z`)) / DAY_MS));
      if (e.days === null || days > e.days) e.days = days; // eng eski = eng og'riqli signal
    } else if (dir === 'fromMe') {
      e.from_me += left;
      if (d.due) {
        const left2 = Math.round((Date.parse(`${d.due}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / DAY_MS);
        if (e.due_in === null || left2 < e.due_in) e.due_in = left2; // eng yaqin muddat
      }
    }
  }
  return [...byPartner.values()].filter((e) => e.to_me > 0 || e.from_me > 0);
}

// ---------- Kontekst matni + belgi xaritasi ----------

/**
 * Agregat matn + psevdonim xaritasini yasaydi (SOF funksiya — DB'siz, testlanadi).
 * input: { now, expenses[], debtAgg[], monthlyLimit, categories[], uncategorized[] }
 * return: { summary, tokens }  tokens: { HAMKOR_1:{...}, YOZUV_1:{...} }
 */
export function composeContext({ now = new Date(), expenses = [], debtAgg = [], monthlyLimit = 0, categories = [], uncategorized = [], otherPartners = [] }) {
  const cur = localParts(now);
  const curKey = `${cur.y}-${cur.m}`;
  const prevDate = new Date(Date.UTC(cur.y, cur.m - 1, 15));
  const prevKey = `${prevDate.getUTCFullYear()}-${prevDate.getUTCMonth()}`;

  const byMonth = new Map();
  for (const r of expenses) {
    const k = monthKeyOf(r.occurred_at);
    if (!byMonth.has(k)) byMonth.set(k, []);
    byMonth.get(k).push(r);
  }
  const curRows = byMonth.get(curKey) || [];
  const prevRows = byMonth.get(prevKey) || [];
  const a = monthAgg(curRows);
  const b = monthAgg(prevRows);

  const tokens = {};
  const lines = [];

  // Belgi mashinasi — early-return'dan OLDIN, chunki qarzsiz hamkorlar ham xaritaga
  // tushishi kerak (pastdagi izohga qarang).
  let n = 0;
  const placed = new Map(); // partner id -> belgi (bitta hamkor ikkala ro'yxatda bo'lishi mumkin)
  const tokenFor = (e) => {
    if (!placed.has(e.id)) {
      const t = `HAMKOR_${++n}`;
      tokens[t] = { ...e };
      placed.set(e.id, t);
    }
    return placed.get(e.id);
  };
  // MAXFIYLIK: qarzi YO'Q hamkorlar ham xaritaga qo'shiladi. Ular summary'ga TUSHMAYDI
  // (ya'ni bitta ham token sarflamaydi), lekin xarita foydalanuvchi XABARIDAGI ismni
  // belgiga almashtirish uchun kerak: "Anvarga uy sotdim" — Anvarning ochiq qarzi
  // bo'lmasa ham, uning ismi modelga ketmasligi shart.
  const addOthers = () => { for (const p of otherPartners) tokenFor(p); };

  // Ma'lumot kam bo'lsa — modelga ANIQ ayt (raqam to'qimasin, §5 "Raqam to'qima")
  if (!curRows.length && !prevRows.length && !debtAgg.length) {
    addOthers();
    return {
      summary: 'Ma\'lumot hali yo\'q: bu oyda ham, o\'tgan oyda ham yozuv kiritilmagan, ochiq qarz ham yo\'q.\n'
        + 'Raqam to\'qima — foydalanuvchini birinchi yozuvni kiritishga muloyim taklif qil.',
      tokens,
    };
  }

  // 1. Joriy / o'tgan oy
  lines.push(`Joriy oy (${MONTHS_UZ[cur.m]}): daromad ${fmtMoney(a.income)}, xarajat ${fmtMoney(a.expense)}, balans ${fmtSigned(a.net)}.`);
  if (prevRows.length) {
    lines.push(`O'tgan oy (${MONTHS_UZ[prevDate.getUTCMonth()]}): daromad ${fmtMoney(b.income)}, xarajat ${fmtMoney(b.expense)}, balans ${fmtSigned(b.net)}.`);
  }

  // 2. Top toifalar (% + o'tgan oyga nisbatan delta)
  const top = [...a.cats.entries()].sort((x, y) => y[1] - x[1]).slice(0, 4);
  if (top.length) {
    const parts = top.map(([name, amt]) => {
      const pct = a.expense > 0 ? Math.round((amt / a.expense) * 100) : 0;
      const d = pctDelta(amt, b.cats.get(name) || 0);
      return `${name} ${fmtMoney(amt)} (${pct}%${d !== null ? `, o'tgan oydan ${fmtPct(d)}` : ''})`;
    });
    lines.push(`Top xarajat toifalari (${MONTHS_UZ[cur.m]}): ${parts.join(', ')}.`);
    // 2b. Top toifaning yillik proyeksiyasi — modelga "oldinga qaragan" ma'no beradi.
    const [topName, topAmt] = top[0];
    if (topAmt > 0) {
      lines.push(`Yillik proyeksiya: ${topName} shu tezlikda yiliga ~${fmtMoney(topAmt * 12)} (joriy oy top toifasi × 12).`);
    }
  }

  // 2c. Oyning eng katta bitta xarajati — toifa + summa (+ xom izoh, foydalanuvchining o'z
  // ma'lumoti, slice(0,30) — 7-bo'limdagi uncategorized konvensiyasi bilan bir xil).
  const bigExp = curRows.filter((r) => !r.income)
    .sort((x, y) => (Number(y.amount) || 0) - (Number(x.amount) || 0))[0];
  if (bigExp && (Number(bigExp.amount) || 0) > 0) {
    const bnote = String(bigExp.note || '').slice(0, 30);
    lines.push(`Oyning eng katta bitta xarajati: ${bigExp.category || 'Boshqa'} ${fmtMoney(bigExp.amount)}${bnote ? ` ("${bnote}")` : ''}.`);
  }

  // 3. Eng tez o'suvchi + sabab
  const fast = fastestGrowing(a.cats, b.cats, curRows);
  if (fast) {
    const cause = fast.cause ? `, asosiy sabab: ${fast.cause.word} (${fast.cause.count} marta, ${fmtMoney(fast.cause.sum)})` : '';
    lines.push(`Eng tez o'suvchi: ${fast.name} (${fmtPct(fast.delta)})${cause}.`);
  }

  // 4. Qarzlar — HAMKOR_n belgilari bilan (real ism modelga BORMAYDI)
  const toMe = debtAgg.filter((e) => e.to_me > 0).sort((x, y) => y.to_me - x.to_me).slice(0, 5);
  const fromMe = debtAgg.filter((e) => e.from_me > 0)
    .sort((x, y) => (x.due_in ?? 9999) - (y.due_in ?? 9999) || y.from_me - x.from_me).slice(0, 5);
  if (toMe.length) {
    lines.push(`Qarzlar (menga qarzdorlar): ${toMe.map((e) => `${tokenFor(e)} ${fmtMoney(e.to_me)} (${e.days ?? 0} kun)`).join(', ')}.`);
  }
  if (fromMe.length) {
    lines.push(`Mening qarzlarim: ${fromMe.map((e) => {
      const t = tokenFor(e);
      let due = 'muddati belgilanmagan';
      if (e.due_in !== null && e.due_in !== undefined) {
        due = e.due_in >= 0 ? `muddati ${e.due_in} kun qoldi` : `muddati ${Math.abs(e.due_in)} kun o'tdi`;
      }
      return `${t}ga ${fmtMoney(e.from_me)} (${due})`;
    }).join(', ')}.`);
  }

  addOthers(); // qarzli hamkorlar past raqamlarni oldi — qolganlari xaritaga (summary'siz)

  // 5. Jamg'arma odati — oxirgi 3 TUGAGAN oy o'rtacha sof balansi
  const trend = [];
  for (let i = 1; i <= 3; i++) {
    const d = new Date(Date.UTC(cur.y, cur.m - i, 15));
    const rows = byMonth.get(`${d.getUTCFullYear()}-${d.getUTCMonth()}`);
    if (rows?.length) trend.push(monthAgg(rows).net);
  }
  if (trend.length >= 2) {
    const avg = trend.reduce((s, v) => s + v, 0) / trend.length;
    lines.push(`Jamg'arma odati: oxirgi ${trend.length} oy o'rtacha ${fmtSigned(avg)}/oy.`);
  }

  // 6. Oylik chegara + streak
  if (monthlyLimit > 0) {
    const daysInMonth = new Date(Date.UTC(cur.y, cur.m + 1, 0)).getUTCDate();
    const daily = Math.round(monthlyLimit / daysInMonth);
    const pct = Math.round((a.expense / monthlyLimit) * 100);
    lines.push(`Oylik chegara: ${fmtMoney(monthlyLimit)}, sarflandi ${fmtMoney(a.expense)} (${pct}%). Kunlik ~${fmtMoney(daily)}.`);
    // 6b. Oy-temp: vaqt ↔ byudjet tezligini taqqoslaydi ("oyning 55%i, byudjetning 62%i").
    const monthPct = Math.round((cur.day / daysInMonth) * 100);
    const pace = pct - monthPct >= 10 ? ' — byudjet vaqtdan oldinda, tez' : '';
    lines.push(`Oy-temp: oyning ${monthPct}%i o'tdi, byudjetning ${pct}%i sarflandi${pace}.`);
    const s = streakDays(expenses, daily, now);
    if (s >= 1) lines.push(`Streak: ${s} kundan beri kunlik byudjetda.`);
    else lines.push('Streak: uzildi — bugun kunlik byudjetdan oshgan.');
  }

  // 7. Toifasiz yozuvlar — category_move taklifi uchun (YOZUV_n = UUID o'rniga)
  if (uncategorized.length) {
    let m = 0;
    const parts = uncategorized.slice(0, 4).map((e) => {
      const t = `YOZUV_${++m}`;
      tokens[t] = { id: e.id, note: e.note || '', amount: Number(e.amount) || 0, category: e.category || 'Boshqa' };
      const day = localParts(e.occurred_at);
      return `${t} "${String(e.note || '').slice(0, 30)}" ${fmtMoney(e.amount)} (${day.day}-${MONTHS_UZ[day.m]})`;
    });
    lines.push(`Toifasiz yozuvlar (category_move taklifi uchun): ${parts.join(', ')}.`);
  }

  if (categories.length) lines.push(`Mavjud toifalar: ${categories.join(', ')}.`);

  // DEFENSE-IN-DEPTH (maxfiylik): xom izohlar (2c "eng katta xarajat", §7 toifasiz
  // yozuvlar) foydalanuvchining o'z matni — lekin ichida hamkor ISMI bo'lishi mumkin
  // ("Anvarga berdim"). Yakuniy summary'ni bir marta psevdonimlashtiramiz: xaritadagi
  // har real ism -> HAMKOR_n. Shu bilan hozirgi va KELAJAKDAGI barcha xom-matn
  // manbalari bitta joyda yopiladi (routes/ai.js summary'ni boshqa tozalamaydi).
  let summary = pseudonymizeText(lines.join('\n'), tokens);
  if (summary.length > MAX_SUMMARY_CHARS) summary = `${summary.slice(0, MAX_SUMMARY_CHARS)}…`;
  return { summary, tokens };
}

// ---------- PSEVDONIMLASHTIRISH ----------

const escapeRe = (s) => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// O'zbek affikslari (uzunroq — oldin): "Anvarga" -> "HAMKOR_1ga" bo'lib to'g'ri almashadi,
// "Alisher" esa "Ali" hamkor bo'lsa ham TEGILMAYDI (ortidan harf qolsa moslik bekor).
const AFFIX = "(?:larining|laringiz|larimiz|larniki|larning|largacha|lardagi|lardan|larga|larda|larni|lari|lar|nikida|niki|ning|gacha|dagi|dan|day|dek|ga|ka|qa|da|ni|ing|im|si|i)?";

/**
 * Matndagi REAL ismlarni HAMKOR_n belgilariga almashtiradi (foydalanuvchi xabari uchun).
 * Model hech qachon real ism ko'rmasin — kontekstda ham, xabarda ham.
 */
export function pseudonymizeText(text, tokens) {
  let out = String(text || '');
  const named = Object.entries(tokens || {})
    .filter(([k, v]) => k.startsWith('HAMKOR_') && v?.name && String(v.name).trim().length >= 3)
    .sort((x, y) => String(y[1].name).length - String(x[1].name).length); // uzun ism oldin
  for (const [tok, v] of named) {
    const re = new RegExp(`(?<![\\p{L}\\p{N}])${escapeRe(String(v.name).trim())}${AFFIX}(?![\\p{L}\\p{N}])`, 'giu');
    out = out.replace(re, (match) => {
      const suffix = match.slice(String(v.name).trim().length);
      return tok + suffix; // affiks saqlanadi: "Anvarga" -> "HAMKOR_1ga"
    });
  }
  return out;
}

// DIQQAT: oxirida \b ISHLATILMAYDI. Model o'zbekcha affiks bilan yozadi ("HAMKOR_2ga
// 1.5 mln qarzing bor") — \b bo'lsa "HAMKOR_2ga" moslikka tushmay, belgi foydalanuvchiga
// XOM holda chiqib ketardi (aynan biz to'sayotgan sizib chiqish). Boshida lookbehind bor,
// oxirida esa affiks ataylab erkin qoldiriladi: "HAMKOR_2" -> "Doniyor", "ga" joyida qoladi.
// KATTA-KICHIK HARFGA BEFARQ (i): Opus belgini "Hamkor_1" deb yozgani kuzatildi
// (2026-07-17, chart labelida XOM chiqib ketdi) — endi har qanday yozilish tiklanadi.
const TOKEN_RE = /(?<![\p{L}\p{N}_])(HAMKOR|YOZUV)_(\d+)/giu;

/** Matndagi belgilarni real ism/izohga qaytaradi (model javobi -> foydalanuvchi). */
export function restoreText(text, tokens) {
  return String(text ?? '').replace(TOKEN_RE, (m, kind, num) => {
    const up = kind.toUpperCase();
    const t = tokens?.[`${up}_${num}`]; // xaritada belgi doim KATTA harfda
    if (!t) return up === 'HAMKOR' ? 'hamkoring' : 'bu yozuv'; // to'qilgan belgi — yumshoq tushirish
    if (up === 'HAMKOR') return t.name || 'hamkoring';
    return t.note ? `"${t.note}"` : 'bu yozuv';
  });
}

/**
 * Model bloklarini foydalanuvchi ko'radigan holatga keltiradi:
 *   - HAMKOR_n / YOZUV_n -> real ism / izoh (matnda)
 *   - partner_id / expense_id -> real UUID (noma'lum belgi -> blok TASHLANADI)
 *   - debt_card raqamlari SERVER tomonidan majburiy to'ldiriladi (model to'qimasin)
 *   - budget_set / category_move — faqat TAKLIF, har doim confirm:true
 * blocks — anthropic.js validateBlocks() dan o'tgan (sxema to'g'ri).
 */
export function restoreBlocks(blocks, tokens, { categories = [] } = {}) {
  const out = [];
  const catOf = (name) => categories.find((c) => c.toLowerCase() === String(name || '').trim().toLowerCase());
  for (const b of blocks || []) {
    if (b.type === 'debt_card') {
      const t = tokens?.[b.partner_id];
      if (!t || !t.id) continue; // to'qilgan hamkor — blok tashlanadi
      const toMe = (t.to_me || 0) > 0;
      const amount = toMe ? t.to_me : t.from_me;
      if (!(amount > 0)) continue;
      out.push({
        type: 'debt_card',
        partner_id: t.id,
        name: t.name,
        amount,
        direction: toMe ? 'toMe' : 'fromMe',
        days: toMe ? (t.days ?? 0) : null,
        due_in: toMe ? null : (t.due_in ?? null),
        // OLTIN QOIDA: amalni AI bajarmaydi — tugma + confirm, foydalanuvchi bosadi
        actions: toMe && t.can_remind
          ? [{ label: 'Eslatma yuborish', action: 'remind', confirm: true }]
          : [],
      });
      continue;
    }
    if (b.type === 'category_move') {
      const t = tokens?.[b.expense_id];
      const to = catOf(b.to);
      if (!t || !t.id || !to) continue;      // noma'lum yozuv yoki toifa -> tashlanadi
      if (to === t.category) continue;        // o'zgarish yo'q -> ma'nosiz taklif
      out.push({
        type: 'category_move',
        expense_id: t.id,
        note: t.note || '',
        amount: t.amount || 0,
        from: t.category || 'Boshqa',
        to,
        actions: [{ label: `${to}ga ko'chirish`, action: 'move_category', confirm: true }],
      });
      continue;
    }
    if (b.type === 'budget_set') {
      const amount = Math.round(Number(b.amount) || 0);
      if (!(amount > 0)) continue;
      // DIQQAT: limits jadvalida faqat UMUMIY oylik chegara bor (toifa bo'yicha YO'Q) —
      // shuning uchun model bergan `category` ATAYLAB tashlanadi (aks holda "Transportga
      // 800k" taklifi butun oylik limitni 800k qilib qo'yardi).
      out.push({
        type: 'budget_set',
        scope: 'monthly',
        label: restoreText(b.label || 'Oylik xarajat chegarasi', tokens),
        amount,
        actions: [{ label: "Chegara qo'yish", action: 'set_limit', confirm: true }],
      });
      continue;
    }
    // Qolgan bloklar: matnli maydonlarda belgilarni tiklaymiz
    const c = { ...b };
    for (const k of ['text', 'label', 'title', 'value', 'delta', 'caption']) {
      if (typeof c[k] === 'string') c[k] = restoreText(c[k], tokens);
    }
    if (Array.isArray(c.items)) c.items = c.items.map((s) => restoreText(s, tokens));
    if (Array.isArray(c.data)) c.data = c.data.map((d) => [restoreText(d[0], tokens), d[1]]);
    out.push(c);
  }
  return out;
}

// ---------- DB qatlami: agregatni yig'ish + ai_profile keshi ----------

/** Foydalanuvchi kira oladigan hamkorlar: o'zi ega YOKI qabul qilingan kontragent. */
async function partnersOf(userId) {
  const [own, cp] = await Promise.all([
    supabaseAdmin.from('partners').select('id, owner_id, counterparty_id, name, client_alias, link_status')
      .eq('owner_id', userId).eq('archived', false),
    supabaseAdmin.from('partners').select('id, owner_id, counterparty_id, name, client_alias, link_status')
      .eq('counterparty_id', userId).eq('link_status', 'accepted'),
  ]);
  const map = new Map();
  for (const p of [...(own.data || []), ...(cp.data || [])]) map.set(p.id, p);
  return [...map.values()];
}

/** Agregatni NOLDAN hisoblaydi (kesh yozilmaydi — buni getProfile qiladi). */
export async function buildAggregate(userId, now = new Date()) {
  const cur = localParts(now);
  const from = monthStartUtc(cur.y, cur.m - 3).toISOString(); // joriy + 3 tugagan oy

  const [expRes, limRes, cats, partners] = await Promise.all([
    supabaseAdmin.from('expenses').select('id, income, amount, category, note, occurred_at')
      .eq('user_id', userId).gte('occurred_at', from)
      .order('occurred_at', { ascending: false }).limit(2000),
    supabaseAdmin.from('limits').select('monthly_limit').eq('user_id', userId).maybeSingle(),
    ensureCategories(userId),
    partnersOf(userId),
  ]);

  let debts = [];
  if (partners.length) {
    const { data } = await supabaseAdmin.from('debts')
      .select('id, partner_id, kind, direction, created_by, amount, paid, currency, acted_at, due, status')
      .in('partner_id', partners.map((p) => p.id)).eq('kind', 'debt').eq('status', 'active');
    debts = data || [];
  }

  const expenses = expRes.data || [];
  const curKey = `${cur.y}-${cur.m}`;
  const uncategorized = expenses.filter(
    (e) => !e.income && (e.category || 'Boshqa') === 'Boshqa' && monthKeyOf(e.occurred_at) === curKey && e.note
  ).slice(0, 4);

  const debtAgg = aggregateDebts(partners, debts, userId, now);
  // Qarzsiz hamkorlar: summary'ga tushmaydi, faqat psevdonim xaritasiga (xabarni tozalash uchun)
  const withDebt = new Set(debtAgg.map((e) => e.id));
  const otherPartners = partners.filter((p) => !withDebt.has(p.id)).map((p) => partnerEntry(p, userId));

  return composeContext({
    now,
    expenses,
    debtAgg,
    otherPartners,
    monthlyLimit: Number(limRes.data?.monthly_limit || 0),
    categories: cats.map((c) => c.name),
    uncategorized,
  });
}

/**
 * Keshlangan agregat. TTL (default 6 soat) dan eski bo'lsa qayta hisoblaydi.
 * force:true — invalidatsiya (yozuv o'zgarganda chaqirish uchun).
 * Kesh MUHIM: u nafaqat DB'ni, prompt cache'ni ham tejaydi — 2-blok bayt-barqaror
 * bo'lgani uchun Anthropic keshi TTL ichida uriladi.
 */
export async function getProfile(userId, { force = false, now = new Date() } = {}) {
  if (!force) {
    const { data } = await supabaseAdmin.from('ai_profile')
      .select('summary, tokens, computed_at').eq('user_id', userId).maybeSingle();
    if (data && now.getTime() - Date.parse(data.computed_at) < config.ai.profileTtlMs) {
      return { summary: data.summary, tokens: data.tokens || {}, cached: true };
    }
  }
  const built = await buildAggregate(userId, now);
  await supabaseAdmin.from('ai_profile').upsert({
    user_id: userId,
    summary: built.summary,
    tokens: built.tokens,
    computed_at: now.toISOString(),
  }, { onConflict: 'user_id' });
  return { ...built, cached: false };
}

/** Yozuv o'zgarganda keshni bekor qilish (xarajat/qarz route'lari chaqirishi mumkin). */
export async function invalidateProfile(userId) {
  await supabaseAdmin.from('ai_profile').delete().eq('user_id', userId);
}
