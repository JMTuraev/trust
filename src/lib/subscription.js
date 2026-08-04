// Obuna (subscription) — YAGONA haqiqat manbai (server-side).
//
// MODUL OBUNALARI (PO 2026-08-04) — yagona $9 premium o'rniga HAR MODUL alohida:
//   xarajat $5/oy · qarz $8/oy · ijarachi (Ijaradagi uylar) $13/oy · toyxona $24/oy.
//   Chegaralar: ijarachi maks 5 uy, toyxona 1 ta to'yxona (MODULES.max_units) —
//   ko'proq kerak bo'lsa alohida akkaunt (PO 2026-08-04, «har zalga» modeli bekor).
//   Bepul tarif: har modulda 5 ta yozuv (mobil menyu kartalarida "0/5"), keyin paywall.
//   ESKI premium (profiles.premium_until, trust_premium_monthly) — muddati tugaguncha
//   BARCHA modullarga kirish (grandfather). Modul obunalari: module_subs jadvali (020).
//   Limitlar FAQAT serverda (env): FREE_DEBT_ENTRIES, FREE_EXPENSE_ENTRIES (default 5).
//   UI hech narsa hardcode qilmaydi — o'zgartirsak update shart emas.
//
// ESKI TARIF TARIXI (PO 2026-07-28): vaqtga asoslangan 7 kunlik trial olib tashlangan,
//   kvota 3+3 edi; 2026-08-03 jonli test uchun 300 ga ko'tarilgan (endi render.yaml env'da).
//
// Kim to'laydi (PO):
//   - Daftar (partner) EGASI to'laydi. Egasi premium yoki kvota ichida bo'lsa —
//     kontragent o'sha daftarda BEPUL ishlaydi (tasdiqlash, qaytarish, yozuv).
//   - Egasining kvotasi tugagan va premium yo'q — YANGI qarz yozuvini hech kim
//     kirita olmaydi (egasi ham, kontragent ham) — 402 + tushunarli xabar.
//   - Kontragent O'ZI daftar ochsa — o'z kvotasi/premiumi bilan oddiy ega kabi.
//   - Mavjud qarzga repay/settle/tasdiq — HAR DOIM ochiq (pul qaytishi bloklanmasin).
import { supabaseAdmin } from './supabase.js';

// Test hook (node:test): unit tests stub the DB instead of hitting live Supabase.
// Production code path is untouched — db stays supabaseAdmin unless a test swaps it.
let db = supabaseAdmin;
export function __setDbForTests(stub) {
  db = stub || supabaseAdmin;
}

export const PRICE_USD_MONTHLY = 9;
export const PREMIUM_PRODUCT_ID = 'trust_premium_monthly';

// Modul katalogi (PO 2026-08-04) — narx/mahsulot ID'lari FAQAT shu yerda.
// soon:true — modul hali chiqmagan (mobil "Tez orada" ko'rsatadi, sotib bo'lmaydi... hozircha
// verify uni ham qabul qiladi — Play Console'da mahsulot oldindan yaratiladi).
//
// NARX QAROR (PO 2026-08-04): "har zalga $24" g'oyasi BEKOR QILINDI — do'konlar miqdorli
// obunani qo'llab-quvvatlamaydi (docs/team-reports/2026-08-04-iap-per-unit-research.md).
// Yechim: bitta obuna = QAT'IY CHEGARA. Ko'proq kerak bo'lsa foydalanuvchi boshqa raqamga
// alohida ro'yxatdan o'tadi (PO: "bu bizga muammo emas") — ya'ni tiered SKU ham kerak emas.
//   max_units — obuna qoplaydigan obyektlar soni. Majburlash MODUL route'larida
//   (toyxona: halls, ijarachi: rent_houses) — bu yerda faqat yagona manba sifatida turadi.
export const MODULES = {
  xarajat:  { price_usd: 5,  product_id: 'trust_xarajat_monthly' },
  qarz:     { price_usd: 8,  product_id: 'trust_qarz_monthly' },
  // "Ijaradagi uylar" (PO 2026-08-04 nomi) — kalit 'ijarachi' saqlanadi: u 020 dagi
  // check-constraint'da qatnashadi va ko'rinadigan nom l10n'dan keladi.
  ijarachi: { price_usd: 13, product_id: 'trust_ijarachi_monthly', max_units: 5 },
  toyxona:  { price_usd: 24, product_id: 'trust_toyxona_monthly', max_units: 1 },
};
// ≤ WARN_DAYS kun qolganda mobil "To'lov muddati yaqinlashdi" bannerini ko'rsatadi (faqat premium)
export const WARN_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

