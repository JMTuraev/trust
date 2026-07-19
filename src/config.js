import 'dotenv/config';

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  supabase: {
    url: process.env.SUPABASE_URL,
    anonKey: process.env.SUPABASE_ANON_KEY,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,

  },
  devsms: {
    token: process.env.DEVSMS_TOKEN,
    baseUrl: 'https://devsms.uz/api',
    serviceName: process.env.SMS_SERVICE_NAME || 'AllClubs',
    templateType: parseInt(process.env.SMS_TEMPLATE_TYPE || '4', 10),
  },
  app: {
    jwtSecret: process.env.APP_JWT_SECRET,
  },
  otp: {
    ttlSeconds: parseInt(process.env.OTP_TTL_SECONDS || '300', 10),
    maxAttempts: parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10),
    // Do'kon review test-login (Google Play / App Store): AYNAN shu raqam uchun
    // haqiqiy SMS yuborilmaydi va kod qat'iy (reviewCode). Boshqa hech qaysi raqamga
    // ta'sir qilmaydi. Review tugagach env'larni olib tashlab, bypass'ni o'chirsa bo'ladi.
    reviewPhone: (process.env.REVIEW_TEST_PHONE || '').replace(/[^\d]/g, ''),
    reviewCode: String(process.env.REVIEW_TEST_CODE || '').trim(),
  },
  // STT (ovoz -> matn) BUTUNLAY OLIB TASHLANDI (2026-07-17, docs/ai-character.md §11):
  // mahsulot qarori — odam pul masalasini ovoz chiqarib aytmaydi. `STT_ENABLED` yo'q,
  // routes/stt.js o'chirildi, mikrofon ruxsati olib tashlandi.
  // DIQQAT: GROQ_API_KEY/OPENAI_API_KEY o'CHIRILMADI — ular STT'niki emas, LLM'niki:
  // parse.js (matn -> JSON) va Trust AI zaxirasi shu kalitlar bilan ishlaydi. Shuning
  // uchun ular o'z uyiga — `llm` ga ko'chirildi.
  llm: {
    // Parsing (matn -> daromad/xarajat/qarz) + Trust AI zaxirasi.
    groqKey: process.env.GROQ_API_KEY,
    openaiKey: process.env.OPENAI_API_KEY,
    groqModel: process.env.GROQ_LLM_MODEL || 'llama-3.3-70b-versatile',
    openaiModel: process.env.OPENAI_LLM_MODEL || 'gpt-4o-mini',
  },
  ai: {
    // Trust AI — moliyaviy hamroh chat (docs/ai-character.md). FAQAT matn (ovoz/STT yo'q).
    // Asosiy: Anthropic Claude Opus 4.8. Zaxira: mavjud Groq kaliti (llm.groqModel).
    // Kalit yo'q bo'lsa route 503 qaytaradi — server ko'tariladi (fail-soft).
    enabled: process.env.AI_ENABLED !== 'false',
    anthropicKey: process.env.ANTHROPIC_API_KEY,
    model: process.env.AI_MODEL || 'claude-opus-4-8',
    // Xarakter suhbatli, lekin mavzu talab qilsa boy javob (insight + vizual bloklar) beradi.
    // 1200 sababi (2026-07-17): "hammasini birma-bir" tipidagi qarz javoblari (uzun matn +
    // bir nechta debt_card + chips) 800 da KESILIB, tool-JSON chala qolar edi -> bloklar
    // bo'sh -> fallback (qurilmada 4x takrorlangan). stop_reason=max_tokens logda ko'rinadi.
    maxTokens: parseInt(process.env.AI_MAX_TOKENS || '1200', 10),
    // Suhbat tarixi: oxirgi N ta xabar (user+assistant) promptga qo'shiladi
    historyMessages: parseInt(process.env.AI_HISTORY_MESSAGES || '12', 10),
    timeoutMs: parseInt(process.env.AI_TIMEOUT_MS || '25000', 10),
    fallbackTimeoutMs: parseInt(process.env.AI_FALLBACK_TIMEOUT_MS || '12000', 10),
    // Limitlar SUIISTE'MOLGA qarshi, ratsion uchun EMAS (PO qarori) — saxiy.
    // 2026-07-17 PO: kunlik 40 -> 100 ("AI dialog saxiyroq ko'rinsin"). Oylik ham
    // mutanosib ko'tarildi (10x kunlik), aks holda 100/kun 4 kunda oylik devorga urardi.
    // Eng yomon holat narxi: 1000 x ~$0.0085 = ~$8.5/oy (obuna $9) — bu CAP, kutilma emas
    // (tipik foydalanuvchi ~40/oy); kerak bo'lsa Render env bilan qaytariladi.
    dailyLimit: parseInt(process.env.AI_DAILY_LIMIT || '100', 10),
    monthlyLimit: parseInt(process.env.AI_MONTHLY_LIMIT || '1000', 10),
    minuteLimit: parseInt(process.env.AI_MINUTE_LIMIT || '5', 10),
    // Agregat kontekst keshi (ai_profile) shu muddatdan eski bo'lsa qayta hisoblanadi
    profileTtlMs: Math.round(parseFloat(process.env.AI_PROFILE_TTL_HOURS || '6') * 3600_000),
    // Narx ($/1M token) — audit (ai_usage.cost_usd) uchun. PO real tarifga qarab sozlaydi.
    // Default: Opus sinfidagi tarif; keshdan o'qish 0.1x, keshga yozish 1.25x.
    price: {
      inPerMTok: parseFloat(process.env.AI_PRICE_IN || '5'),
      cacheWritePerMTok: parseFloat(process.env.AI_PRICE_CACHE_WRITE || '6.25'),
      cacheReadPerMTok: parseFloat(process.env.AI_PRICE_CACHE_READ || '0.5'),
      outPerMTok: parseFloat(process.env.AI_PRICE_OUT || '25'),
    },
  },
  links: {
    // Mijoz rad etganda sotuvchiga signal shu kechikish bilan boradi (tiklansa — umuman bormaydi)
    rejectSignalDelayMs: Math.round(parseFloat(process.env.REJECT_SIGNAL_DELAY_HOURS || '24') * 3600_000),
    // Bitta sotuvchi 24 soatda yaratadigan yangi kontragentlar cheklovi
    partnerDailyLimit: parseInt(process.env.PARTNER_DAILY_LIMIT || '20', 10),
    // Rad-flag: oynada shuncha rad olgan sotuvchi yangi kontragent yarata olmaydi
    rejectFlagCount: parseInt(process.env.REJECT_FLAG_COUNT || '3', 10),
    rejectFlagWindowMs: Math.round(parseFloat(process.env.REJECT_FLAG_WINDOW_HOURS || '72') * 3600_000),
  },
};

