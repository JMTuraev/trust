// TO'YXONA moduli — to'yxona / banket zali boshqaruvi (021 migratsiya).
//
// Mahsulot modeli: egasi SANA + SLOT sotadi. Kunda 3 slot — 'nahor' (nahorgi osh),
// 'tushlik', 'kechki'. Pul: mehmon soni × bir mehmon narxi (food) + qo'shimcha
// xizmatlar (booking_items: musiqa, fotograf, tort, bezak, salyut) − to'lovlar
// (booking_payments: 'avans' sanani ushlaydi, 'yakuniy' to'y kuni).
//
// KO'P TO'YXONA — ASOSIY HOLAT: `halls` qatori = bitta TO'YXONA (bandlanadigan
// obyekt), har biri ALOHIDA HISOB yuritadi. GET /bookings va GET /summary
// ixtiyoriy ?hall_id= filtri bilan aynan bitta to'yxona hisobini beradi;
// filtrsiz — barcha to'yxonalar birgalikda.
//
// NARX TOIFALARI (hall_menus): ega "Oddiy — 150 000", "Lyuks — 200 000" kabi
// toifalarni BIR MARTA belgilaydi, band qilishda bittasini tanlaydi.
// SNAPSHOT QOIDASI: bandning price_per_guest va menu_title — band qilingan
// paytdagi NUSXA. Narx ro'yxati keyin o'zgarsa ham o'tgan bandlar puli
// O'ZGARMAYDI (aks holda avans/qoldiq hisobi orqaga qarab buziladi).
//
// ENG KATTA XATAR — IKKI MARTA BAND QILISH. Ikki qatlamli himoya:
//   1) dastur oldindan tekshiradi (SLOT_TAKEN — chiroyli, mijoz nomi bilan xabar),
//   2) DB'da partial unique indeks (021, bookings_slot_uidx) — parallel ikki
//      so'rov "read-then-write" tekshiruvini chetlab o'tsa ham insert YIQILADI.
//   Shuning uchun 23505 (unique violation) ham SLOT_TAKEN ga aylantiriladi.
//
// Egalik: har so'rov req.user.id bo'yicha filtrlanadi; bola yozuvlar (items /
// payments) ota-band EGASI tekshirilgandan keyingina yoziladi/o'chiriladi.
// Pul: FAQAT UZS, butun son (tiyin yo'q), cheklov 1e13.
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import {
  isModuleActive, MODULES, FREE_TOYXONA_BOOKINGS, isQuotaEnforceable,
} from '../lib/subscription.js';

const router = Router();
router.use(requireAuth);

// ============================ Doimiylar ============================

export const SLOTS = ['nahor', 'tushlik', 'kechki'];
export const STATUSES = ['band', 'tasdiq', 'yakun', 'bekor'];
const KINDS = ['avans', 'yakuniy'];

const MAX_MONEY = 1e13;      // UZS butun son shifti (expenses.js bilan bir xil)
const MAX_GUESTS = 100_000;  // eng katta to'yxona ham bunchaga yaqinlashmaydi
const MAX_QTY = 10_000;
const MAX_RANGE_DAYS = 366;  // bitta so'rovda ko'pi bilan bir yil
const MAX_BOOKINGS = 500;    // RO'YXAT javobi hajmi chegarasi (expenses.js naqshi)
// YAKUN uchun chegara yuqoriroq: /summary faqat 4 ta kichik ustunni tortadi va
// natijasi bitta son — ro'yxat kabi javob hajmi muammosi yo'q. 500 da qolsa
// ko'p to'yxonali ega YIL oralig'ini so'raganda (3 slot × 365 × N zal) daromad
// JIMGINA kam ko'rsatilardi, bu esa pul xatosi.
const MAX_SUMMARY_BOOKINGS = 2000;
const MAX_HALLS = 100;            // bitta egadagi to'yxonalar
const MAX_MENUS_PER_HALL = 50;    // bitta to'yxonadagi narx toifalari
const MAX_MENUS_TOTAL = MAX_HALLS * MAX_MENUS_PER_HALL;   // GET /halls embed chegarasi
// .in(...) bo'laklari — URL UZUNLIGI cheklovi uchun. 200 ta uuid ≈ 7.5 KB so'rov
// satri berardi, bu ko'p proksi/serverlarning 8 KB sarlavha chegarasiga juda yaqin
// (414 xavfi). 100 ta ≈ 3.7 KB — xavfsiz zaxira bilan.
const CHILD_CHUNK = 100;

// Toshkent UTC+5 — default "shu oy" oralig'i EGA vaqtida hisoblanadi, aks holda
// server UTC'da oyning 1-sanasi mahalliy 05:00 gacha "o'tgan oy" bo'lib ko'rinardi.
const TZ_OFFSET_MS = 5 * 60 * 60 * 1000;

// Eslatma: 021 dagi qalqon indeksi hall_id NULL ni nol-UUID ga aylantiradi
// (coalesce) — bu yerda esa NULL uchun `.is('hall_id', null)` ishlatiladi;
// ikkalasi bir xil guruhni bildiradi.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

const SLOT_TAKEN_BODY = {
  success: false,
  code: 'SLOT_TAKEN',
  error: 'Bu sana va vaqt band — boshqa zal yoki vaqt tanlang',
};

// ============================ Validatsiya ============================
// expenses.js madaniyati: butun son Math.round orqali, musbatlik tekshiruvi,
// uzunlik chegarasi, boshqaruv belgilarini olib tashlash, aniq 400 (o'zbekcha).

/** Boshqaruv belgilarini olib tashlaydi, bo'shliqlarni siqadi, n belgiga kesadi. */
function clean(v, n) {
  if (v == null) return null;
  const s = String(v)
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return s ? s.slice(0, n) : null;
}

/** Pul (UZS, butun son). null = noto'g'ri. allowZero — narx 0 bo'lishi mumkin.
 *
 *  TURGA QAT'IY (2026-08-04 review topilmasi — PUL YO'QOTUVCHI xato edi):
 *  ilgari faqat `Math.round(Number(v))` ishlatilardi, lekin JS'da
 *    Number(null) === 0, Number('') === 0, Number(false) === 0, Number([]) === 0
 *  ya'ni PATCH {price_per_guest: null} yoki {price_per_guest: ""} kelishilgan
 *  shartnoma narxini JIMGINA 0 ga tushirardi — 400 ham, iz ham qolmasdi.
 *  Endi FAQAT haqiqiy son yoki sof raqamli satr qabul qilinadi; qolgani -> null -> 400.
 *  (Bo'sh/null qiymatni "tegmaslik" deb talqin qilish CHAQIRUVCHIning ishi —
 *  handler'lar buni `!== undefined` tekshiruvi bilan o'zi hal qiladi.) */
export function money(v, { allowZero = false } = {}) {
  let n;
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) return null;          // NaN / Infinity
    n = Math.round(v);
  } else if (typeof v === 'string' && /^\s*\d+(\.\d+)?\s*$/.test(v)) {
    n = Math.round(Number(v));                     // "150000" yoki "150000.00"
  } else {
    return null;                                   // null, '', false, [], {}, '12abc'
  }
  if (!Number.isInteger(n) || n > MAX_MONEY) return null;
  if (n < 0 || (!allowZero && n === 0)) return null;
  return n;
}

/** KO'PAYTMA chegarasi. Har omil alohida chegarada bo'lsa ham ko'paytmasi
 *  Number.MAX_SAFE_INTEGER (~9.007e15) dan oshishi mumkin edi — masalan
 *  100 000 mehmon × 1e13 narx = 1e18. Bunda JS float arifmetikasi summani
 *  NaN bermasdan JIMGINA noto'g'ri yaxlitlaydi (butun hisob-kitob buziladi).
 *  Shuning uchun ko'paytma ham MAX_MONEY bilan cheklanadi. */