// Bepul kvotalar — faqat env orqali boshqariladi (UI'da yo'q).
// PO 2026-08-04: kod defaulti 5 (har modulda 5 ta bepul yozuv, mobil "0/5" karta).
// MUHIM: production hali TEST rejimida — render.yaml FREE_*="300" qo'yadi (Play billing
// ulanmaguncha mavjud foydalanuvchilar qulflanmasin); launch'da o'sha ikki env qatori
// olib tashlanadi va shu defaultlar (5) kuchga kiradi.
// MUHIM (2026-08-02 audit): ilgari `parseInt(env || '30') || 30` yozilgan edi — parseInt('0')
// = 0 va u FALSY, shuning uchun FREE_DEBT_ENTRIES=0 qo'yilsa ham jimgina 30 bo'lib qolardi
// (ya'ni "bepul tarifni yopish" sozlamasi umuman ishlamas edi).
function intEnv(name, def) {
  const raw = process.env[name];
  if (raw === undefined || raw === null || String(raw).trim() === '') return def;
  const n = Number.parseInt(String(raw), 10);
  if (!Number.isFinite(n) || n < 0) {
    console.warn(`[config] ${name} noto'g'ri ("${raw}") — default ${def} ishlatildi`);
    return def;
  }
  return n;
}
export const FREE_DEBT_ENTRIES = intEnv('FREE_DEBT_ENTRIES', 5);
export const FREE_EXPENSE_ENTRIES = intEnv('FREE_EXPENSE_ENTRIES', 5);

// Orqaga moslik: eski kod TRIAL_DAYS import qilsa yiqilmasin (endi ma'nosi yo'q)
export const TRIAL_DAYS = 0;

/** profiles qatori -> obuna holati (sof funksiya — testlash oson).
 *  YANGI: status 'premium' | 'free' (vaqt bo'yicha 'expired' YO'Q — gating kvota bilan,
 *  har bir yozuv endpointida alohida tekshiriladi). Maydon nomlari mobil bilan mos. */
export function computeSubscription(profile, now = new Date()) {
  const premiumUntil = profile.premium_until ? new Date(profile.premium_until) : null;
  const isPremium = !!(premiumUntil && premiumUntil > now);
  const daysLeft = isPremium
    ? Math.max(0, Math.ceil((premiumUntil.getTime() - now.getTime()) / DAY_MS))
    : null;
  return {
    status: isPremium ? 'premium' : 'free',
    trial_ends_at: null, // trial modeli olib tashlandi
    premium_until: premiumUntil ? premiumUntil.toISOString() : null,
    active_until: isPremium ? premiumUntil.toISOString() : null,
    days_left: daysLeft,
    // Faqat premium tugashiga ≤3 kun qolganda ogohlantiramiz
    warn_expiring: isPremium && daysLeft != null && daysLeft <= WARN_DAYS,
    // Vaqt bo'yicha bloklash yo'q — yozuv kvotasi endpointlarda tekshiriladi
    can_write: true,
    price: {
      monthly_usd: PRICE_USD_MONTHLY,
      currency: 'USD',
      period: 'month',
      trial_days: 0,
      free_debt_entries: FREE_DEBT_ENTRIES,
      free_expense_entries: FREE_EXPENSE_ENTRIES,
      product_id: PREMIUM_PRODUCT_ID,
    },
  };
}

/** Daftar EGASI bo'yicha qarz yozuvlari soni.
 *  MUHIM (2026-08-02 audit): ilgari faqat `created_by = userId` sanalardi. Kontragent
 *  o'sha daftarga yozgan qarzlar HECH KIMGA sanalmasdi (egasiga — created_by boshqa,
 *  yozuvchiga — u ega emas). Ikki foydalanuvchi bir-birining daftariga yozib, ikkalasi
 *  ham cheksiz bepul ishlata olardi. Endi kvota daftar EGALIGI bo'yicha hisoblanadi —
 *  bu "daftar egasi to'laydi" qoidasiga ham aynan mos. */
