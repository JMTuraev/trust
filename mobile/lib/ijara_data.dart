// Trust — "Ijaradagi uylar" (ijarachi) moduli ma'lumot qatlami.
// Backend: /api/ijara (src/routes/ijara.js). Mock YO'Q — hamma ma'lumot serverdan.
//
// BUTUN HTTP shu faylda: shartnoma o'zgarsa faqat shu fayl tahrirlanadi.
// toyxona_data.dart idiomasi: api.dart (umumiy fayl) tegilmaydi, so'rov yordamchisi
// shu yerda — auth header, 401 -> markazlashgan logout, 402 -> obuna to'sig'i
// (Api.onPaymentRequired(code, 'ijarachi') — modul O'ZI paywall chizmaydi),
// timeout xabarlari Api._req bilan bir xil.
//
// FARQ (sabab: fayl-egalik cheklovi): store.dart ga tegib bo'lmagani uchun repo
// O'ZI ChangeNotifier — ekran unga ListenableBuilder bilan ulanadi.
//
// ATAMALAR:
//   `house`  = ijaraga berilayotgan bitta uy/kvartira. Ijarachi (tenant) uchun
//              ALOHIDA hisob YO'Q (v1): ismi va telefoni uyda saqlanadi.
//   `charge` = hisoblangan yig'im: 'ijara' | 'kommunal' | 'boshqa'.
//   `payment`= naqd/kelgan to'lov. Hisobga bog'lanishi (charge_id) yoki
//              umumiy bo'lishi mumkin — QISMAN to'lov normal holat.
//
// HIMOYA QOIDASI (backend parallel qurilmoqda): endpoint hali yo'q bo'lsa
// (404) ekran YIQILMAYDI va xato ham ko'rsatmaydi — bo'sh holat chiziladi.
// Shuning uchun GET'larda 404 alohida ushlanadi (_missing).
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;
import 'package:http/http.dart' as http;
import 'api.dart';
import 'ijara_l10n.dart';

const String _base = '/api/ijara';

/// Bitta hisobdagi eng ko'p uy (PO qarori 2026-08-04, QAT'IY chegara).
/// Ko'proq uy — alohida ro'yxatdan o'tish. Server ham shu chegarani majburlaydi;
/// mijoz tomonda tekshirish — foydalanuvchini bekorga formaga kiritmaslik uchun.
const int kIjaraMaxHouses = 5;

/// Hisob turlari — backend bilan bir xil kalitlar.
const List<String> kIjaraKinds = ['ijara', 'kommunal', 'boshqa'];

/// Hisob holati kalitlari (UI hisoblaydi, 'bekor' serverdan keladi).
const List<String> kIjaraStates = ['kutish', 'qisman', 'kechikkan', 'tolangan', 'bekor'];

/// Modul so'rovi. method: GET | POST | PATCH | DELETE.
/// Javob o'ramasi: {success:true, data:...} — data ajratib olinadi.
Future<ApiRes> _req(String method, String path, {Map<String, dynamic>? body}) async {
  try {
    final uri = Uri.parse('$apiUrl$_base$path');
    final headers = {
      'Content-Type': 'application/json',
      if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
    };
    const t = Duration(seconds: 20);
    final payload = jsonEncode(body ?? const <String, dynamic>{});
    late http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: headers).timeout(t);
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: payload).timeout(t);
      case 'DELETE':
        res = await http.delete(uri, headers: headers, body: payload).timeout(t);
      default:
        res = await http.post(uri, headers: headers, body: payload).timeout(t);
    }
    // Avval STATUS, keyin tana (Render deploy paytida JSON o'rniga HTML kelishi mumkin).
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
    if (res.statusCode >= 400 || map['success'] == false) {
      final code = (map['code'] as String?) ?? '';
      if (res.statusCode == 401 && Api.token != null) Api.onUnauthorized?.call();
      // 402 — bepul limit (5 yozuv) tugagan: modul nomi bilan markazlashgan paywall.
      // Modul O'Z paywallini chizmaydi (umumiy sheet ochiladi).
      if (res.statusCode == 402) Api.onPaymentRequired?.call(code, 'ijarachi');
      return ApiRes(false, null, (map['error'] as String?) ?? ij('errGeneric'), res.statusCode, code, map);
    }
    return ApiRes(true, map.containsKey('data') ? map['data'] : map, '', res.statusCode, '', map);
  } on TimeoutException {
    return ApiRes(false, null, ij('errWaking'), 0);
  } catch (_) {
    // Ulanish xatosi: asosiy manzil ochilmasa zaxiraga o'tamiz (api.dart) — keyingi so'rov o'sha yerga
    Api.useFallback();
    return ApiRes(false, null, ij('errNetwork'), 0);
  }
}

// ===================== Format / sana yordamchilari =====================

