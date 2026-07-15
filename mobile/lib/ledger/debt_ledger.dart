// Trust — qarz daftari (ledger) domen logikasi. SOF DART: UI'dan mustaqil, test qilinadigan.
// Spec (TRUST 1:1 chat) 3–6 bo'limlar bo'yicha. Barcha o'tishlar shu klass orqali.
//
// Model: har qarz ALOHIDA yozuv (netting yo'q). Ikki tomonlama tasdiq — har amal
// qarshi tomon tasdiqlagachgina kuchga kiradi (istisno: oneSided / off-Trust darhol).

enum EntryKind { debt, repay, settle }

enum EntryStatus { pending, active, closed, rejected, cancelled, ok, disputed }

enum CloseReason { returned, forgiven }

// oneSided = "tasdiqsiz" (off-Trust davri yozuvi), twoSided = ikki tomonlama tasdiqlangan
enum Provenance { twoSided, oneSided }

// debt yo'nalishi: toMe = u menga qarzdor, fromMe = men unga qarzdorman
enum DebtDir { toMe, fromMe }

class EntryVersion {
  final int amount;
  final DateTime? due;
  final String note;
  final DateTime editedAt;
  const EntryVersion({required this.amount, this.due, this.note = '', required this.editedAt});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'due': due?.toIso8601String(),
        'note': note,
        'edited_at': editedAt.toIso8601String(),
      };
  factory EntryVersion.fromJson(Map<String, dynamic> j) => EntryVersion(
        amount: (j['amount'] as num).toInt(),
        due: _parseDate(j['due']),
        note: (j['note'] as String?) ?? '',
        editedAt: DateTime.tryParse('${j['edited_at']}') ?? DateTime.now(),
      );
}

class PendingEdit {
  final int amount;
  final DateTime? due;
  final String note;
  final DateTime requestedAt;
  const PendingEdit({required this.amount, this.due, this.note = '', required this.requestedAt});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'due': due?.toIso8601String(),
        'note': note,
        'requested_at': requestedAt.toIso8601String(),
      };
  factory PendingEdit.fromJson(Map<String, dynamic> j) => PendingEdit(
        amount: (j['amount'] as num).toInt(),
        due: _parseDate(j['due']),
        note: (j['note'] as String?) ?? '',
        requestedAt: DateTime.tryParse('${j['requested_at']}') ?? DateTime.now(),
      );
}

class DebtEntry {
  final String id;
  final EntryKind kind;
  DebtDir? direction; // faqat debt uchun
  final String createdBy; // kim yozgan (user id)
  int amount;
  final String currency;
  DateTime date; // amal sanasi (backdating mumkin)
  DateTime? due; // faqat debt, ixtiyoriy
  String note;
  EntryStatus status;
  int paid; // faqat debt: jami yopilgan (qaytarilgan + kechilgan)
  int forgiven; // faqat debt: shundan kechilgani
  CloseReason? reason; // yopilish sababi
  String? ref; // repay/settle -> tegishli debt.id
  Provenance prov;
  List<EntryVersion> versions;
  PendingEdit? pendingEdit;
  bool underReview; // join'dan keyin ko'rib chiqish navbatida

  DebtEntry({
    required this.id,
    required this.kind,
    this.direction,
    required this.createdBy,
    required this.amount,
    this.currency = 'UZS',
    required this.date,
    this.due,
    this.note = '',
    this.status = EntryStatus.pending,
    this.paid = 0,
    this.forgiven = 0,
    this.reason,
    this.ref,
    this.prov = Provenance.twoSided,
    List<EntryVersion>? versions,
    this.pendingEdit,
    this.underReview = false,
  }) : versions = versions ?? [];

  DebtEntry copy() => DebtEntry(
        id: id,
        kind: kind,
        direction: direction,
        createdBy: createdBy,
        amount: amount,
        currency: currency,
        date: date,
        due: due,
        note: note,
        status: status,
        paid: paid,
        forgiven: forgiven,
        reason: reason,
        ref: ref,
        prov: prov,
        versions: List.of(versions),
        pendingEdit: pendingEdit,
        underReview: underReview,
      );

  bool get isDebt => kind == EntryKind.debt;
  bool get isOneSided => prov == Provenance.oneSided;

  // ---- Hisoblanadigan qiymatlar (spec 3-bo'lim) ----
  int get remaining => isDebt ? _max0(amount - paid) : 0;
}

int _max0(int v) => v < 0 ? 0 : v;
int _min(int a, int b) => a < b ? a : b;

