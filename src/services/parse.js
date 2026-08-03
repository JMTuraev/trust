// Parsing (matn -> daromad/xarajat/qarz) — XOTIRA-ovoz-va-kategoriya.md §3–4.
// Uch mustaqil signal: 1) LLM (Anthropic Claude ASOSIY, zaxira Groq -> OpenAI) — qat'iy JSON;
// 2) qoida-parser (validator); 3) kalit so'z lug'ati (o'z-o'zini to'ldiruvchi).
// Qoidalar: LLM+qoida summasi mos va ishonch >= 0.8 -> to'g'ridan-to'g'ri;
// aks holda tasdiqlash kartasi. Qarz iboralari Xarajatga emas, Hamkorlar oqimiga.
// Token tejash (2026-08-03 PO): LLM — OXIRGI chora: lug'at short-circuit ('dict'),
// natija keshi, per-user kunlik chaqiruv limiti, kunlik token kill-switch.
import { config } from '../config.js';
import { supabaseAdmin } from '../lib/supabase.js';
import { ensureCategories } from '../lib/categories.js';

export const DIRECTIONS = [
  'daromad', 'xarajat', 'qarz_berdim', 'qarz_oldim', 'qaytardim', 'menga_qaytarildi',
];
const QARZ = ['qarz_berdim', 'qarz_oldim', 'qaytardim', 'menga_qaytarildi'];
export const isQarz = (d) => QARZ.includes(d);

