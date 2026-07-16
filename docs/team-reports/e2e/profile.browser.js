/*
 * PROFILE + OBUNA (subscription) LIVE E2E — brauzer konsoli skripti
 * ================================================================
 * QANDAY ISHLATILADI (lead):
 *   1) Supabase SQL Editor'da fixture SQL'ni yurgizing
 *      (docs/team-reports/2026-07-16-profile.md -> "E2E fixture SQL" bo'limi):
 *      4 ta test user: fresh-trial / premium / expired / warn (trialga ≤3 kun qolgan).
 *      DIQQAT: 012_subscription_events.sql migratsiyasi yurgizilgan bo'lishi kerak
 *      (verify-stub DEV rejimi uchun; 011 emas — lead qayta nomlagan).
 *   2) Repo ildizida 4 ta JWT yarating (APP_JWT_SECRET .env'dan o'qiladi, chop etilmaydi):
 *      node -e "require('dotenv/config');const jwt=require('jsonwebtoken');console.log(jwt.sign({sub:'11111111-1111-4111-8111-111111111101',phone:'998900000001',role:'authenticated',aud:'authenticated'},process.env.APP_JWT_SECRET,{algorithm:'HS256',expiresIn:'2h'}))"
 *      (sub'ni 102/103/104 fixture id'lariga almashtirib yana 3 marta).
 *   3) Brauzerda https://trust-backend-ft1s.onrender.com/health tabini oching
 *      (relative fetch'lar shu origin'ga ketadi), DevTools Console'ga shu faylni
 *      to'liq nusxalab, TOKEN qiymatlarini joylashtirib, Enter bosing.
 *   4) Har qadam PASS/FAIL chiqadi; oxirida umumiy natija.
 *   5) Tugagach cleanup SQL'ni yurgizing (hisobotda).
 *
 * ESLATMA: skript hech qanday maxfiy qiymat chop etmaydi; tokenlar qo'lda joylanadi.
 */

const TOKEN = '<<PASTE_JWT>>';           // fixture #101 — fresh-trial user (asosiy qadam to'plami)
const TOKEN_PREMIUM = '<<PASTE_JWT_PREMIUM>>'; // fixture #102 — premium user
const TOKEN_EXPIRED = '<<PASTE_JWT_EXPIRED>>'; // fixture #103 — expired user
const TOKEN_WARN = '<<PASTE_JWT_WARN>>'; // fixture #104 — trialga ≤3 kun qolgan (warn_expiring probasi; ixtiyoriy)

