// Summani chiroyli ko'rsatish: 1500000 -> "1 500 000"
export function formatAmount(n) {
  const num = Number(n) || 0;
  return num.toLocaleString('ru-RU').replace(/,/g, ' ');
}

export function formatPhone(p) {
  const d = String(p || '').replace(/\D/g, '');
  if (d.length === 12 && d.startsWith('998')) {
    return `+998 ${d.slice(3, 5)} ${d.slice(5, 8)} ${d.slice(8, 10)} ${d.slice(10)}`;
  }
  return '+' + d;
}
