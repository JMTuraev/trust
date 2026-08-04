// IJARADAGI UYLAR moduli — uy egasi uchun ijara hisobi (022 migratsiya).
//
// Mahsulot modeli (PO 2026-08-04): egasi ijaradagi uylarini yuritadi. IJARACHI
// akkauntsiz — uyda ism + telefon sifatida saqlanadi (to'yxonadagi mijoz kabi).
// Pul ikki bosqichli:
//   1) HISOBLANDI (rent_charges) — oy uchun hisoblangan to'lov: 'ijara' haqi,
//      'kommunal', 'boshqa'. Bu talab, hali pul emas.
//   2) TO'LANDI (rent_payments) — haqiqiy tushum. Bitta hisob-kitobga biriktirilishi
//      (charge_id) yoki TAQSIMLANMAGAN bo'lishi mumkin (charge_id = null: oldindan
//      to'lov, keyin egasi taqsimlaydi).
// Uy qoldig'i = Σ(hisoblangan, bekor emas) − Σ(to'langan).
//
// ==== IKKI TURDAGI CHEGARA — ADASHTIRMANG ====
//   1) 5 TA UY — QAT'IY CHEGARA (403, pul bilan ochilmaydi). Do'konlar miqdorli
//      obunani qo'llab-quvvatlamagani uchun "har uyga $N" o'rniga bitta $13/oy
//      obuna + qat'iy chegara tanlandi; ko'proq uy kerak bo'lsa foydalanuvchi
//      BOSHQA TELEFON RAQAMI bilan alohida hisob ochadi (PO qarori).
//      Majburlash IKKI QATLAM: bu fayl (chiroyli 403) + 022 dagi trigger
//      (parallel so'rovlar uchun; advisory lock bilan).
//   2) BEPUL 5 TA HISOB-KITOB — OBUNA GATE'i (402, obuna bilan ochiladi).
//      Faqat POST /charges sanaladi; 'bekor' yozuvlar kvota YEMAYDI.
//
// Egalik: har so'rov req.user.id bo'yicha filtrlanadi.
// Pul: FAQAT UZS, butun son (tiyin yo'q), chegara 1e13 — toyxona/expenses bilan bir xil.
import { Router } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import { requireAuth } from '../middleware/auth.js';
import { isModuleActive, isQuotaEnforceable, MODULES, FREE_IJARA_CHARGES } from '../lib/subscription.js';

const router = Router();
router.use(requireAuth);

// ============================ Doimiylar ============================

export const KINDS = ['ijara', 'kommunal', 'boshqa'];
export const STATUSES = ['kutilmoqda', 'tolangan', 'bekor'];

// QAT'IY chegara — YAGONA manba src/lib/subscription.js (MODULES.ijarachi.max_units).
// Bu yerda takrorlanmaydi: katalog o'zgarsa route AVTOMATIK ergashadi (022 dagi
// trigger esa SQL bo'lgani uchun qo'lda sinxronlanadi — o'sha fayldagi izohga qarang).
export const MAX_HOUSES = Number(MODULES.ijarachi?.max_units) || 5;

const MAX_MONEY = 1e13;         // UZS butun son shifti (expenses.js/toyxona.js bilan bir xil)
const MAX_RANGE_DAYS = 366;     // bitta so'rovda ko'pi bilan bir yil
const MAX_CHARGES = 500;        // RO'YXAT javobi hajmi chegarasi
const MAX_SUMMARY_CHARGES = 2000;   // yakun faqat 4 ta kichik ustunni tortadi — chegara yuqoriroq
const MAX_PAYMENTS = 2000;      // oraliqdagi to'lovlar
const MAX_HOUSE_ROWS = 5000;    // GET /houses yakuni uchun o'qiladigan qatorlar
// Faol uy ko'pi bilan 5 ta, lekin ARXIV yillar davomida yig'iladi — ro'yxat
// chegarasi shunga qarab keng (50 bo'lsa faol uy arxiv orasida chiqib qolardi).
const MAX_HOUSE_LIST = 200;
const MAX_PAYMENTS_PER_CHARGE = 50;
// Takror to'lovni to'sish oynasi: shu vaqt ichida kelgan AYNAN bir xil to'lov
// (uy + yozuv + summa) yangi qator yaratmaydi — mavjudi qaytariladi.
// Sabab: mobil timeout (20s) + Render sovuq starti + "qayta urinib ko'ring" xabari.
export const DEDUP_MS = 90_000;
// .in(...) bo'laklari — URL UZUNLIGI cheklovi (toyxona.js bilan bir xil hisob:
// 100 ta uuid ≈ 3.7 KB so'rov satri, 8 KB sarlavha chegarasidan xavfsiz uzoqda).
const CHILD_CHUNK = 100;

// Toshkent UTC+5 — default "shu oy" oralig'i EGA vaqtida hisoblanadi, aks holda
// server UTC'da oyning 1-sanasi mahalliy 05:00 gacha "o'tgan oy" bo'lib ko'rinardi.
const TZ_OFFSET_MS = 5 * 60 * 60 * 1000;
const TZ_SUFFIX = '+05:00';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

// ============================ Validatsiya ============================
// ATAYLAB NUSXA (toyxona.js dagi bir xil nomli funksiyalar): route fayllari
// bir-birini import qilmasin (ular router yon ta'siri bilan keladi). Semantika
// AYNAN bir xil bo'lishi shart — ikkalasi ham o'z test faylida qulflangan.
// Kelajakdagi tozalash: ikkalasini src/lib/money.js ga ko'chirish.

/** Boshqaruv belgilarini olib tashlaydi, bo'shliqlarni siqadi, n belgiga kesadi. */
function clean(v, n) {
  if (v == null) return null;
  const s = String(v)
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return s ? s.slice(0, n) : null;
}

/** Pul (UZS, butun son). null = noto'g'ri. allowZero — 0 ruxsat etiladimi.
 *  TURGA QAT'IY: JS'da Number(null)===0, Number('')===0, Number([])===0 —
 *  ilgari to'yxonada shu sabab PATCH {amount: null} kelishilgan summani JIMGINA
 *  0 ga tushirardi. Faqat haqiqiy son yoki sof raqamli satr qabul qilinadi. */
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

