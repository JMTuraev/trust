// Qarz daftari (ledger) sof funksiyalari — DB'siz, faqat debts qatorlari ustida ishlaydi.
// Spec qonunlari: har qarz alohida yozuv (netting yo'q), paid HECH QACHON amount'dan oshmaydi.

/** Qarzning qolgan qoldig'i: amount - paid, manfiy bo'lmaydi. */
export function rem(debt) {
  return Math.max(0, Number(debt.amount || 0) - Number(debt.paid || 0));
}

/** Shu qarzga bog'liq (ref_id) PENDING repay/settle amount yig'indisi. */
export function pendSum(debtId, allRows) {
  return (allRows || [])
    .filter((r) => r.ref_id === debtId && (r.kind === 'repay' || r.kind === 'settle') && r.status === 'pending')
    .reduce((s, r) => s + Number(r.amount || 0), 0);
}

/** Effektiv qoldiq: rem - pending yig'indisi (0 dan past emas). */
export function remEff(debt, allRows) {
  return Math.max(0, rem(debt) - pendSum(debt.id, allRows));
}

/**
 * Qarz BAND (locked) — bir vaqtda faqat BITTA pending amal (repay/settle/edit).
 * pending_edit bo'lsa yoki bog'liq pending repay/settle bo'lsa true.
 */
export function isLockedByPending(debt, allRows) {
  if (debt.pending_edit) return true;
  return (allRows || []).some(
    (r) => r.ref_id === debt.id && (r.kind === 'repay' || r.kind === 'settle') && r.status === 'pending'
  );
}

/**
 * repay/settle TASDIG'Ida qarzga qo'llash (spec formulasi, clamp).
 * e: { kind:'repay'|'settle', amount, reason? }  reason: 'returned'|'forgiven' (faqat settle).
 * Qaytaradi: { paid, forgiven, status, reason } — ref qarzga yoziladigan yangi qiymatlar.
 *   paid    = min(debt.amount, debt.paid + e.amount)   (HECH QACHON amount'dan oshmaydi)
 *   forgiven = settle+forgiven bo'lsa += min(e.amount, oldingi qoldiq)
 *   status  = paid >= amount bo'lsa 'closed', aks holda debt.status (o'zgarmaydi)
 *   reason  = yopilganda: settle bo'lsa uniki, aks holda 'returned'
 */
export function applyRepaySettle(debt, e) {
  const amount = Number(debt.amount || 0);
  const paidBefore = Number(debt.paid || 0);
  const remBefore = Math.max(0, amount - paidBefore);
  const add = Number(e.amount || 0);

  const paid = Math.min(amount, paidBefore + add);

  let forgiven = Number(debt.forgiven || 0);
  if (e.kind === 'settle' && e.reason === 'forgiven') {
    forgiven += Math.min(add, remBefore);
  }

  const closed = paid >= amount;
  const status = closed ? 'closed' : debt.status;
  const reason = closed
    ? (e.kind === 'settle' ? (e.reason || 'returned') : 'returned')
    : (debt.reason || null);

  return { paid, forgiven, status, reason };
}

/** Muddati o'tganmi: kind='debt', due bor, hali ochiq (qoldiq>0) va due < bugun. */
export function isOverdue(debt, today) {
  if (debt.kind !== 'debt' || !debt.due) return false;
  if (['closed', 'cancelled', 'rejected', 'disputed'].includes(debt.status)) return false;
  if (rem(debt) <= 0) return false;
  const t = today || new Date().toISOString().slice(0, 10);
  return String(debt.due) < t;
}

/**
 * Yo'nalishni EGA (owner) nuqtai nazariga normallashtirish.
 * direction created_by nuqtai nazaridan saqlanadi ('toMe' = created_by qarzdorga ega).
 * Qarama-qarshi yo'nalish taqiqini to'g'ri tekshirish uchun kanonik (owner) yo'nalish kerak.
 */
export function canonicalDir(debt, ownerId) {
  if (debt.created_by === ownerId) return debt.direction;
  return debt.direction === 'toMe' ? 'fromMe' : 'toMe';
}
