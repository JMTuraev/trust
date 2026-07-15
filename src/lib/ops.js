// Operatsiya turidan owner balansiga signed ta'sir (+ = menga qarzdor)
export function deltaFor(type, amount) {
  const a = Math.abs(Number(amount));
  switch (type) {
    case 'qarz_berdim': return a;        // men berdim -> menga qarzdor
    case 'qaytardim': return a;          // qarzimni qaytardim -> balans oshadi
    case 'qarz_oldim': return -a;        // men oldim -> men qarzdorman
    case 'menga_qaytarildi': return -a;  // menga qaytarildi -> balans kamayadi
    default: return 0;
  }
}

export function typeLabel(type) {
  return {
    qarz_berdim: 'Qarz berdim',
    qarz_oldim: 'Qarz oldim',
    qaytardim: 'Qaytardim',
    menga_qaytarildi: 'Menga qaytarildi',
  }[type] || type;
}
