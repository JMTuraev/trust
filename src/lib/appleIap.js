// Apple App Store — auto-renewable obuna chekini server tomonda tekshirish (verifyReceipt).
//
// Mobil (in_app_purchase, StoreKit 1) `serverVerificationData` — base64 app receipt — yuboradi.
// Biz uni AVVAL production endpoint'ga POST qilamiz; Apple 21007 qaytarsa (sandbox cheki
// production'ga kelgan) — sandbox'ga qayta yuboramiz. Shu bitta oqim TestFlight, App Review
// (sandbox) VA haqiqiy do'kon xaridlarini bir xil ishlatadi (Apple tavsiyasi).
//
// XAVFSIZLIK: APPLE_SHARED_SECRET (App-Specific Shared Secret, App Store Connect'da
// yaratiladi) FAQAT serverda (Render env) turadi — mobilga chiqmaydi. O'rnatilmasa
// appleConfigured()=false va endpoint 501 qaytaradi (bypass yo'q).
const PROD_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

/** APPLE_SHARED_SECRET o'rnatilganmi? (endpoint shu bilan yoqiladi) */
export function appleConfigured() {
  return !!(process.env.APPLE_SHARED_SECRET && process.env.APPLE_SHARED_SECRET.trim());
}

async function postReceipt(url, receipt) {
  // Node 18+ global fetch (package.json engines: >=18). AbortController bilan 15s timeout.
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15_000);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        'receipt-data': receipt,
        password: process.env.APPLE_SHARED_SECRET.trim(),
        // Faqat oxirgi (amaldagi) tranzaksiyani qaytar — javob kichik bo'ladi.
        'exclude-old-transactions': true,
      }),
      signal: ctl.signal,
    });
    if (!res.ok) throw new Error(`Apple verifyReceipt HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Chekni tekshiradi va bizning mahsulotimiz uchun eng katta (amaldagi) tugash vaqtini topadi.
 * @param {string} receipt  base64 app receipt (mobil yuboradi)
 * @param {string} wantProductId  masalan 'trust_premium_monthly'
 * @returns {Promise<{ok:boolean, status:number, expiryMs:number, txnId:string|null, productIds:string[]}>}
 *   ok=false  => chek yaroqsiz (status Apple kodi: 21002 buzilgan, 21004 secret mos emas, ...).
 *   expiryMs  => 0 bo'lsa bizning mahsulot uchun tranzaksiya topilmadi.
 */
export async function verifyAppleReceipt(receipt, wantProductId) {
  let data = await postReceipt(PROD_URL, receipt);
  // 21007 — sandbox cheki production'ga yuborilgan: sandbox'da qayta tekshiramiz.
  if (data && data.status === 21007) data = await postReceipt(SANDBOX_URL, receipt);
  // 21008 — production cheki sandbox'ga yuborilgan (biz prod'dan boshlaymiz, kamdan-kam): prod'da.
  else if (data && data.status === 21008) data = await postReceipt(PROD_URL, receipt);

  if (!data || data.status !== 0) {
    return { ok: false, status: data ? data.status : -1, expiryMs: 0, txnId: null, originalTxnId: null, productIds: [] };
  }

  // MUHIM (2026-08-02 audit): chek BIZNING ilovamiznikimi? Apple'ning o'z tavsiyasi.
  // APPLE_SHARED_SECRET tasodifan akkaunt darajasidagi (master) secret qo'yilsa, o'sha
  // developer akkauntидagi BOSHQA ilovaning cheki ham status:0 bilan o'tib ketardi.
  const wantBundle = (process.env.APPLE_BUNDLE_ID || '').trim();
  const gotBundle = data.receipt && data.receipt.bundle_id;
  if (wantBundle && gotBundle && gotBundle !== wantBundle) {
    return { ok: false, status: -2, expiryMs: 0, txnId: null, originalTxnId: null, productIds: [] };
  }

  // latest_receipt_info — barcha auto-renew davrlari. Eng katta expires_date_ms = amaldagi tugash.
  // in_app — dastlabki xaridlar (yangi obunada latest bo'sh bo'lsa fallback).
  const infos = [
    ...(Array.isArray(data.latest_receipt_info) ? data.latest_receipt_info : []),
    ...(data.receipt && Array.isArray(data.receipt.in_app) ? data.receipt.in_app : []),
  ];
  let expiryMs = 0;
  let txnId = null;
  let originalTxnId = null;
  for (const it of infos) {
    if (wantProductId && it.product_id !== wantProductId) continue;
    const ex = parseInt(it.expires_date_ms || '0', 10);
    if (ex > expiryMs) {
      expiryMs = ex;
      txnId = it.transaction_id || it.original_transaction_id || null;
      // original_transaction_id — obuna BARQAROR identifikatori (yangilanishda o'zgarmaydi).
      // Akkauntga bog'lash uchun shu ishlatiladi (bitta chek = bitta akkaunt).
      originalTxnId = it.original_transaction_id || it.transaction_id || null;
    }
  }
  const productIds = [...new Set(infos.map((i) => i.product_id).filter(Boolean))];
  return { ok: true, status: 0, expiryMs, txnId, originalTxnId, productIds };
}
