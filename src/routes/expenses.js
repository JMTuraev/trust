import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { parseText, previewKinds, learnFrom, unlearnFrom, isQarz, DIRECTIONS } from '../services/parse.js';
import { ensureCategories } from '../lib/categories.js';
import { requireActiveSub, requireExpenseQuota } from '../lib/subscription.js';

const router = Router();

// Har foydalanuvchi uchun daqiqalik LLM limiti.
// MUHIM (2026-08-02 audit): /parse va /preview har chaqiruvda HAQIQIY Groq/OpenAI
// so'rovi yuboradi, lekin ular faqat IP bo'yicha cheklangan edi. Bitta foydalanuvchi
// 60/min tezlikda ~34 daqiqada Groq'ning kunlik bepul kvotasini tugatib, BARCHA
// foydalanuvchilarni qoida-parseriga tushirib qo'yishi mumkin edi.
const llmBuckets = new Map();
function perUserLlmLimit(max) {
  return (req, res, next) => {
    const now = Date.now();
    const key = `${req.user.id}`;
    let b = llmBuckets.get(key);
    if (!b || now - b.start > 60_000) { b = { start: now, count: 0 }; llmBuckets.set(key, b); }
    b.count += 1;
    if (b.count > max) {
      return res.status(429).json({
        success: false, code: 'PARSE_RATE_MINUTE',
        error: "Biroz sekinroq — bir ozdan keyin qayta urinib ko'ring",
      });
    }
    next();
  };
}
setInterval(() => {
  const now = Date.now();
  for (const [k, b] of llmBuckets) if (now - b.start > 10 * 60_000) llmBuckets.delete(k);
}, 5 * 60_000).unref();
router.use(requireAuth);