/// 1234567 -> "1 234 567" (store._fx bilan bir xil format; valyuta alohida).
String ijFx(num v) {
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// "1 234 567 so'm" — moliyaviy matn hech qachon kesilmaydi.
/// Manfiy qiymat (ortiqcha to'lov) minus bilan ko'rsatiladi.
/// DIQQAT: bu UY VALYUTASINI BILMAYDI — uy konteksti bor joyda
/// `ijMoneyCur(v, house.currency)` ishlatiladi (023).
String ijMoney(num v) => '${v < 0 ? '−' : ''}${ijFx(v)} ${ij('som')}';

/// 023 — qo'llab-quvvatlanadigan valyutalar. Backend CURRENCIES va
/// 023 dagi rent_houses_currency_chk bilan BIR XIL bo'lishi shart.
const String kIjaraCurUzs = 'UZS';
const String kIjaraCurUsd = 'USD';
const List<String> kIjaraCurrencies = [kIjaraCurUzs, kIjaraCurUsd];

/// Serverdan kelgan xom qiymatni xavfsiz valyutaga aylantiradi (noma'lum
/// yoki bo'sh -> UZS; ustun hali qo'shilmagan backend ham shu yo'l bilan
/// to'g'ri ishlaydi).
String ijCurOf(dynamic raw) {
  final c = '${raw ?? ''}'.trim().toUpperCase();
  return kIjaraCurrencies.contains(c) ? c : kIjaraCurUzs;
}

/// Valyuta belgisi: UZS -> tilga qarab "so'm/сум/UZS", USD -> "\$".
String ijCurSym(String cur) => cur == kIjaraCurUsd ? '\$' : ij('som');

/// "1 234 567 so'm" / "1 200 \$" — UY VALYUTASI bilan.
String ijMoneyCur(num v, String cur) =>
    '${v < 0 ? '−' : ''}${ijFx(v)} ${ijCurSym(cur)}';

/// DateTime -> 'YYYY-MM-DD' (mahalliy sana; UTC'ga o'girilmaydi).
String ijYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// DateTime -> 'YYYY-MM' (hisob davri).
String ijPeriod(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// 'YYYY-MM-DD' (yoki to'liq ISO) -> mahalliy DateTime.
/// DateTime.parse ISHLATILMAYDI: 'Z' bilan kelgan sana mahalliy zonada ±1 kunga
/// siljib ketardi (qarz daftaridagi ma'lum xato) — shu sabab qo'lda ajratamiz.
DateTime? ijParseYmd(String raw) {
  final s = raw.length >= 10 ? raw.substring(0, 10) : raw;
  final parts = s.split('-');
  if (parts.length < 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Sana faqat kun aniqligida.
DateTime ijDay(DateTime d) => DateTime(d.year, d.month, d.day);

bool ijSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "12 avgust" — til lug'atidan oy nomi bilan.
String ijDateShort(DateTime d) => '${d.day} ${ijMonth(d.month)}';

/// "12 avgust 2026"
String ijDateLong(DateTime d) => '${d.day} ${ijMonth(d.month)} ${d.year}';

DateTime ijMonthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime ijMonthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

int _int(dynamic v, [int fb = 0]) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? fb);

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _rows(dynamic v) => v is List
    ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
    : const <Map<String, dynamic>>[];

/// Faqat kutilgan kalitlarni int qilib oladi (yo'qlari tushib qoladi — shunda
/// "server bermadi" va "server 0 dedi" farqlanadi).
Map<String, int> _totals(dynamic v, List<String> keys) {
  final m = _map(v);
  return {
    for (final k in keys)
      if (m[k] != null) k: _int(m[k]),
  };
}

// ===================== Modellar =====================

/// Pul yakunlari: hisoblandi / to'landi / qoldiq.
class IjaraTotals {
  final int charged, paid, left;
  const IjaraTotals({this.charged = 0, this.paid = 0, this.left = 0});

  /// Ortiqcha to'lovda left MANFIY bo'lishi mumkin — clamp QILINMAYDI.
  factory IjaraTotals.of(int charged, int paid) =>
      IjaraTotals(charged: charged, paid: paid, left: charged - paid);
}

/// Ijaraga berilgan uy. Ijarachi (ism + telefon) SHU YERDA saqlanadi — v1'da
/// ijarachining alohida hisobi yo'q.
class House {
  final String id;
  final String name;
  final String tenantName;
  final String tenantPhone;
  final int rentAmount;

  /// 023 — uy valyutasi: 'UZS' yoki 'USD'. rentAmount VA shu uyning barcha
  /// hisob-kitoblari SHU birlikda o'qiladi. Server bermasa 'UZS' (eski uylar).
  final String currency;

  /// 023 — oylik to'lov kuni (1..31) yoki 0 = kelishilmagan. Yangi hisob
  /// yaratishda muddat (due_date) shu kundan yasaladi; 0 bo'lsa muddat yo'q.
  final int dueDay;

  final int sort;
  final bool archived;

  /// Server bergan yakunlar (bo'lmasa bo'sh) — hisoblar endpointi yo'q bo'lgan
  /// holatda zaxira sifatida ishlatiladi.
  final Map<String, int> totals;

  /// Server bergan "muddati o'tgan" soni (bo'lmasa 0).
  final int overdueCount;

  const House({
    required this.id,
    required this.name,
    this.tenantName = '',
    this.tenantPhone = '',
    this.rentAmount = 0,
    this.currency = kIjaraCurUzs,
    this.dueDay = 0,
    this.sort = 0,
    this.archived = false,
    this.totals = const {},
    this.overdueCount = 0,
  });

  factory House.fromJson(Map<String, dynamic> j) {
    final t = _totals(j['totals'], const ['charged', 'paid', 'left']);
    final rawOverdue = j['overdue_count'] ?? j['overdue'] ?? _map(j['totals'])['overdue_count'];
    return House(
      id: '${j['id']}',
      name: (j['name'] as String?) ?? '',
      tenantName: (j['tenant_name'] as String?) ?? '',
      tenantPhone: (j['tenant_phone'] as String?) ?? '',
      rentAmount: _int(j['rent_amount']),
      currency: ijCurOf(j['currency']),
      // 1..31 dan tashqarisi (null, 0, axlat) — "kelishilmagan" = 0
      dueDay: (() {
        final d = _int(j['due_day']);
        return d >= 1 && d <= 31 ? d : 0;
      })(),
      sort: _int(j['sort']),
      archived: j['archived'] == true,
      totals: t,
      overdueCount: rawOverdue is bool ? (rawOverdue ? 1 : 0) : _int(rawOverdue),
    );
  }

  /// Serverning uy yakunlari (bermagan bo'lsa nollar).
  IjaraTotals get serverTotals => IjaraTotals(
        charged: totals['charged'] ?? 0,
        paid: totals['paid'] ?? 0,
        left: totals['left'] ?? ((totals['charged'] ?? 0) - (totals['paid'] ?? 0)),
      );

  bool get hasServerTotals => totals.isNotEmpty;
}

/// To'lov. charge_id bo'sh bo'lsa — uyga umumiy to'lov.
class IjaraPayment {
  final String id;
  final String houseId;
  final String chargeId; // bo'sh = umumiy
  final int amount;
  final String paidAt;
  final String note;

  const IjaraPayment({
    required this.id,
    required this.amount,
    this.houseId = '',
    this.chargeId = '',
    this.paidAt = '',
    this.note = '',
  });

  factory IjaraPayment.fromJson(Map<String, dynamic> j) => IjaraPayment(
        id: '${j['id']}',
        houseId: j['house_id'] == null ? '' : '${j['house_id']}',
        chargeId: j['charge_id'] == null ? '' : '${j['charge_id']}',
        amount: _int(j['amount']),
        paidAt: '${j['paid_at'] ?? ''}',
        note: (j['note'] as String?) ?? '',
      );

  DateTime? get date => paidAt.isEmpty ? null : ijParseYmd(paidAt);
}

/// Hisoblangan yig'im (accrual).
class Charge {
  final String id;
  final String houseId;
  final String houseName;
  final String period; // 'YYYY-MM'
  final String kind; // ijara | kommunal | boshqa
  final String title;
  final int amount;
  final String status; // serverdan; 'bekor' = soft-cancel
  final String dueDateRaw;
  final List<IjaraPayment> payments;
  final Map<String, int> totals; // server bergan {paid, left}

  const Charge({
    required this.id,
    required this.amount,
    this.houseId = '',
    this.houseName = '',
    this.period = '',
    this.kind = 'boshqa',
    this.title = '',
    this.status = '',
    this.dueDateRaw = '',
    this.payments = const [],
    this.totals = const {},
  });

  factory Charge.fromJson(Map<String, dynamic> j) => Charge(
        id: '${j['id']}',
        houseId: j['house_id'] == null ? '' : '${j['house_id']}',
        houseName: (j['house_name'] as String?) ?? '',
        period: '${j['period'] ?? ''}',
        // Notanish tur kelsa 'boshqa' — chip/yorliq baribir chiziladi.
        kind: kIjaraKinds.contains(j['kind']) ? '${j['kind']}' : 'boshqa',
        title: (j['title'] as String?) ?? '',
        amount: _int(j['amount']),
        status: (j['status'] as String?) ?? '',
        dueDateRaw: '${j['due_date'] ?? ''}',
        payments: _rows(j['payments']).map(IjaraPayment.fromJson).toList(),
        totals: _totals(j['totals'], const ['paid', 'left']),
      );

  /// Nusxa + berilgan to'lovlar (javobda to'lovlar ALOHIDA massivda kelgan holat).
  Charge withPayments(List<IjaraPayment> list) => Charge(
        id: id,
        houseId: houseId,
        houseName: houseName,
        period: period,
        kind: kind,
        title: title,
        amount: amount,
        status: status,
        dueDateRaw: dueDateRaw,
        payments: list,
        totals: totals,
      );

  DateTime? get dueDate => dueDateRaw.isEmpty ? null : ijParseYmd(dueDateRaw);

  /// Server yakunlari ustuvor; bo'lmasa bog'langan to'lovlardan hisoblanadi.
  int get paid => totals['paid'] ?? payments.fold(0, (s, p) => s + p.amount);

  /// QISMAN to'lov ko'rinishi shu yerda: 0 < left < amount.
  /// Ortiqcha to'lovda manfiy bo'lishi mumkin — clamp QILINMAYDI.
  int get left => totals['left'] ?? (amount - paid);

  bool get cancelled => status == 'bekor';
}

/// Davr yakunlari (GET /summary yoki /charges ichidagi totals).
class IjaraSummary {
  final int count;
  final int charged, paid, left;
  final Map<String, int> byStatus;
  const IjaraSummary({
    this.count = 0,
    this.charged = 0,
    this.paid = 0,
    this.left = 0,
    this.byStatus = const {},
  });

  factory IjaraSummary.fromJson(Map<String, dynamic> j) {
    final charged = _int(j['charged']);
    final paid = _int(j['paid']);
    return IjaraSummary(
      count: _int(j['count']),
      charged: charged,
      paid: paid,
      // left yuborilmagan bo'lsa hisoblab olamiz (eski/qisqa javob).
      left: j['left'] != null ? _int(j['left']) : charged - paid,
      byStatus: {
        for (final e in _map(j['byStatus']).entries) '${e.key}': _int(e.value),
      },
    );
  }
}

/// GET /charges javobining ajratilgan ko'rinishi.
class ChargesPage {
  final List<Charge> charges;
  final List<IjaraPayment> payments;
  final IjaraSummary? totals;
  const ChargesPage({this.charges = const [], this.payments = const [], this.totals});
}

// ===================== Sof ajratgichlar (test qilinadi) =====================

/// GET /houses javobi: [...] yoki {houses:[...]} — ikkalasi ham qabul qilinadi.
List<House> ijParseHouses(dynamic data) {
  final rows = data is Map ? _rows(_map(data)['houses']) : _rows(data);
  return [
    for (final r in rows)
      if (r['id'] != null) House.fromJson(r),
  ];
}

/// GET /charges javobi. Shakllar:
///   {charges:[...], payments:[...], totals:{...}}  — asosiy shartnoma
///   [...]                                          — faqat hisoblar
/// To'lovlar ALOHIDA massivda kelsa, hisoblarga charge_id bo'yicha biriktiriladi
/// (hisob ichida allaqachon to'lovlar bo'lsa — TEGILMAYDI, ikki marta sanalmasin).
ChargesPage ijParseCharges(dynamic data) {
  if (data is List) {
    return ChargesPage(charges: [
      for (final r in _rows(data))
        if (r['id'] != null) Charge.fromJson(r),
    ]);
  }
  final m = _map(data);
  final charges = [
    for (final r in _rows(m['charges']))
      if (r['id'] != null) Charge.fromJson(r),
  ];
  final pays = [
    for (final r in _rows(m['payments']))
      if (r['id'] != null) IjaraPayment.fromJson(r),
  ];
  final linked = pays.isEmpty
      ? charges
      : [
          for (final c in charges)
            c.payments.isNotEmpty
                ? c
                : c.withPayments(pays.where((p) => p.chargeId == c.id).toList()),
        ];
  // Hisoblar ichidagi to'lovlar ham umumiy ro'yxatga qo'shiladi (id bo'yicha
  // takrorlanmaydi) — uy tafsilotidagi "TO'LOVLAR" bo'limi to'liq bo'lsin.
  final all = <String, IjaraPayment>{for (final p in pays) p.id: p};
  for (final c in charges) {
    for (final p in c.payments) {
      all.putIfAbsent(p.id, () => p.houseId.isEmpty ? _withHouse(p, c.houseId) : p);
    }
  }
  return ChargesPage(
    charges: linked,
    payments: all.values.toList(),
    totals: m['totals'] == null ? null : IjaraSummary.fromJson(_map(m['totals'])),
  );
}

IjaraPayment _withHouse(IjaraPayment p, String houseId) => IjaraPayment(
      id: p.id,
      houseId: houseId,
      chargeId: p.chargeId,
      amount: p.amount,
      paidAt: p.paidAt,
      note: p.note,
    );

/// GET /charges javobini bitta shaklga keltirish.
/// HAQIQIY backend (src/routes/ijara.js) shunday yuboradi:
///   {success, data:[hisoblar], unallocated:[bog'lanmagan to'lovlar], totals:{...}}
/// ya'ni to'lovlar va yakunlar `data` NING ICHIDA emas, YONIDA turadi — _req esa
/// faqat `data`ni ajratib beradi. Shuning uchun ularni `body`dan yig'ib olamiz.
/// Muqobil shakl ({charges, payments, totals}) ham qo'llab-quvvatlanadi.
dynamic ijChargesPayload(dynamic data, Map<String, dynamic> body) {
  final extraPays = body['unallocated'] ?? body['payments'];
  if (extraPays == null && body['totals'] == null) return data;
  return {
    'charges': data,
    if (extraPays != null) 'payments': extraPays,
    if (body['totals'] != null) 'totals': body['totals'],
  };
}

/// Hisob holati kaliti: 'bekor' | 'tolangan' | 'kechikkan' | 'qisman' | 'kutish'.
/// Tartib MUHIM: bekor qilingan hisob hech qachon "kechikkan" bo'lmaydi,
/// muddati o'tgani esa qisman to'langanidan USTUN (harakat talab qiladi).
String ijChargeState(Charge c, {DateTime? today}) {
  if (c.cancelled) return 'bekor';
  if (c.left <= 0) return 'tolangan';
  final due = c.dueDate;
  if (due != null && ijDay(due).isBefore(ijDay(today ?? DateTime.now()))) return 'kechikkan';
  return c.paid > 0 ? 'qisman' : 'kutish';
}

/// Hisoblar ro'yxatidan davr yakunlari. Bekor qilinganlar SANALMAYDI.
IjaraTotals ijSumCharges(Iterable<Charge> charges) {
  var charged = 0, paid = 0;
  for (final c in charges) {
    if (c.cancelled) continue;
    charged += c.amount;
    paid += c.paid;
  }
  return IjaraTotals.of(charged, paid);
}

/// Davr/uy yakuni: hisoblar + TAQSIMLANMAGAN (bog'lanmagan) to'lovlar.
/// Server foldCharges()/foldHouses() bilan AYNAN bir xil qoida
/// (src/routes/ijara.js):
///   * bekor qilingan hisob va unga BOG'LANGAN to'lov yakunga kirmaydi;
///   * charge_id'siz to'lov HAR DOIM tushum sifatida qo'shiladi.
/// Backend hisobni bekor qilganda to'lovlarni UZADI (charge_id -> null), ya'ni
/// qo'lga olingan pul aynan shu ikkinchi yo'l bilan yakunda qoladi — mijoz ham
/// shu qoidada bo'lmasa ekrandagi son server soni bilan farq qilardi.
IjaraTotals ijSumPeriod(Iterable<Charge> charges, Iterable<IjaraPayment> payments) {
  final t = ijSumCharges(charges);
  var free = 0;
  for (final p in payments) {
    if (p.chargeId.isEmpty) free += p.amount;
  }
  return free == 0 ? t : IjaraTotals.of(t.charged, t.paid + free);
}

/// GET /houses javobidan uy chegarasi.
/// HAQIQIY backend uni `limit` ICHIDA yuboradi (src/routes/ijara.js):
///   {success, data:[...], limit:{max_houses, used}}
/// 403 HOUSE_LIMIT javobida esa `limit` — RAQAM: {code, limit:5, used:5}.
/// Eski/tekis shakl (`max_houses` ildizda) ham qabul qilinadi.
/// Hech biri topilmasa — zaxira (lokal kIjaraMaxHouses).
int ijMaxHouses(Map<String, dynamic> body, [int fallback = kIjaraMaxHouses]) {
  final raw = body['limit'];
  var v = 0;
  if (raw is Map) {
    v = _int(_map(raw)['max_houses']);
  } else if (raw != null) {
    v = _int(raw);
  }
  if (v <= 0) v = _int(body['max_houses']);
  return v > 0 ? v : fallback;
}

// ===================== Ekran yordamchilari (sof, test qilinadi) =====================

/// Oy menyusi variantlari (F9): TANLANGAN oyga nisbatan 24 oy orqaga va 6 oy
/// oldinga. Joriy oy oraliqdan chiqib qolsa ham ro'yxatga QADALADI (chetiga
/// qo'shiladi) — ega qaysi oyda bo'lmasin bir bosishda bugungi oyga qaytadi.
List<DateTime> ijMonthOptions(DateTime selected, {DateTime? now}) {
  final sel = ijMonthStart(selected);
  final cur = ijMonthStart(now ?? DateTime.now());
  final list = [for (var i = -24; i <= 6; i++) DateTime(sel.year, sel.month + i, 1)];
  final has = list.any((d) => d.year == cur.year && d.month == cur.month);
  if (!has) {
    if (cur.isBefore(list.first)) {
      list.insert(0, cur);
    } else {
      list.add(cur);
    }
  }
  return list;
}

/// U2: bu oy uchun 'ijara' turidagi hisobi YOZILMAGAN faol uylar (oylik ijarasi
/// belgilanganlar). Bekor qilingan hisob HISOB EMAS — uy ro'yxatda qoladi,
/// kommunal/boshqa hisob esa ijara o'rnini bosmaydi.
List<House> ijMissingRentHouses(Iterable<House> houses, Iterable<Charge> charges) {
  final have = <String>{
    for (final c in charges)
      if (!c.cancelled && c.kind == 'ijara') c.houseId,
  };
  return [
    for (final h in houses)
      if (!h.archived && h.rentAmount > 0 && !have.contains(h.id)) h,
  ];
}

/// U4: pill kaliti -> hisob holatlari guruhi. Pill bosilganda uylar ro'yxati
/// shu holatdagi hisobi bor uylargagina toraytiriladi. 'qisman' ham
/// "kutilmoqda" guruhida — u hali yopilmagan hisob.
const Map<String, List<String>> kIjaraPillStates = {
  'pending': ['kutish', 'qisman'],
  'overdue': ['kechikkan'],
  'paid': ['tolangan'],
};

/// U4: oy holat yakunlari — kutilmoqda (muddati o'tmagan qoldiq), kechikkan
/// (muddati o'tgan qoldiq) va to'langan (davrda tushgan pul; sarlavhadagi
/// "To'landi" bilan BIR XIL qoida — bog'lanmagan to'lovlar ham kiradi).
Map<String, int> ijPillSums(Iterable<Charge> charges, Iterable<IjaraPayment> payments,
    {DateTime? today}) {
  final t = today ?? DateTime.now();
  var pending = 0, overdue = 0;
  for (final c in charges) {
    switch (ijChargeState(c, today: t)) {
      case 'kutish':
      case 'qisman':
        pending += c.left;
      case 'kechikkan':
        overdue += c.left;
    }
  }
  return {
    'pending': pending,
    'overdue': overdue,
    'paid': ijSumPeriod(charges, payments).paid,
  };
}

/// U4: uyning SHU OY hisoblari orasida berilgan pill holatidagisi bormi.
/// Notanish pill — filtr yo'q deb qabul qilinadi (ro'yxat to'liq qoladi).
bool ijHouseMatchesPill(String pill, Iterable<Charge> houseCharges, {DateTime? today}) {
  final states = kIjaraPillStates[pill];
  if (states == null) return true;
  final t = today ?? DateTime.now();
  return houseCharges.any((c) => states.contains(ijChargeState(c, today: t)));
}

// ===================== Repozitoriy =====================

/// Tarmoqli repozitoriy. Ekran `ListenableBuilder(listenable: ijaraRepo, ...)`
/// bilan ulanadi. Xatolar `error` maydonida — UI toast + qayta urinish beradi.
class IjaraRepo extends ChangeNotifier {
  final List<House> _houses = [];
  final List<Charge> _charges = [];
  final List<IjaraPayment> _payments = [];

  DateTime month = ijMonthStart(DateTime.now());
  IjaraSummary summary = const IjaraSummary();

  bool loading = false;
  bool loaded = false;
  bool housesLoaded = false;

  /// Davr (oy) yuklashidagi xato (F1): ro'yxat TANASIDA qayta urinish tugmali
  /// inline banner chiziladi, sarlavha esa ishlayveradi. Mutatsiya xatolaridan
  /// ALOHIDA maydon — ular toast bo'lib ketadi, banner emas.
  String? loadError;

  /// FAQAT TESTLAR UCHUN: true bo'lsa load()/loadHouses() tarmoqqa umuman
  /// chiqmaydi. Widget-testlar repo'ni applyHouses/applyPage bilan urug'laydi —
  /// test muhitidagi soxta HTTP (hamma so'rovga 400) urug'ni yuvib yubormasin.
  @visibleForTesting
  bool testOffline = false;

  /// /houses hali yo'q (404): ekran XATO emas, BO'SH holat ko'rsatadi.
  bool backendMissing = false;

  /// /charges hali yo'q (404). ALOHIDA bayroq: /houses ishlab, /charges
  /// ishlamasligi mumkin — o'shanda uy qatorlari serverning uy yakunlariga
  /// tushadi (aks holda hamma joyda 0 ko'rinardi).
  bool chargesMissing = false;

  String? error;
  int errorStatus = 0;

  /// Oxirgi so'rovning server xato KODI ('HOUSE_LIMIT', 'SUB_EXPIRED', ...).
  String lastCode = '';

  /// Oxirgi xatoning qo'shimcha tafsiloti.
  String lastDetail = '';

  /// Arxivlanmagan uylar (tartib bo'yicha).
  List<House> get houses {
    final list = _houses.where((h) => !h.archived).toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.name.compareTo(b.name));
    return list;
  }

  /// Arxivlangan uylar (U7) — ro'yxat oxiridagi yig'ma bo'lim uchun.
  /// GET /houses arxivlanganlarni ham beradi; ular _houses'da saqlanadi,
  /// faqat ko'rsatish joyi alohida.
  List<House> get archivedHouses {
    final list = _houses.where((h) => h.archived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  bool get hasHouses => houses.isNotEmpty;

  /// Server ruxsat etgan eng ko'p uy — GET /houses javobidagi
  /// `limit.max_houses` (yo'q bo'lsa lokal kIjaraMaxHouses; ijMaxHouses'ga
  /// qarang). Chegarani SERVER majburlaydi (403, code 'HOUSE_LIMIT'); mijoz
  /// buni faqat formani bekorga ochmaslik uchun biladi.
  int maxHouses = kIjaraMaxHouses;

  /// Yangi uy qo'shish mumkinmi (QAT'IY chegara).
  bool get canAddHouse => houses.length < maxHouses;

  House? houseById(String? id) {
    if (id == null) return null;
    for (final h in _houses) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Davr hisoblari — SERVER TARTIBIDA.
  List<Charge> get charges => List.unmodifiable(_charges);

  /// Davr to'lovlari — SERVER TARTIBIDA (U4 pill yig'indilari shu ro'yxatdan).
  List<IjaraPayment> get payments => List.unmodifiable(_payments);

  /// Bitta uyning davr hisoblari.
  List<Charge> chargesOf(String houseId) =>
      _charges.where((c) => c.houseId == houseId).toList();

  /// Bitta uyning davr to'lovlari (eng yangisi tepada).
  List<IjaraPayment> paymentsOf(String houseId) {
    final list = _payments.where((p) => p.houseId == houseId).toList()
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return list;
  }

  Charge? chargeById(String? id) {
    if (id == null) return null;
    for (final c in _charges) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Uy bo'yicha DAVR yakunlari. Asosiy manba — shu davr uchun yuklangan
  /// hisoblar (ko'rilayotgan oy bilan kafolatli mos keladi). Hisoblar endpointi
  /// yo'q bo'lsa (404) — serverning uy yakunlariga tushamiz.
  IjaraTotals totalsOf(String houseId) {
    final list = chargesOf(houseId);
    if (list.isEmpty && (backendMissing || chargesMissing)) {
      final h = houseById(houseId);
      if (h != null && h.hasServerTotals) return h.serverTotals;
    }
    // Hisobga bog'lanmagan (umumiy) to'lovlar ham qoldiqni kamaytiradi —
    // bekor qilingan hisobdan UZILGAN to'lov ham shu yo'l bilan qoladi.
    return ijSumPeriod(list, _payments.where((p) => p.houseId == houseId));
  }

  /// Uydagi muddati o'tgan hisoblar soni. Hisoblar yuklangan bo'lsa SHU
  /// davrdan hisoblanadi; endpoint yo'q bo'lsa — serverning soni (zaxira).
  /// Davrda hisob bo'lmasa 0 (eski oyda "kechikkan" yolg'on chiqmasin).
  int overdueOf(String houseId) {
    final list = chargesOf(houseId);
    if (list.isEmpty) {
      if (backendMissing || chargesMissing) return houseById(houseId)?.overdueCount ?? 0;
      return 0;
    }
    final today = ijDay(DateTime.now());
    return list.where((c) => ijChargeState(c, today: today) == 'kechikkan').length;
  }

  void _clearErr() {
    error = null;
    errorStatus = 0;
    lastCode = '';
    lastDetail = '';
  }

  void _fail(ApiRes r) {
    error = r.error;
    errorStatus = r.status;
    lastCode = r.code;
    lastDetail = (r.body['detail'] as String?) ?? '';
    // 403 HOUSE_LIMIT javobi chegarani O'ZI aytadi ({limit, used}) — modal shu
    // raqamni ko'rsatsin (mijozdagi zaxira 5 dan farq qilishi mumkin).
    if (r.code == 'HOUSE_LIMIT') maxHouses = ijMaxHouses(r.body, maxHouses);
  }

  /// Endpoint yo'qmi? 404 — backend hali chiqmagan (yoki yo'l o'zgargan):
  /// bu XATO emas, BO'SH holat. 401/402 markazlashgan holda ishlanadi.
  bool _missing(ApiRes r) => r.status == 404;

  String get _range => 'from=${ijYmd(ijMonthStart(month))}&to=${ijYmd(ijMonthEnd(month))}';

  // ---------------- Javobni holatga qo'llash ----------------
  // Ajratish (ijParse*) va QO'LLASH alohida turadi: yuklash yo'li ham, testlar
  // ham AYNAN shu ikki metoddan o'tadi (test tarmoqsiz holat qura oladi, lekin
  // ishlab turgan kodni tekshiradi).

  /// Uylar ro'yxati + (ixtiyoriy) javob tanasidagi chegara.
  void applyHouses(List<House> list, [Map<String, dynamic>? body]) {
    backendMissing = false;
    _houses
      ..clear()
      ..addAll(list);
    housesLoaded = true;
    if (body != null) maxHouses = ijMaxHouses(body, maxHouses);
  }

  /// Davr hisoblari + to'lovlari (+ javob ichidagi yakunlar bo'lsa — xulosa;
  /// u holda alohida /summary kutilmaydi).
  void applyPage(ChargesPage page) {
    chargesMissing = false;
    _charges
      ..clear()
      ..addAll(page.charges);
    _payments
      ..clear()
      ..addAll(page.payments);
    if (page.totals != null) summary = page.totals!;
  }

  // ---------------- Yuklash ----------------

  /// So'rovlar poygasiga qarshi token (store._periodSeq naqshi, F2): har load()
  /// yangi raqam oladi, ESKIRGAN javob (raqam mos kelmasa) TASHLANADI — tez
  /// oy almashtirganda oldingi oyning kech kelgan javobi ekranni bosolmaydi.
  /// reset() ham raqamni oshiradi: logout'dan keyin uchayotgan javob o'ladi.
  int _seq = 0;

  /// Davr ko'rinishi uchun hamma narsa: uylar (kerak bo'lsa), davr hisoblari
  /// va to'lovlari, xulosa. Ekran faqat shuni biladi.
  Future<void> load(DateTime m, {bool silent = false}) async {
    if (testOffline) return; // faqat testlar: urug'langan holat tegilmaydi
    final seq = ++_seq;
    month = ijMonthStart(m);
    // F4: eski oyning xulosasi yangi oy raqami bo'lib ko'rinmasin — avval
    // tozalanadi; /summary yiqilsa periodTotals yuklangan qatorlardan hisoblaydi.
    summary = const IjaraSummary();
    loadError = null;
    _clearErr();
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    if (!housesLoaded) await loadHouses(notify: false, seq: seq);
    if (seq != _seq) return; // eskirgan — holatni yangiroq load boshqaradi
    await Future.wait([
      _loadCharges(seq),
      _loadSummary(seq),
    ]);
    if (seq != _seq) return;
    loading = false;
    if (error == null) loaded = true;
    notifyListeners();
  }

  /// Modulga KIRISH (F5/F9): ko'riladigan oy HAR DOIM joriy oyga qaytadi va
  /// uylar ro'yxati har safar serverdan yangilanadi. Kesh bo'lsa skelet
  /// chiqmaydi (loaded=true qoladi) — ro'yxat ustida yupqa progress ko'rinadi.
  Future<void> enter() {
    housesLoaded = false;
    return load(DateTime.now());
  }

  /// Joriy davrni jimgina qayta o'qish (mutatsiyalardan keyin).
  Future<void> refresh() => load(month, silent: true);

  /// LOGOUT (F6): BUTUN modul holati tozalanadi — keyingi hisob oldingi
  /// egasining uylarini ko'rmasin. store.dart chiqishda AYNAN `reset` nomi
  /// bilan chaqiradi (nomni o'zgartirmang).
  void reset() {
    _seq++; // uchayotgan javoblar endi qo'llanilmaydi
    _houses.clear();
    _charges.clear();
    _payments.clear();
    month = ijMonthStart(DateTime.now());
    summary = const IjaraSummary();
    loading = false;
    loaded = false;
    housesLoaded = false;
    backendMissing = false;
    chargesMissing = false;
    maxHouses = kIjaraMaxHouses;
    loadError = null;
    _clearErr();
    notifyListeners();
  }

  Future<void> loadHouses({bool notify = true, int? seq}) async {
    if (testOffline) return; // faqat testlar
    final r = await _req('GET', '/houses');
    if (seq != null && seq != _seq) return; // eskirgan javob (F2)
    if (r.ok) {
      // Chegara serverdan keladi (tarif o'zgarsa ilova yangilanmasdan ham
      // to'g'ri). Shakl: body.limit.max_houses — ILDIZDA emas (FINDING 6).
      applyHouses(ijParseHouses(r.data), r.body);
    } else if (_missing(r)) {
      // Backend hali yo'q — bo'sh ro'yxat, xato ko'rsatilmaydi.
      backendMissing = true;
      housesLoaded = true;
      _houses.clear();
    } else {
      // Kesh SAQLANADI (F5: bor ro'yxat skeletga tushmasin) — faqat banner
      // bayrog'i ko'tariladi.
      _fail(r);
      loadError = r.error;
    }
    if (notify) notifyListeners();
  }

  Future<void> _loadCharges(int seq) async {
    final r = await _req('GET', '/charges?$_range');
    if (seq != _seq) return; // eskirgan javob (F2)
    if (r.ok) {
      applyPage(ijParseCharges(ijChargesPayload(r.data, r.body)));
    } else if (_missing(r)) {
      // Backend hali yo'q — bo'sh davr, xato ko'rsatilmaydi.
      chargesMissing = true;
      _charges.clear();
      _payments.clear();
    } else {
      // F1: ESKI OY qatorlari jim qolib ketmasin — davr tozalanadi, ro'yxat
      // tanasida qayta urinish tugmali banner chiziladi (loadError).
      _fail(r);
      loadError = r.error;
      _charges.clear();
      _payments.clear();
    }
  }

  Future<void> _loadSummary(int seq) async {
    final r = await _req('GET', '/summary?$_range');
    if (seq != _seq) return; // eskirgan javob (F2)
    if (r.ok && r.data is Map) {
      summary = IjaraSummary.fromJson(_map(r.data));
    }
    // Xato bo'lsa jim o'tamiz: summary load() boshida tozalangan (F4), shuning
    // uchun periodTotals yuklangan qatorlardan O'ZI hisoblaydi — eski oyning
    // raqami hech qachon qolib ketmaydi.
  }

  /// 023 — ko'rinadigan uylarda AMALDA ishlatilayotgan valyutalar (tartibi
  /// kIjaraCurrencies bo'yicha barqaror). Bitta bo'lsa ekran avvalgidek bitta
  /// yakun ko'rsatadi; ikkitasi bo'lsa yakunlar VALYUTA BO'YICHA AJRATILADI.
  List<String> get currenciesInUse {
    final set = <String>{for (final h in houses) h.currency};
    final list = [for (final c in kIjaraCurrencies) if (set.contains(c)) c];
    return list.isEmpty ? const [kIjaraCurUzs] : list;
  }

  /// 023 — birdan ortiq valyuta ishlatilyaptimi. TRUE bo'lsa server xulosasi
  /// (summary) ISHLATILMAYDI: u so'm va dollarni bitta songa qo'shib yuboradi,
  /// bu esa pul xatosi. Bunday holatda yakunlar lokal, valyuta bo'yicha
  /// ajratilgan holda hisoblanadi.
  bool get mixedCurrency => currenciesInUse.length > 1;

  /// Uy id -> valyuta (yakunlarni ajratish uchun tez qidiruv).
  String currencyOf(String houseId) => houseById(houseId)?.currency ?? kIjaraCurUzs;

  /// 023 — bitta valyuta bo'yicha davr yakunlari.
  IjaraTotals periodTotalsOf(String cur) => ijSumPeriod(
        _charges.where((c) => currencyOf(c.houseId) == cur),
        _payments.where((pm) => currencyOf(pm.houseId) == cur),
      );

  /// 023 — bitta valyuta bo'yicha pill yig'indilari.
  Map<String, int> pillSumsOf(String cur) => ijPillSums(
        _charges.where((c) => currencyOf(c.houseId) == cur),
        _payments.where((pm) => currencyOf(pm.houseId) == cur),
      );

  /// Ko'rinadigan davr yakunlari. Server xulosasi bo'lmasa — yuklangan
  /// hisoblar VA taqsimlanmagan to'lovlardan hisoblanadi (raqamlar ro'yxat
  /// bilan doim mos bo'lsin). Ilgari bu yerda faqat ijSumCharges edi: hisob
  /// bekor qilinganda backend unga bog'langan to'lovni UZADI, natijada qo'lga
  /// olingan pul sarlavhadagi yakundan YO'QOLARDI (server esa uni sanaydi).
  IjaraTotals get periodTotals {
    // 023: aralash valyutada server xulosasi noto'g'ri (so'm + dollar) —
    // lokal hisobga tushamiz va UI yakunlarni ajratib ko'rsatadi.
    if (!mixedCurrency && (summary.charged != 0 || summary.paid != 0)) {
      return IjaraTotals(charged: summary.charged, paid: summary.paid, left: summary.left);
    }
    return ijSumPeriod(_charges, _payments);
  }

  // ---------------- Uylar ----------------

  /// Yangi uy. 403 (HOUSE_LIMIT) / 402 (SUB_EXPIRED) — server rad etdi:
  /// `lastCode` to'ldiriladi va UI serverning o'zbekcha matni O'RNIGA modulning
  /// 6 tilli xabarini ko'rsatadi (ijara.dart `_toastErr`).
  Future<bool> createHouse(Map<String, dynamic> body) async {
    _clearErr();
    final r = await _req('POST', '/houses', body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    // Uylar ro'yxatini refresh() o'zi qayta o'qiydi (bitta yo'l, bitta seq) —
    // alohida loadHouses chaqirilsa poyga tokenidan chetda qolardi (F2).
    housesLoaded = false;
    await refresh();
    return true;
  }

  Future<bool> patchHouse(String id, Map<String, dynamic> body) async {
    _clearErr();
    final r = await _req('PATCH', '/houses/$id', body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    housesLoaded = false; // createHouse'dagi izohga qarang
    await refresh();
    return true;
  }

  /// O'chirish YO'Q — arxivlash (tarix saqlanadi).
  Future<bool> archiveHouse(String id) => patchHouse(id, {'archived': true});

  // ---------------- Hisoblar ----------------

  Future<bool> createCharge(Map<String, dynamic> body) => _mutate('POST', '/charges', body: body);

  Future<bool> patchCharge(String id, Map<String, dynamic> body) =>
      _mutate('PATCH', '/charges/$id', body: body);

  /// Soft-cancel: server status'ni 'bekor' qiladi (yozuv yo'qolmaydi).
  Future<bool> cancelCharge(String id) => _mutate('DELETE', '/charges/$id');

  // ---------------- To'lovlar ----------------

  Future<bool> addPayment(Map<String, dynamic> body) => _mutate('POST', '/payments', body: body);

  Future<bool> deletePayment(String id) => _mutate('DELETE', '/payments/$id');

  // ---------------- Oy generatori (U2) ----------------

  /// Ko'rilayotgan oy uchun tanlangan uylarga KETMA-KET 'ijara' hisobi yozadi
  /// (davr — joriy ko'rilayotgan oy, summa — uyning oylik ijarasi). Bitta uy
  /// xato bersa QOLGANLARI davom etadi; 402 (kvota) kelsa to'xtaydi — paywall
  /// _req ichida allaqachon ochilgan, davomi ham shu xatoni olardi.
  /// Qaytadi: yozilganlar soni. Oxirida davr BIR marta qayta o'qiladi.
  Future<int> generateRentCharges(List<House> targets,
      {void Function(int done, int total)? onProgress}) async {
    _clearErr();
    final seq = _seq; // reset/logout bo'lsa yozishni davom ettirmaymiz
    final per = ijPeriod(month);
    var ok = 0;
    for (var i = 0; i < targets.length; i++) {
      if (seq != _seq) return ok;
      final h = targets[i];
      final r = await _req('POST', '/charges', body: {
        'house_id': h.id,
        'period': per,
        'kind': 'ijara',
        'title': ij('kindIjara'),
        'amount': h.rentAmount,
      });
      if (r.ok) {
        ok++;
      } else {
        _fail(r);
        if (r.status == 402) break;
      }
      onProgress?.call(i + 1, targets.length);
    }
    if (seq == _seq) await refresh();
    return ok;
  }

  /// Mutatsiya + davrni qayta o'qish. Muvaffaqiyatsizda `error`/`lastCode`
  /// to'ldiriladi va UI toast qiladi (402 bo'lsa paywall allaqachon ochilgan).
  Future<bool> _mutate(String method, String path, {Map<String, dynamic>? body}) async {
    _clearErr();
    final r = await _req(method, path, body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    await refresh();
    return true;
  }
}

/// Yagona nusxa — ekran shunga ulanadi.
final IjaraRepo ijaraRepo = IjaraRepo();
