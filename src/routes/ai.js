// Trust AI — moliyaviy hamroh chat (docs/ai-character.md).
// FAQAT MATN (ovoz/STT yo'q — PO qarori §11: odam pul masalasini ovoz chiqarib aytmaydi).
//
// Endpointlar:
//   POST /api/ai/chat      — xabar yuborish (obuna: requireActiveSub -> expired 402)
//   GET  /api/ai/messages  — tarix (OCHIQ: expired user o'qiy oladi — read-only model)
//   POST /api/ai/flag      — "noto'g'ri javob" (Google Play 2026 AI-Generated Content
//                            talabi — MAJBURIY; obunadan qat'i nazar ochiq)
//
// XAVFSIZLIK SHARTNOMASI:
//   - LLM faqat SHU YERDA chaqiriladi — kalit mobilga hech qachon chiqmaydi.
//   - System prompt server konstantasi (services/ai-persona.js) — user o'zgartira olmaydi.
//   - Model javobi HECH QACHON amal sifatida bajarilmaydi: bloklar `confirm:true` bilan
//     TAKLIF bo'lib qaytadi, mobil foydalanuvchi bosgandan keyin mavjud endpointni chaqiradi.
//   - Hamkor ismlari modelga yuborilmaydi (ai-context.js psevdonimlashtirish).
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { requireActiveSub } from '../lib/subscription.js';
import { ensureCategories } from '../lib/categories.js';
import { config } from '../config.js';
import { askAI, costOf, aiReady } from '../lib/anthropic.js';
import { contextBlock, stripNameOpening, EMPTY_TEXT } from '../services/ai-persona.js';
import { pickKnowledge } from '../services/ai-knowledge.js';
import {
  getProfile, pseudonymizeText, restoreBlocks, localParts, dayStartUtc, monthStartUtc, uzDate,
} from '../services/ai-context.js';

const router = Router();
router.use(requireAuth);

const MAX_MESSAGE_CHARS = 1000;

/**
 * Tarixni QAT'IY navbatma-navbat holatga keltiradi: user, assistant, user, ...
 * Anthropic talabi: birinchi xabar 'user' bo'lsin va rollar almashib kelsin — aks holda 400.
 * Buzilish real: agar oldingi so'rovda user qatori yozilib, assistant yozilishi yiqilgan
 * bo'lsa, tarixda ketma-ket ikkita 'user' qoladi va CHAT BUTUNLAY ishlamay qolardi.
 * Oxiri 'user' bo'lsa ham tashlanadi — yangi xabar ham 'user' rolida qo'shiladi.
 */
export function alternating(msgs) {
  const out = [];
  for (const m of msgs) {
    if (!out.length && m.role !== 'user') continue;          // 'assistant' bilan boshlanmasin
    if (out.length && out[out.length - 1].role === m.role) { // ketma-ket bir xil rol
      out[out.length - 1] = m;                               // eng so'nggisini qoldiramiz
      continue;
    }
    out.push(m);
  }
  if (out.length && out[out.length - 1].role === 'user') out.pop();
  return out;
}

// ---------- Limitlar ----------
// Falsafa (PO): limitlar SUIISTE'MOLGA qarshi, ratsion uchun EMAS. Shuning uchun saxiy
// (40/kun, 400/oy) va hammasi env bilan sozlanadi. Har chaqiruv ai_usage'ga yoziladi —
// PO real ma'lumot bilan keyin sozlaydi.