// GET /api/expenses?from=ISO&to=ISO&category=Nomi&limit=N
// category/limit — ixtiyoriy (papka ichi so'rovlari va sahifalash uchun; default o'zgarmagan)
router.get('/', async (req, res, next) => {
  try {
    let q = supabaseAdmin.from('expenses').select('*').eq('user_id', req.user.id).order('occurred_at', { ascending: false });
    // Sana filtrlari TEKSHIRILADI: ?from[]=a&from[]=b massiv berardi va PostgREST'da
    // `gte.a,b` bo'lib 500 qaytarardi (2026-08-02 audit).
    const isIsoish = (v) => typeof v === 'string' && v.length <= 40 && !Number.isNaN(Date.parse(v));
    if (req.query.from) {
      if (!isIsoish(req.query.from)) return res.status(400).json({ success: false, error: "from noto'g'ri sana" });
      q = q.gte('occurred_at', req.query.from);
    }
    if (req.query.to) {
      if (!isIsoish(req.query.to)) return res.status(400).json({ success: false, error: "to noto'g'ri sana" });
      q = q.lte('occurred_at', req.query.to);
    }
    if (req.query.category) q = q.eq('category', String(req.query.category).slice(0, 40));
    // DEFAULT LIMIT majburiy: limitsiz so'rov foydalanuvchining butun tarixini bir
    // javobda tortib, Render'ning kichik xotirasini to'ldirardi (2026-08-02 audit).
    const lim = parseInt(req.query.limit, 10);
    q = q.limit(Number.isFinite(lim) && lim > 0 ? Math.min(lim, 1000) : 500);
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/expenses  { income, amount, category?, note? }
// Obuna: expired user yangi yozuv yarata olmaydi (402 SUB_EXPIRED) — o'qish ochiq qoladi.
// YANGI TARIF (PO 2026-07-28): bepul 3 ta xarajat yozuvi, keyin $9/oy (kvota serverda)
router.post('/', requireExpenseQuota, async (req, res, next) => {
  try {
    const { income, amount, category, note } = req.body || {};
    // MUHIM (2026-08-02 audit): ilgari Number.isFinite yetarli deb hisoblanardi.
    // amount=0.001 tekshiruvdan o'tib, numeric(18,2) ustunida 0.00 ga yaxlitlanardi va
    // `check (amount > 0)` buzilib, foydalanuvchi XOM Postgres xatosi bilan 500 olardi;
    // 1e17 esa ustun sig'imidan oshib ketardi. Boshqa yozuv yo'llari kabi butun son.
    const amt = Math.round(Number(amount));
    if (!Number.isInteger(amt) || amt <= 0 || amt > 1e13) {
      return res.status(400).json({ success: false, error: 'amount musbat butun son bo\'lishi kerak' });
    }
    // Toifa SANITATSIYA qilinadi (2026-08-02 audit: prompt injection + uzunlik), ammo
    // ro'yxatga MAJBURLANMAYDI (2026-08-03 tuzatish). Majburlash ikki oqimni sindirardi:
    //  (1) daromad manbalari — mobil kirimni category='@nomi' bilan yuboradi, bu nom
    //      categories jadvalida YO'Q (manbalar yozuvlardan quriladi) -> kirim jimgina
    //      'Boshqa'ga tushib, manba qoldig'i 0 bo'lib qolardi;
    //  (2) undo-restore — o'chirilgan yozuv qaytarilganda toifasi jadvalda bo'lmasligi
    //      mumkin (papkalar expenses qatorlaridan hosil bo'ladi) -> tarix buzilardi.
    // Injection himoyasi: boshqaruv belgilari olib tashlanadi + 40 belgi limiti.
    let cat = category == null
      ? null
      : String(category).replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim() || null;
    if (cat) {
      if (cat.length > 40) return res.status(400).json({ success: false, error: 'Toifa nomi 40 belgidan oshmasin' });
      const cats = await ensureCategories(req.user.id);
      const hit = cats.find((c) => c.name.toLowerCase() === cat.toLowerCase());
      if (hit) cat = hit.name; // ro'yxatda bo'lsa — kanonik yozilish
    }
    const noteVal = note == null ? null : String(note).trim().slice(0, 200) || null;
    const { data, error } = await supabaseAdmin.from('expenses').insert({
      user_id: req.user.id, income: !!income, amount: amt, category: cat, note: noteVal,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data });
  } catch (e) { next(e); }
});

// POST /api/expenses/parse  { text, source? }
// Uch signal (LLM + qoida + lug'at) -> { actions[], needs_confirm, provider }
// Hech narsa saqlanmaydi — saqlash /confirm orqali (tasdiqlash kartasi oqimi).
router.post('/parse', requireActiveSub, rateLimit({ windowMs: 60_000, max: 30 }), perUserLlmLimit(20), async (req, res, next) => {
  try {
    const text = String(req.body?.text || '').trim();
    if (text.length < 2 || text.length > 300) {
      return res.status(400).json({ success: false, error: "Matn 2–300 belgi bo'lsin" });
    }
    const r = await parseText(text, req.user.id);
    console.log(`[parse] provider=${r.provider} | ${text.length} belgi -> ${r.actions.length} amal`);
    if (r.errors?.length) console.warn('parse fallback:', r.errors.join(' | '));
    res.json({ success: true, data: { actions: r.actions, needs_confirm: r.needs_confirm, provider: r.provider } });
  } catch (e) { next(e); }
});

// POST /api/expenses/preview  { text }
// Jonli input rangi (summa yashil "in" / qizil "out") — DB'ga YOZILMAYDI, javob tez.
// Mobil 550ms debounce bilan chaqiradi (xarajat.dart _HlController); natija kesh
// bilan qaytadi. Limit /parse'dan yuqori — yozish jarayonida bir necha so'rov normal.
router.post('/preview', rateLimit({ windowMs: 60_000, max: 60 }), perUserLlmLimit(40), async (req, res, next) => {
  try {
    const text = String(req.body?.text || '').trim();
    if (!text || text.length > 300) {
      return res.status(400).json({ success: false, error: "Matn 1–300 belgi bo'lsin" });
    }
    const r = await previewKinds(text);
    res.json({ success: true, data: r });
  } catch (e) { next(e); }
});

// POST /api/expenses/confirm  { text, source?, actions: [...], parsed?: [...] }
// actions — user tasdiqlagan yakuniy holat (kartada tahrirlangan bo'lishi mumkin).
// daromad/xarajat -> expenses'ga yoziladi; qarz_* -> saqlanmaydi, `routed` bo'lib qaytadi
// (mobil Hamkorlar oqimiga yo'naltiradi). O'rganish: lug'at + tuzatishlar (few-shot).
// YANGI TARIF: confirm ham expenses'ga YOZADI — xuddi shu kvota gate'i
router.post('/confirm', requireExpenseQuota, async (req, res, next) => {
  try {
    const text = String(req.body?.text || '').trim();
    const source = req.body?.source === 'voice' ? 'voice' : 'text';
    const list = Array.isArray(req.body?.actions) ? req.body.actions : [];
    if (!list.length) return res.status(400).json({ success: false, error: 'actions kerak' });
    if (list.length > 5) return res.status(400).json({ success: false, error: "Bitta gapda ko'pi bilan 5 amal" });

    const cats = await ensureCategories(req.user.id);
    const saved = []; const routed = []; const finals = [];
    for (const raw of list) {
      const direction = DIRECTIONS.includes(raw?.direction) ? raw.direction : 'xarajat';
      const amount = Math.round(Number(raw?.amount) || 0);
      if (amount <= 0) return res.status(400).json({ success: false, error: "Summa noto'g'ri" });
      const note = String(raw?.note || text).trim().slice(0, 200);
      const action = { direction, amount, currency: 'UZS', note, person: raw?.person ? String(raw.person).trim() : null };

      if (isQarz(direction)) { routed.push(action); finals.push(action); continue; }

      let category = direction === 'daromad' ? 'Daromad' : String(raw?.category || 'Boshqa').trim();
      if (direction === 'xarajat') {
        const hit = cats.find((c) => c.name.toLowerCase() === category.toLowerCase());
        if (!hit && raw?.accept_new_category === true && category.length >= 2 && category.length <= 40) {
          // Yangi toifa — faqat user "qo'shilsin" degan holatda (jimgina yaratilmaydi)
          const { error: ce } = await supabaseAdmin.from('categories')
            .insert({ user_id: req.user.id, name: category });
          if (ce && !/duplicate/i.test(ce.message)) throw new Error(ce.message);
          // learnFrom (b)-sharti (2026-08-03): user yangi toifani OCHIQ qabul qildi —
          // bayroq final amalga o'tadi (learnFrom uni corrections'ga yozishdan oldin kesadi)
          action.accept_new_category = true;
        } else if (!hit) category = 'Boshqa';
        else category = hit.name;
      }
      action.category = category;

      const { data, error } = await supabaseAdmin.from('expenses').insert({
        user_id: req.user.id, income: direction === 'daromad', amount,
        category, note: note || null, source, raw_text: text || null,
        confidence: raw?.confidence != null ? Math.max(0, Math.min(1, Number(raw.confidence))) : null,
      }).select().single();
      if (error) throw new Error(error.message);
      saved.push(data); finals.push(action);
    }

    // O'rganish — bloklamaydi, xatosi asosiy oqimni buzmaydi
    const parsed = Array.isArray(req.body?.parsed) ? req.body.parsed : null;
    learnFrom(req.user.id, text, finals, parsed);

    res.status(201).json({ success: true, data: { saved, routed } });
  } catch (e) { next(e); }
});

// PATCH /api/expenses/:id  { amount?, income?, category?, note? }
// Chatdagi yozuvni inline tahrirlash. Toifa faqat mavjud ro'yxatdan (yangi jimgina yaratilmaydi).
router.patch('/:id', requireActiveSub, async (req, res, next) => {
  try {
    const { data: e } = await supabaseAdmin.from('expenses').select('*').eq('id', req.params.id).maybeSingle();
    if (!e || e.user_id !== req.user.id) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const patch = {};
    if (req.body?.amount !== undefined) {
      const a = Math.round(Number(req.body.amount) || 0);
      if (a <= 0) return res.status(400).json({ success: false, error: "Summa noto'g'ri" });
      patch.amount = a;
    }
    if (req.body?.income !== undefined) patch.income = !!req.body.income;
    if (req.body?.note !== undefined) patch.note = req.body.note || null;
    if (req.body?.category !== undefined) {
      const income = patch.income ?? e.income;
      if (income) patch.category = 'Daromad';
      else {
        const cats = await ensureCategories(req.user.id);
        const cat = String(req.body.category || 'Boshqa').trim();
        const hit = cats.find((c) => c.name.toLowerCase() === cat.toLowerCase());
        patch.category = hit ? hit.name : 'Boshqa';
      }
    } else if (patch.income === true) {
      patch.category = 'Daromad';
    } else if (patch.income === false && e.income && e.category === 'Daromad') {
      // Kirim -> chiqimga o'girildi, toifa berilmadi: 'Daromad' nomli CHIQIM yozuvi
      // qolsa papka rangi/yig'indisi aralashib ketardi (kirim+chiqim bitta papkada) —
      // zaxira 'Boshqa'ga tushiramiz.
      patch.category = 'Boshqa';
    }
    if (!Object.keys(patch).length) return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    const { data, error } = await supabaseAdmin.from('expenses').update(patch).eq('id', e.id).select().single();
    if (error) throw new Error(error.message);
    // O'rganish TUZATISHI (2026-08-03 CRITICAL to'plami): inline toifa tahriri — bu USER
    // tuzatishi. Eski so'z->toifa bog'i pasayadi (unlearn), yangisi o'rganiladi va
    // corrections qatori few-shot'ni ham davolaydi (learnFrom (a)-sharti: parsed=[eski]
    // final=[yangi] farq qiladi). Bloklamaydi (fire-and-forget, learnFrom uslubi).
    // Faqat XARAJAT bo'lib qolgan yozuvda, toifa HAQIQATAN o'zgarganda va note bo'lsa.
    if (!e.income && !data.income && req.body?.category !== undefined
        && data.category !== e.category && (data.note || e.note)) {
      const mk = (category, note) => ({
        direction: 'xarajat', amount: Math.round(Number(data.amount)), currency: 'UZS',
        category, note: note || '', person: null,
      });
      unlearnFrom(req.user.id, e.note, e.category);
      learnFrom(req.user.id, data.note || e.note || '',
        [mk(data.category, data.note)], [mk(e.category, e.note)]);
    }
    res.json({ success: true, data });
  } catch (e) { next(e); }
});

// DELETE /api/expenses/:id — chatdan yozuvni o'chirish
router.delete('/:id', async (req, res, next) => {
  try {
    const { data: e } = await supabaseAdmin.from('expenses')
      .select('user_id, income, category, note').eq('id', req.params.id).maybeSingle();
    if (!e || e.user_id !== req.user.id) return res.status(404).json({ success: false, error: 'Topilmadi' });
    await supabaseAdmin.from('expenses').delete().eq('id', req.params.id);
    // TESKARI o'rganish (2026-08-03 CRITICAL to'plami): o'chirilgan xarajat o'z
    // so'z->toifa bog'ini bitta pog'ona pasaytiradi (hits-1, 0 da qator o'chadi) —
    // xato saqlanib keyin o'chirilgan yozuv lug'atda STRONG iz qoldirmaydi.
    // Bloklamaydi — xatosi asosiy oqimni buzmaydi (unlearnFrom ichida try/catch).
    if (!e.income && e.category && e.note) unlearnFrom(req.user.id, e.note, e.category);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// GET /api/expenses/summary  (bu oy: daromad, xarajat, sof, toifalar, limit)
router.get('/summary/month', async (req, res, next) => {
  try {
    const start = new Date(); start.setDate(1); start.setHours(0, 0, 0, 0);
    const { data } = await supabaseAdmin.from('expenses').select('income, amount, category')
      .eq('user_id', req.user.id).gte('occurred_at', start.toISOString());
    const rows = data || [];
    const income = rows.filter((r) => r.income).reduce((s, r) => s + Number(r.amount), 0);
    const expense = rows.filter((r) => !r.income).reduce((s, r) => s + Number(r.amount), 0);
    const cats = {};
    rows.filter((r) => !r.income).forEach((r) => { const k = r.category || 'Boshqa'; cats[k] = (cats[k] || 0) + Number(r.amount); });
    const { data: lim } = await supabaseAdmin.from('limits').select('monthly_limit').eq('user_id', req.user.id).maybeSingle();
    res.json({ success: true, data: { income, expense, net: income - expense,
      categories: Object.entries(cats).map(([name, amt]) => ({ name, amt })).sort((a, b) => b.amt - a.amt),
      limit: Number(lim?.monthly_limit || 0), spent: expense } });
  } catch (e) { next(e); }
});

export default router;