// ---------- Yordamchi: matn normalizatsiya va so'zlar ----------
const norm = (s) => String(s || '').toLowerCase().replace(/[’'`ʼ]/g, "'").trim();

const STOP = new Set([
  'ming', 'mln', 'million', 'milion', "so'm", 'som', 'sum', 'dollar', 'uzs',
  'минг', 'млн', 'миллион', 'милион', 'тыс', 'тысяч', 'сум', 'сўм',
  'uchun', 'bilan', 'dan', 'ga', 'da', 'ni', 'va', 'ham', 'esa', 'edi',
  'bugun', 'kecha', 'ertaga', 'oldim', 'berdim', 'qarz', "to'ladim", 'toladim',
  'ketdi', 'tushdi', 'keldi', 'qildim', 'boldi', "bo'ldi", 'menga', 'unga',
  // 2026-08-03 kech: umumiy fe'l IMLO VARIANTLARI lug'atga o'rganilib STRONG bo'lib
  // olgan (tuladim->Transport hits=7 "svetga ... tuladim"ni doim Transportga majburlagan).
  // Fe'l toifa signali EMAS — barcha keng tarqalgan yozilishlari STOP'da tursin.
  'tuladim', 'tulladim', 'tulash', 'tolash', "to'lash", 'sarfladim', 'ishlatdim',
  'bedim', 'berdm', 'ketti', 'qilish', 'qivordim', 'qildik', 'yedim', 'yedik',
]);

// Lug'at uchun ma'noli so'zlar (raqam/stop-so'z/qisqa so'zlar chiqariladi)
export function meaningfulWords(text) {
  return [...new Set(
    norm(text)
      .replace(/[.,!?;:()"«»]/g, ' ')
      .split(/\s+/)
      .map((w) => w.replace(/(ga|da|dan|ni|ning)$/, '')) // sodda affiks kesish
      .filter((w) => w.length >= 3 && !STOP.has(w) && !/\d/.test(w))
  )].slice(0, 8);
}

// ---------- 2-signal: QOIDA-PARSER (validator roli) ----------
// Matndagi barcha summalarni POZITSIYASI bilan topadi: "25 ming"->25000, "5 mln"->5000000,
// "120 000"->120000 (bo'shliq/nuqta/vergul bilan guruhlangan minglar ham).
// Multiplikator KO'P TILLI — KANONIK SPEC (2026-08-03, 6 ilova tili: uz lotin/kirill,
// ru, en, es, fr, zh; mobil _amtRe AYNAN shu specni ko'zgulaydi — o'zgartirsang mobil
// jamoaga xabar ber). UCH qiymat klassi (shuning uchun ikkilik isThousandMult emas,
// multValue funksiyasi):
//   x1e3: ming*|минг*|тыс*|thousand|mil/mille (es/fr; lookahead million/milion/millón'ni
//         himoya qiladi)|千|k|к
//   x1e4: 万 (xitoy "wan")
//   x1e6: mln*|million*|milion*|millón*/millon*|млн|миллион*|милион*|百万|m|м
// Tartib: UZUN shakllar OLDIN — "mil" hech qachon million/milion/millón'ni yeb qo'ymaydi.
// Qisqa k|к|m|м faqat alohida turganda multiplikator ("5000 kofe"dagi "k" emas).
const MULT_SRC = String.raw`(mln[a-z]*|million[a-z]*|milion[a-z]*|mill[oó]n[a-z]*|млн\.?|миллион[а-яё]*|милион[а-яё]*|百万|ming[a-z'’]*|минг[а-яё]*|тыс[а-яё]*\.?|thousand|mil(?:le)?(?![a-zа-яё])|千|万|[kк](?![a-zа-яё0-9])|[mм](?![a-zа-яё0-9]))`;
function multValue(w) {
  const s = String(w).toLowerCase();
  if (s === '万') return 10_000;
  if (/^(mln|million|milion|mill[oó]n|млн|миллион|милион|百万|[mм]$)/.test(s)) return 1_000_000;
  return 1_000; // ming/минг/тыс/thousand/mil/mille/千/k/к
}
export function amountSpans(text) {
  const t = norm(text);
  const out = [];
  // [  ] — oddiy bo'shliq YOKI nbsp (mobil _NumGroupFmt guruh belgisi)
  const re = new RegExp(
    String.raw`(\d{1,3}(?:[  ]\d{3})+|\d{1,3}(?:\.\d{3})+|\d{1,3}(?:,\d{3})+|\d+(?:[.,]\d+)?)\s*` + MULT_SRC + '?',
    'gi',
  );
  for (const m of t.matchAll(re)) {
    const raw = m[1];
    let a;
    if (/^\d{1,3}(?:[  ]\d{3})+$/.test(raw)) a = parseFloat(raw.replace(/[  ]/g, ''));
    else if (/^\d{1,3}(?:\.\d{3})+$/.test(raw)) a = parseFloat(raw.replace(/\./g, ''));
    else if (/^\d{1,3}(?:,\d{3})+$/.test(raw)) a = parseFloat(raw.replace(/,/g, ''));
    else a = parseFloat(raw.replace(',', '.'));
    if (!a) continue;
    if (m[2]) a *= multValue(m[2]);
    out.push({ amount: Math.round(a), start: m.index, end: m.index + m[0].length });
  }
  return out;
}

export function amountsFromText(text) {
  return amountSpans(text).map((s) => s.amount);
}

// Har bir summaning kirim/chiqim turi — kalit so'z O'Z YO'NALISHIDAGI eng yaqin summaga
// bog'lanadi: OT (oylik, kredit...) odatda summadan OLDIN keladi -> KEYINGI summaga,
// FE'L (oldim, berdim...) summadan KEYIN keladi -> OLDINGI summaga. Masofada teng
// bo'lsa chiqim ustun. Mobil inputdagi rang mantiqi bilan bir xil (xarajat.dart _amtKinds).
// 2026-08-03: es/fr/zh minimal shakllar qo'shildi (kompakt; aksentli so'zlarga \b
// QO'YILMAYDI — JS \b ASCII-only, é/ç/у chegarada ishlamaydi; 收入|工资 OT bo'lgani
// uchun INC_NOUN'da — oldinga bog'lanadi)
const INC_NOUN = /\b(oylik|maosh|avans|daromad|bonus|kirim|foyda|salary|income|profit|revenue)\b|mijoz\w*|sotuv\w*|ойлик|маош|даромад|кирим|фойда|аванс|бонус|зарплат[а-яё]*|доход[а-яё]*|мижоз[а-яё]*|сотув[а-яё]*|收入|工资/g;
const INC_VERB = /\boldim\b|\bsotdim\b|keldi|tushdi|qaytdi\b|qaytardi\b|\breceived\b|\bearned\b|\bgot\b|\bsold\b|олдим|сотдим|келди|тушди|қайтди|получил[а-яё]*|заработал[а-яё]*|пришл[а-яё]*|поступил[а-яё]*|продал[а-яё]*|cobré|recibí|reçu|gagné/g;
const EXP_NOUN = /kredit\w*|xarid\w*|\bqarzga\b|\brent\b|кредит[а-яё]*|аренд[а-яё]*|харид[а-яё]*/g;
const EXP_VERB = /berdim|sarfladim|ishlatdim|to'ladim|toladim|ketdi|sotib\s+oldim|qaytardim|qaytarib\s+berdim|\bspent\b|\bpaid\b|\bbought\b|\bgave\b|бердим|сарфладим|тўладим|туладим|кетди|сотиб\s+олдим|потратил[а-яё]*|купил[а-яё]*|заплатил[а-яё]*|оплатил[а-яё]*|отдал[а-яё]*|pagué|compré|gasté|payé|acheté|dépensé|买|付|花/g;

export function amountKinds(text) {
  const t = norm(text);
  const spans = amountSpans(text);
  const n = spans.length;
  const kind = new Array(n).fill(false); // sukut: chiqim
  const best = new Array(n).fill(Infinity);
  if (!n) return kind;

  const ms = [];
  const collect = (re, inc, forward) => {
    for (const m of t.matchAll(re)) {
      const s = m.index, e = m.index + m[0].length;
      // Chiqim avval yig'iladi — uning ichiga tushgan kirim matchi tashlanadi
      // ("sotib oldim" ichidagi "oldim" kabi)
      if (inc && ms.some((x) => !(e <= x.s || s >= x.e))) continue;
      ms.push({ s, e, inc, forward });
    }
  };
  collect(EXP_VERB, false, false);
  collect(EXP_NOUN, false, true);
  collect(INC_VERB, true, false);
  collect(INC_NOUN, true, true);

  for (const m of ms) {
    let target = null, dist = Infinity;
    if (m.forward) {
      for (let i = 0; i < n; i++) if (spans[i].start >= m.e) { target = i; dist = spans[i].start - m.e; break; }
      if (target === null) for (let i = n - 1; i >= 0; i--) if (spans[i].end <= m.s) { target = i; dist = m.s - spans[i].end + 0.5; break; }
    } else {
      for (let i = n - 1; i >= 0; i--) if (spans[i].end <= m.s) { target = i; dist = m.s - spans[i].end; break; }
      if (target === null) for (let i = 0; i < n; i++) if (spans[i].start >= m.e) { target = i; dist = spans[i].start - m.e + 0.5; break; }
    }
    if (target === null) continue;
    if (dist < best[target] || (dist === best[target] && !m.inc)) {
      best[target] = dist;
      kind[target] = m.inc;
    }
  }
  return kind;
}

// ---------- JONLI PREVIEW: input rangi (summa yashil "in" / qizil "out") ----------
// Mobil debounce bilan chaqiradi (xarajat.dart _HlController) — DB'ga TEGMAYDI.
// Yengil LLM chaqiruvi: faqat yo'nalish (kategoriya/lug'at/few-shot YO'Q) — javob tez.
// Til cheklovi yo'q: istalgan tildagi matn tasniflanadi. Rang endi saqlashdagi
// parser bilan BIR MANBADAN — input hech qachon yakuniy natijaga zid ko'rsatmaydi.
const PREVIEW_SYS = `You classify money amounts in a short personal-finance note. The note may be in ANY language (Uzbek Latin or Cyrillic, Russian, English, mixed, informal).
For EACH listed amount decide the WRITER'S cash-flow direction:
"in" — writer's money INCREASES: salary, income, revenue, bonus, sale, gift received, debt paid back to the writer, money borrowed/received.
"out" — writer's money DECREASES: purchase, expense, bill, rent, payment, gave or lent money, repaid own debt.
If context is ambiguous or absent, answer "out". Reply ONLY with JSON: {"kinds":["in"|"out",...]} — exactly one entry per amount, same order as listed.`;

// Preview user-xabari — OpenAI-mos va Anthropic yo'llari BIR xil matndan foydalanadi
const previewUserMsg = (text, amounts) =>
  `Note: "${String(text).slice(0, 300)}"\nAmounts (${amounts.length}): ${amounts.map((a, i) => `${i + 1}) ${a}`).join('  ')}`;

async function previewLlm({ url, key, model, text, amounts, timeoutMs }) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model, temperature: 0, max_tokens: 80, response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: PREVIEW_SYS },
        { role: 'user', content: previewUserMsg(text, amounts) },
      ],
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error?.message || `HTTP ${res.status}`);
  const parsed = JSON.parse(data.choices?.[0]?.message?.content || '{}');
  const kinds = parsed.kinds;
  if (!Array.isArray(kinds) || kinds.length !== amounts.length
      || kinds.some((k) => k !== 'in' && k !== 'out')) throw new Error('kinds formati xato');
  return kinds;
}