DateTime? _parseDate(dynamic v) {
  if (v == null || v == '') return null;
  return DateTime.tryParse('$v');
}

/// Qarz daftari — bitta hamkor doirasidagi barcha yozuvlar ustidan sof biznes logika.
/// [meId] joriy foydalanuvchi; [partnerAccepted] hamkor Trust'da va bog'lanish qabul qilingan
/// (false = off-Trust => oneSided oqim). Barcha metodlar yangi ro'yxat qaytaradi (immutable uslub) —
/// yoki mavjud ustida ishlaydi; UI qavati natijani qabul qiladi.
class DebtLedger {
  final String meId;
  final bool partnerAccepted;
  final List<DebtEntry> entries;

  DebtLedger({required this.meId, required this.partnerAccepted, List<DebtEntry>? entries})
      : entries = entries ?? [];

  // ---------- Hisoblovchilar ----------

  /// Shu qarzga bog'liq pending repay/settle summasi (band summa)
  int pendingSum(DebtEntry debt) {
    var s = 0;
    for (final e in entries) {
      if ((e.kind == EntryKind.repay || e.kind == EntryKind.settle) &&
          e.ref == debt.id &&
          e.status == EntryStatus.pending) {
        s += e.amount;
      }
    }
    return s;
  }

  /// Effektiv qoldiq: qoldiqdan pending amallar ayiriladi
  int remainingEff(DebtEntry debt) => _max0(debt.remaining - pendingSum(debt));

  /// Qarzga faol pending amal (repay/settle) yoki pending_edit bormi
  bool isLockedByPending(DebtEntry debt) => pendingSum(debt) > 0 || debt.pendingEdit != null;

