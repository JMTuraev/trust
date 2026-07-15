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
  },
  stt: {
    // XOTIRA-ovoz-va-kategoriya.md: asosiy Groq whisper-large-v3, zaxira OpenAI gpt-4o-transcribe
    // Default YONIQ (chat ovozi hold-to-talk uchun, 2026-07-15). O'chirish: env STT_ENABLED=false.
    // Kalitlar parse.js (LLM) uchun ham ishlatiladi — ular o'chirilmaydi.
    enabled: process.env.STT_ENABLED !== 'false',
    groqKey: process.env.GROQ_API_KEY,
    openaiKey: process.env.OPENAI_API_KEY,
  },
  llm: {
    // Parsing (matn -> daromad/xarajat/qarz). STT bilan bir xil kalitlar — qo'shimcha sozlash yo'q.
    groqModel: process.env.GROQ_LLM_MODEL || 'llama-3.3-70b-versatile',
    openaiModel: process.env.OPENAI_LLM_MODEL || 'gpt-4o-mini',
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

export function assertConfig() {
  const missing = [];
  if (!config.supabase.url) missing.push('SUPABASE_URL');
  if (!config.supabase.serviceRoleKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!config.app.jwtSecret) missing.push('APP_JWT_SECRET');
  if (!missing.length) return;
  // Production'da fail-fast: buzuq konfiguratsiya bilan server ko'tarilmasin (aks holda
  // /health yashil bo'lib, auth butunlay buzuq holatda sezilmay production'ga chiqadi).
  if (process.env.NODE_ENV === 'production') {
    console.error(`FATAL: majburiy env yo'q: ${missing.join(', ')} — server to'xtatilmoqda`);
    process.exit(1);
  }
  console.warn(`OGOHLANTIRISH: .env da quyidagilar yo'q: ${missing.join(', ')}`);
}