// ---- VAQTINCHA moslik aliasi (o'chirilishi kerak) ----
// services/parse.js hali `config.stt.groqKey/openaiKey` ni o'qiydi. U fayl bu sub-sessiyaning
// ruxsat ro'yxatida EMAS, shuning uchun alias qoldirildi: usiz parse.js da
// "Cannot read properties of undefined" — ya'ni xarajat parsingi (asosiy funksiya) yiqilardi.
// Hisobotdagi §NEW-PATCHES da parse.js uchun aniq patch bor; qo'llangach SHU 2 QATOR O'CHIRILSIN.
config.stt = { groqKey: config.llm.groqKey, openaiKey: config.llm.openaiKey };

export function assertConfig() {
  const missing = [];
  if (!config.supabase.url) missing.push('SUPABASE_URL');
  if (!config.supabase.serviceRoleKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!config.app.jwtSecret) missing.push('APP_JWT_SECRET');

  // Trust AI — MAJBURIY EMAS (fail-soft): kalitsiz ham server ko'tariladi, chat esa
  // zaxiraga (Groq) yoki 503 AI_OFF ga tushadi. Sabab: AI — fishka, oldi-berdi yadrosi
  // emas; kalit yo'qligi butun ilovani (auth, qarz, xarajat) yiqitmasligi kerak.
  // Kalit QIYMATI hech qachon loglanmaydi — faqat bor/yo'qligi.
  if (config.ai.enabled && !config.ai.anthropicKey) {
    if (config.llm.groqKey) {
      console.warn("OGOHLANTIRISH: ANTHROPIC_API_KEY yo'q — Trust AI zaxira modelda (Groq) "
        + 'ishlaydi, sifat pasayadi. Render Dashboard\'da kalitni qo\'shing.');
    } else {
      console.warn("OGOHLANTIRISH: ANTHROPIC_API_KEY ham, GROQ_API_KEY ham yo'q — "
        + 'Trust AI chat 503 (AI_OFF) qaytaradi.');
    }
  }

  if (!missing.length) return;
  // Production'da fail-fast: buzuq konfiguratsiya bilan server ko'tarilmasin (aks holda
  // /health yashil bo'lib, auth butunlay buzuq holatda sezilmay production'ga chiqadi).
  if (process.env.NODE_ENV === 'production') {
    console.error(`FATAL: majburiy env yo'q: ${missing.join(', ')} — server to'xtatilmoqda`);
    process.exit(1);
  }
  console.warn(`OGOHLANTIRISH: .env da quyidagilar yo'q: ${missing.join(', ')}`);
}