async function countOwnerDebts(ownerId) {
  const { data: partners } = await db
    .from('partners').select('id').eq('owner_id', ownerId).limit(2000);
  const ids = (partners || []).map((p) => p.id);
  if (!ids.length) return 0;
  // `operations` ham SANALADI (2026-08-02 audit): mobil "Yangi operatsiya" varag'i
  // aynan shu jadvalga yozadi va u hamkor balansiga qo'shiladi. Ilgari kvota faqat
  // `debts` bo'yicha edi, ya'ni bepul foydalanuvchi cheksiz oldi-berdi kiritaverardi
  // va paywall hech qachon ko'rinmasdi.
  const [d, o] = await Promise.all([
    db
      .from('debts')
      .select('id', { count: 'exact', head: true })
      .in('partner_id', ids)
      .eq('kind', 'debt')
      .not('status', 'in', '(cancelled,rejected)'),
    db
      .from('operations')
      .select('id', { count: 'exact', head: true })
      .eq('owner_id', ownerId)
      .neq('status', 'cancelled'),
  ]);
  return (d.count || 0) + (o.count || 0);
}

/** Foydalanuvchining ishlatilgan kvotasi (server hisobi). */
export async function countUsage(userId) {
  const [debts_used, e] = await Promise.all([
    countOwnerDebts(userId),
    db
      .from('expenses')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId),
  ]);
  return { debts_used, expenses_used: e.count || 0 };
}

/** Foydalanuvchi obunasi: profiles'dan o'qib hisoblaydi. null = profil topilmadi. */
export async function getSubscription(userId) {
  const { data, error } = await db
    .from('profiles')
    .select('id, created_at, premium_until, deleted_at')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  return { profile: data, sub: computeSubscription(data) };
}

/** userId premiummi? (tez, bitta select) */
async function isPremiumUser(userId) {
  const { data } = await db
    .from('profiles').select('premium_until').eq('id', userId).maybeSingle();
  return !!(data?.premium_until && new Date(data.premium_until) > new Date());
}

// ============ Modul obunalari (PO 2026-08-04, 020 migratsiya) ============

/** Migratsiya hali qo'llanmaganmi? (jadval topilmadi xatosi)
 *  TOR TUTILGAN (review 2026-08-04): ilgari HAR QANDAY "does not exist"/"schema cache"
 *  xabari mos kelardi — jumladan USTUN topilmadi (42703 / PGRST204). Bunday doimiy xato
 *  kvota gate'ini HAMMA uchun cheksiz ochiq qoldirar va faqat bitta log qatori bilan
 *  bildirilardi (jimgina daromad yo'qolishi). Endi: jadval kodlari YOKI xabar aynan shu
 *  jadval nomini o'z ichiga olishi shart. */
function isMissingTableError(error, table) {
  const code = error?.code || '';
  // 42P01 = undefined_table (Postgres), PGRST205 = jadval schema cache'da yo'q (PostgREST)
  if (code === '42P01' || code === 'PGRST205') return true;
  const msg = error?.message || '';
  return !!table && msg.includes(table) && /does not exist|schema cache/i.test(msg);
}

// 020 migratsiya qo'llanganmi — oxirgi so'rov natijasi (null = hali noma'lum).
// XAVFSIZLIK KLAPANI: jadval yo'q bo'lsa obunani SOTIB BO'LMAYDI (grantModule 409 beradi),
// demak kvota ham majburlanmasligi kerak — aks holda limit tushirilgan (FREE_*=5) va
// migratsiya qo'llanmagan holatda foydalanuvchilar TO'LASH IMKONIYATISIZ qulflanib qolardi.
// Shuning uchun kvota middleware'lari `moduleSubsReady === false` bo'lsa OCHIQ o'tkazadi.
let moduleSubsReady = null;
let moduleSubsWarnedAt = 0;

/** Foydalanuvchining module_subs qatorlari. 020 hali qo'llanmagan bo'lsa — bo'sh ro'yxat
 *  (notify() debts.js:93 dagi kabi bardoshlilik: yangi ustun/jadval deploy'ni yiqitmasin).
 *  BOSHQA xatolar tashlanadi — modul obunasini sotib olgan foydalanuvchi tranzit DB
 *  xatosi tufayli jimgina 402 ga urilmasin (aniq 500 yaxshiroq). */
async function getModuleSubRows(userId) {
  const { data, error } = await db
    .from('module_subs')
    .select('module, active_until')
    .eq('user_id', userId);
  if (error) {
    if (isMissingTableError(error, 'module_subs')) {
      // Klapan OCHIQ turgan har daqiqada bitta ERROR — Render loglarida ko'rinsin
      // (bir marta warn qilib jim qolish = jimgina daromad yo'qolishi).
      const now = Date.now();
      if (now - moduleSubsWarnedAt > 60_000) {
        moduleSubsWarnedAt = now;
        console.error('[obuna] module_subs jadvali YO\'Q (020 qo\'llanmagan) — kvota MAJBURLANMAYAPTI');
      }
      moduleSubsReady = false;
      return [];
    }
    throw new Error(error.message);
  }
  moduleSubsReady = true;
  return data || [];
}

