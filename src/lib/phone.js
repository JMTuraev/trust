// Telefon raqamni normalizatsiya qilish: faqat raqamlar, boshidagi + va 00 olib tashlanadi
export function normalizePhone(raw) {
  if (!raw) return null;
  let p = String(raw).replace(/[^\d]/g, '');
  if (p.startsWith('00')) p = p.slice(2);
  if (p.length < 9 || p.length > 15) return null;
  return p;
}

export function isUzbekPhone(phone) {
  return phone.startsWith('998') && phone.length === 12;
}
