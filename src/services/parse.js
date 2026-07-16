// Parsing (matn -> daromad/xarajat/qarz) — XOTIRA-ovoz-va-kategoriya.md §3–4.
// Uch mustaqil signal: 1) LLM (Groq, zaxira OpenAI) — qat'iy JSON, massiv;
// 2) qoida-parser (validator); 3) kalit so'z lug'ati (o'z-o'zini to'ldiruvchi).
// Qoidalar: LLM+qoida summasi mos va ishonch >= 0.8 -> to'g'ridan-to'g'ri;
// aks holda tasdiqlash kartasi. Qarz iboralari Xarajatga emas, Hamkorlar oqimiga.
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
// Multiplikator KO'P TILLI (mobil _amtRe bilan sinxron — xarajat.dart):
// ming/минг/тыс/k/к -> x1000; mln/million/млн/миллион/m/м -> x1000000.
// Qisqa k|к|m|м faqat alohida turganda multiplikator ("5000 kofe"dagi "k" emas).
const MULT_SRC = String.raw`(ming[a-z'’]*|минг[а-яё]*|тыс[а-яё]*\.?|mln[a-z]*|million[a-z]*|milion[a-z]*|млн\.?|миллион[а-яё]*|милион[а-яё]*|[kк](?![a-zа-яё0-9])|[mм](?![a-zа-яё0-9]))`;
const isThousandMult = (w) => /^(ming|минг|тыс|k|к)/i.test(w);
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
    if (m[2]) a *= isThousandMult(m[2]) ? 1_000 : 1_000_000;
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
const INC_NOUN = /\b(oylik|maosh|avans|daromad|bonus|kirim|foyda|salary|income|profit|revenue)\b|mijoz\w*|sotuv\w*|ойлик|маош|даромад|кирим|фойда|аванс|бонус|зарплат[а-яё]*|доход[а-яё]*|мижоз[а-яё]*|сотув[а-яё]*/g;
const INC_VERB = /\boldim\b|\bsotdim\b|keldi|tushdi|qaytdi\b|qaytardi\b|\breceived\b|\bearned\b|\bgot\b|\bsold\b|олдим|сотдим|келди|тушди|қайтди|получил[а-яё]*|заработал[а-яё]*|пришл[а-яё]*|поступил[а-яё]*|продал[а-яё]*/g;
const EXP_NOUN = /kredit\w*|xarid\w*|\bqarzga\b|\brent\b|кредит[а-яё]*|аренд[а-яё]*|харид[а-яё]*/g;
const EXP_VERB = /berdim|sarfladim|ishlatdim|to'ladim|toladim|ketdi|sotib\s+oldim|qaytardim|qaytarib\s+berdim|\bspent\b|\bpaid\b|\bbought\b|\bgave\b|бердим|сарфладим|тўладим|туладим|кетди|сотиб\s+олдим|потратил[а-яё]*|купил[а-яё]*|заплатил[а-яё]*|оплатил[а-яё]*|отдал[а-яё]*/g;

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

async function previewLlm({ url, key, model, text, amounts, timeoutMs }) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model, temperature: 0, max_tokens: 80, response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: PREVIEW_SYS },
        { role: 'user', content: `Note: "${String(text).slice(0, 300)}"\nAmounts (${amounts.length}): ${amounts.map((a, i) => `${i + 1}) ${a}`).join('  ')}` },
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