/** Modul obunalari sotuvga tayyormi (020 qo'llanganmi)? Kvota shu bilan gate qilinadi.
 *  Hali tekshirilmagan bo'lsa — bitta yengil so'rov bilan aniqlanadi. */
async function moduleSubsAvailable(userId) {
  if (moduleSubsReady === null) await getModuleSubRows(userId);
  return moduleSubsReady !== false;
}

/** Kvotani MAJBURLASH mumkinmi? false = `module_subs` (020) yo'q, ya'ni obunani sotib
 *  bo'lmaydi — bunday holatda hech kimni bloklamaymiz (xavfsizlik klapani).
 *  Modul route'lari (toyxona, ijara) O'Z kvota middleware'ida shuni chaqiradi —
 *  aks holda 022/021 avval qo'llanib 020 keyin qolsa foydalanuvchilar TO'LASH
 *  IMKONIYATISIZ qulflanib qolardi (review 2026-08-04). */
export async function isQuotaEnforceable(userId) {
  return moduleSubsAvailable(userId);
}

/** Faqat testlar uchun: keshlangan holatni tozalash. */
export function __resetModuleSubsReady() {
  moduleSubsReady = null;
}

/** Xarid tekshiruvida ishlatiladigan product_id — YAGONA joy.
 *  XAVFSIZLIK: klient product_id yubormaydi, faqat modul kalitini beradi; SKU shu
 *  yerdan olinadi. Ya'ni arzon modul cheki bilan qimmatini ochib bo'lmaydi (chek
 *  aynan shu product_id bo'yicha tekshiriladi).
 *  '' / null  -> eski $9 premium (orqaga moslik: `module` yubormaydigan mobil versiyalar)
 *  noma'lum   -> null (chaqiruvchi 400 qaytaradi) */
export function productIdForModule(module) {
  if (!module) return PREMIUM_PRODUCT_ID;
  return MODULES[module]?.product_id ?? null;
}

/** userId uchun `module` faolmi? Legacy premium (profiles.premium_until kelajakda) —
 *  grandfather: BARCHA modullar uchun faol hisoblanadi. */
export async function isModuleActive(userId, module) {
  if (await isPremiumUser(userId)) return true;
  const rows = await getModuleSubRows(userId);
  const row = rows.find((r) => r.module === module);
  return !!(row?.active_until && new Date(row.active_until) > new Date());
}

/** To'yxona bepul kvotasi — routes/toyxona.js dagi majburlash bilan BIR XIL env
 *  (aks holda mobil "3/5" ko'rsatib, server 5-chida to'sib qo'yardi yoki aksincha). */
export const FREE_TOYXONA_BOOKINGS = intEnv('FREE_TOYXONA_BOOKINGS', 5);

/** Ijaradagi uylar moduli bepul kvotasi — routes/ijara.js bilan BIR XIL env. */
export const FREE_IJARA_CHARGES = intEnv('FREE_IJARA_CHARGES', 5);

/** Ijara modulida ishlatilgan kvota: bekor qilinmagan hisob-kitob yozuvlari.
 *  022 migratsiya hali qo'llanmagan bo'lsa 0 (module_subs bilan bir xil bardoshlilik). */
async function countIjaraCharges(userId) {
  const { count, error } = await db
    .from('rent_charges')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .neq('status', 'bekor');
  if (error) {
    if (isMissingTableError(error, 'rent_charges')) return 0;
    throw new Error(error.message);
  }
  return count || 0;
}

/** To'yxona modulida ishlatilgan kvota: bekor qilinmagan bronlar soni (To'yxona
 *  sessiyasi bilan kelishilgan qoida — bekor qilingan bron kvotani YEMAYDI).
 *  021 migratsiya hali qo'llanmagan bo'lsa 0 (module_subs bilan bir xil bardoshlilik). */
async function countBookings(userId) {
  const { count, error } = await db
    .from('bookings')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .neq('status', 'bekor');
  if (error) {
    if (isMissingTableError(error, 'bookings')) return 0;
    throw new Error(error.message);
  }
  return count || 0;
}