// Daqiqalik limit — PER USER (middleware/rateLimit.js IP bo'yicha ishlaydi, bu yetarli emas:
// bitta uy Wi-Fi ortidagi 3 kishi bir-birining limitini yeb qo'ymasin).
const minuteBuckets = new Map();
function perUserMinuteLimit(req, res, next) {
  const now = Date.now();
  let b = minuteBuckets.get(req.user.id);
  if (!b || now - b.start > 60_000) { b = { start: now, count: 0 }; minuteBuckets.set(req.user.id, b); }
  b.count += 1;
  if (b.count > config.ai.minuteLimit) {
    return res.status(429).json({
      success: false, code: 'AI_RATE_MINUTE',
      error: `Biroz sekinroq — bir daqiqada ${config.ai.minuteLimit} ta xabar. Bir ozdan keyin davom etamiz.`,
    });
  }
  next();
}
setInterval(() => {
  const now = Date.now();
  for (const [k, b] of minuteBuckets) if (now - b.start > 10 * 60_000) minuteBuckets.delete(k);
}, 5 * 60_000).unref();

/** Kunlik/oylik sarf (faqat HAQIQIY model chaqiruvlari — 'fallback' hisobga olinmaydi). */
async function usageCounts(userId, now = new Date()) {
  const p = localParts(now);
  const dayFrom = dayStartUtc(p.y, p.m, p.day).toISOString();
  const monthFrom = monthStartUtc(p.y, p.m).toISOString();
  const q = (from) => supabaseAdmin.from('ai_usage')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId).neq('provider', 'fallback').gte('created_at', from);
  const [day, month] = await Promise.all([q(dayFrom), q(monthFrom)]);
  return { day: day.count || 0, month: month.count || 0 };
}