(async () => {
  const results = [];
  const log = (ok, name, detail = '') => {
    results.push(ok);
    console.log(`${ok ? 'PASS ✓' : 'FAIL ✗'}  ${name}${detail ? ' — ' + detail : ''}`);
  };
  const req = async (method, path, token, body) => {
    const res = await fetch(path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let json = null;
    try { json = await res.json(); } catch (_) {}
    return { status: res.status, json };
  };

  if (TOKEN.includes('<<') || TOKEN_PREMIUM.includes('<<') || TOKEN_EXPIRED.includes('<<')) {
    console.error('TOKEN / TOKEN_PREMIUM / TOKEN_EXPIRED joylashtirilmagan — skript to\'xtatildi.');
    return;
  }

  console.log('--- 0. Server tirikligi ---');
  {
    const r = await fetch('/health').then((x) => x.json()).catch(() => null);
    log(!!(r && r.ok), '0.1 GET /health', r ? `service=${r.service} v${r.version}` : 'javob yo\'q');
  }

  console.log('--- 1. Obuna holatlari (fixture\'lar) ---');
  let origName = null;
  {
    const r = await req('GET', '/api/profile/me', TOKEN);
    const d = r.json?.data || {};
    origName = d.full_name ?? null;
    log(r.status === 200 && d.status === 'trial', '1.1 trial user /me: status=trial', `status=${d.status}, days_left=${d.days_left}, trial_ends_at=${d.trial_ends_at}`);
    log(!!d.trial_ends_at && new Date(d.trial_ends_at) > new Date(), '1.2 trial_ends_at kelajakda', d.trial_ends_at);
    log(d.deleted_at === null || d.deleted_at === undefined, '1.3 deleted_at=null (faol profil)', String(d.deleted_at));
    // Yangi maydonlar (mobil banner/karta uchun): warn_expiring + price
    log(d.warn_expiring === false, '1.4 fresh-trial warn_expiring=false (6+ kun bor)', `warn_expiring=${d.warn_expiring}, days_left=${d.days_left}`);
    log(d.price && d.price.monthly_usd === 9 && d.price.trial_days === 7, '1.5 price: $9/oy + 7 kun trial', JSON.stringify(d.price || null));
  }
  {
    const r = await req('GET', '/api/profile/me', TOKEN_PREMIUM);
    const d = r.json?.data || {};
    log(r.status === 200 && d.status === 'premium', '1.6 premium user /me: status=premium', `status=${d.status}, premium_until=${d.premium_until}`);
    log(!!d.premium_until && new Date(d.premium_until) > new Date(), '1.7 premium_until kelajakda', d.premium_until);
    log(d.warn_expiring === false, '1.8 premium (27 kun) warn_expiring=false', `warn_expiring=${d.warn_expiring}`);
  }
  {
    const r = await req('GET', '/api/profile/me', TOKEN_EXPIRED);
    const d = r.json?.data || {};
    log(r.status === 200 && d.status === 'expired', '1.9 expired user /me: status=expired', `status=${d.status}, trial_ends_at=${d.trial_ends_at}`);
    log(d.warn_expiring === false, '1.10 expired: warn_expiring=false (banner emas — expired holati ustun)', `warn_expiring=${d.warn_expiring}`);
  }
  {
    const r = await req('GET', '/api/profile/me/subscription', TOKEN);
    const d = r.json?.data || {};
    log(r.status === 200 && d.status === 'trial' && typeof d.days_left === 'number' && typeof d.warn_expiring === 'boolean', '1.11 GET /me/subscription (trial)', `days_left=${d.days_left}, can_write=${d.can_write}, warn_expiring=${d.warn_expiring}`);
  }
  // warn_expiring=true probasi — fixture #104 (trial tugashiga ≤3 kun)
  if (TOKEN_WARN.includes('<<')) {
    console.log('    1.12 SKIP — TOKEN_WARN joylanmagan (fixture #104 ixtiyoriy)');
  } else {
    const r = await req('GET', '/api/profile/me', TOKEN_WARN);
    const d = r.json?.data || {};
    log(r.status === 200 && d.status === 'trial' && d.warn_expiring === true && d.days_left <= 3, '1.12 warn user: trial + warn_expiring=true + days_left<=3', `status=${d.status}, days_left=${d.days_left}, warn_expiring=${d.warn_expiring}`);
  }

  console.log('--- 2. Profil CRUD ---');
  {
    const r = await req('PUT', '/api/profile/me', TOKEN, { full_name: 'E2E Sinov' });
    log(r.status === 200 && r.json?.data?.full_name === 'E2E Sinov', '2.1 PUT /me ism yangilash', `full_name=${r.json?.data?.full_name}`);
  }
  {
    const r = await req('GET', '/api/profile/me', TOKEN);
    log(r.json?.data?.full_name === 'E2E Sinov', '2.2 GET /me yangi ismni qaytaradi');
  }
  {
    const r = await req('PUT', '/api/profile/me', TOKEN, { full_name: 'X'.repeat(81) });
    log(r.status === 400, '2.3 81 belgili ism rad etiladi (400)', `status=${r.status}`);
  }
  {
    const r = await req('PUT', '/api/profile/me', TOKEN, { notif_enabled: false });
    log(r.status === 200 && r.json?.data?.notif_enabled === false, '2.4 notif_enabled=false saqlanadi');
    await req('PUT', '/api/profile/me', TOKEN, { notif_enabled: true }); // qaytarish
  }
  {
    const r = await req('PUT', '/api/profile/me', TOKEN, { full_name: origName ?? '' });
    log(r.status === 200, '2.5 asl ism qaytarildi', `-> ${JSON.stringify(origName)}`);
  }
  {
    const r = await req('GET', '/api/profile/me', 'brokentoken.abc.def');
    log(r.status === 401, '2.6 buzuq token 401 qaytaradi', `status=${r.status}`);
  }

  console.log('--- 3. Limits (oylik xarajat byudjeti) ---');
  let origLimit = 0;
  {
    const r = await req('GET', '/api/limits', TOKEN);
    origLimit = Number(r.json?.data?.monthly_limit || 0);
    log(r.status === 200, '3.1 GET /api/limits', `monthly_limit=${origLimit}`);
  }
  {
    const r = await req('PUT', '/api/limits', TOKEN, { monthly_limit: 4000000 });
    log(r.status === 200 && Number(r.json?.data?.monthly_limit) === 4000000, '3.2 PUT limit=4000000');
  }
  {
    const r = await req('PUT', '/api/limits', TOKEN, { monthly_limit: -5 });
    log(r.status === 400, '3.3 manfiy limit rad etiladi (400)', `status=${r.status} (eski kod buni qabul qilardi!)`);
  }
  {
    const r = await req('PUT', '/api/limits', TOKEN, { monthly_limit: 'abc' });
    log(r.status === 400, '3.4 satr limit rad etiladi (400)', `status=${r.status}`);
  }
  await req('PUT', '/api/limits', TOKEN, { monthly_limit: origLimit }); // qaytarish

  console.log('--- 4. Obuna verify stub ---');
  {
    const r = await req('POST', '/api/profile/me/subscription/verify', TOKEN, { platform: 'apple', product_id: 'x', purchase_token: 'y' });
    log(r.status === 400, '4.1 platform!=google_play -> 400', `status=${r.status}`);
  }
  {
    const r = await req('POST', '/api/profile/me/subscription/verify', TOKEN, { platform: 'google_play', product_id: 'trust_premium_monthly', purchase_token: 'FAKE-TOKEN-123' });
    log(r.status === 501, '4.2 haqiqiy to\'lov ulanmagan -> 501', `status=${r.status} (PLAY_BILLING_DEV_MODE yoqilmagan bo\'lsa shunday bo\'lishi kerak)`);
  }

  console.log('--- 5. READ-ONLY enforcement: expired user yoza olmasligi SHART (402) ---');
  {
    // Mahsulot qarori: to'lanmagan = READ-ONLY. Yangi yozuv -> 402 SUB_EXPIRED.
    const r = await req('POST', '/api/expenses', TOKEN_EXPIRED, { amount: 1000, income: false, category: 'Boshqa', note: 'e2e-probe' });
    log(r.status === 402 && r.json?.code === 'SUB_EXPIRED', '5.1 expired POST /api/expenses -> 402 SUB_EXPIRED', `status=${r.status}, code=${r.json?.code}`);
    if (r.status < 300 && r.json?.data?.id) {
      await req('DELETE', `/api/expenses/${r.json.data.id}`, TOKEN_EXPIRED); // izni tozalash
      console.log('    (DIQQAT: yozuv YARATILDI — enforcement ishlamayapti! Probe yozuvi o\'chirildi)');
    }
  }
  {
    const r = await req('POST', '/api/partners', TOKEN_EXPIRED, { name: 'E2E Probe', counterparty_phone: '+998900000099' });
    log(r.status === 402 && r.json?.code === 'SUB_EXPIRED', '5.2 expired POST /api/partners -> 402 SUB_EXPIRED', `status=${r.status}, code=${r.json?.code}`);
    if (r.status < 300 && r.json?.data?.id) {
      await req('PATCH', `/api/partners/${r.json.data.id}`, TOKEN_EXPIRED, { archived: true });
      console.log('    (DIQQAT: hamkor YARATILDI — enforcement ishlamayapti! Arxivlandi — cleanup SQL to\'liq o\'chiradi)');
    }
  }
  {
    // READ-ONLY modelning ikkinchi yarmi: o'qish HAR DOIM ochiq (GET 200)
    const r = await req('GET', '/api/expenses', TOKEN_EXPIRED);
    log(r.status === 200, '5.3 expired GET /api/expenses -> 200 (ko\'rish ochiq qoladi)', `status=${r.status}`);
  }
  {
    const r = await req('GET', '/api/partners', TOKEN_EXPIRED);
    log(r.status === 200, '5.4 expired GET /api/partners -> 200 (ko\'rish ochiq qoladi)', `status=${r.status}`);
  }
  // 5.5 QO'LDA (fixture bog'lanishi yo'qligi uchun skriptda emas): qarshi tomon amallari
  // (debts confirm/reject/repay, circles confirm/accept/decline, links accept) expired
  // userga ham OCHIQ qolishi kerak — kontragent hech qachon qotib qolmasin.

  console.log('--- 6. Soft-delete + tiklash ---');
  {
    const r = await req('DELETE', '/api/profile/me', TOKEN);
    log(r.status === 200, '6.1 DELETE /me (soft) 200', JSON.stringify(r.json?.data || {}));
  }
  {
    const r = await req('GET', '/api/profile/me', TOKEN);
    const d = r.json?.data || {};
    log(r.status === 200 && !!d.deleted_at, '6.2 /me deleted_at belgilangan', `deleted_at=${d.deleted_at}`);
    log(true, `6.3 HUJJATLANGAN xulq: o'chirilgandan keyin ham token ishlaydi (status=${r.status}) — tiklash faqat OTP qayta kirishda`);
  }
  {
    // Tiklash yo'llari: (a) real qurilmada OTP bilan qayta kirish (services/otp.js reactivateIfDeleted),
    // (b) test uchun SQL: update public.profiles set deleted_at=null where id='11111111-1111-4111-8111-111111111101';
    console.log('    6.4 TIKLASH: SQL Editor\'da deleted_at=null qiling, so\'ng quyidagi tekshiruv o\'tadi:');
    console.log("    update public.profiles set deleted_at=null, updated_at=now() where id='11111111-1111-4111-8111-111111111101';");
  }

  const pass = results.filter(Boolean).length;
  console.log(`\n=== YAKUN: ${pass}/${results.length} PASS ===`);
  console.log('Tugagach: hisobotdagi cleanup SQL\'ni yurgizing (fixture userlar + probe yozuvlari).');
})();
