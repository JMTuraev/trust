// DebtLedger domen testlari — spec 6-bo'lim qabul mezonlari (10 ta).
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/ledger/debt_ledger.dart';

DebtLedger led({bool accepted = true, List<DebtEntry>? e}) =>
    DebtLedger(meId: 'me', partnerAccepted: accepted, entries: e);

DebtEntry debt({
  required String id,
  DebtDir dir = DebtDir.toMe,
  String by = 'me',
  int amount = 1000,
  int paid = 0,
  EntryStatus st = EntryStatus.active,
  Provenance prov = Provenance.twoSided,
  String cur = 'UZS',
  DateTime? due,
  bool review = false,
  String note = '',
}) =>
    DebtEntry(
      id: id, kind: EntryKind.debt, direction: dir, createdBy: by,
      amount: amount, paid: paid, status: st, prov: prov, currency: cur,
      date: DateTime(2026, 1, 1), due: due, underReview: review, note: note,
    );

void main() {
  final today = DateTime(2026, 7, 16);

  test('1) Bitta qarzga ikkinchi pending amal yo\'q; remainingEff pending ayiradi', () {
    final l = led(e: [debt(id: 'd1', amount: 1000, paid: 200)]);
    // remaining = 800; pending repay 300 => remEff = 500
    l.openOp(id: 'r1', kind: EntryKind.repay, refDebtId: 'd1', amount: 300, date: today);
    final d = l.entries.first;
    expect(l.remainingEff(d), 500);
    expect(l.isLockedByPending(d), true);
    // Ikkinchi pending amal — rad etiladi (istisno)
    expect(
      () => l.openOp(id: 'r2', kind: EntryKind.repay, refDebtId: 'd1', amount: 100, date: today),
      throwsStateError,
    );
  });

  test('2) paid hech qachon amount dan oshmaydi (ketma-ket tasdiqlar)', () {
    final l = led(e: [debt(id: 'd1', amount: 1000, paid: 900)]);
    // remEff = 100. Repay 100 (cap), tasdiq -> closed, paid=1000
    final r = l.openOp(id: 'r1', kind: EntryKind.repay, refDebtId: 'd1', amount: 500, date: today);
    expect(r.amount, 100); // remEff bo'yicha cheklangan
    // qarshi tomon tasdiqlaydi
    final l2 = DebtLedger(meId: 'them', partnerAccepted: true, entries: l.entries);
    l2.confirm('r1');
    final d = l.entries.first;
    expect(d.paid, 1000);
    expect(d.paid <= d.amount, true);
    expect(d.status, EntryStatus.closed);
  });

  test('3) Faol qarz tahriri rad etilganda eski qiymatlar bilan active qoladi', () {
    final l = led(e: [debt(id: 'd1', amount: 1000, note: 'eski')]);
    l.edit('d1', amount: 5000, note: 'yangi', at: today);
    final d = l.entries.first;
    // pending_edit qatlamida — qarz o'zi eski
    expect(d.amount, 1000);
    expect(d.note, 'eski');
    expect(d.pendingEdit, isNotNull);
    // qarshi tomon rad etadi
    l.rejectEdit('d1');
    expect(d.pendingEdit, isNull);
    expect(d.amount, 1000);
    expect(d.status, EntryStatus.active);
  });

  test('4) Tahrir kutilayotganda balans eski qiymatlardan', () {
    final l = led(e: [debt(id: 'd1', dir: DebtDir.toMe, amount: 1000)]);
    l.edit('d1', amount: 9999, at: today);
    expect(l.balances()['UZS'], 1000); // eski qiymat
    // tasdiqdan keyin yangi
    l.confirmEdit('d1', at: today);
    expect(l.balances()['UZS'], 9999);
    expect(l.entries.first.versions.length, 1);
    expect(l.entries.first.versions.first.amount, 1000);
  });

  test('5) Qarama-qarshi yo\'nalish tugmalari', () {
    final toMe = led(e: [debt(id: 'd1', dir: DebtDir.toMe)]);
    expect(toMe.canGive, true);
    expect(toMe.canTake, false); // u menga qarzdor -> olish yo'q
    expect(toMe.takeDisabledReason('Ali'), contains('qarzdor'));

    final fromMe = led(e: [debt(id: 'd2', dir: DebtDir.fromMe)]);
    expect(fromMe.canTake, true);
    expect(fromMe.canGive, false); // men unga qarzdorman -> berish yo'q
    expect(fromMe.giveDisabledReason('Ali'), contains('qarzdorsiz'));
  });

  test('6) Yopish oqimi: fromMe->repay, toMe->settle', () {
    // fromMe qarz — men qaytaraman (repay)
    final l1 = led(e: [debt(id: 'd1', dir: DebtDir.fromMe, amount: 1000)]);
    final r = l1.openOp(id: 'r1', kind: EntryKind.repay, refDebtId: 'd1', amount: 1000, date: today);
    l1.confirm('r1'); // by=me bo'lgani uchun... them tasdiqlaydi
    final l1t = DebtLedger(meId: 'them', partnerAccepted: true, entries: l1.entries);
    l1t.confirm('r1');
    expect(l1.entries.first.status, EntryStatus.closed);
    expect(r.kind, EntryKind.repay);

    // toMe qarz — pulni oldim (settle returned)
    final l2 = led(e: [debt(id: 'd2', dir: DebtDir.toMe, amount: 500)]);
    l2.openOp(id: 's1', kind: EntryKind.settle, refDebtId: 'd2', amount: 500, reason: CloseReason.returned, date: today);
    final l2t = DebtLedger(meId: 'them', partnerAccepted: true, entries: l2.entries);
    l2t.confirm('s1');
    expect(l2.entries.first.status, EntryStatus.closed);
    expect(l2.entries.first.reason, CloseReason.returned);
  });

  test('7) Qisman kechish: forgiven va sabab to\'g\'ri', () {
    final l = led(e: [debt(id: 'd1', dir: DebtDir.toMe, amount: 1000, paid: 600)]);
    // qoldiq 400 ni kechiraman (settle forgiven)
    l.openOp(id: 's1', kind: EntryKind.settle, refDebtId: 'd1', amount: 400, reason: CloseReason.forgiven, date: today);
    final lt = DebtLedger(meId: 'them', partnerAccepted: true, entries: l.entries);
    lt.confirm('s1');
    final d = l.entries.first;
    expect(d.paid, 1000);
    expect(d.forgiven, 400);
    expect(d.status, EntryStatus.closed);
    expect(d.reason, CloseReason.forgiven);
  });

  test('8) Off-Trust: atomik darhol qo\'llanish; join underReview; rad->disputed; bulk', () {
    // oneSided debt darhol active
    final l = led(accepted: false);
    final d = l.openDebt(id: 'd1', direction: DebtDir.toMe, amount: 1000, date: today);
    expect(d.status, EntryStatus.active);
    expect(d.prov, Provenance.oneSided);
    // repay darhol ok + qo'llanadi (ATOMIK)
    final r = l.openOp(id: 'r1', kind: EntryKind.repay, refDebtId: 'd1', amount: 400, date: today);
    expect(r.status, EntryStatus.ok);
    expect(d.paid, 400);
    expect(l.balances()['UZS'], 600); // 1000-400

    // Join: underReview
    for (final e in l.entries) {
      e.underReview = true;
    }
    expect(l.reviewDebts().length, 1);
    // Rad -> disputed, balansdan chiqadi
    l.reviewReject('d1');
    expect(d.status, EntryStatus.disputed);
    expect(l.balances().containsKey('UZS'), false);

    // Bulk confirm
    final l2 = led(accepted: false, e: [
      debt(id: 'a', prov: Provenance.oneSided, review: true),
      debt(id: 'b', prov: Provenance.oneSided, review: true),
    ]);
    l2.reviewConfirmAll();
    expect(l2.entries.every((e) => e.prov == Provenance.twoSided), true);
    expect(l2.reviewDebts().isEmpty, true);
  });

  test('9) Overdue: due<bugun va faqat active', () {
    final l = led(e: [
      debt(id: 'd1', due: DateTime(2026, 7, 10)), // o'tgan, active
      debt(id: 'd2', due: DateTime(2026, 8, 1)), // kelajak
      debt(id: 'd3', st: EntryStatus.closed, due: DateTime(2026, 1, 1)), // closed
    ]);
    expect(l.isOverdue(l.entries[0], today: today), true);
    expect(l.isOverdue(l.entries[1], today: today), false);
    expect(l.isOverdue(l.entries[2], today: today), false);
  });

  test('10) Bekor qilish faqat o\'z pending amaliga', () {
    final l = led(e: [
      DebtEntry(id: 'mine', kind: EntryKind.debt, direction: DebtDir.toMe, createdBy: 'me',
          amount: 100, date: today, status: EntryStatus.pending),
      DebtEntry(id: 'theirs', kind: EntryKind.debt, direction: DebtDir.fromMe, createdBy: 'them',
          amount: 100, date: today, status: EntryStatus.pending),
    ]);
    l.cancel('theirs'); // begona — o'zgarmaydi
    expect(l.entries[1].status, EntryStatus.pending);
    l.cancel('mine'); // o'ziniki
    expect(l.entries[0].status, EntryStatus.cancelled);
  });
}