/** Barcha modullar holati bitta chaqiruvda (GET /api/subs/status — MOBIL KONTRAKT).
 *  Har element: { module, active, active_until, soon, price_usd, product_id, used, free_limit }.
 *  used: xarajat -> expenses soni, qarz -> daftar EGASI bo'yicha debts+operations,
 *  toyxona -> bekor qilinmagan bronlar, ijarachi -> bekor qilinmagan hisob-kitoblar.
 *  (Ikkala modul ham 2026-08-04 da ishga tushdi — «kelajak modul» holati qolmadi.) */
export async function getModulesStatus(userId, now = new Date()) {
  const [prof, rows, usage, bookings, ijara] = await Promise.all([
    db.from('profiles').select('premium_until').eq('id', userId).maybeSingle(),
    getModuleSubRows(userId),
    countUsage(userId),
    countBookings(userId),
    countIjaraCharges(userId),
  ]);
  const legacyUntil = prof?.data?.premium_until ? new Date(prof.data.premium_until) : null;
  const legacyActive = !!(legacyUntil && legacyUntil > now);
  const byModule = new Map(rows.map((r) => [r.module, r]));

  return Object.entries(MODULES).map(([module, cfg]) => {
    const own = byModule.get(module);
    const ownUntil = own?.active_until ? new Date(own.active_until) : null;
    const ownActive = !!(ownUntil && ownUntil > now);
    const active = legacyActive || ownActive;
    // active_until — ko'rsatish uchun eng uzoq muddat (legacy va modul obunasidan kattasi)
    let activeUntil = null;
    if (active) {
      const ms = Math.max(legacyActive ? legacyUntil.getTime() : 0, ownActive ? ownUntil.getTime() : 0);
      activeUntil = new Date(ms).toISOString();
    }
    const used = module === 'xarajat' ? usage.expenses_used
      : module === 'qarz' ? usage.debts_used
      : module === 'toyxona' ? bookings
      : module === 'ijarachi' ? ijara
      : 0;
    // MUHIM: ko'rsatiladigan limit SERVER MAJBURLAYOTGAN limit bilan bir xil bo'lsin.
    const freeLimit = module === 'xarajat' ? FREE_EXPENSE_ENTRIES
      : module === 'qarz' ? FREE_DEBT_ENTRIES
      : module === 'toyxona' ? FREE_TOYXONA_BOOKINGS
      : module === 'ijarachi' ? FREE_IJARA_CHARGES
      : 0;
    return {
      module,
      active,
      active_until: activeUntil,
      soon: !!cfg.soon,
      price_usd: cfg.price_usd,
      product_id: cfg.product_id,
      used,
      free_limit: freeLimit,
    };
  });
}

// ============ Express middleware'lar ============

/** ESKI vaqt-gate endi PASS-THROUGH: faqat o'chirilgan profil bloklanadi.
 *  (Partner yaratish, chat, AI va h.k. — bepul; pullik joylar quyidagi
 *  kvota-middleware'lar bilan ANIQ nuqtalarda gate qilinadi.) */
export function requireActiveSub(req, res, next) {
  if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') return next();
  getSubscription(req.user.id)
    .then((r) => {
      if (!r) return res.status(403).json({ success: false, error: 'Profil topilmadi' });
      if (r.profile.deleted_at) {
        return res
          .status(403)
          .json({ success: false, error: "Profil o'chirilgan — qayta kirsangiz tiklanadi" });
      }
      next();
    })
    .catch(next);
}
export const requireWriteAccess = requireActiveSub;

/** Shu so'rovda YANA `n` ta xarajat yozuvi sig'adimi?
 *  null = sig'adi (yoki gate qo'llanmaydi); aks holda 402 javob tanasi qaytadi.
 *  MUHIM (review 2026-08-04 #12): `/confirm` bitta so'rovda 5 tagacha amal yozadi —
 *  faqat "1 ta joy bormi" deb tekshirilsa, 4/5 da turgan user 9 tagacha chiqib ketardi
 *  ("5 bepul" va'dasi buzilardi). Shuning uchun kvota BUTUN TO'PLAM bo'yicha sanaladi. */
export async function expenseQuotaBlock(userId, n = 1) {
  if (n <= 0) return null;
  if (await isModuleActive(userId, 'xarajat')) return null;
  // 020 qo'llanmagan -> obuna sotib bo'lmaydi -> kvota majburlanmaydi (xavfsizlik klapani)
  if (!(await moduleSubsAvailable(userId))) return null;
  const { expenses_used } = await countUsage(userId);
  if (expenses_used + n <= FREE_EXPENSE_ENTRIES) return null;
  return {
    success: false,
    code: 'SUB_EXPIRED',
    // `module` — mobil aynan shu modul paywall'ini ochadi (2026-08-04 kontrakt)
    module: 'xarajat',
    error: `Bepul ${FREE_EXPENSE_ENTRIES} ta xarajat yozuvi ishlatildi — davom etish uchun obuna kerak ($${MODULES.xarajat.price_usd}/oy)`,
  };
}