// ---------- POST /api/ai/chat ----------
// Body: { message: string }
// Javob: { success:true, data:{ id, blocks, provider, created_at, limits } }
router.post('/chat', requireActiveSub, rateLimit({ windowMs: 60_000, max: 20 }), perUserMinuteLimit,
  async (req, res, next) => {
    try {
      if (!config.ai.enabled || !aiReady()) {
        return res.status(503).json({ success: false, code: 'AI_OFF', error: 'Trust AI hozircha mavjud emas' });
      }
      const message = String(req.body?.message || '').trim();
      if (message.length < 1 || message.length > MAX_MESSAGE_CHARS) {
        return res.status(400).json({ success: false, error: `Xabar 1–${MAX_MESSAGE_CHARS} belgi bo'lsin` });
      }

      const now = new Date();
      const counts = await usageCounts(req.user.id, now);
      if (counts.day >= config.ai.dailyLimit) {
        return res.status(429).json({
          success: false, code: 'AI_LIMIT_DAILY',
          error: `Bugunga xabar chegarasi tugadi (${config.ai.dailyLimit} ta). Ertaga yana gaplashamiz.`,
        });
      }
      if (counts.month >= config.ai.monthlyLimit) {
        return res.status(429).json({
          success: false, code: 'AI_LIMIT_MONTHLY',
          error: `Bu oyga xabar chegarasi tugadi (${config.ai.monthlyLimit} ta). Keyingi oy yangilanadi.`,
        });
      }

      // 1. Kontekst (keshlangan agregat + psevdonim xaritasi) + profil ismi + toifalar
      const [profile, prof, cats, histRes] = await Promise.all([
        getProfile(req.user.id, { now }),
        supabaseAdmin.from('profiles').select('full_name').eq('id', req.user.id).maybeSingle(),
        ensureCategories(req.user.id),
        supabaseAdmin.from('ai_messages').select('role, content')
          .eq('user_id', req.user.id).order('created_at', { ascending: false })
          .limit(config.ai.historyMessages),
      ]);

      const firstName = String(prof.data?.full_name || '').trim().split(/\s+/)[0] || "do'stim";
      // Bilim kartalari (xilma-xillik): ai_profile keshiga YOZILMAYDI — summary o'zgarmaydi,
      // kartalar faqat so'rov paytida qo'shiladi. pickKnowledge kun ichida deterministik
      // (bir user -> bir xil 3 karta), shuning uchun 2-kesh nuqtasi bayt-barqaror qoladi
      // va Anthropic prompt-cache buzilmaydi; kun almashganda bir marta yangilanadi.
      const contextText = contextBlock({
        name: firstName,
        date: uzDate(now),
        currency: "so'm",
        summary: profile.summary,
        knowledge: pickKnowledge(req.user.id, now, 3),
      });

      // 2. Tarix (eskidan yangiga) — modelga PSEVDONIMLASHGAN holda boradi.
      //    Oxirgi 6–8 almashinuv yetarli: token tejaladi, xarakter esa qisqa suhbat quradi.
      const history = alternating(
        (histRes.data || []).reverse()
          .filter((m) => m.content)
          .map((m) => ({ role: m.role, content: pseudonymizeText(m.content, profile.tokens).slice(0, 1500) }))
      );

      // 3. Foydalanuvchi xabaridagi real ismlar ham belgiga almashadi ("Anvarga" -> "HAMKOR_1ga")
      const safeMessage = pseudonymizeText(message, profile.tokens);

      // 4. Model: Anthropic -> Groq -> iliq xato (hech qachon tashlamaydi)
      const r = await askAI({ contextText, history, message: safeMessage });

      // 5. Belgilarni real ism/UUID'ga qaytarish + server tomonidan majburlangan maydonlar.
      //    Hammasi tushib qolsa XOM bloklar KO'RSATILMAYDI — ular ichida HAMKOR_n belgisi
      //    qolgan bo'lishi mumkin (aynan biz to'sayotgan sizib chiqish).
      const blocks = restoreBlocks(r.blocks, profile.tokens, { categories: cats.map((c) => c.name) });
      // Suhbat DAVOMIDA "Ism, ..." ochilishini deterministik kesamiz (model eski
      // tarixga ergashadi — prompt yetarli emas). Birinchi javobda ism qoladi.
      if (history.length) stripNameOpening(blocks, firstName);
      const safeBlocks = blocks.length ? blocks : [{ type: 'text', text: EMPTY_TEXT }];
      const content = safeBlocks.filter((b) => b.type === 'text').map((b) => b.text).join('\n');

      // 6. Tarix: xabarlar ASL (psevdonimlashmagan) holda saqlanadi — foydalanuvchi
      //    o'z daftarini real ism bilan ko'radi. Belgilar faqat MODEL yo'nalishida.
      const ts = now.toISOString();
      const tsA = new Date(now.getTime() + 1).toISOString();
      const { error: insErr } = await supabaseAdmin.from('ai_messages').insert([
        { user_id: req.user.id, role: 'user', content: message, created_at: ts },
      ]);
      if (insErr) throw new Error(insErr.message);
      const { data: aRow, error: aErr } = await supabaseAdmin.from('ai_messages').insert({
        user_id: req.user.id, role: 'assistant', content, blocks: safeBlocks,
        provider: r.provider, created_at: tsA,
      }).select('id, created_at').single();
      if (aErr) throw new Error(aErr.message);

      // 7. Token/xarajat auditi (PO real ma'lumot bilan limitlarni sozlaydi).
      //    cost_usd faqat Anthropic uchun hisoblanadi — narx jadvali (config.ai.price)
      //    o'shanikidir. Groq ~10x arzon va sozlash nishoni emas: tokenlari yoziladi,
      //    xarajati 0 (aks holda audit Opus narxida shishib, tahlilni chalg'itardi).
      const cost = r.provider === 'anthropic' ? costOf(r.usage) : 0;
      await supabaseAdmin.from('ai_usage').insert({
        user_id: req.user.id, provider: r.provider, model: r.model,
        input_tokens: r.usage.input_tokens, cached_input_tokens: r.usage.cached_input_tokens,
        cache_write_tokens: r.usage.cache_write_tokens, output_tokens: r.usage.output_tokens,
        cost_usd: cost,
      });

      // Log: kalit/xabar mazmuni EMAS — faqat o'lchov
      console.log(`[ai] ${r.provider}/${r.model} in=${r.usage.input_tokens} cached=${r.usage.cached_input_tokens} `
        + `write=${r.usage.cache_write_tokens} out=${r.usage.output_tokens} $${cost} blocks=${safeBlocks.length}`
        + (r.stop && r.stop !== 'tool_use' ? ` stop=${r.stop}` : ''));
      if (r.errors?.length) console.warn('[ai] fallback:', r.errors.join(' | '));

      res.status(201).json({
        success: true,
        data: {
          id: aRow.id,
          role: 'assistant',
          blocks: safeBlocks,
          provider: r.provider,
          created_at: aRow.created_at,
          limits: {
            daily_left: Math.max(0, config.ai.dailyLimit - counts.day - 1),
            monthly_left: Math.max(0, config.ai.monthlyLimit - counts.month - 1),
          },
        },
      });
    } catch (e) { next(e); }
  });

