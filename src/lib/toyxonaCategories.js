// TO'YXONA — SERVIS KATEGORIYALARI (025 migratsiya, PO 2026-09-09).
//
// PLATFORMA belgilaydigan ro'yxat. To'yxonachi kategoriya YARATA OLMAYDI — u
// faqat kategoriya ICHINI to'ldiradi (masalan "Musiqa" biznikidir, ichidagi
// "Ansambl Navro'z — 4 000 000" eganiki). Sabab: kategoriya nomi 6 tilda
// ko'rsatiladi, har biriga ikonka va gradient biriktirilgan, bron varaqasi ham
// shu tartibda chiqadi — buni ega kiritadigan erkin matnga tayanib qurib
// bo'lmaydi.
//
// BU FAYL — HAQIQAT MANBAI (validatsiya shu yerda). Mobil tomonda ayni
// slug'lar `mobile/lib/toyxona_data.dart` → kToyServiceCats da takrorlanadi
// (nom + ikonka + rang o'sha yerda, chunki ular ilova ichidagi resurslar).
// YANGI KATEGORIYA QO'SHILSA IKKALA RO'YXATNI ham yangilang; mobil tanimagan
// slug'ni 'boshqa' sifatida ko'rsatadi, ya'ni eski ilova YIQILMAYDI.
//
// TARTIB MUHIM: mobil grid shu ketma-ketlikda chiziladi (sort maydoni yo'q).
// 'boshqa' HAR DOIM oxirgi — eski (kategoriyasiz) qatorlar shu yerga tushadi.

/** unit — narx BIRLIGI maslahati (formadagi izoh; hisobga TA'SIR QILMAYDI):
 *    'guest' kishi boshiga · 'piece' dona · 'set' paket · 'hour' soat · 'once' bir marta */
export const TOY_SERVICE_CATEGORIES = [
  { slug: 'taomnoma',   unit: 'guest' },  // osh, kabob, milliy/evropacha set
  { slug: 'tort',       unit: 'piece' },  // to'y torti, mini tortlar
  { slug: 'ichimlik',   unit: 'guest' },  // choy, suv, sharbat
  { slug: 'musiqa',     unit: 'once'  },  // xonanda, ansambl, karnay-surnay, DJ
  { slug: 'boshlovchi', unit: 'once'  },  // tamada, ikki tilli boshlovchi
  { slug: 'shou',       unit: 'once'  },  // raqs guruhi, olov shou, illyuziya
  { slug: 'foto',       unit: 'set'   },  // fotograf, videograf, dron
  { slug: 'bezak',      unit: 'set'   },  // sahna/stol bezagi, gullar, sharlar
  { slug: 'yoruglik',   unit: 'once'  },  // svet-shou, LED ekran, ovoz apparaturasi
  { slug: 'salyut',     unit: 'piece' },  // sovuq olov, salyut, fontan
  { slug: 'gozallik',   unit: 'set'   },  // vizajist, sartarosh, libos ijarasi
  { slug: 'transport',  unit: 'hour'  },  // limuzin, kortej, mehmon avtobusi
  { slug: 'taklifnoma', unit: 'piece' },  // taklifnoma, stol kartochkalari
  { slug: 'sovga',      unit: 'piece' },  // bomboniyerka, esdalik
  { slug: 'xizmat',     unit: 'once'  },  // ofitsiant, xavfsizlik, parkovka
  { slug: 'bolalar',    unit: 'hour'  },  // animator, batut, bolalar burchagi
  { slug: 'zal',        unit: 'piece' },  // qo'shimcha stol, VIP xona, taxt
  { slug: 'boshqa',     unit: 'once'  },  // ZAXIRA — har doim oxirgi
];

/** Zaxira kategoriya: noma'lum/bo'sh slug shu yerga tushadi. */
export const TOY_DEFAULT_CATEGORY = 'boshqa';

const SET = new Set(TOY_SERVICE_CATEGORIES.map((c) => c.slug));

/** Ro'yxatdagi slug'mi? */
export function isToyCategory(slug) {
  return typeof slug === 'string' && SET.has(slug);
}

/** Kiruvchi qiymatni xavfsiz slug'ga keltiradi (noma'lum → null, bo'sh → default). */
export function normToyCategory(v) {
  if (v == null || v === '') return TOY_DEFAULT_CATEGORY;
  const s = String(v).trim().toLowerCase();
  return SET.has(s) ? s : null;   // null = 400 (mijozga xato qaytariladi)
}

/** Kategoriya tartib raqami (ro'yxatlashda saralash uchun). */
export function toyCategoryOrder(slug) {
  const i = TOY_SERVICE_CATEGORIES.findIndex((c) => c.slug === slug);
  return i < 0 ? TOY_SERVICE_CATEGORIES.length : i;
}

// Nomlar — mijoz tomoni (kelajakdagi veb bron sahifasi) uchun. Mobil ilova
// bularni ISHLATMAYDI: unda o'z l10n lug'ati bor (6 til).
export const TOY_CATEGORY_NAMES = {
  taomnoma:   { uz: 'Taomnoma',            ru: 'Меню',                  en: 'Menu' },
  tort:       { uz: 'Tort',                ru: 'Торт',                  en: 'Cake' },
  ichimlik:   { uz: 'Ichimliklar',         ru: 'Напитки',               en: 'Drinks' },
  musiqa:     { uz: 'Musiqa va sozandalar',ru: 'Музыка и музыканты',    en: 'Music & bands' },
  boshlovchi: { uz: 'Boshlovchi',          ru: 'Ведущий',               en: 'Host' },
  shou:       { uz: 'Shou dastur',         ru: 'Шоу-программа',         en: 'Show programme' },
  foto:       { uz: 'Foto va video',       ru: 'Фото и видео',          en: 'Photo & video' },
  bezak:      { uz: 'Bezak',               ru: 'Декор',                 en: 'Decoration' },
  yoruglik:   { uz: 'Yorug‘lik va texnika',ru: 'Свет и техника',        en: 'Light & sound' },
  salyut:     { uz: 'Salyut',              ru: 'Салют',                 en: 'Fireworks' },
  gozallik:   { uz: 'Go‘zallik va stil',   ru: 'Красота и стиль',       en: 'Beauty & style' },
  transport:  { uz: 'Transport',           ru: 'Транспорт',             en: 'Transport' },
  taklifnoma: { uz: 'Taklifnoma',          ru: 'Приглашения',           en: 'Invitations' },
  sovga:      { uz: 'Esdalik sovg‘alar',   ru: 'Подарки гостям',        en: 'Guest gifts' },
  xizmat:     { uz: 'Xizmat ko‘rsatish',   ru: 'Обслуживание',          en: 'Staff & service' },
  bolalar:    { uz: 'Bolalar burchagi',    ru: 'Детская зона',          en: 'Kids zone' },
  zal:        { uz: 'Zal qo‘shimchalari',  ru: 'Дополнения зала',       en: 'Venue extras' },
  boshqa:     { uz: 'Boshqa',              ru: 'Другое',                en: 'Other' },
};