/** XARAJAT yozuvi kvotasi (bitta yozuv): 'xarajat' moduli obunasi (yoki legacy premium)
 *  YOKI expenses soni < FREE_EXPENSE_ENTRIES. To'plamli yo'l uchun expenseQuotaBlock(n). */
export function requireExpenseQuota(req, res, next) {
  expenseQuotaBlock(req.user.id, 1)
    .then((block) => (block ? res.status(402).json(block) : next()))
    .catch(next);
}

/** YANGI OPERATSIYA kvotasi — POST /api/operations uchun (partner_id BODY'da).
 *  MUHIM (2026-08-02 audit): bu endpoint mobil ilovaning asosiy "yangi yozuv" yo'li,
 *  lekin unda kvota tekshiruvi UMUMAN yo'q edi — paywall hech qachon ishlamasdi. */
export function requireNewOpQuota(req, res, next) {
  (async () => {
    const partnerId = req.body?.partner_id;
    if (!partnerId) return next(); // handler o'zi 400 beradi
    const { data: p } = await db
      .from('partners').select('owner_id').eq('id', partnerId).maybeSingle();
    if (!p) return next();
    if (await isModuleActive(p.owner_id, 'qarz')) return next();
    // 020 qo'llanmagan -> obuna sotib bo'lmaydi -> kvota majburlanmaydi (xavfsizlik klapani)
    if (!(await moduleSubsAvailable(p.owner_id))) return next();
    const { debts_used } = await countUsage(p.owner_id);
    if (debts_used < FREE_DEBT_ENTRIES) return next();
    const isOwner = p.owner_id === req.user.id;
    return res.status(402).json({
      success: false,
      code: isOwner ? 'SUB_EXPIRED' : 'OWNER_SUB_EXPIRED',
      module: 'qarz',
      error: isOwner
        ? `Bepul ${FREE_DEBT_ENTRIES} ta yozuv ishlatildi — davom etish uchun obuna kerak ($${MODULES.qarz.price_usd}/oy)`
        : "Daftar egasining obunasi faol emas — bu daftarga hozircha yangi yozuv kiritib bo'lmaydi",
    });
  })().catch(next);
}

/** YANGI QARZ yozuvi kvotasi — daftar EGASI bo'yicha (PO qoidasi).
 *  POST /api/debts/:partnerId dan OLDIN turadi. */
export function requireNewDebtQuota(req, res, next) {
  (async () => {
    const { data: p } = await db
      .from('partners').select('owner_id').eq('id', req.params.partnerId).maybeSingle();
    // Hamkor topilmasa handler o'zi 404 beradi — bu yerda bloklamaymiz
    if (!p) return next();
    if (await isModuleActive(p.owner_id, 'qarz')) return next();
    // 020 qo'llanmagan -> obuna sotib bo'lmaydi -> kvota majburlanmaydi (xavfsizlik klapani)
    if (!(await moduleSubsAvailable(p.owner_id))) return next();
    const { debts_used } = await countUsage(p.owner_id);
    if (debts_used < FREE_DEBT_ENTRIES) return next();
    const isOwner = p.owner_id === req.user.id;
    // MUHIM (2026-08-02 audit): kod AJRATILDI. Ilgari ikkala holat ham 'SUB_EXPIRED'
    // qaytarardi, mobil esa uni "MENING obunam tugadi" deb qabul qilib, butun ilovada
    // qizil banner ko'rsatardi — holbuki kvota tugagani QARSHI TOMONNIKI edi.
    return res.status(402).json({
      success: false,
      code: isOwner ? 'SUB_EXPIRED' : 'OWNER_SUB_EXPIRED',
      module: 'qarz',
      error: isOwner
        ? `Bepul ${FREE_DEBT_ENTRIES} ta qarz yozuvi ishlatildi — davom etish uchun obuna kerak ($${MODULES.qarz.price_usd}/oy)`
        : "Daftar egasining obunasi faol emas — bu daftarga hozircha yangi yozuv kiritib bo'lmaydi",
    });
  })().catch(next);
}