// Multiplikator/valyuta so'zlari kontekst EMAS ("400 ming so'm"da yo'nalish so'zi yo'q)
const NOCTX = /^(ming|mln|million|milion|минг|млн|миллион|милион|тыс|тысяч|so'm|som|sum|сум|сўм|uzs|k|к|m|м)/i;

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
  if (hasContext && config.stt.groqKey) {
    try {
      kinds = await previewLlm({ url: 'https://api.groq.com/openai/v1/chat/completions',
        key: config.stt.groqKey, model: config.llm.groqModel, text, amounts, timeoutMs: 3500 });
      provider = 'groq';
    } catch { /* zaxiraga o'tamiz */ }
  }
  if (hasContext && !kinds && config.stt.openaiKey) {
    try {
      kinds = await previewLlm({ url: 'https://api.openai.com/v1/chat/completions',
        key: config.stt.openaiKey, model: config.llm.openaiModel, text, amounts, timeoutMs: 4500 });
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

const CAT_RULES = [
  ['Oziq-ovqat', /oziq|ovqat|bozor|non|go'sht|gosht|market|korzinka|restoran|kafe|choyxona/],
  ['Transport', /taksi|benzin|yo'l|yol|metro|avtobus|mashina/],
  ['Kommunal', /kommunal|svet|elektr|gaz|suv|internet|telefon/],
  ["Ko'ngilochar", /kino|konsert|o'yin|oyin|sayohat|dam olish/],
  ['Kiyim', /kiyim|ko'ylak|koylak|poyabzal|shim|kurtka/],
  ['Salomatlik', /dori|apteka|shifokor|klinika|tish|salomatlik/],
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

// ---------- 3-signal: KALIT SO'Z LUG'ATI ----------
// User lug'ati kuchli (x3), global agregat kuchsiz. score>=2 bo'lsa ishonchli.
async function dictLookup(userId, words) {
  if (!words.length) return new Map();
  const { data } = await supabaseAdmin
    .from('word_map').select('user_id, word, category, hits').in('word', words).limit(500);
  const scores = new Map(); // word -> Map(category -> score)
  for (const r of data || []) {
    const w = scores.get(r.word) || new Map();
    w.set(r.category, (w.get(r.category) || 0) + r.hits * (r.user_id === userId ? 3 : 1));
    scores.set(r.word, w);
  }
  const best = new Map(); // word -> {category, score}
  for (const [word, cats] of scores) {
    const top = [...cats.entries()].sort((a, b) => b[1] - a[1])[0];
    if (top && top[1] >= 2) best.set(word, { category: top[0], score: top[1] });
  }
  return best;
}

// ---------- 1-signal: LLM (Groq asosiy, OpenAI zaxira) ----------
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
7. Aralash gapda har amal yo'nalishini O'Z bo'lagidagi so'zlarga qarab aniqla: "oylik oldim 4 mln kreditga 200 ming berdim" -> daromad 4000000 VA xarajat 200000 (bitta gapdagi boshqa bo'lak so'zlari amal yo'nalishini o'zgartirmasin).${shots ? `\n\nMISOLLAR (shu foydalanuvchining tuzatishlari — uslubiga moslash):\n${shots}` : ''}`;
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
  return !!(config.stt.groqKey || config.stt.openaiKey);
}

export async function parseText(text, userId) {
  const words = meaningfulWords(text);
  const [cats, fewshotsRes, dict] = await Promise.all([
    ensureCategories(userId),
    supabaseAdmin.from('corrections').select('text, final').eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(4),
    dictLookup(userId, words),
  ]);
  const categories = cats.map((c) => c.name);
  const fewshots = (fewshotsRes.data || []).map((r) => ({ text: r.text, final: r.final })).reverse();

  // LLM: Groq -> OpenAI zaxira
  let actions = null; let provider = 'rules'; const errors = [];
  if (config.stt.groqKey) {
    try {
      actions = await callLlm({
        url: 'https://api.groq.com/openai/v1/chat/completions',
        key: config.stt.groqKey, model: config.llm.groqModel,
        text, categories, fewshots, timeoutMs: 7000,
      });
      provider = 'groq';
    } catch (e) { errors.push(`groq: ${e.message}`); }
  }
  if (!actions && config.stt.openaiKey) {
    try {
      actions = await callLlm({
        url: 'https://api.openai.com/v1/chat/completions',
        key: config.stt.openaiKey, model: config.llm.openaiModel,
        text, categories, fewshots, timeoutMs: 9000,
      });
      provider = 'openai';
    } catch (e) { errors.push(`openai: ${e.message}`); }
  }

  const rule = ruleParse(text);
  let clean = (actions || []).map((a) => sanitizeAction(a, categories, text)).filter(Boolean);

  // LLM yiqilsa -> qoida-parser natijasi MAJBURIY tasdiq bilan (XOTIRA §3)
  if (!clean.length) {
    if (rule.amount > 0) clean = [{ ...rule, new_category_suggestion: null }];
    return { actions: clean, needs_confirm: true, provider: clean.length ? 'rules' : provider, errors };
  }

  // Lug'at: tanish so'z -> toifani lug'atdan (LLM'siz to'g'ri tushadi)
  for (const a of clean) {
    if (a.direction !== 'xarajat') continue;
    for (const w of meaningfulWords(a.note)) {
      const hit = dict.get(w);
      if (!hit) continue;
      if (hit.category !== a.category) { a.category = hit.category; a.new_category_suggestion = null; }
      a.confidence = Math.max(a.confidence, 0.9);
      break;
    }
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

  return { actions: clean, needs_confirm: needsConfirm, provider, errors };
}

// ---------- O'RGANISH: tasdiqlangan yozuvdan lug'at + tuzatish (few-shot) ----------
export async function learnFrom(userId, text, finalActions, parsedActions) {
  try {
    // 1. so'z -> toifa lug'ati (faqat xarajat)
    const rows = [];
    for (const a of finalActions) {
      if (a.direction !== 'xarajat' || !a.category) continue;
      for (const w of meaningfulWords(a.note || text)) rows.push({ user_id: userId, word: w, category: a.category });
    }
    for (const r of rows) {
      const { data } = await supabaseAdmin.from('word_map')
        .select('hits').match({ user_id: r.user_id, word: r.word, category: r.category }).maybeSingle();
      await supabaseAdmin.from('word_map').upsert(
        { ...r, hits: (data?.hits || 0) + 1, updated_at: new Date().toISOString() },
        { onConflict: 'user_id,word,category' });
    }
    // 2. tuzatish bo'lsa — few-shot xotiraga
    const sig = (arr) => JSON.stringify((arr || []).map((a) => [a.direction, a.amount, a.category]));
    if (parsedActions && sig(parsedActions) !== sig(finalActions)) {
      await supabaseAdmin.from('corrections').insert({
        user_id: userId, text: String(text).slice(0, 300),
        parsed: parsedActions, final: finalActions,
      });
    }
  } catch (e) {
    console.error('learnFrom:', e.message); // o'rganish yiqilsa ham asosiy oqim buzilmaydi
  }
}