  bool isOverdue(DebtEntry debt, {DateTime? today}) {
    if (debt.status != EntryStatus.active || debt.due == null) return false;
    final t = _dayOnly(today ?? DateTime.now());
    return debt.due!.isBefore(t);
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Faol qarzlar (balans/tugma qoidalari uchun — spec 4.4: faqat ACTIVE)
  List<DebtEntry> get _activeDebts =>
      entries.where((e) => e.isDebt && e.status == EntryStatus.active).toList();

  bool _hasActive(DebtDir dir) => _activeDebts.any((d) => d.direction == dir);

  /// Faol qarzlarning hammasi pending amal bilan bandmi (kamida bittasi bo'lsa)
  bool get _allActiveLocked =>
      _activeDebts.isNotEmpty && _activeDebts.every((d) => isLockedByPending(d));

  // ---------- Tugma holatlari (spec 4.4) ----------
  // toMe active bor -> "olish" o'chirilgan; fromMe active bor -> "berish" o'chirilgan.
  bool get canGive => !_hasActive(DebtDir.fromMe);
  bool get canTake => !_hasActive(DebtDir.toMe);
  // Yopish faqat yopiladigan (band bo'lmagan) faol qarz bo'lganda
  bool get canClose => _activeDebts.any((d) => !isLockedByPending(d));

  String? giveDisabledReason(String partnerName) {
    if (canGive) return null;
    final sum = _sumActive(DebtDir.fromMe);
    return "Siz «$partnerName»ga $sum qarzdorsiz — yana qarz berish mantiqsiz, avval hisobni yoping";
  }

  String? takeDisabledReason(String partnerName) {
    if (canTake) return null;
    final sum = _sumActive(DebtDir.toMe);
    return "«$partnerName» sizga $sum qarzdor — qarz olish o'rniga «Qarzni yopish»dan foydalaning";
  }

  String? closeDisabledReason() {
    if (_activeDebts.isEmpty) return 'Faol qarz yo\'q';
    if (_allActiveLocked) return 'Amal tasdiqlanishi kutilmoqda';
    return canClose ? null : 'Faol qarz yo\'q';
  }

  String _sumActive(DebtDir dir) {
    final byCur = <String, int>{};
    for (final d in _activeDebts.where((d) => d.direction == dir)) {
      byCur[d.currency] = (byCur[d.currency] ?? 0) + d.remaining;
    }
    return byCur.entries.map((e) => '${e.value} ${e.key}').join(' + ');
  }

  // ---------- Yopish oqimi uchun tanlanadigan qarzlar (spec 4.5) ----------
  List<DebtEntry> closableDebts() =>
      _activeDebts.where((d) => remainingEff(d) > 0 || isLockedByPending(d)).toList();

  // ---------- O'TISHLAR ----------

  DebtEntry? _byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Yangi qarz ochish. twoSided -> pending; oneSided (off-Trust) -> active DARHOL (atomik).
  /// Qarama-qarshi taqiq (spec 4.4) UI tomonda tugma bilan bloklanadi; bu yerda ham himoya.
  DebtEntry openDebt({
    required String id,
    required DebtDir direction,
    required int amount,
    String currency = 'UZS',
    required DateTime date,
    DateTime? due,
    String note = '',
  }) {
    final e = DebtEntry(
      id: id,
      kind: EntryKind.debt,
      direction: direction,
      createdBy: meId,
      amount: amount,
      currency: currency,
      date: date,
      due: due,
      note: note,
      prov: partnerAccepted ? Provenance.twoSided : Provenance.oneSided,
      status: partnerAccepted ? EntryStatus.pending : EntryStatus.active,
    );
    entries.add(e);
    return e;
  }

  /// Repay/settle ochish. Band qarzga (pending amal bor) yuborib bo'lmaydi.
  /// oneSided -> DARHOL ok + qarzga atomik qo'llanadi.
  DebtEntry openOp({
    required String id,
    required EntryKind kind, // repay | settle
    required String refDebtId,
    required int amount,
    CloseReason? reason, // settle uchun
    required DateTime date,
    String note = '',
  }) {
    assert(kind == EntryKind.repay || kind == EntryKind.settle);
    final debt = _byId(refDebtId);
    if (debt == null) throw StateError('Qarz topilmadi');
    if (isLockedByPending(debt)) throw StateError('Bu qarzda amal tasdiqlanishi kutilmoqda');
    final capped = _min(amount, remainingEff(debt));
    final e = DebtEntry(
      id: id,
      kind: kind,
      createdBy: meId,
      amount: capped,
      currency: debt.currency,
      date: date,
      note: note,
      ref: refDebtId,
      reason: reason,
      prov: partnerAccepted ? Provenance.twoSided : Provenance.oneSided,
      status: partnerAccepted ? EntryStatus.pending : EntryStatus.ok,
    );
    entries.add(e);
    // oneSided: darhol qo'llanadi (ATOMIK — bitta o'zgarishda)
    if (!partnerAccepted) _apply(debt, e);
    return e;
  }

  /// Repay/settle ni debtga qo'llash (spec 4.2). paid HECH QACHON amount dan oshmaydi.
  void _apply(DebtEntry debt, DebtEntry op) {
    final before = debt.paid;
    debt.paid = _min(debt.amount, debt.paid + op.amount);
    if (op.kind == EntryKind.settle && op.reason == CloseReason.forgiven) {
      final applied = debt.paid - before; // shu amalda haqiqatda yopilgan qism
      debt.forgiven += applied;
    }
    if (debt.paid >= debt.amount) {
      debt.status = EntryStatus.closed;
      debt.reason = op.kind == EntryKind.settle ? (op.reason ?? CloseReason.returned) : CloseReason.returned;
    }
  }

  /// Qarshi tomon pending debt/opни tasdiqlaydi.
  void confirm(String entryId) {
    final e = _byId(entryId);
    if (e == null || e.status != EntryStatus.pending) return;
    if (e.createdBy == meId) return; // o'z yozuvini tasdiqlab bo'lmaydi
    if (e.kind == EntryKind.debt) {
      e.status = EntryStatus.active;
    } else {
      // repay/settle
      final debt = e.ref != null ? _byId(e.ref!) : null;
      e.status = EntryStatus.ok;
      if (debt != null) _apply(debt, e);
    }
  }

  /// Qarshi tomon pending amalni rad etadi.
  void reject(String entryId) {
    final e = _byId(entryId);
    if (e == null || e.status != EntryStatus.pending) return;
    if (e.createdBy == meId) return;
    e.status = EntryStatus.rejected;
  }

  /// Muallif o'z pending (yoki disputed) yozuvini bekor qiladi.
  void cancel(String entryId) {
    final e = _byId(entryId);
    if (e == null) return;
    if (e.createdBy != meId) return;
    if (e.status != EntryStatus.pending && e.status != EntryStatus.disputed) return;
    e.status = EntryStatus.cancelled;
  }

  /// Tahrirlash (spec 4.3). Faqat o'z debt, pending/active holatda.
  /// pending/oneSided -> to'g'ridan-to'g'ri (versions ga eski). active twoSided -> pending_edit.
  void edit(String entryId, {required int amount, DateTime? due, String note = '', DateTime? at}) {
    final e = _byId(entryId);
    if (e == null || !e.isDebt || e.createdBy != meId) return;
    if (e.status != EntryStatus.pending && e.status != EntryStatus.active) return;
    final now = at ?? DateTime.now();
    final direct = e.status == EntryStatus.pending || e.isOneSided;
    if (direct) {
      e.versions.add(EntryVersion(amount: e.amount, due: e.due, note: e.note, editedAt: now));
      e.amount = amount;
      e.due = due;
      e.note = note;
      e.paid = _min(e.paid, e.amount); // clamp
    } else {
      // active twoSided: eski qiymatlari bilan faol qoladi
      e.pendingEdit = PendingEdit(amount: amount, due: due, note: note, requestedAt: now);
    }
  }

  /// Qarshi tomon pending_editни tasdiqlaydi -> yangi qiymat qo'llanadi, eski versions ga.
  void confirmEdit(String debtId, {DateTime? at}) {
    final e = _byId(debtId);
    if (e == null || e.pendingEdit == null) return;
    final pe = e.pendingEdit!;
    e.versions.add(EntryVersion(amount: e.amount, due: e.due, note: e.note, editedAt: at ?? DateTime.now()));
    e.amount = pe.amount;
    e.due = pe.due;
    e.note = pe.note;
    e.paid = _min(e.paid, e.amount); // clamp
    e.pendingEdit = null;
  }

  /// Qarshi tomon pending_editни rad etadi -> qarz eski holida faol. QARZ YO'QOLMAYDI.
  void rejectEdit(String debtId) {
    final e = _byId(debtId);
    if (e == null) return;
    e.pendingEdit = null;
  }

  // ---------- Join / review oqimi (spec 5.1) ----------

  /// Ko'rib chiqilayotgan oneSided qarzlar (join'dan keyin)
  List<DebtEntry> reviewDebts() =>
      entries.where((e) => e.isDebt && e.underReview && e.isOneSided).toList();

  /// Bog'liq yozuvlar (repay/settle) shu debtga
  List<DebtEntry> relatedOps(String debtId) =>
      entries.where((e) => e.ref == debtId).toList();

  /// Review: qarz + bog'liq yozuvlarni twoSided qiladi (teglar yo'qoladi).
  void reviewConfirm(String debtId) {
    final e = _byId(debtId);
    if (e == null) return;
    e.prov = Provenance.twoSided;
    e.underReview = false;
    for (final op in relatedOps(debtId)) {
      op.prov = Provenance.twoSided;
      op.underReview = false;
    }
  }

  /// Review rad -> disputed (o'chmaydi, balansdan chiqadi, egasi qayta yubora oladi).
  void reviewReject(String debtId) {
    final e = _byId(debtId);
    if (e == null) return;
    e.status = EntryStatus.disputed;
    e.underReview = false;
  }

  /// Hammasini tasdiqlash (bulk) — barcha review qarzlarini twoSided qiladi.
  void reviewConfirmAll() {
    for (final d in reviewDebts()) {
      reviewConfirm(d.id);
    }
  }

  // ---------- Balans (spec 4.9 header) ----------
  // Balansga faqat balansga kiradigan yozuvlar: active/closed twoSided+oneSided debtlar
  // qoldig'i. disputed KIRMAYDI. Yo'nalish+valyuta bo'yicha net.
  // Natija: {currency: net} — musbat = u menga qarzdor (toMe ustun), manfiy = men unga.
  Map<String, int> balances() {
    final byCur = <String, int>{};
    for (final d in entries) {
      if (!d.isDebt) continue;
      if (d.status != EntryStatus.active) continue; // faqat faol qarz balansda
      final rem = d.remaining;
      if (rem == 0) continue;
      final signed = d.direction == DebtDir.toMe ? rem : -rem;
      byCur[d.currency] = (byCur[d.currency] ?? 0) + signed;
    }
    byCur.removeWhere((_, v) => v == 0);
    return byCur;
  }

  /// Tasdiqsiz (oneSided, active) qoldiq — header'da alohida ko'rsatiladi
  Map<String, int> unverifiedBalances() {
    final byCur = <String, int>{};
    for (final d in entries) {
      if (!d.isDebt || !d.isOneSided) continue;
      if (d.status != EntryStatus.active) continue;
      final rem = d.remaining;
      if (rem == 0) continue;
      final signed = d.direction == DebtDir.toMe ? rem : -rem;
      byCur[d.currency] = (byCur[d.currency] ?? 0) + signed;
    }
    byCur.removeWhere((_, v) => v == 0);
    return byCur;
  }
}