export function overMax(a, b) {
  return (Number(a) || 0) * (Number(b) || 0) > MAX_MONEY;
}

/** 'YYYY-MM-DD' — kalendar jihatdan HAQIQIY sana (2026-02-31 rad etiladi). */
export function isDateStr(v) {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
  const [y, m, d] = v.split('-').map(Number);
  if (y < 2000 || y > 2100) return false;
  const dt = new Date(Date.UTC(y, m - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
}

/** Ikki 'YYYY-MM-DD' orasidagi kunlar (to - from). */
export function daysBetween(from, to) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

/** Default oraliq — Toshkent vaqtidagi joriy oy. { from, to } (ikkalasi ham inklyuziv). */
export function monthBounds(now = new Date()) {
  const t = new Date(now.getTime() + TZ_OFFSET_MS);
  const y = t.getUTCFullYear();
  const m = t.getUTCMonth();
  const p = (n) => String(n).padStart(2, '0');
  const last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  return { from: `${y}-${p(m + 1)}-01`, to: `${y}-${p(m + 1)}-${p(last)}` };
}

/** ?hall_id= (ixtiyoriy to'yxona filtri).
 *   - berilmagan / bo'sh -> BARCHA to'yxonalar ("Hammasi" ko'rinishi), shu jumladan
 *     hall_id NULL bo'lgan bandlar (to'yxonasiz ega yoki o'chirilgan to'yxona);
 *   - <uuid>            -> aynan o'sha to'yxona;
 *   - 'none'            -> FAQAT to'yxonasiz (hall_id NULL) bandlar.
 *  Egalik alohida tekshirilmaydi — so'rov baribir user_id bo'yicha filtrlanadi,
 *  begona ID shunchaki bo'sh natija beradi (enumeratsiya yo'q). */
export function readHallFilter(query) {
  const raw = query.hall_id;
  if (raw === undefined || raw === null || raw === '') return { hallId: null, nullOnly: false };
  const id = String(raw);
  if (id === 'none') return { hallId: null, nullOnly: true };
  if (!isUuid(id)) return { error: "hall_id noto'g'ri" };
  return { hallId: id, nullOnly: false };
}

/** hall_id filtrini so'rovga qo'llaydi (bookings va summary bir xil mantiq). */
function applyHallFilter(q, filter) {
  if (filter.nullOnly) return q.is('hall_id', null);
  if (filter.hallId) return q.eq('hall_id', filter.hallId);
  return q;
}

/** ?from/?to ni o'qiydi. Xato bo'lsa { error } qaytaradi (handler 400 beradi). */
function readRange(query) {
  const def = monthBounds();
  const from = query.from === undefined || query.from === '' ? def.from : String(query.from);
  const to = query.to === undefined || query.to === '' ? def.to : String(query.to);
  if (!isDateStr(from)) return { error: "from noto'g'ri sana (YYYY-MM-DD)" };
  if (!isDateStr(to)) return { error: "to noto'g'ri sana (YYYY-MM-DD)" };
  const days = daysBetween(from, to);
  if (days < 0) return { error: "from sanasi to dan keyin bo'lmasin" };
  if (days > MAX_RANGE_DAYS) return { error: `Oraliq ${MAX_RANGE_DAYS} kundan oshmasin` };
  return { from, to };
}

// ============================ Sof hisob-kitob ============================
// (Sof funksiyalar — DB'siz test qilinadi: src/routes/toyxona.test.js)

/** Bir bandning pul yakuni.
 *  food  = mehmon soni × bir mehmon narxi
 *  extras= Σ(qo'shimcha xizmat narxi × soni)
 *  total = food + extras · paid = Σ(to'lovlar) · left = total − paid (manfiy bo'lishi mumkin) */
export function computeTotals(booking, items = [], payments = []) {
  const guests = Number(booking?.guests) || 0;
  const ppg = Number(booking?.price_per_guest) || 0;
  const food = guests > 0 && ppg > 0 ? guests * ppg : 0;
  const extras = items.reduce(
    (s, it) => s + (Number(it?.amount) || 0) * (Number(it?.qty) || 0), 0);
  const paid = payments.reduce((s, p) => s + (Number(p?.amount) || 0), 0);
  const total = food + extras;
  return { food, extras, total, paid, left: total - paid };
}

/** AQLLI STATUS QOIDALARI (deterministik, faqat TO'LOV QO'SHILGANDA ishlaydi):
 *   1) 'band' + birinchi to'lov  -> 'tasdiq'   (avans olindi = sana tasdiqlandi)
 *   2) 'tasdiq' + left <= 0      -> 'yakun'    (to'liq to'landi)
 *   3) 'bekor' va 'yakun' — TEGILMAYDI (bekor qilingan bandga to'lov kiritish
 *      qaytarim/jarima hisobi bo'lishi mumkin, uni tiriltirmaymiz)
 *   4) TO'LOV O'CHIRILGANDA statusni PASAYTIRMAYMIZ — egasi nazoratda qoladi
 *      (xato summani tuzatish uchun o'chirib-qayta kiritish odatiy ish).
 *   5) Qo'lda PATCH status har doim USTUN — u avtomatik qoidalarni chaqirmaydi. */
export function autoStatusAfterPayment(current, left) {
  if (current === 'bekor' || current === 'yakun') return current;
  const s = current === 'band' ? 'tasdiq' : current;
  return s === 'tasdiq' && left <= 0 ? 'yakun' : s;
}

/** Davr yakuni — SOF yig'ish (DB'siz test qilinadi).
 *
 *  MUHIM ASIMMETRIYA (ataylab): pul yig'indilari 'bekor' bandlarni hisobga OLMAYDI
 *  (bekor qilingan to'y daromad emas), `count` esa oraliqdagi BARCHA qatorlarni
 *  sanaydi. Ikkalasini bitta sarlavhada ko'rsatganda ("N to'y · <total>") bu
 *  o'zaro zid ko'rinardi, shuning uchun `countActive` ham qaytariladi —
 *  bu AYNAN pul yig'indisiga kirgan bandlar soni (mijoz o'zi ayirmasin).
 *
 *  `cancelledPaid` (2026-08-04 review) — BEKOR qilingan bandlarga HAQIQATAN
 *  tushgan pul. O'zbekistonda odatiy holat: mijoz to'yni bekor qiladi, AVANS
 *  egada QOLADI. Ilgari bu summa `paid` dan chiqib ketib, ekranda hech qanday
 *  iz qoldirmasdi — oyning "olingan puli" kassadagi naqd bilan mos kelmasdi.
 *  Endi u ALOHIDA qator bo'lib chiqadi: `paid` semantikasi o'zgarmaydi
 *  (faol bandlar puli), lekin pul KO'RINMAY qolmaydi.
 *  DIQQAT: to'lov qatori bandiga BOG'LIQ qoladi (FK uzilmaydi) — har so'm qaysi
 *  to'ydan kelganini har doim kuzatib bo'ladi (audit izi buzilmaydi). */
export function foldSummary(rows, itemsBy = new Map(), paysBy = new Map()) {
  const byStatus = { band: 0, tasdiq: 0, yakun: 0, bekor: 0 };
  let total = 0; let paid = 0; let cancelledPaid = 0;
  for (const b of rows) {
    if (byStatus[b.status] !== undefined) byStatus[b.status] += 1;
    const t = computeTotals(b, itemsBy.get(b.id) || [], paysBy.get(b.id) || []);
    if (b.status === 'bekor') {
      // Bekor qilingan band: faqat TUSHGAN pul sanaladi (uning `total`i daromad
      // emas — to'y bo'lmadi; lekin olingan avans real pul).
      cancelledPaid += t.paid;
      continue;
    }
    total += t.total; paid += t.paid;
  }
  return {
    count: rows.length,
    countActive: rows.length - byStatus.bekor,   // pul yig'indisi qamragan bandlar
    total,
    paid,
    left: total - paid,
    cancelledPaid,                               // bekor qilinganlardan qolgan pul
    byStatus,
  };
}

/** Kalendar tartibi: sana bo'yicha, keyin slot bo'yicha (nahor -> tushlik -> kechki).
 *  DB'da slot MATN — `order('slot')` alifbo tartibi berardi (kechki, nahor, tushlik). */
export function sortBookings(rows) {
  return [...rows].sort((a, b) =>
    String(a.event_date).localeCompare(String(b.event_date))
    || SLOTS.indexOf(a.slot) - SLOTS.indexOf(b.slot)
    || String(a.created_at || '').localeCompare(String(b.created_at || '')));
}

// ============================ Obuna gate'i ============================
// Monetizatsiya SIMLARI src/lib/subscription.js va src/routes/subs.js EGASIDA —
// bu fayl ularga TEGMAYDI, faqat READ-ONLY import qiladi.
// FREE_TOYXONA_BOOKINGS ilgari shu yerda TAKRORLANGAN edi (o'z intEnv nusxasi
// bilan). Endi umumiy manbadan import qilinadi: getModulesStatus() ham AYNAN shu
// konstantani `free_limit` sifatida qaytaradi, ya'ni mobil kartadagi "0/5"
// hisoblagichi va bu yerdagi majburlash BIR-BIRIDAN AJRALIB KETA OLMAYDI.
// Qolgan kechiktirilgan qism: $24/oy HAR TO'YXONAGA (MODULES.toyxona.per_unit) —
// to'yxona soni bo'yicha hisob-kitob hali yo'q, u ham subs sessiyasida.

/** YANGI BAND kvotasi. O'qish (GET) hech qachon bloklanmaydi; zal/xizmat/to'lov
 *  qo'shish ham ochiq — pul kirishi hech qachon to'sib qo'yilmasin (circles.js
 *  siyosati). Faqat POST /bookings sanaladi. 'bekor' bandlar kvota yemaydi. */
function requireBookingQuota(req, res, next) {
  (async () => {
    // XAVFSIZLIK KLAPANI: 020 va 021 migratsiyalarini EGA QO'LDA qo'llaydi, ya'ni
    // 021 birinchi tushishi mumkin. Bunday holatda module_subs jadvali yo'q —
    // obunani SOTIB BO'LMAYDI — lekin kvota 5 dan keyin bloklab, egani to'lash
    // imkoniyatisiz qulflab qo'yardi. Sotish mumkin bo'lmasa — bloklamaymiz.
    if (!(await isQuotaEnforceable(req.user.id))) return next();
    if (await isModuleActive(req.user.id, 'toyxona')) return next();
    const { count, error } = await supabaseAdmin
      .from('bookings')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', req.user.id)
      .neq('status', 'bekor');
    if (error) throw new Error(error.message);
    if ((count || 0) < FREE_TOYXONA_BOOKINGS) return next();
    return res.status(402).json({
      success: false,
      code: 'SUB_EXPIRED',
      module: 'toyxona',
      error: `Bepul ${FREE_TOYXONA_BOOKINGS} ta band ishlatildi — davom etish uchun obuna kerak ($${MODULES.toyxona.price_usd}/oy)`,
    });
  })().catch(next);
}

// ============================ DB yordamchilari ============================

/** 23505 — unique buzilishi (bookings_slot_uidx). Xom Postgres matni mijozga chiqmaydi. */
export function isUniqueViolation(error) {
  return error?.code === '23505' || /duplicate key|unique constraint/i.test(error?.message || '');
}

/** Band EGA'nikimi? Yo'q/begona bo'lsa null (404 "Topilmadi" — enumeratsiya yo'q). */
async function ownedBooking(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('bookings').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Faol (arxivlanmagan) to'yxonalar soni chegaradan oshdimi?
 *  Oshgan bo'lsa tayyor xato obyektini, aks holda null qaytaradi.
 *  Chegara — MODULES.toyxona.max_units (PO 2026-08-04: $24 = BITTA to'yxona;
 *  do'konlar obunada miqdorni qo'llamaydi, shuning uchun ko'proq zal SOTIB
 *  BO'LMAYDI — ega alohida akkaunt ochadi). Katalogda max_units yo'q/0 bo'lsa
 *  chegara qo'llanmaydi (kelajakda pog'onali SKU'ga o'tilsa shu yerda ishlaydi). */
async function hallLimitError(userId) {
  const max = MODULES?.toyxona?.max_units;
  if (!Number.isInteger(max) || max <= 0) return null;
  const { count, error } = await supabaseAdmin
    .from('halls').select('id', { count: 'exact', head: true })
    .eq('user_id', userId).eq('archived', false);
  if (error) throw new Error(error.message);   // sanoq yiqilsa chegara JIMGINA ochilib qolmasin
  if ((count || 0) < max) return null;
  return {
    success: false,
    code: 'HALL_LIMIT',
    error: max === 1
      ? "Bitta akkauntda bitta to'yxona yuritiladi. Yana to'yxona uchun boshqa raqamga alohida ro'yxatdan o'ting"
      : `Obuna ${max} ta to'yxonani qoplaydi — ortiqchasi uchun alohida akkaunt kerak`,
  };
}

/** To'yxona EGA'nikimi? (band yaratishda begona zal ID'si berilmasin) */
async function ownedHall(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('halls').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Narx toifasi EGA'nikimi? */
async function ownedMenu(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('hall_menus').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Bandga toifa biriktirish tekshiruvi: toifa EGA'niki VA AYNAN SHU to'yxonaniki
 *  bo'lishi shart (aks holda "Lyuks" narxi boshqa to'yxonaga o'tib ketardi).
 *  { menu } yoki { error } qaytaradi — handler 400 beradi. */
async function resolveMenu(userId, menuId, hallId) {
  const menu = await ownedMenu(userId, menuId);
  if (!menu) return { error: 'Narx toifasi topilmadi' };
  if ((menu.hall_id || null) !== (hallId || null)) {
    return { error: "Narx toifasi boshqa to'yxonaga tegishli" };
  }
  return { menu };
}

/** Slot bandmi? exceptId — PATCH'da bandning O'ZI hisobga olinmasin.
 *  hall_id NULL bo'lsa `.is(null)` — 021 dagi coalesce indeksi bilan bir xil mantiq. */
async function findSlotConflict(userId, { hallId, date, slot, exceptId }) {
  let q = supabaseAdmin
    .from('bookings').select('id, client_name')
    .eq('user_id', userId).eq('event_date', date).eq('slot', slot)
    .neq('status', 'bekor');
  q = hallId ? q.eq('hall_id', hallId) : q.is('hall_id', null);
  if (exceptId) q = q.neq('id', exceptId);
  const { data, error } = await q.limit(1);
  if (error) throw new Error(error.message);
  return data?.[0] || null;
}

/** Bolalarni TO'PLAB yuklaydi — N+1 YO'Q. Oylik ko'rinishda (≤200 band) jami
 *  2 ta so'rov; kattaroq oraliqda 200 talik bo'laklarga bo'linadi. */
async function loadChildren(bookingIds) {
  const itemsBy = new Map();
  const paysBy = new Map();
  if (!bookingIds.length) return { itemsBy, paysBy };
  const chunks = [];
  for (let i = 0; i < bookingIds.length; i += CHILD_CHUNK) {
    chunks.push(bookingIds.slice(i, i + CHILD_CHUNK));
  }
  const results = await Promise.all(chunks.flatMap((ids) => [
    supabaseAdmin.from('booking_items')
      .select('id, booking_id, title, amount, qty, created_at')
      .in('booking_id', ids).order('created_at'),
    supabaseAdmin.from('booking_payments')
      .select('id, booking_id, amount, kind, paid_at, note, created_at')
      .in('booking_id', ids).order('paid_at'),
  ]));
  results.forEach((r, i) => {
    if (r.error) throw new Error(r.error.message);
    const bucket = i % 2 === 0 ? itemsBy : paysBy;
    for (const row of r.data || []) {
      const arr = bucket.get(row.booking_id) || [];
      arr.push(row);
      bucket.set(row.booking_id, arr);
    }
  });
  return { itemsBy, paysBy };
}

/** Foydalanuvchining zallari: id -> nomi (bitta kichik so'rov). */
async function hallNameMap(userId) {
  const { data, error } = await supabaseAdmin
    .from('halls').select('id, name').eq('user_id', userId).limit(200);
  if (error) throw new Error(error.message);
  return new Map((data || []).map((h) => [h.id, h.name]));
}

/** Mobil KONTRAKTI — bitta to'yxona JSON'i. `menus` HAR DOIM massiv (yo'q bo'lsa
 *  bo'sh) — mobil bir xil shaklni parse qilsin, `null` tekshiruvi kerak bo'lmasin. */
function mapHall(h, menus = []) {
  return {
    id: h.id,
    name: h.name,
    capacity: h.capacity == null ? null : Number(h.capacity),
    price_per_guest: Number(h.price_per_guest) || 0,   // toifasiz egalar uchun zaxira narx
    sort: Number(h.sort) || 0,
    archived: !!h.archived,
    created_at: h.created_at,
    menus,
  };
}

/** Mobil KONTRAKTI — bitta narx toifasi JSON'i. */
function mapMenu(m) {
  return {
    id: m.id,
    hall_id: m.hall_id,
    title: m.title,
    price_per_guest: Number(m.price_per_guest) || 0,
    sort: Number(m.sort) || 0,
    archived: !!m.archived,
    created_at: m.created_at,
  };
}

/** Mobil KONTRAKTI — bitta band JSON'i. */
function mapBooking(b, hallName, items = [], payments = []) {
  return {
    id: b.id,
    hall_id: b.hall_id,
    hall_name: hallName || null,
    menu_id: b.menu_id || null,
    menu_title: b.menu_title || null,   // SNAPSHOT — toifa o'chsa ham qoladi
    event_date: b.event_date,
    slot: b.slot,
    client_name: b.client_name,
    client_phone: b.client_phone,
    guests: Number(b.guests) || 0,
    price_per_guest: Number(b.price_per_guest) || 0,
    note: b.note,
    status: b.status,
    created_at: b.created_at,
    updated_at: b.updated_at,
    items: items.map((it) => ({
      id: it.id, title: it.title, amount: Number(it.amount) || 0, qty: Number(it.qty) || 0,
    })),
    payments: payments.map((p) => ({
      id: p.id, amount: Number(p.amount) || 0, kind: p.kind, paid_at: p.paid_at, note: p.note,
    })),
    totals: computeTotals(b, items, payments),
  };
}

/** Bitta bandni bolalari bilan qayta yuklab, mobil ko'rinishida qaytaradi
 *  (mutatsiyalardan keyin: mobil ro'yxatdagi qatorni shundoq almashtiradi). */
async function loadOneBooking(userId, bookingId) {
  const { data: b, error } = await supabaseAdmin
    .from('bookings').select('*').eq('id', bookingId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!b || b.user_id !== userId) return null;
  const [{ itemsBy, paysBy }, halls] = await Promise.all([
    loadChildren([b.id]),
    b.hall_id ? hallNameMap(userId) : Promise.resolve(new Map()),
  ]);
  return mapBooking(b, halls.get(b.hall_id), itemsBy.get(b.id) || [], paysBy.get(b.id) || []);
}

// ============================ ZALLAR (halls) ============================

// GET /api/toyxona/halls — arxivlanganlar ham qaytadi (mobil o'zi filtrlaydi).
// Har to'yxona narx toifalarini (menus[]) O'ZI BILAN olib keladi — mobil zallar
// ro'yxatini ochganda har zal uchun alohida so'rov yubormasin (2 so'rov, N+1 emas).
router.get('/halls', async (req, res, next) => {
  try {
    const [hallsRes, menusRes] = await Promise.all([
      supabaseAdmin.from('halls').select('*').eq('user_id', req.user.id)
        .order('sort').order('created_at').limit(200),
      // Chegara limitlarga MOS: 100 zal × 50 toifa = 5000 (ilgari 1000 edi va
      // toifalar jimgina yo'qolardi — mobil ularni "o'chirilgan" deb ko'rsatardi)
      supabaseAdmin.from('hall_menus').select('*').eq('user_id', req.user.id)
        .order('sort').order('created_at').limit(MAX_MENUS_TOTAL),
    ]);
    if (hallsRes.error) throw new Error(hallsRes.error.message);
    if (menusRes.error) throw new Error(menusRes.error.message);

    const menusBy = new Map();
    for (const m of menusRes.data || []) {
      const arr = menusBy.get(m.hall_id) || [];
      arr.push(mapMenu(m));
      menusBy.set(m.hall_id, arr);
    }
    res.json({
      success: true,
      data: (hallsRes.data || []).map((h) => mapHall(h, menusBy.get(h.id) || [])),
    });
  } catch (e) { next(e); }
});

// POST /api/toyxona/halls  { name, capacity?, price_per_guest? }
router.post('/halls', async (req, res, next) => {
  try {
    const name = clean(req.body?.name, 60);
    if (!name) return res.status(400).json({ success: false, error: 'Zal nomi kerak' });

    let capacity = null;
    if (req.body?.capacity != null && req.body.capacity !== '') {
      capacity = Math.round(Number(req.body.capacity));
      if (!Number.isInteger(capacity) || capacity < 0 || capacity > MAX_GUESTS) {
        return res.status(400).json({ success: false, error: `Sig'im 0–${MAX_GUESTS} oralig'ida bo'lsin` });
      }
    }
    let ppg = 0;
    if (req.body?.price_per_guest != null && req.body.price_per_guest !== '') {
      ppg = money(req.body.price_per_guest, { allowZero: true });
      if (ppg == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
    }
    // sort — ro'yxat oxiriga (mobil keyin PATCH bilan qayta tartiblashi mumkin)
    const { count, error: ce } = await supabaseAdmin
      .from('halls').select('id', { count: 'exact', head: true }).eq('user_id', req.user.id);
    if (ce) throw new Error(ce.message);   // sanoq yiqilsa limit JIMGINA chetlab o'tilmasin
    if ((count || 0) >= MAX_HALLS) {
      return res.status(400).json({ success: false, error: `To'yxonalar soni ${MAX_HALLS} tadan oshmasin` });
    }
    // BITTA TO'YXONA QOIDASI (PO 2026-08-04): $24 obuna FAQAT bitta to'yxonani
    // qoplaydi — do'konlar obunada "miqdor"ni qo'llamaydi (2026-08-04-iap-per-unit-research).
    // Ko'proq kerak bo'lsa ega alohida akkaunt ochadi. Yagona manba —
    // MODULES.toyxona.max_units (subscription.js), majburlash SHU YERDA.
    // 403, 402 EMAS: ortiqcha zalni SOTIB BO'LMAYDI, shuning uchun mobil paywall
    // ochmasligi kerak (402 -> Api.onPaymentRequired -> paywall).
    const limitErr = await hallLimitError(req.user.id);
    if (limitErr) return res.status(403).json(limitErr);

    const { data, error } = await supabaseAdmin.from('halls').insert({
      user_id: req.user.id, name, capacity, price_per_guest: ppg, sort: count || 0,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data: mapHall(data, []) });   // yangi to'yxonada toifa yo'q
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/halls/:id  { name?, capacity?, price_per_guest?, archived?, sort? }
router.patch('/halls/:id', async (req, res, next) => {
  try {
    const hall = await ownedHall(req.user.id, req.params.id);
    if (!hall) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const patch = {};
    if (req.body?.name !== undefined) {
      const name = clean(req.body.name, 60);
      if (!name) return res.status(400).json({ success: false, error: 'Zal nomi kerak' });
      patch.name = name;
    }
    if (req.body?.capacity !== undefined) {
      if (req.body.capacity === null || req.body.capacity === '') patch.capacity = null;
      else {
        const c = Math.round(Number(req.body.capacity));
        if (!Number.isInteger(c) || c < 0 || c > MAX_GUESTS) {
          return res.status(400).json({ success: false, error: `Sig'im 0–${MAX_GUESTS} oralig'ida bo'lsin` });
        }
        patch.capacity = c;
      }
    }
    if (req.body?.price_per_guest !== undefined) {
      const p = money(req.body.price_per_guest, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
      patch.price_per_guest = p;
    }
    if (req.body?.archived !== undefined) {
      patch.archived = !!req.body.archived;
      // Arxivdan QAYTARISH ham chegaraga bo'ysunadi — aks holda qoidani chetlab
      // o'tish yo'li ochiq qolardi: A'ni arxivla -> B yarat -> A'ni qaytar = 2 faol.
      if (patch.archived === false && hall.archived === true) {
        const limitErr = await hallLimitError(req.user.id);
        if (limitErr) return res.status(403).json(limitErr);
      }
    }
    if (req.body?.sort !== undefined) {
      const s = Math.round(Number(req.body.sort));
      if (!Number.isInteger(s) || s < 0 || s > 1000) {
        return res.status(400).json({ success: false, error: "Tartib noto'g'ri" });
      }
      patch.sort = s;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }
    const { data, error } = await supabaseAdmin
      .from('halls').update(patch).eq('id', hall.id).select().single();
    if (error) throw new Error(error.message);
    // Toifalar ham qaytadi — GET /halls bilan bir xil shakl (mobil qatorni almashtiradi).
    // Xato JIMGINA yutilmaydi: bo'sh menus[] qaytarsak mobil "toifalar o'chib ketdi"
    // deb ko'rsatardi — bu ma'lumot yo'qolgandek tuyuladi.
    const { data: menus, error: me } = await supabaseAdmin.from('hall_menus').select('*')
      .eq('user_id', req.user.id).eq('hall_id', hall.id).order('sort').order('created_at');
    if (me) throw new Error(me.message);
    res.json({ success: true, data: mapHall(data, (menus || []).map(mapMenu)) });
  } catch (e) { next(e); }
});

// ============================ NARX TOIFALARI (menus) ============================

// GET /api/toyxona/halls/:hallId/menus
router.get('/halls/:hallId/menus', async (req, res, next) => {
  try {
    const hall = await ownedHall(req.user.id, req.params.hallId);
    if (!hall) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data, error } = await supabaseAdmin
      .from('hall_menus').select('*')
      .eq('user_id', req.user.id).eq('hall_id', hall.id)
      .order('sort').order('created_at').limit(100);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: (data || []).map(mapMenu) });
  } catch (e) { next(e); }
});

// POST /api/toyxona/halls/:hallId/menus  { title, price_per_guest }
router.post('/halls/:hallId/menus', async (req, res, next) => {
  try {
    const hall = await ownedHall(req.user.id, req.params.hallId);
    if (!hall) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const title = clean(req.body?.title, 60);
    if (!title) return res.status(400).json({ success: false, error: 'Toifa nomi kerak' });
    const price = money(req.body?.price_per_guest, { allowZero: true });
    if (price == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });

    const { count, error: ce } = await supabaseAdmin.from('hall_menus')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', req.user.id).eq('hall_id', hall.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= MAX_MENUS_PER_HALL) {
      return res.status(400).json({
        success: false, error: `Bitta to'yxonada ${MAX_MENUS_PER_HALL} tadan ortiq toifa bo'lmasin`,
      });
    }
    const { data, error } = await supabaseAdmin.from('hall_menus').insert({
      user_id: req.user.id, hall_id: hall.id, title, price_per_guest: price, sort: count || 0,
    }).select().single();
    if (error) throw new Error(error.message);
    res.status(201).json({ success: true, data: mapMenu(data) });
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/menus/:id  { title?, price_per_guest?, archived?, sort? }
// DIQQAT: narxni o'zgartirish FAQAT kelajakdagi bandlarga ta'sir qiladi —
// mavjud bandlarda narx SNAPSHOT bo'lib saqlangan (021 dagi qoida).
router.patch('/menus/:id', async (req, res, next) => {
  try {
    const menu = await ownedMenu(req.user.id, req.params.id);
    if (!menu) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const patch = {};
    if (req.body?.title !== undefined) {
      const t = clean(req.body.title, 60);
      if (!t) return res.status(400).json({ success: false, error: 'Toifa nomi kerak' });
      patch.title = t;
    }
    if (req.body?.price_per_guest !== undefined) {
      const p = money(req.body.price_per_guest, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Narx noto'g'ri" });
      patch.price_per_guest = p;
    }
    if (req.body?.archived !== undefined) patch.archived = !!req.body.archived;
    if (req.body?.sort !== undefined) {
      const s = Math.round(Number(req.body.sort));
      if (!Number.isInteger(s) || s < 0 || s > 1000) {
        return res.status(400).json({ success: false, error: "Tartib noto'g'ri" });
      }
      patch.sort = s;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }
    const { data, error } = await supabaseAdmin
      .from('hall_menus').update(patch).eq('id', menu.id).select().single();
    if (error) throw new Error(error.message);
    res.json({ success: true, data: mapMenu(data) });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/menus/:id — qat'iy o'chirish.
// Bandlar YO'QOLMAYDI: bookings.menu_id NULL bo'ladi, menu_title/price_per_guest
// esa SNAPSHOT sifatida qoladi (o'tgan shartnoma summasi o'zgarmaydi).
// Ro'yxatdan yashirish uchun PATCH { archived: true } afzal.
router.delete('/menus/:id', async (req, res, next) => {
  try {
    const menu = await ownedMenu(req.user.id, req.params.id);
    if (!menu) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { error } = await supabaseAdmin.from('hall_menus').delete().eq('id', menu.id);
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// ============================ BANDLAR (bookings) ============================

// GET /api/toyxona/bookings?from=YYYY-MM-DD&to=YYYY-MM-DD&hall_id=<uuid>
// from/to berilmasa — Toshkent vaqtidagi JORIY OY.
// hall_id — AYNAN BITTA to'yxona hisobi; berilmasa barcha to'yxonalar birgalikda.
router.get('/bookings', async (req, res, next) => {
  try {
    const range = readRange(req.query);
    if (range.error) return res.status(400).json({ success: false, error: range.error });
    const hallFilter = readHallFilter(req.query);
    if (hallFilter.error) return res.status(400).json({ success: false, error: hallFilter.error });

    let q = supabaseAdmin
      .from('bookings').select('*')
      .eq('user_id', req.user.id)
      .gte('event_date', range.from).lte('event_date', range.to);
    q = applyHallFilter(q, hallFilter);
    const { data, error } = await q.order('event_date').limit(MAX_BOOKINGS);
    if (error) throw new Error(error.message);

    const rows = sortBookings(data || []);
    const [{ itemsBy, paysBy }, halls] = await Promise.all([
      loadChildren(rows.map((b) => b.id)),
      hallNameMap(req.user.id),
    ]);
    res.json({
      success: true,
      data: rows.map((b) => mapBooking(b, halls.get(b.hall_id), itemsBy.get(b.id) || [], paysBy.get(b.id) || [])),
      range: { from: range.from, to: range.to, hall_id: hallFilter.hallId },
      // Chegaraga tegdi — mobil oraliqni toraytirishi yoki hall_id qo'yishi kerak
      // (JIMGINA kesilgan ro'yxat pul yakunini kam ko'rsatardi)
      truncated: rows.length >= MAX_BOOKINGS,
    });
  } catch (e) { next(e); }
});

// POST /api/toyxona/bookings
// { hall_id?, menu_id?, event_date, slot, client_name, client_phone?, guests,
//   price_per_guest?, note?, advance? }
// Narx ustuvorligi: aniq price_per_guest > tanlangan toifa (menu) > to'yxona defaulti > 0.
router.post('/bookings', requireBookingQuota, async (req, res, next) => {
  try {
    const b = req.body || {};

    const event_date = String(b.event_date || '');
    if (!isDateStr(event_date)) {
      return res.status(400).json({ success: false, error: "Sana noto'g'ri (YYYY-MM-DD)" });
    }
    const slot = String(b.slot || '');
    if (!SLOTS.includes(slot)) {
      return res.status(400).json({ success: false, error: "Vaqt noto'g'ri (nahor / tushlik / kechki)" });
    }
    const client_name = clean(b.client_name, 80);
    if (!client_name) return res.status(400).json({ success: false, error: 'Mijoz ismi kerak' });
    const client_phone = clean(b.client_phone, 20);

    const guests = Math.round(Number(b.guests));
    if (!Number.isInteger(guests) || guests <= 0 || guests > MAX_GUESTS) {
      return res.status(400).json({ success: false, error: `Mehmonlar soni 1–${MAX_GUESTS} bo'lsin` });
    }

    let hall = null;
    if (b.hall_id != null && b.hall_id !== '') {
      hall = await ownedHall(req.user.id, b.hall_id);
      if (!hall) return res.status(400).json({ success: false, error: "To'yxona topilmadi" });
    }

    // Narx toifasi (menyu) — EGA'niki va AYNAN shu to'yxonaniki bo'lishi shart
    let menu = null;
    if (b.menu_id != null && b.menu_id !== '') {
      const r = await resolveMenu(req.user.id, b.menu_id, hall?.id || null);
      if (r.error) return res.status(400).json({ success: false, error: r.error });
      menu = r.menu;
    }

    // SNAPSHOT: narx bandga NUSXA olinadi — toifa/to'yxona narxi keyin o'zgarsa
    // yoki toifa o'chirilsa ham bu bandning puli o'zgarmaydi.
    let price_per_guest;
    if (b.price_per_guest != null && b.price_per_guest !== '') {
      price_per_guest = money(b.price_per_guest, { allowZero: true });
      if (price_per_guest == null) {
        return res.status(400).json({ success: false, error: "Bir mehmon narxi noto'g'ri" });
      }
    } else if (menu) {
      price_per_guest = Number(menu.price_per_guest) || 0;
    } else {
      price_per_guest = Number(hall?.price_per_guest) || 0;
    }
    if (overMax(guests, price_per_guest)) {
      return res.status(400).json({ success: false, error: 'Umumiy summa juda katta' });
    }
    const note = clean(b.note, 300);

    let advance = 0;
    if (b.advance != null && b.advance !== '') {
      advance = money(b.advance, { allowZero: true });
      if (advance == null) return res.status(400).json({ success: false, error: "Avans noto'g'ri" });
    }

    // 1-qatlam: oldindan tekshiruv (chiroyli xabar, mijoz nomi bilan)
    const clash = await findSlotConflict(req.user.id, { hallId: hall?.id || null, date: event_date, slot });
    if (clash) {
      return res.status(409).json({
        ...SLOT_TAKEN_BODY,
        detail: `Band: ${clash.client_name}`,
      });
    }

    // 2-qatlam: DB indeksi (parallel so'rovlar) — 23505 ham SLOT_TAKEN
    const { data: created, error } = await supabaseAdmin.from('bookings').insert({
      user_id: req.user.id,
      hall_id: hall?.id || null,
      menu_id: menu?.id || null,
      menu_title: menu?.title || null,   // SNAPSHOT
      event_date, slot, client_name, client_phone, guests, price_per_guest, note,
    }).select().single();
    if (error) {
      if (isUniqueViolation(error)) return res.status(409).json(SLOT_TAKEN_BODY);
      throw new Error(error.message);
    }

    // Avans > 0 — birinchi to'lov + AQLLI STATUS ('band' -> 'tasdiq').
    // QO'LDA ORTGA QAYTARISH: bu yerda tranzaksiya yo'q (PostgREST har chaqiruvni
    // alohida commit qiladi). To'lov yozilmasa BAND QOLIB KETARDI — mijoz "xato"
    // ko'radi, lekin sana band bo'lib, bepul kvotadan ham bittasi yeb qo'yilardi.
    // Shuning uchun to'lov yiqilsa yangi bandni O'CHIRAMIZ va xatoni qaytaramiz.
    if (advance > 0) {
      const { error: pe } = await supabaseAdmin.from('booking_payments')
        .insert({ booking_id: created.id, amount: advance, kind: 'avans' });
      if (pe) {
        // Ortga qaytarishning O'ZI ham yiqilishi mumkin. Ilgari uning xatosi
        // e'tiborsiz qolardi: mijoz "hech narsa yaratilmadi" degan 500 olardi,
        // ammo band QOLIB KETARDI va o'sha sana abadiy SLOT_TAKEN berardi —
        // egasi uchun chiqish yo'li yo'q edi. Endi baland ovozda log qilamiz
        // (booking id bilan — qo'lda tozalash uchun). user_id — qo'shimcha
        // himoya qatlami: bu delete faqat O'Z bandimizga tegishi kafolatlanadi.
        const { error: de } = await supabaseAdmin.from('bookings')
          .delete().eq('id', created.id).eq('user_id', req.user.id);
        if (de) {
          console.error(`[toyxona] JIDDIY: avans yozilmadi va band ham o'chmadi — `
            + `qo'lda tozalash kerak (booking=${created.id}, user=${req.user.id}):`, de.message);
        }
        throw new Error(pe.message);
      }
      const totals = computeTotals(created, [], [{ amount: advance }]);
      const next = autoStatusAfterPayment(created.status, totals.left);
      if (next !== created.status) {
        const { error: ue } = await supabaseAdmin.from('bookings')
          .update({ status: next, updated_at: new Date().toISOString() }).eq('id', created.id);
        // Status yangilanmasa band + to'lov O'RNIDA qoladi (pul yo'qolmaydi) —
        // faqat status 'band' bo'lib qoladi, egasi qo'lda tuzatadi. O'chirmaymiz.
        if (ue) console.warn('[toyxona] avans statusi yangilanmadi:', ue.message);
      }
    }

    const full = await loadOneBooking(req.user.id, created.id);
    res.status(201).json({ success: true, data: full });
  } catch (e) { next(e); }
});

// PATCH /api/toyxona/bookings/:id
// { hall_id?, menu_id?, event_date?, slot?, client_name?, client_phone?, guests?,
//   price_per_guest?, note?, status? }
// Sana / slot / zal o'zgarsa — konflikt QAYTA tekshiriladi (409).
// QO'LDA berilgan status HAR DOIM ustun (avtomatik qoidalar bu yerda ishlamaydi).
router.patch('/bookings/:id', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const b = req.body || {};
    const patch = {};

    if (b.event_date !== undefined) {
      const d = String(b.event_date || '');
      if (!isDateStr(d)) return res.status(400).json({ success: false, error: "Sana noto'g'ri (YYYY-MM-DD)" });
      patch.event_date = d;
    }
    if (b.slot !== undefined) {
      const s = String(b.slot || '');
      if (!SLOTS.includes(s)) {
        return res.status(400).json({ success: false, error: "Vaqt noto'g'ri (nahor / tushlik / kechki)" });
      }
      patch.slot = s;
    }
    if ('hall_id' in b) {
      if (b.hall_id == null || b.hall_id === '') patch.hall_id = null;
      else {
        const hall = await ownedHall(req.user.id, b.hall_id);
        if (!hall) return res.status(400).json({ success: false, error: "To'yxona topilmadi" });
        patch.hall_id = hall.id;
      }
    }
    if (b.client_name !== undefined) {
      const n = clean(b.client_name, 80);
      if (!n) return res.status(400).json({ success: false, error: 'Mijoz ismi kerak' });
      patch.client_name = n;
    }
    if (b.client_phone !== undefined) patch.client_phone = clean(b.client_phone, 20);
    if (b.note !== undefined) patch.note = clean(b.note, 300);
    if (b.guests !== undefined) {
      const g = Math.round(Number(b.guests));
      if (!Number.isInteger(g) || g <= 0 || g > MAX_GUESTS) {
        return res.status(400).json({ success: false, error: `Mehmonlar soni 1–${MAX_GUESTS} bo'lsin` });
      }
      patch.guests = g;
    }
    if (b.price_per_guest !== undefined) {
      const p = money(b.price_per_guest, { allowZero: true });
      if (p == null) return res.status(400).json({ success: false, error: "Bir mehmon narxi noto'g'ri" });
      patch.price_per_guest = p;
    }
    // Narx toifasi — YANGI to'yxona (agar o'zgargan bo'lsa) bo'yicha tekshiriladi
    const effHallId = patch.hall_id !== undefined ? patch.hall_id : (cur.hall_id || null);
    if ('menu_id' in b) {
      if (b.menu_id == null || b.menu_id === '') {
        patch.menu_id = null;
        patch.menu_title = null;   // toifani ATAYLAB uzdi — narx o'zgarmaydi
      } else {
        const r = await resolveMenu(req.user.id, b.menu_id, effHallId);
        if (r.error) return res.status(400).json({ success: false, error: r.error });
        patch.menu_id = r.menu.id;
        patch.menu_title = r.menu.title;              // yangi SNAPSHOT
        // Aniq narx berilmagan bo'lsa — yangi toifa narxi ko'chiriladi
        if (b.price_per_guest === undefined) patch.price_per_guest = Number(r.menu.price_per_guest) || 0;
      }
    } else if (patch.hall_id !== undefined && cur.menu_id) {
      // To'yxona o'zgardi, toifa berilmadi — eski toifa boshqa to'yxonaniki bo'lishi
      // mumkin. Bog'lanish uziladi, LEKIN menu_title va narx SNAPSHOT bo'lib qoladi
      // (mijozga nima sotilgani tarixi va shartnoma summasi yo'qolmasin).
      const old = await ownedMenu(req.user.id, cur.menu_id);
      if (!old || (old.hall_id || null) !== effHallId) patch.menu_id = null;
    }
    // Yakuniy (mehmon × narx) ko'paytmasi ham chegarada bo'lsin
    if (overMax(patch.guests ?? cur.guests, patch.price_per_guest ?? cur.price_per_guest)) {
      return res.status(400).json({ success: false, error: 'Umumiy summa juda katta' });
    }
    if (b.status !== undefined) {
      const s = String(b.status || '');
      if (!STATUSES.includes(s)) return res.status(400).json({ success: false, error: "Holat noto'g'ri" });
      patch.status = s;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }

    // Konflikt qayta tekshiruvi: sana/slot/zal yoki 'bekor' dan qaytish holatida
    const nextStatus = patch.status ?? cur.status;
    const touchesSlot = patch.event_date !== undefined || patch.slot !== undefined
      || patch.hall_id !== undefined || (cur.status === 'bekor' && nextStatus !== 'bekor');
    if (touchesSlot && nextStatus !== 'bekor') {
      const clash = await findSlotConflict(req.user.id, {
        hallId: patch.hall_id !== undefined ? patch.hall_id : cur.hall_id,
        date: patch.event_date ?? cur.event_date,
        slot: patch.slot ?? cur.slot,
        exceptId: cur.id,
      });
      if (clash) {
        return res.status(409).json({ ...SLOT_TAKEN_BODY, detail: `Band: ${clash.client_name}` });
      }
    }

    patch.updated_at = new Date().toISOString();
    const { error } = await supabaseAdmin.from('bookings').update(patch).eq('id', cur.id);
    if (error) {
      if (isUniqueViolation(error)) return res.status(409).json(SLOT_TAKEN_BODY);
      throw new Error(error.message);
    }
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/bookings/:id — QAT'IY o'chirish (items/payments cascade).
// Yumshoq bekor qilish = PATCH { status: 'bekor' } (u sanani bo'shatadi, tarixni saqlaydi).
router.delete('/bookings/:id', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { error } = await supabaseAdmin.from('bookings').delete().eq('id', cur.id);
    if (error) throw new Error(error.message);
    res.json({ success: true });
  } catch (e) { next(e); }
});

// ============================ XIZMATLAR (items) ============================

// POST /api/toyxona/bookings/:id/items  { title, amount, qty? }
router.post('/bookings/:id/items', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const title = clean(req.body?.title, 60);
    if (!title) return res.status(400).json({ success: false, error: 'Xizmat nomi kerak' });
    const amount = money(req.body?.amount);
    if (amount == null) {
      return res.status(400).json({ success: false, error: "Summa musbat butun son bo'lishi kerak" });
    }
    let qty = 1;
    if (req.body?.qty != null && req.body.qty !== '') {
      qty = Math.round(Number(req.body.qty));
      if (!Number.isInteger(qty) || qty <= 0 || qty > MAX_QTY) {
        return res.status(400).json({ success: false, error: `Soni 1–${MAX_QTY} bo'lsin` });
      }
    }
    if (overMax(amount, qty)) {
      return res.status(400).json({ success: false, error: 'Xizmat summasi juda katta' });
    }
    const { count, error: ce } = await supabaseAdmin
      .from('booking_items').select('id', { count: 'exact', head: true }).eq('booking_id', cur.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= 50) {
      return res.status(400).json({ success: false, error: "Bitta bandga 50 tadan ortiq xizmat qo'shib bo'lmaydi" });
    }
    const { error } = await supabaseAdmin.from('booking_items')
      .insert({ booking_id: cur.id, title, amount, qty });
    if (error) throw new Error(error.message);
    // INVARIANT (ataylab tanlangan, mobil shunga qarab chizsin): status — EGA
    // boshqaradigan ish holati, `left` dan HOSIL QILINMAYDI. Xizmat qo'shish
    // statusni o'zgartirmaydi, shuning uchun 'yakun' bandga keyin xizmat
    // qo'shilsa `left > 0` bo'lib qolishi MUMKIN va bu buzuq holat EMAS —
    // "to'y o'tdi, lekin salyut alohida hisoblandi" degani.
    // Avtomatik ko'tarish faqat TO'LOVDA ishlaydi (autoStatusAfterPayment), chunki
    // bu yerda uni chaqirish hech qachon foyda bermaydi: xizmat `left` ni
    // OSHIRADI, ko'tarish sharti esa left <= 0 ni talab qiladi.
    // Mobil qoidasi: qoldiqni HAR DOIM `totals.left` bo'yicha ko'rsating, statusga
    // qarab emas. Egasi xohlasa statusni oddiy PATCH bilan qaytaradi.
    res.status(201).json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/items/:itemId — ota-band EGA tekshiriladi (cross-user yo'q)
router.delete('/items/:itemId', async (req, res, next) => {
  try {
    if (!isUuid(req.params.itemId)) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data: item, error: ie } = await supabaseAdmin
      .from('booking_items').select('id, booking_id').eq('id', req.params.itemId).maybeSingle();
    if (ie) throw new Error(ie.message);
    if (!item) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const cur = await ownedBooking(req.user.id, item.booking_id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { error } = await supabaseAdmin.from('booking_items').delete().eq('id', item.id);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// ============================ TO'LOVLAR (payments) ============================

// POST /api/toyxona/bookings/:id/payments  { amount, kind?, note?, paid_at? }
// AQLLI STATUS shu yerda ishlaydi (autoStatusAfterPayment).
router.post('/bookings/:id/payments', async (req, res, next) => {
  try {
    const cur = await ownedBooking(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const amount = money(req.body?.amount);
    if (amount == null) {
      return res.status(400).json({ success: false, error: "Summa musbat butun son bo'lishi kerak" });
    }
    const kind = req.body?.kind == null || req.body.kind === '' ? 'avans' : String(req.body.kind);
    if (!KINDS.includes(kind)) {
      return res.status(400).json({ success: false, error: "To'lov turi noto'g'ri (avans / yakuniy)" });
    }
    const note = clean(req.body?.note, 200);
    let paid_at = null;
    if (req.body?.paid_at != null && req.body.paid_at !== '') {
      const raw = String(req.body.paid_at).slice(0, 40);
      const ts = Date.parse(raw);
      if (Number.isNaN(ts)) return res.status(400).json({ success: false, error: "To'lov sanasi noto'g'ri" });
      paid_at = new Date(ts).toISOString();
    }
    const { count, error: ce } = await supabaseAdmin
      .from('booking_payments').select('id', { count: 'exact', head: true }).eq('booking_id', cur.id);
    if (ce) throw new Error(ce.message);
    if ((count || 0) >= 50) {
      return res.status(400).json({ success: false, error: "Bitta bandga 50 tadan ortiq to'lov qo'shib bo'lmaydi" });
    }

    const row = { booking_id: cur.id, amount, kind, note };
    if (paid_at) row.paid_at = paid_at;
    const { error } = await supabaseAdmin.from('booking_payments').insert(row);
    if (error) throw new Error(error.message);

    // Yangi yakun bo'yicha avtomatik status (faqat KO'TARILADI, hech qachon pasaymaydi)
    const full = await loadOneBooking(req.user.id, cur.id);
    const next = autoStatusAfterPayment(cur.status, full.totals.left);
    if (next !== cur.status) {
      const { error: ue } = await supabaseAdmin.from('bookings')
        .update({ status: next, updated_at: new Date().toISOString() }).eq('id', cur.id);
      // TAKROR TO'LOVGA QARSHI (2026-08-04 review): ilgari bu yerda `throw` bor edi.
      // To'lov qatori ALLAQACHON yozilgandan keyin status yangilanmasa mijoz 500
      // olardi, qayta yuborardi va PUL IKKI MARTA yozilardi. Endi POST /bookings
      // dagi avans yo'li bilan BIR XIL: ogohlantirib, 201 qaytaramiz — status
      // 'band' bo'lib qoladi, egasi oddiy PATCH bilan tuzatadi.
      if (ue) console.warn(`[toyxona] status yangilanmadi (booking=${cur.id}):`, ue.message);
      else full.status = next;
    }
    res.status(201).json({ success: true, data: full });
  } catch (e) { next(e); }
});

// DELETE /api/toyxona/payments/:payId
// Status ATAYLAB pasaytirilmaydi (qoida 4) — egasi qo'lda PATCH qiladi.
router.delete('/payments/:payId', async (req, res, next) => {
  try {
    if (!isUuid(req.params.payId)) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { data: pay, error: pe } = await supabaseAdmin
      .from('booking_payments').select('id, booking_id').eq('id', req.params.payId).maybeSingle();
    if (pe) throw new Error(pe.message);
    if (!pay) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const cur = await ownedBooking(req.user.id, pay.booking_id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { error } = await supabaseAdmin.from('booking_payments').delete().eq('id', pay.id);
    if (error) throw new Error(error.message);
    res.json({ success: true, data: await loadOneBooking(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// ============================ YAKUN (summary) ============================

// GET /api/toyxona/summary?from=&to=&hall_id=
//   -> { count, countActive, total, paid, left, cancelledPaid, byStatus }
// hall_id — AYNAN BITTA to'yxona hisobi (har to'yxona alohida hisob yuritadi);
// berilmasa barcha to'yxonalar birgalikda.
// PUL yig'indilari 'bekor' bandlarni HISOBGA OLMAYDI (bekor qilingan to'y daromad
// emas), `count` esa ularni ham sanaydi — shu sababli `countActive` (= count −
// bekor) ham qaytariladi: sarlavhada "N to'y · <total>" ko'rsatgan mijoz o'zi
// ayirish qilmasin (foldSummary izohiga qarang).
// Bekor qilinganlarga tushgan AVANS `cancelledPaid` da alohida chiqadi — u
// `paid` ga QO'SHILMAYDI, lekin ekranda ko'rinib turadi (egada qolgan real pul).
router.get('/summary', async (req, res, next) => {
  try {
    const range = readRange(req.query);
    if (range.error) return res.status(400).json({ success: false, error: range.error });
    const hallFilter = readHallFilter(req.query);
    if (hallFilter.error) return res.status(400).json({ success: false, error: hallFilter.error });

    let q = supabaseAdmin
      .from('bookings').select('id, guests, price_per_guest, status')
      .eq('user_id', req.user.id)
      .gte('event_date', range.from).lte('event_date', range.to);
    q = applyHallFilter(q, hallFilter);
    // `.order()` SHART: `.limit()` tartibsiz qo'llanilsa Postgres ixtiyoriy
    // qatorlarni qaytaradi — /summary va /bookings bir oraliq uchun HAR XIL pul
    // ko'rsatishi mumkin edi. Endi ikkalasi ham event_date bo'yicha tartiblangan,
    // ya'ni kesilganda ham AYNAN bir xil to'plamni ko'radi.
    const { data, error } = await q.order('event_date').limit(MAX_SUMMARY_BOOKINGS);
    if (error) throw new Error(error.message);

    const rows = data || [];
    const truncated = rows.length >= MAX_SUMMARY_BOOKINGS;
    // Kesilgan bo'lsa rows.length HAQIQIY sonni bildirmaydi (u shunchaki shift) —
    // "N to'y" sarlavhasi jimgina yolg'on gapirardi. Haqiqiy sonni alohida
    // head-so'rov bilan olamiz (faqat kesilganda — ortiqcha so'rov qilmaymiz).
    let realCount = null;
    if (truncated) {
      let cq = supabaseAdmin
        .from('bookings').select('id', { count: 'exact', head: true })
        .eq('user_id', req.user.id)
        .gte('event_date', range.from).lte('event_date', range.to);
      cq = applyHallFilter(cq, hallFilter);
      const { count, error: ce } = await cq;
      if (ce) throw new Error(ce.message);
      realCount = count || 0;
    }
    const { itemsBy, paysBy } = await loadChildren(rows.map((b) => b.id));
    const summary = foldSummary(rows, itemsBy, paysBy);
    // count — oraliqdagi HAQIQIY band soni; countActive/total/paid esa faqat
    // o'qilgan qatorlar bo'yicha (truncated=true bo'lsa ular to'liq emas).
    if (realCount != null) summary.count = realCount;
    res.json({
      success: true,
      data: summary,
      range: { from: range.from, to: range.to, hall_id: hallFilter.hallId },
      truncated,   // yakun to'liq emasligi belgisi
    });
  } catch (e) { next(e); }
});

export default router;