/** 'YYYY-MM-DD' — kalendar jihatdan HAQIQIY sana (2026-02-31 rad etiladi). */
export function isDateStr(v) {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
  const [y, m, d] = v.split('-').map(Number);
  if (y < 2000 || y > 2100) return false;
  const dt = new Date(Date.UTC(y, m - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
}

/** 'YYYY-MM' — oy (rent_charges.period). 022 dagi CHECK bilan bir xil qoida. */
export function isPeriodStr(v) {
  if (typeof v !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(v)) return false;
  const y = Number(v.slice(0, 4));
  return y >= 2000 && y <= 2100;
}

/** 'YYYY-MM-DD' -> 'YYYY-MM'. Oraliq filtri OY aniqligida ishlaydi. */
export function periodOf(dateStr) {
  return String(dateStr).slice(0, 7);
}

/** Ikki 'YYYY-MM-DD' orasidagi kunlar (to - from). */
export function daysBetween(from, to) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

/** Default oraliq — Toshkent vaqtidagi joriy oy. { from, to } (ikkalasi inklyuziv). */
export function monthBounds(now = new Date()) {
  const t = new Date(now.getTime() + TZ_OFFSET_MS);
  const y = t.getUTCFullYear();
  const m = t.getUTCMonth();
  const p = (n) => String(n).padStart(2, '0');
  const last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  return { from: `${y}-${p(m + 1)}-01`, to: `${y}-${p(m + 1)}-${p(last)}` };
}

/** Toshkent vaqtidagi joriy oy — 'YYYY-MM' (yangi hisob-kitob defaulti). */
export function currentPeriod(now = new Date()) {
  return periodOf(monthBounds(now).from);
}

/** ?from/?to ni o'qiydi. Xato bo'lsa { error } (handler 400 beradi).
 *  Qaytadi: { from, to, fromPeriod, toPeriod } — hisob-kitoblar OY bo'yicha
 *  filtrlanadi (due_date ixtiyoriy bo'lgani uchun sana bo'yicha filtr muddatsiz
 *  yozuvlarni JIMGINA yo'qotardi), to'lovlar esa paid_at bo'yicha. */
function readRange(query) {
  const def = monthBounds();
  const from = query.from === undefined || query.from === '' ? def.from : String(query.from);
  const to = query.to === undefined || query.to === '' ? def.to : String(query.to);
  if (!isDateStr(from)) return { error: "from noto'g'ri sana (YYYY-MM-DD)" };
  if (!isDateStr(to)) return { error: "to noto'g'ri sana (YYYY-MM-DD)" };
  const days = daysBetween(from, to);
  if (days < 0) return { error: "from sanasi to dan keyin bo'lmasin" };
  if (days > MAX_RANGE_DAYS) return { error: `Oraliq ${MAX_RANGE_DAYS} kundan oshmasin` };
  return { from, to, fromPeriod: periodOf(from), toPeriod: periodOf(to) };
}

/** ?house_id= (ixtiyoriy uy filtri). Berilmagan/bo'sh -> BARCHA uylar.
 *  Egalik alohida tekshirilmaydi — so'rov baribir user_id bo'yicha filtrlanadi,
 *  begona ID shunchaki bo'sh natija beradi (enumeratsiya yo'q). */
export function readHouseFilter(query) {
  const raw = query.house_id;
  if (raw === undefined || raw === null || raw === '') return { houseId: null };
  const id = String(raw);
  if (!isUuid(id)) return { error: "house_id noto'g'ri" };
  return { houseId: id };
}

// ============================ Sof hisob-kitob ============================
// (Sof funksiyalar — DB'siz test qilinadi: src/routes/ijara.test.js)

/** Bitta hisob-kitob yakuni.
 *  BEKOR QILINGAN yozuv PULGA UMUMAN KIRMAYDI (charged = paid = left = 0) —
 *  to'yxonadagi 'bekor' bron qoidasi bilan bir xil. Yozuvning xom summasi
 *  JSON'da `amount` bo'lib qoladi, ya'ni ekranda ko'rinadi, lekin yakunga
 *  qo'shilmaydi. Bekor qilingan yozuvda to'lov turgan bo'lsa — egasi o'sha
 *  to'lovni o'chirishi yoki biriktirishni uzishi kerak (u holda u
 *  TAQSIMLANMAGAN to'lov sifatida yakunga qaytadi). */
export function chargeTotals(charge, payments = []) {
  if (charge?.status === 'bekor') return { charged: 0, paid: 0, left: 0 };
  const charged = Number(charge?.amount) || 0;
  const paid = payments.reduce((s, p) => s + (Number(p?.amount) || 0), 0);
  return { charged, paid, left: charged - paid };
}

/** Hisob-kitob statusi TO'LOV o'zgargandan keyin (deterministik).
 *  1) 'bekor' — TEGILMAYDI (bekor qilingan talabga tushgan pul uni tiriltirmaydi);
 *  2) left <= 0 -> 'tolangan' (to'liq to'landi, ortiqcha to'lov ham);
 *  3) aks holda -> 'kutilmoqda'.
 *  TO'YXONADAN FARQ (ataylab): bu yerda status PASAYADI ham. To'yxonada status
 *  ish OQIMI edi (band -> tasdiq -> yakun), bu yerda esa 'tolangan' so'zma-so'z
 *  "puli to'liq tushgan" degani — noto'g'ri to'lov o'chirilganda uni 'tolangan'
 *  qoldirish qarzni JIMGINA yashirardi.
 *  Qo'lda PATCH status har doim USTUN — bu funksiya faqat to'lov qo'shilganda/
 *  o'chirilganda va summa tahrirlanganda chaqiriladi. */
export function autoChargeStatus(current, left) {
  if (current === 'bekor') return current;
  return left <= 0 ? 'tolangan' : 'kutilmoqda';
}

/** Davr yakuni — SOF yig'ish.
 *  MUHIM ASIMMETRIYA (ataylab, foldSummary/toyxona bilan bir xil): pul yig'indisi
 *  'bekor' yozuvlarni hisobga OLMAYDI, `count` esa oraliqdagi BARCHA qatorlarni
 *  sanaydi — shuning uchun `countActive` (= count − bekor) ham qaytariladi.
 *  `unallocated` — hech qaysi hisob-kitobga biriktirilmagan to'lovlar: ular
 *  ham tushum, shuning uchun `paid` ga kiradi (aks holda oy yakunida haqiqiy
 *  pul kam ko'rinardi). */
export function foldCharges(rows, paysBy = new Map(), unallocated = []) {
  const byStatus = { kutilmoqda: 0, tolangan: 0, bekor: 0 };
  let charged = 0; let paid = 0;
  for (const c of rows) {
    if (byStatus[c.status] !== undefined) byStatus[c.status] += 1;
    if (c.status === 'bekor') continue;
    const t = chargeTotals(c, paysBy.get(c.id) || []);
    charged += t.charged; paid += t.paid;
  }
  paid += unallocated.reduce((s, p) => s + (Number(p?.amount) || 0), 0);
  return {
    count: rows.length,
    countActive: rows.length - byStatus.bekor,
    charged,
    paid,
    left: charged - paid,
    byStatus,
  };
}

/** Uy bo'yicha UMRBOD yakun (GET /houses uchun) — id -> {charged, paid, left}.
 *  Bekor qilingan hisob-kitob ham, unga biriktirilgan to'lov ham kirmaydi
 *  (chargeTotals bilan bir xil qoida). Taqsimlanmagan to'lov (charge_id null)
 *  har doim uy tushumiga kiradi. */
export function foldHouses(houses, charges = [], payments = []) {
  const byId = new Map(charges.map((c) => [c.id, c]));
  const totals = new Map(houses.map((h) => [h.id, { charged: 0, paid: 0, left: 0 }]));
  for (const c of charges) {
    if (c.status === 'bekor') continue;
    const t = totals.get(c.house_id);
    if (t) t.charged += Number(c.amount) || 0;
  }
  for (const p of payments) {
    // Bekor qilingan yozuvga biriktirilgan to'lov PULGA KIRMAYDI (charged ham 0).
    // Yuklanmagan (kesilgan) hisob-kitobga tegishli to'lov SANALADI — pulni
    // jimgina yo'qotgandan ko'ra ko'rsatgan yaxshiroq.
    if (p.charge_id && byId.get(p.charge_id)?.status === 'bekor') continue;
    const t = totals.get(p.house_id);
    if (t) t.paid += Number(p.amount) || 0;
  }
  for (const t of totals.values()) t.left = t.charged - t.paid;
  return totals;
}

/** Ro'yxat tartibi: oy, keyin muddat (muddatsizlar oxirida), keyin yaratilgan vaqt. */
export function sortCharges(rows) {
  return [...rows].sort((a, b) =>
    String(a.period).localeCompare(String(b.period))
    || String(a.due_date || '9999-12-31').localeCompare(String(b.due_date || '9999-12-31'))
    || String(a.created_at || '').localeCompare(String(b.created_at || '')));
}

// ============================ Obuna gate'i ============================
// Monetizatsiya SIMLARI src/lib/subscription.js EGASIDA — bu fayl unga TEGMAYDI,
// faqat READ-ONLY import qiladi. FREE_IJARA_CHARGES umumiy manbadan keladi:
// getModulesStatus() ham AYNAN shu konstantani `free_limit` sifatida qaytaradi va
// AYNAN shu sanoqni (`rent_charges`, status <> 'bekor') `used` deb ko'rsatadi —
// ya'ni mobil kartadagi "0/5" bilan bu yerdagi majburlash AJRALIB KETA OLMAYDI.

/** YANGI HISOB-KITOB kvotasi. O'qish (GET) hech qachon bloklanmaydi; uy qo'shish
 *  va TO'LOV kiritish ham ochiq — pul kirishi hech qachon to'sib qo'yilmasin
 *  (circles.js/toyxona.js siyosati). Faqat POST /charges sanaladi.
 *  'bekor' yozuvlar kvota YEMAYDI. */
function requireChargeQuota(req, res, next) {
  (async () => {
    if (await isModuleActive(req.user.id, 'ijarachi')) return next();
    // XAVFSIZLIK KLAPANI: 020 (module_subs) qo'llanmagan bo'lsa obunani SOTIB BO'LMAYDI,
    // demak kvota ham majburlanmaydi — aks holda 022 avval qo'llansa foydalanuvchi
    // 5-yozuvda to'lash imkoniyatisiz qulflanardi (review 2026-08-04).
    if (!(await isQuotaEnforceable(req.user.id))) return next();
    const { count, error } = await supabaseAdmin
      .from('rent_charges')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', req.user.id)
      .neq('status', 'bekor');
    if (error) throw new Error(error.message);
    if ((count || 0) < FREE_IJARA_CHARGES) return next();
    return res.status(402).json({
      success: false,
      code: 'SUB_EXPIRED',
      // `module` — mobil AYNAN shu modul paywall'ini ochadi (2026-08-04 kontrakt)
      module: 'ijarachi',
      error: `Bepul ${FREE_IJARA_CHARGES} ta hisob-kitob yozuvi ishlatildi — davom etish uchun obuna kerak ($${MODULES.ijarachi.price_usd}/oy)`,
    });
  })().catch(next);
}

// ============================ DB yordamchilari ============================

/** 022 dagi 5-uy triggeri ishga tushdimi? (parallel so'rovlar yo'li)
 *  Xom Postgres matni mijozga chiqmaydi — 403 + o'zbekcha xabarga aylanadi. */
export function isHouseLimitError(error) {
  const blob = `${error?.message || ''} ${error?.details || ''} ${error?.hint || ''}`;
  return /IJARA_HOUSE_LIMIT/.test(blob);
}

/** 5-uy chegarasi javobi. 402 EMAS, 403: bu QAT'IY chegara — obuna sotib olish
 *  uni OCHMAYDI, shuning uchun mobil paywall'ni ochmasligi kerak (402 + module
 *  aynan paywall signali). `limit`/`used` — ekranda "5/5" ko'rsatish uchun. */
function houseLimitBody(used = MAX_HOUSES) {
  return {
    success: false,
    code: 'HOUSE_LIMIT',
    limit: MAX_HOUSES,
    used,
    error: `Bitta hisobda ko'pi bilan ${MAX_HOUSES} ta uy bo'lishi mumkin — `
      + "ko'proq uy uchun boshqa telefon raqami bilan alohida hisob oching",
  };
}

/** Arxivlanmagan uylar soni (chegara sanog'i). */
async function activeHouseCount(userId) {
  const { count, error } = await supabaseAdmin
    .from('rent_houses')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('archived', false);
  if (error) throw new Error(error.message);   // sanoq yiqilsa chegara JIMGINA ochilmasin
  return count || 0;
}

/** Uy EGA'nikimi? Yo'q/begona bo'lsa null (404 "Topilmadi" — enumeratsiya yo'q). */
async function ownedHouse(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('rent_houses').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Hisob-kitob EGA'nikimi? */
async function ownedCharge(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('rent_charges').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** To'lov EGA'nikimi? */
async function ownedPayment(userId, id) {
  if (!isUuid(id)) return null;
  const { data, error } = await supabaseAdmin
    .from('rent_payments').select('*').eq('id', id).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.user_id !== userId) return null;
  return data;
}

/** Hisob-kitoblarning to'lovlarini TO'PLAB yuklaydi — N+1 YO'Q. */
async function loadPaymentsFor(chargeIds) {
  const paysBy = new Map();
  if (!chargeIds.length) return paysBy;
  const chunks = [];
  for (let i = 0; i < chargeIds.length; i += CHILD_CHUNK) {
    chunks.push(chargeIds.slice(i, i + CHILD_CHUNK));
  }
  const results = await Promise.all(chunks.map((ids) => supabaseAdmin
    .from('rent_payments')
    .select('id, house_id, charge_id, amount, paid_at, note, created_at')
    .in('charge_id', ids).order('paid_at')));
  for (const r of results) {
    if (r.error) throw new Error(r.error.message);
    for (const row of r.data || []) {
      const arr = paysBy.get(row.charge_id) || [];
      arr.push(row);
      paysBy.set(row.charge_id, arr);
    }
  }
  return paysBy;
}

/** Foydalanuvchining uylari: id -> nomi (bitta kichik so'rov). */
async function houseNameMap(userId) {
  const { data, error } = await supabaseAdmin
    .from('rent_houses').select('id, name').eq('user_id', userId).limit(MAX_HOUSE_LIST);
  if (error) throw new Error(error.message);
  return new Map((data || []).map((h) => [h.id, h.name]));
}

// ============================ Mobil KONTRAKTI ============================

function mapHouse(h, totals) {
  return {
    id: h.id,
    name: h.name,
    tenant_name: h.tenant_name,
    tenant_phone: h.tenant_phone,
    rent_amount: Number(h.rent_amount) || 0,
    archived: !!h.archived,
    sort: Number(h.sort) || 0,
    created_at: h.created_at,
    updated_at: h.updated_at,
    // HAR DOIM mavjud (yozuvsiz uyda nollar) — mobil `null` tekshiruvi qilmasin
    totals: totals || { charged: 0, paid: 0, left: 0 },
  };
}

function mapPayment(p) {
  return {
    id: p.id,
    house_id: p.house_id,
    charge_id: p.charge_id || null,
    amount: Number(p.amount) || 0,
    paid_at: p.paid_at,
    note: p.note,
    created_at: p.created_at,
  };
}

function mapCharge(c, houseName, payments = []) {
  return {
    id: c.id,
    house_id: c.house_id,
    house_name: houseName || null,
    period: c.period,
    kind: c.kind,
    title: c.title,
    amount: Number(c.amount) || 0,   // XOM summa (bekor bo'lsa ham ko'rinadi)
    due_date: c.due_date,
    status: c.status,
    created_at: c.created_at,
    updated_at: c.updated_at,
    payments: payments.map(mapPayment),
    totals: chargeTotals(c, payments),   // bekor -> hammasi 0
  };
}

/** Bitta hisob-kitobni to'lovlari bilan qayta yuklab qaytaradi (mutatsiyalardan
 *  keyin: mobil ro'yxatdagi qatorni shundoq almashtiradi). */
async function loadOneCharge(userId, chargeId) {
  const { data: c, error } = await supabaseAdmin
    .from('rent_charges').select('*').eq('id', chargeId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!c || c.user_id !== userId) return null;
  const [paysBy, houses] = await Promise.all([
    loadPaymentsFor([c.id]),
    houseNameMap(userId),
  ]);
  return mapCharge(c, houses.get(c.house_id), paysBy.get(c.id) || []);
}

/** To'lov qo'shilgach/o'chirilgach hisob-kitob statusini qayta hisoblaydi.
 *  XATO YUTILADI (throw EMAS): to'lov qatori ALLAQACHON yozilgan/o'chirilgan —
 *  bu yerda 500 bersak mijoz qayta yuborardi va PUL IKKI MARTA yozilardi
 *  (toyxona.js dagi 2026-08-04 review saboqi). Status noto'g'ri qolsa egasi
 *  oddiy PATCH bilan tuzatadi. */
async function refreshChargeStatus(userId, chargeId) {
  if (!chargeId) return;
  const full = await loadOneCharge(userId, chargeId);
  if (!full || full.status === 'bekor') return;
  const next = autoChargeStatus(full.status, full.totals.left);
  if (next === full.status) return;
  const { error } = await supabaseAdmin.from('rent_charges')
    .update({ status: next, updated_at: new Date().toISOString() })
    .eq('id', chargeId).eq('user_id', userId);
  if (error) console.warn(`[ijara] status yangilanmadi (charge=${chargeId}):`, error.message);
}

// ============================ UYLAR (houses) ============================

// GET /api/ijara/houses — arxivlanganlar ham qaytadi (mobil o'zi filtrlaydi).
// Har uyda UMRBOD yakun: totals { charged, paid, left }.
router.get('/houses', async (req, res, next) => {
  try {
    const [housesRes, chargesRes, paysRes] = await Promise.all([
      supabaseAdmin.from('rent_houses').select('*').eq('user_id', req.user.id)
        .order('sort').order('created_at').limit(MAX_HOUSE_LIST),
      supabaseAdmin.from('rent_charges').select('id, house_id, amount, status')
        .eq('user_id', req.user.id).order('period').limit(MAX_HOUSE_ROWS),
      supabaseAdmin.from('rent_payments').select('id, house_id, charge_id, amount')
        .eq('user_id', req.user.id).order('paid_at').limit(MAX_HOUSE_ROWS),
    ]);
    if (housesRes.error) throw new Error(housesRes.error.message);
    if (chargesRes.error) throw new Error(chargesRes.error.message);
    if (paysRes.error) throw new Error(paysRes.error.message);

    const houses = housesRes.data || [];
    const totals = foldHouses(houses, chargesRes.data || [], paysRes.data || []);
    res.json({
      success: true,
      data: houses.map((h) => mapHouse(h, totals.get(h.id))),
      // QAT'IY chegara holati — mobil "3/5" va "qo'shish" tugmasini shu bilan chizadi
      limit: {
        max_houses: MAX_HOUSES,
        used: houses.filter((h) => !h.archived).length,
      },
      // Yakun to'liq emasligi belgisi (juda uzoq tarixda)
      truncated: houses.length >= MAX_HOUSE_LIST
        || (chargesRes.data || []).length >= MAX_HOUSE_ROWS
        || (paysRes.data || []).length >= MAX_HOUSE_ROWS,
    });
  } catch (e) { next(e); }
});

// POST /api/ijara/houses  { name, tenant_name?, tenant_phone?, rent_amount? }
// 5 TA UY — QAT'IY CHEGARA (403). Ikki qatlam: bu tekshiruv + 022 dagi trigger.
router.post('/houses', async (req, res, next) => {
  try {
    const name = clean(req.body?.name, 80);
    if (!name) return res.status(400).json({ success: false, error: 'Uy nomi kerak' });
    const tenant_name = clean(req.body?.tenant_name, 80);
    const tenant_phone = clean(req.body?.tenant_phone, 20);

    let rent_amount = 0;
    if (req.body?.rent_amount != null && req.body.rent_amount !== '') {
      rent_amount = money(req.body.rent_amount, { allowZero: true });
      if (rent_amount == null) {
        return res.status(400).json({ success: false, error: "Ijara summasi noto'g'ri" });
      }
    }

    const used = await activeHouseCount(req.user.id);
    if (used >= MAX_HOUSES) return res.status(403).json(houseLimitBody(used));

    // sort — ro'yxat oxiriga (mobil keyin PATCH bilan qayta tartiblashi mumkin)
    const { count, error: ce } = await supabaseAdmin
      .from('rent_houses').select('id', { count: 'exact', head: true }).eq('user_id', req.user.id);
    if (ce) throw new Error(ce.message);

    const { data, error } = await supabaseAdmin.from('rent_houses').insert({
      user_id: req.user.id, name, tenant_name, tenant_phone, rent_amount, sort: count || 0,
    }).select().single();
    if (error) {
      // 2-qatlam: parallel so'rov yuqoridagi sanoqni chetlab o'tgan bo'lsa trigger to'sadi
      if (isHouseLimitError(error)) return res.status(403).json(houseLimitBody(MAX_HOUSES));
      throw new Error(error.message);
    }
    res.status(201).json({ success: true, data: mapHouse(data, null) });
  } catch (e) { next(e); }
});

// PATCH /api/ijara/houses/:id
//   { name?, tenant_name?, tenant_phone?, rent_amount?, archived?, sort? }
// QAT'IY o'chirish YO'Q — arxivlash (tarix va pul yakuni yo'qolmasin).
router.patch('/houses/:id', async (req, res, next) => {
  try {
    const house = await ownedHouse(req.user.id, req.params.id);
    if (!house) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const b = req.body || {};
    const patch = {};
    if (b.name !== undefined) {
      const n = clean(b.name, 80);
      if (!n) return res.status(400).json({ success: false, error: 'Uy nomi kerak' });
      patch.name = n;
    }
    // Ijarachi almashishi ODATIY hol — bo'sh qiymat "tozalash" demakdir
    if (b.tenant_name !== undefined) patch.tenant_name = clean(b.tenant_name, 80);
    if (b.tenant_phone !== undefined) patch.tenant_phone = clean(b.tenant_phone, 20);
    if (b.rent_amount !== undefined) {
      const a = money(b.rent_amount, { allowZero: true });
      if (a == null) return res.status(400).json({ success: false, error: "Ijara summasi noto'g'ri" });
      patch.rent_amount = a;
    }
    if (b.archived !== undefined) patch.archived = !!b.archived;
    if (b.sort !== undefined) {
      const s = Math.round(Number(b.sort));
      if (!Number.isInteger(s) || s < 0 || s > 1000) {
        return res.status(400).json({ success: false, error: "Tartib noto'g'ri" });
      }
      patch.sort = s;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }

    // ARXIVDAN QAYTARISH ham chegaraga kiradi: aks holda ega 5 ta faol uy ustiga
    // eskisini tiklab 6 tada ishlayverardi (chegarani chetlab o'tishning eng oson yo'li).
    if (patch.archived === false && house.archived) {
      const used = await activeHouseCount(req.user.id);
      if (used >= MAX_HOUSES) return res.status(403).json(houseLimitBody(used));
    }

    patch.updated_at = new Date().toISOString();
    const { data, error } = await supabaseAdmin
      .from('rent_houses').update(patch).eq('id', house.id).select().single();
    if (error) {
      if (isHouseLimitError(error)) return res.status(403).json(houseLimitBody(MAX_HOUSES));
      throw new Error(error.message);
    }
    res.json({ success: true, data: mapHouse(data, null) });
  } catch (e) { next(e); }
});

// ============================ HISOB-KITOB (charges) ============================

// GET /api/ijara/charges?from=YYYY-MM-DD&to=YYYY-MM-DD&house_id=<uuid>
// from/to berilmasa — Toshkent vaqtidagi JORIY OY.
// DIQQAT: hisob-kitoblar OY (period) bo'yicha filtrlanadi — from/to ularning OYIGA
// keltiriladi. Sabab: due_date IXTIYORIY, sana bo'yicha filtr muddatsiz yozuvlarni
// JIMGINA yo'qotardi. Taqsimlanmagan to'lovlar esa paid_at bo'yicha (Toshkent kuni).
router.get('/charges', async (req, res, next) => {
  try {
    const range = readRange(req.query);
    if (range.error) return res.status(400).json({ success: false, error: range.error });
    const houseFilter = readHouseFilter(req.query);
    if (houseFilter.error) return res.status(400).json({ success: false, error: houseFilter.error });

    let q = supabaseAdmin
      .from('rent_charges').select('*')
      .eq('user_id', req.user.id)
      .gte('period', range.fromPeriod).lte('period', range.toPeriod);
    if (houseFilter.houseId) q = q.eq('house_id', houseFilter.houseId);
    const { data, error } = await q.order('period').order('created_at').limit(MAX_CHARGES);
    if (error) throw new Error(error.message);

    const rows = sortCharges(data || []);

    // Taqsimlanmagan to'lovlar (charge_id NULL) — oraliqdagi HAQIQIY tushum
    let uq = supabaseAdmin
      .from('rent_payments')
      .select('id, house_id, charge_id, amount, paid_at, note, created_at')
      .eq('user_id', req.user.id).is('charge_id', null)
      .gte('paid_at', `${range.from}T00:00:00${TZ_SUFFIX}`)
      .lte('paid_at', `${range.to}T23:59:59.999${TZ_SUFFIX}`);
    if (houseFilter.houseId) uq = uq.eq('house_id', houseFilter.houseId);

    const [paysBy, unallocRes, houses] = await Promise.all([
      loadPaymentsFor(rows.map((c) => c.id)),
      uq.order('paid_at').limit(MAX_PAYMENTS),
      houseNameMap(req.user.id),
    ]);
    if (unallocRes.error) throw new Error(unallocRes.error.message);
    const unallocated = unallocRes.data || [];

    res.json({
      success: true,
      data: rows.map((c) => mapCharge(c, houses.get(c.house_id), paysBy.get(c.id) || [])),
      unallocated: unallocated.map(mapPayment),
      totals: foldCharges(rows, paysBy, unallocated),
      range: {
        from: range.from, to: range.to,
        period_from: range.fromPeriod, period_to: range.toPeriod,
        house_id: houseFilter.houseId,
      },
      // Chegaraga tegdi — mobil oraliqni toraytirishi yoki house_id qo'yishi kerak
      // (JIMGINA kesilgan ro'yxat pul yakunini kam ko'rsatardi)
      truncated: rows.length >= MAX_CHARGES || unallocated.length >= MAX_PAYMENTS,
    });
  } catch (e) { next(e); }
});

// POST /api/ijara/charges
//   { house_id, amount?, period?, kind?, title?, due_date? }
// KVOTA NUQTASI: bepul FREE_IJARA_CHARGES ta yozuv, keyin 402 + module:'ijarachi'.
// amount berilmasa — uyning rent_amount defaulti (faqat kind='ijara' uchun mantiqiy,
// lekin qoida barcha turlarga bir xil: aniq summa har doim ustun).
router.post('/charges', requireChargeQuota, async (req, res, next) => {
  try {
    const b = req.body || {};
    const house = await ownedHouse(req.user.id, b.house_id);
    if (!house) return res.status(400).json({ success: false, error: 'Uy topilmadi' });

    const kind = b.kind == null || b.kind === '' ? 'ijara' : String(b.kind);
    if (!KINDS.includes(kind)) {
      return res.status(400).json({ success: false, error: "Tur noto'g'ri (ijara / kommunal / boshqa)" });
    }

    let due_date = null;
    if (b.due_date != null && b.due_date !== '') {
      due_date = String(b.due_date);
      if (!isDateStr(due_date)) {
        return res.status(400).json({ success: false, error: "Muddat noto'g'ri (YYYY-MM-DD)" });
      }
    }

    // period: aniq berilgan > muddat oyi > Toshkent joriy oyi
    let period;
    if (b.period != null && b.period !== '') {
      period = String(b.period);
      if (!isPeriodStr(period)) {
        return res.status(400).json({ success: false, error: "Oy noto'g'ri (YYYY-MM)" });
      }
    } else {
      period = due_date ? periodOf(due_date) : currentPeriod();
    }

    // Summa: aniq berilgan > uyning ijara haqi. Nol/bo'sh summa yozuv sifatida
    // ma'nosiz — 0 hech qachon qabul qilinmaydi (022 dagi check bilan bir xil).
    let amount;
    if (b.amount != null && b.amount !== '') {
      amount = money(b.amount);
      if (amount == null) {
        return res.status(400).json({ success: false, error: "Summa musbat butun son bo'lishi kerak" });
      }
    } else {
      amount = Number(house.rent_amount) || 0;
      if (amount <= 0) {
        return res.status(400).json({ success: false, error: "Summa kerak (uyda ijara haqi belgilanmagan)" });
      }
    }
    const title = clean(b.title, 120);

    const { data: created, error } = await supabaseAdmin.from('rent_charges').insert({
      user_id: req.user.id, house_id: house.id, period, kind, title, amount, due_date,
    }).select().single();
    if (error) throw new Error(error.message);

    res.status(201).json({ success: true, data: await loadOneCharge(req.user.id, created.id) });
  } catch (e) { next(e); }
});

// PATCH /api/ijara/charges/:id  { period?, kind?, title?, amount?, due_date?, status? }
// Qo'lda berilgan status HAR DOIM ustun. Summa o'zgarsa va status berilmagan bo'lsa —
// status qayta hisoblanadi (aks holda summa tushirilgan yozuv to'langan bo'lib
// turgani holda 'kutilmoqda' bo'lib qolardi va aksincha).
router.patch('/charges/:id', async (req, res, next) => {
  try {
    const cur = await ownedCharge(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const b = req.body || {};
    const patch = {};
    if (b.period !== undefined) {
      const p = String(b.period || '');
      if (!isPeriodStr(p)) return res.status(400).json({ success: false, error: "Oy noto'g'ri (YYYY-MM)" });
      patch.period = p;
    }
    if (b.kind !== undefined) {
      const k = String(b.kind || '');
      if (!KINDS.includes(k)) {
        return res.status(400).json({ success: false, error: "Tur noto'g'ri (ijara / kommunal / boshqa)" });
      }
      patch.kind = k;
    }
    if (b.title !== undefined) patch.title = clean(b.title, 120);
    if (b.amount !== undefined) {
      const a = money(b.amount);
      if (a == null) {
        return res.status(400).json({ success: false, error: "Summa musbat butun son bo'lishi kerak" });
      }
      patch.amount = a;
    }
    if (b.due_date !== undefined) {
      if (b.due_date === null || b.due_date === '') patch.due_date = null;
      else {
        const d = String(b.due_date);
        if (!isDateStr(d)) return res.status(400).json({ success: false, error: "Muddat noto'g'ri (YYYY-MM-DD)" });
        patch.due_date = d;
      }
    }
    if (b.status !== undefined) {
      const s = String(b.status || '');
      if (!STATUSES.includes(s)) return res.status(400).json({ success: false, error: "Holat noto'g'ri" });
      patch.status = s;
    }
    if (!Object.keys(patch).length) {
      return res.status(400).json({ success: false, error: "O'zgarish yo'q" });
    }

    patch.updated_at = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('rent_charges').update(patch).eq('id', cur.id).eq('user_id', req.user.id);
    if (error) throw new Error(error.message);

    // PATCH orqali bekor qilinsa ham to'lovlar uziladi — DELETE bilan bir xil yo'l
    // (aks holda pul yakunlardan yo'qolardi; review 2026-08-04, HIGH).
    if (patch.status === 'bekor' && cur.status !== 'bekor') {
      await detachPaymentsOf(req.user.id, cur.id);
    }
    // Summa o'zgardi, status qo'lda berilmadi -> to'lovlarga qarab qayta hisoblanadi
    if (patch.amount !== undefined && patch.status === undefined) {
      await refreshChargeStatus(req.user.id, cur.id);
    }
    res.json({ success: true, data: await loadOneCharge(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// Yozuv bekor qilinganda unga biriktirilgan to'lovlar UZILADI (charge_id -> null).
// SABAB (review 2026-08-04, HIGH): bekor qilingan yozuv pul yakuniga kirmaydi, lekin
// to'lov qatorlari o'sha yozuvga bog'liq bo'lib qolardi — natijada egasi QO'LIGA OLGAN
// pul barcha yakunlardan (yozuv, davr, uy) YO'QOLARDI, ekranda esa to'lovlar ro'yxatida
// to'liq summa turaverardi. Uzilgandan keyin ular TAQSIMLANMAGAN tushum bo'lib qoladi:
// pul hech qayerga yo'qolmaydi (modulning asosiy qoidasi).
async function detachPaymentsOf(userId, chargeId) {
  const { error } = await supabaseAdmin.from('rent_payments')
    .update({ charge_id: null, updated_at: new Date().toISOString() })
    .eq('charge_id', chargeId).eq('user_id', userId);
  if (error) throw new Error(error.message);
}

// DELETE /api/ijara/charges/:id — YUMSHOQ bekor qilish (status: 'bekor').
// QAT'IY o'chirish YO'Q: tarix va unga biriktirilgan to'lovlar yo'qolmasin.
// Bekor qilingan yozuv KVOTA YEMAYDI (sanoq status <> 'bekor' bo'yicha) va pul
// yakuniga kirmaydi. Tiklash: PATCH { status: 'kutilmoqda' }.
router.delete('/charges/:id', async (req, res, next) => {
  try {
    const cur = await ownedCharge(req.user.id, req.params.id);
    if (!cur) return res.status(404).json({ success: false, error: 'Topilmadi' });
    const { error } = await supabaseAdmin.from('rent_charges')
      .update({ status: 'bekor', updated_at: new Date().toISOString() })
      .eq('id', cur.id).eq('user_id', req.user.id);
    if (error) throw new Error(error.message);
    await detachPaymentsOf(req.user.id, cur.id);
    res.json({ success: true, data: await loadOneCharge(req.user.id, cur.id) });
  } catch (e) { next(e); }
});

// ============================ TO'LOVLAR (payments) ============================

// POST /api/ijara/payments  { charge_id? | house_id, amount, paid_at?, note? }
// charge_id berilsa — uy o'sha yozuvdan olinadi va status qayta hisoblanadi
// ('tolangan' / 'kutilmoqda'). charge_id berilmasa — TAQSIMLANMAGAN to'lov
// (oldindan/aralash to'lov); u uy yakunida tushum sifatida qatnashadi.
// KVOTA YO'Q: pul kirishi hech qachon to'sib qo'yilmasin.
router.post('/payments', async (req, res, next) => {
  try {
    const b = req.body || {};

    let charge = null;
    let houseId = null;
    if (b.charge_id != null && b.charge_id !== '') {
      charge = await ownedCharge(req.user.id, b.charge_id);
      if (!charge) return res.status(400).json({ success: false, error: 'Hisob-kitob topilmadi' });
      houseId = charge.house_id;
      // Uy ham berilgan bo'lsa — mos kelishi shart (mobil xatosi jimgina o'tmasin).
      // Solishtirish REGISTRSIZ: uuid katta harflar bilan kelsa soxta 400 bermasin.
      if (b.house_id != null && b.house_id !== ''
        && String(b.house_id).toLowerCase() !== String(houseId).toLowerCase()) {
        return res.status(400).json({ success: false, error: 'Hisob-kitob boshqa uyga tegishli' });
      }
    } else {
      const house = await ownedHouse(req.user.id, b.house_id);
      if (!house) return res.status(400).json({ success: false, error: 'Uy topilmadi' });
      houseId = house.id;
    }

    const amount = money(b.amount);
    if (amount == null) {
      return res.status(400).json({ success: false, error: "Summa musbat butun son bo'lishi kerak" });
    }
    const note = clean(b.note, 200);

    let paid_at = null;
    if (b.paid_at != null && b.paid_at !== '') {
      const ts = Date.parse(String(b.paid_at).slice(0, 40));
      if (Number.isNaN(ts)) return res.status(400).json({ success: false, error: "To'lov sanasi noto'g'ri" });
      paid_at = new Date(ts).toISOString();
    }

    if (charge) {
      const { count, error: ce } = await supabaseAdmin
        .from('rent_payments').select('id', { count: 'exact', head: true }).eq('charge_id', charge.id);
      if (ce) throw new Error(ce.message);
      if ((count || 0) >= MAX_PAYMENTS_PER_CHARGE) {
        return res.status(400).json({
          success: false,
          error: `Bitta yozuvga ${MAX_PAYMENTS_PER_CHARGE} tadan ortiq to'lov qo'shib bo'lmaydi`,
        });
      }
    }

    // TAKROR TO'LOVDAN HIMOYA (review 2026-08-04, #10). Render sovuq startda
    // javob mobil timeout'idan (20s) kechikishi mumkin; mobil esa foydalanuvchiga
    // ATAYLAB "qayta urinib ko'ring" deydi. So'rov aslida bajarilgan bo'lsa,
    // takror urinish AYNAN o'sha to'lovni IKKINCHI marta yozardi — pul ikki barobar
    // ko'rinardi. Shu bois qisqa oynada (DEDUP_MS) bir xil (uy + yozuv + summa)
    // to'lov qayta yozilmaydi: mavjudi qaytariladi (idempotent).
    // Haqiqatan ikkita bir xil to'lovni ketma-ket kiritish kerak bo'lsa —
    // oynadan keyin kiritiladi; pulni ikki marta sanagandan ko'ra shu yaxshiroq.
    const dupSince = new Date(Date.now() - DEDUP_MS).toISOString();
    let dupQ = supabaseAdmin
      .from('rent_payments').select('*')
      .eq('user_id', req.user.id).eq('house_id', houseId).eq('amount', amount)
      .gte('created_at', dupSince).limit(1);
    dupQ = charge?.id ? dupQ.eq('charge_id', charge.id) : dupQ.is('charge_id', null);
    const { data: dup } = await dupQ;
    if (dup && dup.length) {
      return res.status(200).json({
        success: true,
        data: mapPayment(dup[0]),
        charge: charge ? await loadOneCharge(req.user.id, charge.id) : null,
        deduped: true,
      });
    }

    const row = {
      user_id: req.user.id, house_id: houseId, charge_id: charge?.id || null, amount, note,
    };
    if (paid_at) row.paid_at = paid_at;
    const { data: created, error } = await supabaseAdmin
      .from('rent_payments').insert(row).select().single();
    if (error) throw new Error(error.message);

    // Status faqat biriktirilgan to'lovda o'zgaradi (xato YUTILADI — izohga qarang)
    await refreshChargeStatus(req.user.id, charge?.id || null);

    res.status(201).json({
      success: true,
      data: mapPayment(created),
      // Biriktirilgan bo'lsa — yangilangan yozuv ham qaytadi (mobil qatorni almashtiradi)
      charge: charge ? await loadOneCharge(req.user.id, charge.id) : null,
    });
  } catch (e) { next(e); }
});

// DELETE /api/ijara/payments/:id — to'lovni olib tashlash (xato kiritish odatiy hol).
// Biriktirilgan bo'lsa hisob-kitob statusi QAYTA hisoblanadi: 'tolangan' bo'lib
// qolgan yozuv yana 'kutilmoqda' ga tushadi (qarz jimgina yashirilmasin).
router.delete('/payments/:id', async (req, res, next) => {
  try {
    const pay = await ownedPayment(req.user.id, req.params.id);
    if (!pay) return res.status(404).json({ success: false, error: 'Topilmadi' });

    const { error } = await supabaseAdmin
      .from('rent_payments').delete().eq('id', pay.id).eq('user_id', req.user.id);
    if (error) throw new Error(error.message);

    await refreshChargeStatus(req.user.id, pay.charge_id || null);

    res.json({
      success: true,
      charge: pay.charge_id ? await loadOneCharge(req.user.id, pay.charge_id) : null,
    });
  } catch (e) { next(e); }
});

// ============================ YAKUN (summary) ============================

// GET /api/ijara/summary?from=&to=&house_id=
//   -> { count, countActive, charged, paid, left, byStatus }
// 'bekor' yozuvlar PULGA kirmaydi (`count` esa ularni ham sanaydi — shuning uchun
// `countActive` ham qaytariladi, mijoz o'zi ayirmasin).
router.get('/summary', async (req, res, next) => {
  try {
    const range = readRange(req.query);
    if (range.error) return res.status(400).json({ success: false, error: range.error });
    const houseFilter = readHouseFilter(req.query);
    if (houseFilter.error) return res.status(400).json({ success: false, error: houseFilter.error });

    let q = supabaseAdmin
      .from('rent_charges').select('id, house_id, amount, status')
      .eq('user_id', req.user.id)
      .gte('period', range.fromPeriod).lte('period', range.toPeriod);
    if (houseFilter.houseId) q = q.eq('house_id', houseFilter.houseId);
    // `.order()` SHART: tartibsiz `.limit()` da Postgres ixtiyoriy qatorlarni
    // qaytaradi — /charges va /summary bir oraliq uchun HAR XIL pul ko'rsatishi
    // mumkin edi. Ikkalasi ham period bo'yicha tartiblangan.
    const { data, error } = await q.order('period').order('created_at').limit(MAX_SUMMARY_CHARGES);
    if (error) throw new Error(error.message);

    const rows = data || [];
    const truncated = rows.length >= MAX_SUMMARY_CHARGES;

    let uq = supabaseAdmin
      .from('rent_payments').select('id, amount')
      .eq('user_id', req.user.id).is('charge_id', null)
      .gte('paid_at', `${range.from}T00:00:00${TZ_SUFFIX}`)
      .lte('paid_at', `${range.to}T23:59:59.999${TZ_SUFFIX}`);
    if (houseFilter.houseId) uq = uq.eq('house_id', houseFilter.houseId);

    const [paysBy, unallocRes] = await Promise.all([
      loadPaymentsFor(rows.map((c) => c.id)),
      uq.order('paid_at').limit(MAX_PAYMENTS),
    ]);
    if (unallocRes.error) throw new Error(unallocRes.error.message);

    // Kesilgan bo'lsa rows.length HAQIQIY sonni bildirmaydi (u shunchaki shift) —
    // "N yozuv" sarlavhasi jimgina yolg'on gapirardi. Haqiqiy sonni alohida
    // head-so'rov bilan olamiz (faqat kesilganda — ortiqcha so'rov qilmaymiz).
    const summary = foldCharges(rows, paysBy, unallocRes.data || []);
    if (truncated) {
      let cq = supabaseAdmin
        .from('rent_charges').select('id', { count: 'exact', head: true })
        .eq('user_id', req.user.id)
        .gte('period', range.fromPeriod).lte('period', range.toPeriod);
      if (houseFilter.houseId) cq = cq.eq('house_id', houseFilter.houseId);
      const { count, error: ce } = await cq;
      if (ce) throw new Error(ce.message);
      summary.count = count || 0;
    }

    res.json({
      success: true,
      data: summary,
      range: {
        from: range.from, to: range.to,
        period_from: range.fromPeriod, period_to: range.toPeriod,
        house_id: houseFilter.houseId,
      },
      truncated,   // yakun to'liq emasligi belgisi
    });
  } catch (e) { next(e); }
});

export default router;