// ---------- Anthropic Claude — ASOSIY provayder (2026-08-03 PO qarori) ----------
// Sabab: Groq bepul kvotasi (100k token/kun) tugab, prod parsing qoida-parserga tushib
// qolgan edi; PO'ning to'langan Claude Console hisobi bor. So'rov shakli OpenAI-mos EMAS:
// system — alohida top-level maydon, sarlavhalar x-api-key + anthropic-version,
// response_format yo'q — kafolatlangan JSON uchun MAJBURIY tool_choice (tool_use bloki).
// `strict` maydoni ATAYIN yuborilmaydi (reviewer 2026-08-03): u beta-headerga bog'liq
// bo'lishi mumkin — noma'lum maydon = 400 xavfi = jimgina zaxiraga qulash. Majburiy
// tool_choice + sanitizeAction/kinds tekshiruvi baribir to'liq validatsiya qiladi.
const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const NULLABLE_STR = { anyOf: [{ type: 'string' }, { type: 'null' }] };

// Preview javobi: {"kinds":["in"|"out",...]} — PREVIEW_SYS'dagi shakl bilan 1:1
const KINDS_TOOL = {
  name: 'emit_kinds',
  description: 'Report the cash-flow kind for each listed amount, in the same order.',
  input_schema: {
    type: 'object',
    properties: { kinds: { type: 'array', items: { type: 'string', enum: ['in', 'out'] } } },
    required: ['kinds'],
    additionalProperties: false,
  },
};

// Parse javobi: {"actions":[...]} — llmSystemPrompt'dagi JSON shakli bilan 1:1
const ACTIONS_TOOL = {
  name: 'emit_actions',
  description: 'Report the finance actions parsed from the note.',
  input_schema: {
    type: 'object',
    properties: {
      actions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            direction: { type: 'string', enum: DIRECTIONS },
            amount: { type: 'integer' },
            currency: { type: 'string' },
            category: NULLABLE_STR,
            note: { type: 'string' },
            person: NULLABLE_STR,
            new_category_suggestion: NULLABLE_STR,
            confidence: { type: 'number' },
          },
          required: ['direction', 'amount', 'currency', 'category', 'note', 'person',
            'new_category_suggestion', 'confidence'],
          additionalProperties: false,
        },
      },
    },
    required: ['actions'],
    additionalProperties: false,
  },
};

// ---------- Token tejash (2026-08-03 PO: "balans kichik — juda tejamkor sarfla") ----------
// 1) Butun servis bo'yicha kunlik token kill-switch — Groq-uslub kutilmagan uzilish VA
//    kutilmagan hisob-kitobning oldini oladi (oshsa Anthropic o'tkazib yuboriladi,
//    Groq/OpenAI/qoidalar zanjiri davom etadi);
// 2) per-user kunlik Anthropic chaqiruv limiti (anti-abuse) — oshsa o'sha user uchun
//    LLM umuman chaqirilmaydi, lug'at/qoida yo'li ishlaydi.
// Hisoblagichlar xotirada — Render'da bitta instans; deploy'da nolga tushishi muammo emas.
const dayKey = () => new Date().toISOString().slice(0, 10);
let anthropicDayUsage = { day: dayKey(), tokens: 0 };

function anthropicGlobalOk() {
  if (anthropicDayUsage.day !== dayKey()) anthropicDayUsage = { day: dayKey(), tokens: 0 };
  return anthropicDayUsage.tokens < config.llm.anthropicDailyTokenMax;
}

function anthropicLogUsage(usage) {
  if (anthropicDayUsage.day !== dayKey()) anthropicDayUsage = { day: dayKey(), tokens: 0 };
  const inTok = usage?.input_tokens || 0;
  const outTok = usage?.output_tokens || 0;
  anthropicDayUsage.tokens += inTok + outTok;
  console.log(`[llm] anthropic in=${inTok} out=${outTok} day_total=${anthropicDayUsage.tokens}`);
}

const userLlmDay = new Map(); // userId -> { day, count }
function userLlmBudgetOk(userId) {
  const e = userLlmDay.get(userId);
  const used = e && e.day === dayKey() ? e.count : 0;
  return used < config.llm.anthropicUserDailyMax;
}
function userLlmBudgetSpend(userId) {
  const d = dayKey();
  const e = userLlmDay.get(userId);
  if (!e || e.day !== d) {
    // O'sishdan saqlanish: faqat ESKI kun yozuvlari o'chiriladi (reviewer — .clear()
    // bugungi jonli hisoblagichlarni ham nolga tushirib yuborardi)
    if (userLlmDay.size > 10_000) {
      for (const [k, v] of userLlmDay) if (v.day !== d) userLlmDay.delete(k);
    }
    userLlmDay.set(userId, { day: d, count: 1 });
  } else e.count += 1;
}

// Prompt caching (cache_control) ATAYIN ISHLATILMAYDI: Haiku 4.5'da keshlanadigan minimal
// prefiks 4096 token, bizning system prompt (qoidalar + toifalar + 2 few-shot) ~1k token —
// belgi qo'yilsa ham JIMGINA keshlanmaydi, sun'iy to'ldirish (padding) esa teskari samara.
async function anthropicJson({ key, model, system, user, tool, maxTokens, timeoutMs }) {
  const res = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model, max_tokens: maxTokens, temperature: 0, system,
      messages: [{ role: 'user', content: user }],
      tools: [tool],
      tool_choice: { type: 'tool', name: tool.name },
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error?.message || `HTTP ${res.status}`);
  anthropicLogUsage(data.usage); // kunlik hisob + bitta qator log (kalit YO'Q, faqat sonlar)
  const block = (data.content || []).find((b) => b.type === 'tool_use');
  if (block?.input && typeof block.input === 'object') return block.input;
  // Zaxira: model tool o'rniga matn qaytarsa — JSON bo'lagini ajratib olamiz
  const txt = (data.content || []).find((b) => b.type === 'text')?.text || '';
  const m = /\{[\s\S]*\}/.exec(txt);
  if (m) return JSON.parse(m[0]);
  throw new Error("tool_use bloki yo'q");
}

