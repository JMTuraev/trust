import 'dotenv/config';

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  supabase: {
    url: process.env.SUPABASE_URL,
    anonKey: process.env.SUPABASE_ANON_KEY,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    jwtSecret: process.env.SUPABASE_JWT_SECRET,
  },
  devsms: {
    token: process.env.DEVSMS_TOKEN,
    baseUrl: 'https://devsms.uz/api',
    serviceName: process.env.SMS_SERVICE_NAME || 'AllClubs',
    templateType: parseInt(process.env.SMS_TEMPLATE_TYPE || '4', 10),
  },
  otp: {
    ttlSeconds: parseInt(process.env.OTP_TTL_SECONDS || '300', 10),
    maxAttempts: parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10),
  },
};

export function assertConfig() {
  const missing = [];
  if (!config.supabase.url) missing.push('SUPABASE_URL');
  if (!config.supabase.serviceRoleKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!config.supabase.jwtSecret) missing.push('SUPABASE_JWT_SECRET');
  if (missing.length) {
    console.warn(`OGOHLANTIRISH: .env da quyidagilar yo'q: ${missing.join(', ')}`);
  }
}