// ---------- GET /api/ai/messages?limit=30&before=<iso> ----------
//            (sinonim: GET /api/ai/history — spec shu nomni so'ragan)
// Tarix, yangidan eskiga (mobil ro'yxatni teskari chizadi). OBUNA TALAB QILINMAYDI:
// muddati tugagan user hamma narsani KO'RADI, faqat yangi xabar yubora olmaydi.
//
// IKKI YO'L, BITTA HANDLER: mobil (api.dart) `/messages` ga qurilgan, texnik topshiriq esa
// `/history` deydi. Nomni o'zgartirish mobilni sindirardi, spec'ni e'tiborsiz qoldirish esa
// integratsiyada yana shu bahsni tug'dirardi — shuning uchun ikkalasi ham ishlaydi.
router.get(['/messages', '/history'], async (req, res, next) => {
  try {
    const lim = Math.min(Math.max(parseInt(req.query.limit, 10) || 30, 1), 100);
    let q = supabaseAdmin.from('ai_messages')
      .select('id, role, content, blocks, provider, created_at')
      .eq('user_id', req.user.id)
      .order('created_at', { ascending: false })
      .limit(lim + 1); // +1 — has_more aniqlash uchun
    if (req.query.before) {
      const before = new Date(req.query.before);
      if (Number.isNaN(before.getTime())) {
        return res.status(400).json({ success: false, error: "before noto'g'ri sana formatida" });
      }
      q = q.lt('created_at', before.toISOString());
    }
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    const rows = data || [];
    const hasMore = rows.length > lim;
    res.json({ success: true, data: rows.slice(0, lim), has_more: hasMore });
  } catch (e) { next(e); }
});

// ---------- POST /api/ai/flag  { message_id, reason? } ----------
// Google Play 2026 AI-Generated Content siyosati: foydalanuvchi har AI javobini
// belgilay olishi SHART. Obuna tekshirilmaydi — bu shikoyat mexanizmi, mahsulot emas.
router.post('/flag', rateLimit({ windowMs: 60_000, max: 20 }), async (req, res, next) => {
  try {
    const messageId = String(req.body?.message_id || '').trim();
    if (!messageId) return res.status(400).json({ success: false, error: 'message_id kerak' });
    const reason = req.body?.reason ? String(req.body.reason).trim().slice(0, 500) : null;

    const { data: m } = await supabaseAdmin.from('ai_messages')
      .select('id, user_id, role').eq('id', messageId).maybeSingle();
    if (!m || m.user_id !== req.user.id) return res.status(404).json({ success: false, error: 'Xabar topilmadi' });
    if (m.role !== 'assistant') {
      return res.status(400).json({ success: false, error: 'Faqat AI javobini belgilash mumkin' });
    }

    // unique(user_id, message_id) — takror bosish xato bermasin (idempotent)
    const { error } = await supabaseAdmin.from('ai_flags')
      .upsert({ user_id: req.user.id, message_id: messageId, reason }, { onConflict: 'user_id,message_id' });
    if (error) throw new Error(error.message);
    res.json({ success: true, data: { message: 'Rahmat — javob ko\'rib chiqiladi' } });
  } catch (e) { next(e); }
});

export default router;