// Multiplikator/valyuta so'zlari kontekst EMAS ("400 ming so'm"da yo'nalish so'zi yo'q)
const NOCTX = /^(ming|mln|million|milion|millon|millón|mille|mil|thousand|минг|млн|миллион|милион|тыс|тысяч|百万|千|万|so'm|som|sum|сум|сўм|uzs|k|к|m|м)/i;

const previewCache = new Map(); // norm(matn) -> natija (user ma'lumotisiz — global kesh)
export async function previewKinds(text) {
  const spans = amountSpans(text);
  if (!spans.length) return { amounts: [], provider: 'none' };
  const key = norm(text);
  const hit = previewCache.get(key);
  if (hit) return hit;

  // Yo'nalish so'zisiz matnga ("5000" yoki "400 ming so'm") LLM chaqirilmaydi
  const hasContext = key.split(/[\s.,!?;:()"«»]+/)
    .some((w) => w.length >= 2 && !/\d/.test(w) && !NOCTX.test(w));

  const amounts = spans.map((s) => s.amount);
  let kinds = null; let provider = 'rules';
  if (hasContext && config.llm.anthropicKey && anthropicGlobalOk()) {
    try {
      const parsed = await anthropicJson({
        key: config.llm.anthropicKey, model: config.llm.anthropicModel,
        system: PREVIEW_SYS, user: previewUserMsg(text, amounts),
        // Dinamik cap (reviewer): ko'p-summali matnda qat'iy 60 kesib qo'yardi
        tool: KINDS_TOOL, maxTokens: Math.max(80, 20 + amounts.length * 8), timeoutMs: 3500,
      });
      const k = parsed.kinds;
      if (!Array.isArray(k) || k.length !== amounts.length
          || k.some((x) => x !== 'in' && x !== 'out')) throw new Error('kinds formati xato');
      kinds = k; provider = 'anthropic';
    } catch (e) {
      console.warn(`[llm] anthropic preview: ${e.message}`); // jim yutmaymiz (reviewer)
    }
  }
  if (hasContext && !kinds && config.llm.groqKey) {
    try {
      kinds = await previewLlm({ url: 'https://api.groq.com/openai/v1/chat/completions',
        key: config.llm.groqKey, model: config.llm.groqModel, text, amounts, timeoutMs: 3500 });
      provider = 'groq';
    } catch { /* zaxiraga o'tamiz */ }
  }
  if (hasContext && !kinds && config.llm.openaiKey) {
    try {
      kinds = await previewLlm({ url: 'https://api.openai.com/v1/chat/completions',
        key: config.llm.openaiKey, model: config.llm.openaiModel, text, amounts, timeoutMs: 4500 });
      provider = 'openai';
    } catch { /* rules zaxirasi */ }
  }
  if (!kinds) kinds = amountKinds(text).map((b) => (b ? 'in' : 'out'));

  const out = { amounts: spans.map((s, i) => ({ amount: s.amount, kind: kinds[i] })), provider };
  // Faqat LLM javobi keshlanadi — rules zaxirasi LLM tiklanganda yangilanishi kerak
  if (provider !== 'rules') {
    previewCache.set(key, out);
    if (previewCache.size > 300) previewCache.delete(previewCache.keys().next().value);
  }
  return out;
}

// Fallback toifa qoidalari — 6 ilova tili (2026-08-03): uz lotin/kirill + SHEVA (bazar,
// shipoxona — Xorazm QA), ru, en, es, fr, zh. Kompakt: bular FAQAT LLM'siz zaxira.
// Qisqa yangi so'zlarga \b yoki lookbehind — boshqa so'z ichida adashmasin
// (gas/gasté, rent/parent, eau/bureau, bus/business, cine/medicine, jeu/jeudi,
// газ/магазин). ESKI uz yozuvlarga atayin tegilmagan (non->nonushta, gaz->gazing
// prefiks matchlari saqlanadi).
const CAT_RULES = [
  ['Oziq-ovqat', /oziq|ovqat|bozor|bazar|non|go'sht|gosht|market|korzinka|restoran|kafe|choyxona|obed|(?<!п)обед|(?<![а-яё])еда|продукт|lunch|food|grocer|comida|almuerzo|repas|nourriture|饭|吃|超市/],
  ['Transport', /taksi|benzin|yo'l|yol|metro|avtobus|mashina|такси|метро|бензин|taxi|\bbus\b|fuel|\bgas\b|essence|出租|地铁|油/],
  ['Kommunal', /kommunal|svet|elektr|gaz|suv|internet|telefon|свет|(?<![а-яё])газ|вода|аренда|\brent\b|electricity|water|\bluz\b|agua|alquiler|loyer|\beau\b|房租|水电/],
  ["Ko'ngilochar", /kino|konsert|o'yin|oyin|sayohat|dam olish|кино|cinema|movie|concert|juego|\bcine\b|\bjeux?\b|电影|游戏/],
  ['Kiyim', /kiyim|ko'ylak|koylak|poyabzal|shim|kurtka|одежда|обувь|clothes|shoes|ropa|zapatos|vêtement|衣|鞋/],
  ['Salomatlik', /dori|apteka|shifokor|klinika|tish|salomatlik|shipoxona|аптека|врач|лекарств|pharmacy|doctor|medicine|farmacia|médico|pharmacie|médecin|药|医院/],
];

// Qarz ibora -> yo'nalish (operations type'lariga 1:1)
function qarzDirection(t) {
  if (/qarz(ga)?\s+(berdim|berib)/.test(t)) return 'qarz_berdim';
  if (/qarz(ga)?\s+(oldim|olib)/.test(t)) return 'qarz_oldim';
  if (/qaytar(dim|ib berdim)/.test(t)) return 'qaytardim';
  if (/qaytar(di|ib berdi)|qaytarildi/.test(t)) return 'menga_qaytarildi';
  return null;
}

// Ism (qarz uchun): "Anvarga 500 ming" -> Anvar. Bosh harfli so'z + -ga affiksi.
function personFromText(original) {
  const m = /([A-ZА-ЯЎҚҒҲO'][a-zа-яўқғҳo']{2,})(?:ga|ge)\b/.exec(String(original || ''));
  return m ? m[1] : null;
}

// Bitta amal qaytaradi (qoida-parser murakkab gaplarni bo'lmaydi — validator).
export function ruleParse(text) {
  const t = norm(text);
  const amounts = amountsFromText(text);
  const amount = amounts[0] || 0;
  const qarz = qarzDirection(t);
  let direction = qarz;
  let category = null;
  if (!direction) {
    // Yo'nalish BIRINCHI SUMMANING o'z kontekstidan (butun gapdan emas) — aralash
    // gapda ("taksiga 50 ming berdim va mijozdan 300 ming keldi") "keldi" so'zi
    // birinchi (chiqim) summani daromadga aylantirib yubormasin
    const income = amounts.length
      ? amountKinds(text)[0]
      : /(oylik|maosh|daromad|tushdi|keldi|sotdim|foyda|bonus)/.test(t);
    direction = income ? 'daromad' : 'xarajat';
    category = income ? 'Daromad' : 'Boshqa';
    if (!income) for (const [name, re] of CAT_RULES) if (re.test(t)) { category = name; break; }
  }
  const trimmed = String(text || '').trim();
  return {
    direction, amount, currency: 'UZS', category,
    note: trimmed ? trimmed[0].toUpperCase() + trimmed.slice(1) : '',
    person: qarz ? personFromText(text) : null,
    confidence: amount > 0 ? 0.55 : 0,
  };
}

// LLM'siz KO'P-AMALLI zaxira (2026-08-03 owner, data-loss fix): ilgari fallback faqat
// amounts[0]'dan bitta amal qurardi — "bozorga 200 ming taksiga 30 ming berdim"da 30k
// JIMGINA YO'QOLARDI (mobil needs_confirm'ga qaramay keladi-saqlaydi). Endi har summa
// uchun alohida amal (cap 5 — /confirm limiti bilan bir xil):
//  - yo'nalish: amountKinds[i] (kirim -> daromad, aks holda xarajat);
//  - toifa: summaning LOKAL kontekst oynasidan (oldingi summa OXIRIdan keyingi summa
//    BOSHIgacha norm-matn kesimi): CAT_RULES -> lug'at (MIN pog'ona, guardlar
//    dictCategory'da; hit bo'lsa ishonch 0.9 — Task B saqlanadi) -> 'Boshqa';
//  - note: oyna kesimi (bo'sh bo'lsa to'liq matn), confidence 0.55.
// ruleParse YAKKA amalligicha qoladi (u LLM validatori); qarz matnlari chaqiruvchida
// mavjud yakka qarzDirection yo'lidan ketadi.
export function rulesFallbackActions(text, dict, categories) {
  const t = norm(text);
  // Nol-summa spanlar FILTRLANADI (2026-08-03 reviewer): "60 ming gosht 0.4 kg"da
  // 0.4 -> round 0 amal bo'lib o'tib, /confirm'da 400 + QISMAN saqlash (birinchi qator
  // yozilib ikkinchisi rad) + retry'da duplikat xavfini berardi. kinds hizalanishi
  // ORIGINAL indeks (s.i) orqali saqlanadi; oyna chegaralari filtrlangan ro'yxatdan.
  const spans = amountSpans(text).map((s, i) => ({ ...s, i })).filter((s) => s.amount > 0).slice(0, 5);
  const kinds = amountKinds(text);
  const full = String(text || '').trim();
  return spans.map((s, j) => {
    const from = j === 0 ? 0 : spans[j - 1].end;
    const to = j === spans.length - 1 ? t.length : spans[j + 1].start;
    const win = t.slice(from, to);
    const income = !!kinds[s.i];
    let category = 'Daromad';
    let confidence = 0.55;
    if (!income) {
      category = null;
      for (const [name, re] of CAT_RULES) if (re.test(win)) { category = name; break; }
      if (!category) {
        const cat = dictCategory(dict, meaningfulWords(win), categories, DICT_SCORE_MIN);
        if (cat) { category = cat; confidence = 0.9; }
      }
      if (!category) category = 'Boshqa';
    }
    const note = win.trim() || full;
    return {
      direction: income ? 'daromad' : 'xarajat',
      amount: s.amount, currency: 'UZS', category,
      note: note ? note[0].toUpperCase() + note.slice(1) : full,
      person: null, new_category_suggestion: null, confidence,
    };
  });
}

// ---------- 3-signal: KALIT SO'Z LUG'ATI ----------
// User lug'ati kuchli (x3), global agregat kuchsiz.
// Ishonch POG'ONALARI (2026-08-03 QA: prod word_map'da hits=1 "zahar" yozuvlar bor —
// bozor->Kiyim, kitob->Kiyim: learnFrom yozuvning HAR BIR ma'noli so'zini o'rganadi,
// bitta eski tasdiq LLM toifasini conf 0.9 bilan jimgina bosib ketardi). Yozuvlar
// O'CHIRILMAYDI ham O'ZGARTIRILMAYDI — o'qish pog'onasi ularni neytrallaydi:
//   STRONG (>=6) — LLM toifasini bosish yoki LLM'siz short-circuit ('dict') uchun:
//     kamida 2 ta shu-user tasdig'i (og'irlik x3) yoki 6 global hit;
//   MIN (>=2) — FAQAT rules-fallback'da (hech bir LLM ishlamaganda), doim needs_confirm=true.
export const DICT_SCORE_MIN = 2;
export const DICT_SCORE_STRONG = 6;

// SOF funksiya (testlanadi): word_map qatorlari -> word -> {category, score}.
// Tenglikni HECH QACHON Map/iteratsiya tartibi hal qilmaydi (2026-08-03 QA:
// svet->Transport vs svet->Kommunal nodeterminizmi): score desc -> hits desc ->
// updated_at desc; shunda ham to'liq teng bo'lsa — ISHONCHLI HIT YO'Q (so'z tashlanadi).
export function rankDictRows(rows, userId) {
  const agg = new Map(); // word -> Map(category -> {score, hits, updated})
  for (const r of rows || []) {
    const w = agg.get(r.word) || new Map();
    const e = w.get(r.category) || { score: 0, hits: 0, updated: 0 };
    e.score += r.hits * (r.user_id === userId ? 3 : 1);
    e.hits += r.hits;
    e.updated = Math.max(e.updated, Date.parse(r.updated_at) || 0);
    w.set(r.category, e);
    agg.set(r.word, w);
  }
  const best = new Map(); // word -> {category, score}
  for (const [word, cats] of agg) {
    const ranked = [...cats.entries()].sort((a, b) =>
      (b[1].score - a[1].score) || (b[1].hits - a[1].hits) || (b[1].updated - a[1].updated));
    const top = ranked[0];
    if (!top || top[1].score < DICT_SCORE_MIN) continue;
    const nxt = ranked[1];
    if (nxt && nxt[1].score === top[1].score && nxt[1].hits === top[1].hits
        && nxt[1].updated === top[1].updated) continue; // to'liq teng -> hit yo'q
    best.set(word, { category: top[0], score: top[1].score });
  }
  return best;
}

async function dictLookup(userId, words) {
  if (!words.length) return new Map();
  const { data } = await supabaseAdmin.from('word_map')
    .select('user_id, word, category, hits, updated_at').in('word', words).limit(500);
  return rankDictRows(data || [], userId);
}

// Lug'atdan toifa — UMUMIY guardlar (short-circuit, asosiy sikl va fallback uchalasi shu
// yerdan o'tadi): minScore pog'onasi; 'Boshqa' TOIFANI MAJBURLAMAYDI (eski lug'atda
// so'z->Boshqa yozuvlari to'planib qolgan — ular to'g'ri toifani va ✨ yangi-toifa
// taklifini o'chirardi); arxivlangan/yo'q toifa ham majburlanmaydi.
export function dictCategory(dict, words, categories, minScore) {
  for (const w of words) {
    const hit = dict.get(w);
    if (!hit || hit.score < minScore) continue;
    if (String(hit.category).trim().toLowerCase() === 'boshqa') continue;
    if (!categories.some((c) => c.toLowerCase() === String(hit.category).toLowerCase())) continue;
    return hit.category;
  }
  return null;
}

// ---------- 1-signal: LLM (Anthropic asosiy; Groq -> OpenAI zaxira) ----------
// Baza toifalarga qisqa tavsif — noto'g'ri "Boshqa"ga tushishni kamaytiradi
// (user o'zi ochgan papkalar tavsifsiz, nomi bilan qoladi)
const CAT_HINTS = {
  'Oziq-ovqat': "bozor, oziq-ovqat do'koni, restoran, kafe, tushlik, mahsulotlar",
  'Transport': 'taksi, benzin, metro, avtobus, mashina xizmati, parkovka',
  'Kommunal': 'svet, gaz, suv, internet, telefon, kvartira ijarasi',
  "Ko'ngilochar": "kino, konsert, o'yin, sayohat, dam olish, obunalar",
  'Kiyim': 'kiyim-kechak, poyabzal, aksessuar',
  'Salomatlik': 'dori, apteka, shifokor, klinika, sport zali',
  'Boshqa': 'yuqoridagilarning hech biriga mos kelmasa',
};

function llmSystemPrompt(categories, fewshots) {
  const shots = fewshots.map((f) =>
    `Matn: "${f.text}"\nJavob: ${JSON.stringify({ actions: f.final })}`).join('\n');
  return `Sen moliyaviy yozuvlar tahlilchisisan. Foydalanuvchi ISTALGAN tilda (o'zbek lotin/kiril, rus, ingliz, aralash, sheva) daromad, xarajat yoki qarz haqida gapiradi. Faqat JSON qaytar:
{"actions":[{"direction":"daromad|xarajat|qarz_berdim|qarz_oldim|qaytardim|menga_qaytarildi","amount":<butun son, so'mda>,"currency":"UZS","category":<string|null>,"note":<qisqa izoh>,"person":<ism yoki null>,"new_category_suggestion":<string|null>,"confidence":<0..1>}]}

QOIDALAR:
1. Bitta gapda bir nechta amal bo'lishi mumkin ("bozorga 200 ming, taksiga 30") — har birini alohida qaytar.
2. Summa: "25 ming"=25000, "5 mln"=5000000, "200k"/"200к"/"200 тыс"=200000, "4m"/"4 млн"=4000000. Summa aniq aytilmagan bo'lsa amount=0 va confidence past.
3. Qarz iboralari ("qarz berdim/oldim", "qaytardi/qaytardim") — direction qarz_*, person maydoniga ismni yoz, category=null.
4. Xarajat uchun category FAQAT shu ro'yxatdan (qavsda — nimalar kiradi): ${categories.map((c) => (CAT_HINTS[c] ? `${c} (${CAT_HINTS[c]})` : c)).join('; ')}. Daromad uchun category="Daromad".
5. Ro'yxatda mos toifa yo'q bo'lsa: category="Boshqa" va new_category_suggestion maydoniga yangi nom taklif qil. Nom uslubi: o'zbekcha, 1-2 so'z, bosh harf bilan, birlikda; juda tor EMAS ("Lavash" emas — "Fastfud"), juda keng EMAS ("Xarajat" emas). Yaxshi misollar: "Ta'lim", "Sovg'a", "Remont", "Sport", "Uy-ro'zg'or", "Go'zallik". Yangi nom ro'yxatdagiga ma'nodosh bo'lsa, taklif QILMA — mavjudini tanla.
6. confidence: matn aniq bo'lsa 0.9+, summa/ma'no noaniq bo'lsa <0.8.
7. Aralash gapda har amal yo'nalishini O'Z bo'lagidagi so'zlarga qarab aniqla: "oylik oldim 4 mln kreditga 200 ming berdim" -> daromad 4000000 VA xarajat 200000 (bitta gapdagi boshqa bo'lak so'zlari amal yo'nalishini o'zgartirmasin).
8. Shevaga bardoshli bo'l: aldim=oldim, bardim=berdim, bazar=bozor, shipoxona=klinika, savdo etdim=xarid qildim.${shots ? `\n\nMISOLLAR (shu foydalanuvchining tuzatishlari — uslubiga moslash):\n${shots}` : ''}`;
}

async function callLlm({ url, key, model, text, categories, fewshots, timeoutMs }) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model, temperature: 0, response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: llmSystemPrompt(categories, fewshots) },
        { role: 'user', content: String(text).slice(0, 300) },
      ],
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error?.message || `HTTP ${res.status}`);
  const parsed = JSON.parse(data.choices?.[0]?.message?.content || '{}');
  if (!Array.isArray(parsed.actions)) throw new Error('actions massivi yo\'q');
  return parsed.actions;
}

// Qarz uchun DETERMINISTIK guard: LLM qarz_berdim/qarz_oldim desa ham, matnda ANIQ
// qarz-signal so'zi bo'lmasa oddiy xarajat/daromadga tushiriladi ("anvarga 200 ming
// berdim" — xarajat, Hamkorlar oqimiga sakramaydi). qaytardim/menga_qaytarildi
// yo'nalishlari signalning o'zi ("qaytar...") bilan keladi — ularga tegilmaydi.
const QARZ_SIGNAL = /qarz|карз|қарз|долг|взайм|в долг|одолжил|занял|debt|\blent\b|\bloan\b|borrow|iou/i;

function sanitizeAction(a, categories, text) {
  if (!a || typeof a !== 'object') return null;
  const amount = Math.round(Number(a.amount) || 0);
  if (amount <= 0) return null;
  let direction = DIRECTIONS.includes(a.direction) ? a.direction : 'xarajat';
  if ((direction === 'qarz_berdim' || direction === 'qarz_oldim') && !QARZ_SIGNAL.test(String(text || ''))) {
    direction = direction === 'qarz_berdim' ? 'xarajat' : 'daromad';
  }
  let category = a.category ? String(a.category).trim() : null;
  let suggestion = a.new_category_suggestion ? String(a.new_category_suggestion).trim() : null;
  if (direction === 'daromad') { category = 'Daromad'; suggestion = null; }
  else if (isQarz(direction)) { category = null; suggestion = null; }
  else {
    // xarajat: toifa faqat ro'yxatdan; notanish toifa -> taklifga o'tadi
    const hit = categories.find((c) => c.toLowerCase() === (category || '').toLowerCase());
    if (!hit) { if (category && !suggestion) suggestion = category; category = 'Boshqa'; }
    else category = hit;
    if (suggestion && categories.some((c) => c.toLowerCase() === suggestion.toLowerCase())) suggestion = null;
  }
  let conf = Number(a.confidence);
  if (!(conf >= 0 && conf <= 1)) conf = 0.6;
  return {
    direction, amount, currency: 'UZS', category,
    note: String(a.note || text).trim().slice(0, 200) || String(text).trim(),
    person: a.person ? String(a.person).trim().slice(0, 60) : null,
    new_category_suggestion: suggestion,
    confidence: conf,
  };
}

// ---------- ORKESTR: uch signalni birlashtirish ----------
export function llmReady() {
  return !!(config.llm.anthropicKey || config.llm.groqKey || config.llm.openaiKey);
}

const parseCache = new Map(); // norm(matn)+toifalar -> LLM natijasi (token tejash keshi)

export async function parseText(text, userId) {
  const words = meaningfulWords(text);
  const [cats, fewshotsRes, dict] = await Promise.all([
    ensureCategories(userId),
    // Few-shot 4 -> 2 (2026-08-03 token tejash): eng so'nggi 2 tuzatish yetarli signal
    supabaseAdmin.from('corrections').select('text, final').eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(2),
    dictLookup(userId, words),
  ]);
  const categories = cats.map((c) => c.name);
  const fewshots = (fewshotsRes.data || []).map((r) => ({ text: r.text, final: r.final })).reverse();

  const rule = ruleParse(text);

  // 0-signal: LUG'AT SHORT-CIRCUIT (2026-08-03 token tejash) — LLM oxirgi chora.
  // KESHDAN OLDIN turadi (reviewer): tuzatishdan keyin lug'at kuchayganda eski keshlangan
  // LLM natijasi ustun kelmasin — o'z-o'zini o'rgatish sikli ishlashi shart.
  // Shartlar TOR: bitta summa, aniq xarajat yo'nalishi, qarz-signal yo'q va KUCHLI
  // lug'at hit (score >= DICT_SCORE_STRONG) — hits=1 zahar yozuvlar bu yerga yetmaydi.
  // Qarz va ko'p-summali matnlar LLM'ga boradi (bo'linish/person LLM ishi).
  if (rule.amount > 0 && rule.direction === 'xarajat' && !QARZ_SIGNAL.test(String(text || ''))
      && amountsFromText(text).length === 1) {
    const cat = dictCategory(dict, words, categories, DICT_SCORE_STRONG);
    if (cat) {
      return {
        actions: [{ ...rule, category: cat, new_category_suggestion: null,
          confidence: Math.max(rule.confidence, 0.9) }],
        needs_confirm: false, provider: 'dict', errors: [],
      };
    }
  }

  // KESH (2026-08-03 token tejash): bir xil user + matn + toifa ro'yxati -> 0 token.
  // userId kalitda (reviewer): natija userlar aro sizib o'tmasin. FAQAT LLM natijasi
  // keshlanadi; structuredClone — chaqiruvchi mutatsiyasi keshni zaharlamasin.
  const cacheKey = `${userId}|${norm(text)}|${categories.join(',').toLowerCase()}`;
  const cachedRes = parseCache.get(cacheKey);
  if (cachedRes) return structuredClone(cachedRes);

  // LLM: Anthropic (asosiy, 2026-08-03) -> Groq -> OpenAI zaxira.
  // Per-user kunlik budjet oshgan bo'lsa LLM UMUMAN chaqirilmaydi -> lug'at/qoida yo'li.
  // Sarf zanjir BOSHIDA hisoblanadi (reviewer): Anthropic o'tkazib yuborilganda ham
  // Groq/OpenAI urinishi limitga kiradi — aks holda cap amalda ishlamay qolardi.
  let actions = null; let provider = 'rules'; const errors = [];
  const userOk = userLlmBudgetOk(userId);
  if (!userOk) errors.push('budget: user kunlik LLM limiti');
  else if (llmReady()) userLlmBudgetSpend(userId);
  if (userOk && config.llm.anthropicKey) {
    if (!anthropicGlobalOk()) {
      errors.push('budget: anthropic kunlik token limiti'); // kill-switch; zaxira davom etadi
    } else {
      try {
        const parsed = await anthropicJson({
          key: config.llm.anthropicKey, model: config.llm.anthropicModel,
          system: llmSystemPrompt(categories, fewshots),
          user: String(text).slice(0, 300),
          tool: ACTIONS_TOOL, maxTokens: 500, timeoutMs: 7000,
        });
        if (!Array.isArray(parsed.actions)) throw new Error("actions massivi yo'q");
        actions = parsed.actions;
        provider = 'anthropic';
      } catch (e) { errors.push(`anthropic: ${e.message}`); }
    }
  }
  if (userOk && !actions && config.llm.groqKey) {
    try {
      actions = await callLlm({
        url: 'https://api.groq.com/openai/v1/chat/completions',
        key: config.llm.groqKey, model: config.llm.groqModel,
        text, categories, fewshots, timeoutMs: 7000,
      });
      provider = 'groq';
    } catch (e) { errors.push(`groq: ${e.message}`); }
  }
  if (userOk && !actions && config.llm.openaiKey) {
    try {
      actions = await callLlm({
        url: 'https://api.openai.com/v1/chat/completions',
        key: config.llm.openaiKey, model: config.llm.openaiModel,
        text, categories, fewshots, timeoutMs: 9000,
      });
      provider = 'openai';
    } catch (e) { errors.push(`openai: ${e.message}`); }
  }

  let clean = (actions || []).map((a) => sanitizeAction(a, categories, text)).filter(Boolean);

  // LLM yiqilsa -> qoida-zaxira MAJBURIY tasdiq bilan (XOTIRA §3).
  // 2026-08-03 owner: endi KO'P-AMALLI (rulesFallbackActions) — har summa alohida amal,
  // "taksiga 30 ming" yo'qolmaydi; lug'at MIN pog'onada oyna ichida qo'llanadi (Task B).
  // Qarz matni mavjud YAKKA qarzDirection yo'lida qoladi (person/yo'nalish ruleParse'da).
  if (!clean.length) {
    if (rule.amount > 0) {
      clean = isQarz(rule.direction)
        ? [{ ...rule, new_category_suggestion: null }]
        : rulesFallbackActions(text, dict, categories);
    }
    return { actions: clean, needs_confirm: true, provider: clean.length ? 'rules' : provider, errors };
  }

  // Lug'at: tanish so'z -> toifani lug'atdan. LLM toifasini FAQAT KUCHLI hit bosadi
  // (score >= DICT_SCORE_STRONG) — hits=1 zahar yozuv LLM'ni indira olmaydi (2026-08-03 QA)
  for (const a of clean) {
    if (a.direction !== 'xarajat') continue;
    const cat = dictCategory(dict, meaningfulWords(a.note), categories, DICT_SCORE_STRONG);
    if (!cat) continue;
    if (cat !== a.category) { a.category = cat; a.new_category_suggestion = null; }
    a.confidence = Math.max(a.confidence, 0.9);
  }

  // Validator: qoida-parser topgan har bir summa LLM natijasida bo'lishi kerak
  const ruleAmounts = amountsFromText(text);
  const llmAmounts = clean.map((a) => a.amount);
  const amountsMatch = ruleAmounts.length === 0
    || ruleAmounts.every((ra) => llmAmounts.includes(ra));

  const needsConfirm =
    !amountsMatch
    || clean.some((a) => a.confidence < 0.8)
    || clean.some((a) => a.new_category_suggestion) // yangi toifa JIMGINA yaratilmaydi (§4)
    || clean.some((a) => isQarz(a.direction));      // qarz -> Hamkorlar oqimi, user ishtiroki shart

  const result = { actions: clean, needs_confirm: needsConfirm, provider, errors };
  // Faqat LLM natijasi keshlanadi (previewCache siyosati) — takror ibora 0 token.
  // errors keshga YOZILMAYDI (reviewer): eski fallback ogohlantirishlari hitda takrorlanmasin
  if (provider !== 'rules') {
    parseCache.set(cacheKey, structuredClone({ ...result, errors: [] }));
    if (parseCache.size > 500) parseCache.delete(parseCache.keys().next().value);
  }
  return result;
}

// ---------- O'RGANISH: tasdiqlangan yozuvdan lug'at + tuzatish (few-shot) ----------
export async function learnFrom(userId, text, finalActions, parsedActions) {
  try {
    // 0. Kesh invalidatsiyasi (reviewer 2026-08-03): yangi o'rganish shu user'ning eski
    // keshlangan parse natijalarini bekor qiladi (arzon: kesh <= 500 yozuv)
    const cachePrefix = `${userId}|`;
    for (const k of parseCache.keys()) if (k.startsWith(cachePrefix)) parseCache.delete(k);
    // 1. so'z -> toifa lug'ati (faqat xarajat) — FAQAT USER TASDIQLAGAN amallardan.
    // O'Z-O'ZINI ZAHARLASH tuzatildi (2026-08-03 CRITICAL, jonli qurilmada topildi):
    // eski xato tuzatish -> few-shot Claude'ni zaharlaydi -> Claude svet matnini
    // Transport deb belgilaydi -> avto-saqlash learnFrom'ni chaqiradi -> word_map
    // svet->Transport hits=2 = STRONG -> lug'at endi LLM'ni HAR DOIM o'sha xatoga
    // majburlaydi (matnda 'kommunal' so'zi tursa ham). LLM avto-natijasi hech qachon
    // o'z-o'zini STRONG obro'ga ko'tarmasligi kerak. Amal o'rganiladi FAQAT:
    //  (a) parsed BERILGAN va amalning [direction,amount,category] uchligi hech bir
    //      parsed amalga teng emas (user kartada O'ZGARTIRGAN; tray-tanlov ham shunga
    //      kiradi — parsed'da 'Boshqa' edi), YOKI
    //  (b) accept_new_category === true (user yangi toifani OCHIQ qabul qilgan).
    // Jim avto-saqlash (parse natijasi bilan bir xil) -> word_map'ga YOZILMAYDI.
    // Toifa kichik harfda solishtiriladi — registr farqi jim avto-saqlashni
    // "user tasdiqlagan"ga aylantirib yubormasin (reviewer 4-raund).
    const triple = (a) => [a.direction, a.amount, String(a.category || '').toLowerCase()];
    const asig = (a) => JSON.stringify(triple(a));
    const parsedSigs = new Set((parsedActions || []).map(asig));
    const rows = [];
    for (const a of finalActions) {
      if (a.direction !== 'xarajat' || !a.category) continue;
      // 'Boshqa' O'RGANILMAYDI (2026-08-03): zaxira papka lug'atga tushsa, o'sha so'zlar
      // keyingi parse'larda doim 'Boshqa'ga majburlanib, ✨ yangi-toifa taklifi umrbod
      // yo'qolardi (parseText'dagi juft tekshiruvga qarang).
      if (String(a.category).trim().toLowerCase() === 'boshqa') continue;
      const userVerified = a.accept_new_category === true
        || (parsedActions && !parsedSigs.has(asig(a)));
      if (!userVerified) continue;
      for (const w of meaningfulWords(a.note || text)) rows.push({ user_id: userId, word: w, category: a.category });
    }
    for (const r of rows) {
      const { data } = await supabaseAdmin.from('word_map')
        .select('hits').match({ user_id: r.user_id, word: r.word, category: r.category }).maybeSingle();
      await supabaseAdmin.from('word_map').upsert(
        { ...r, hits: (data?.hits || 0) + 1, updated_at: new Date().toISOString() },
        { onConflict: 'user_id,word,category' });
    }
    // 2. tuzatish bo'lsa — few-shot xotiraga (sig — yuqoridagi triple bilan umumiy).
    // accept_new_category YORLIG'I final'dan OLIB TASHLANADI — few-shot promptga
    // texnik maydon sizib kirmasin (LLM uni taqlid qilib o'rganishi mumkin edi).
    const sig = (arr) => JSON.stringify((arr || []).map(triple));
    if (parsedActions && sig(parsedActions) !== sig(finalActions)) {
      await supabaseAdmin.from('corrections').insert({
        user_id: userId, text: String(text).slice(0, 300),
        parsed: parsedActions,
        final: finalActions.map(({ accept_new_category, ...rest }) => rest),
      });
    }
  } catch (e) {
    console.error('learnFrom:', e.message); // o'rganish yiqilsa ham asosiy oqim buzilmaydi
  }
}

// TESKARI o'rganish (2026-08-03 CRITICAL to'plamining bir qismi): yozuv o'chirilganda
// yoki toifasi o'zgartirilganda eski so'z->toifa bog'lari BITTA pog'ona pasayadi
// (hits-1; 0 ga tushsa qator O'CHIRILADI) — xato/zahar bog'lar tabiiy yemiriladi,
// word_map ma'lumotiga qo'lda tegilmaydi. learnFrom kabi bloklamaydi (fail-soft).
export async function unlearnFrom(userId, text, category) {
  try {
    const cat = String(category || '').trim();
    if (!cat) return;
    for (const w of meaningfulWords(text || '')) {
      const { data } = await supabaseAdmin.from('word_map')
        .select('hits').match({ user_id: userId, word: w, category: cat }).maybeSingle();
      if (!data) continue;
      if ((data.hits || 0) <= 1) {
        await supabaseAdmin.from('word_map').delete()
          .match({ user_id: userId, word: w, category: cat });
      } else {
        await supabaseAdmin.from('word_map')
          .update({ hits: data.hits - 1, updated_at: new Date().toISOString() })
          .match({ user_id: userId, word: w, category: cat });
      }
    }
    // Lug'at o'zgardi — shu user'ning parse keshi ham eskirdi
    const cachePrefix = `${userId}|`;
    for (const k of parseCache.keys()) if (k.startsWith(cachePrefix)) parseCache.delete(k);
  } catch (e) {
    console.error('unlearnFrom:', e.message); // asosiy oqim buzilmaydi
  }
}
