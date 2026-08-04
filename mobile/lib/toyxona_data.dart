// Trust — To'yxona (to'y zali) moduli ma'lumot qatlami.
// Backend: /api/toyxona (src/routes/toyxona.js), sxema: supabase/migrations/021_toyxona.sql.
// Mock YO'Q — hamma ma'lumot serverdan.
//
// BUTUN HTTP shu faylda: shartnoma o'zgarsa faqat shu fayl tahrirlanadi.
// circles_data.dart idiomasi: api.dart (umumiy fayl) tegilmaydi, so'rov yordamchisi
// shu yerda — auth header, 401 -> markazlashgan logout, 402 -> obuna to'sig'i,
// timeout xabarlari Api._req bilan bir xil.
//
// FARQ (sabab: fayl-egalik cheklovi): store.dart ga tegib bo'lmagani uchun repo
// O'ZI ChangeNotifier — ekranlar unga ListenableBuilder bilan ulanadi
// (CirclesRepo'da bu vazifani store bajaradi).
//
// ATAMA: `hall` = bitta TO'YXONA (bandlanadigan obyekt), zal ichidagi xona emas.
// Har to'yxona ALOHIDA hisob yuritadi. `menu` (hall_menus) = narx toifasi.
//
// SNAPSHOT QOIDASI (backend bilan kelishilgan): bandning price_per_guest va
// menu_title — band qilingan PAYTDAGI nusxa. Narx toifasi keyin o'zgarsa yoki
// o'chsa, eski bandlarning puli QAYTA HISOBLANMAYDI. Shuning uchun UI narxni
// HAR DOIM booking'dan o'qiydi, hech qachon menu'dan qayta hisoblamaydi.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'toyxona_l10n.dart';

const String _base = '/api/toyxona';

/// Tanlangan to'yxona SharedPreferences kaliti (modul ichidagi holat).
const String _prefHall = 'toy_hall';

/// "Hammasi" (barcha to'yxonalar) tanlovi uchun saqlash qiymati.
const String _allSentinel = '__all__';

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
      // 402 — bepul limit (5 bron) tugagan: modul nomi bilan markazlashgan paywall.
      //
      // DIQQAT: 403 HALL_LIMIT (bitta akkaunt = bitta to'yxona) SHU YERGA
      // TUSHMAYDI va tushmasligi ham kerak — u yerda sotib olinadigan narsa yo'q
      // (do'konlar "miqdorli" obunani sotmaydi, ikkinchi to'yxona = alohida
      // akkaunt). Paywall ochilsa foydalanuvchi pul to'lab ham hech narsa
      // ololmasdi. Faqat 402 paywallga ketadi.
      if (res.statusCode == 402) Api.onPaymentRequired?.call(code, 'toyxona');
      return ApiRes(false, null, (map['error'] as String?) ?? ty('errGeneric'), res.statusCode, code, map);
    }
    return ApiRes(true, map.containsKey('data') ? map['data'] : map, '', res.statusCode, '', map);
  } on TimeoutException {
    return ApiRes(false, null, ty('errWaking'), 0);
  } catch (_) {
    return ApiRes(false, null, ty('errNetwork'), 0);
  }
}

// ===================== Format / sana yordamchilari =====================

/// 1234567 -> "1 234 567" (store._fx bilan bir xil format; valyuta alohida).
String toyFx(num v) {
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
String toyMoney(num v) => '${v < 0 ? '−' : ''}${toyFx(v)} ${ty('som')}';

/// DateTime -> 'YYYY-MM-DD' (mahalliy sana; UTC'ga o'girilmaydi).
String toyYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 'YYYY-MM-DD' (yoki to'liq ISO) -> mahalliy DateTime.
/// DateTime.parse ISHLATILMAYDI: 'Z' bilan kelgan sana mahalliy zonada ±1 kunga
/// siljib ketardi (qarz daftaridagi ma'lum xato) — shu sabab qo'lda ajratamiz.
DateTime toyParseYmd(String raw) {
  final s = raw.length >= 10 ? raw.substring(0, 10) : raw;
  final parts = s.split('-');
  if (parts.length < 3) return DateTime.now();
  final y = int.tryParse(parts[0]) ?? DateTime.now().year;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  return DateTime(y, m, d);
}

/// Sana faqat kun aniqligida.
DateTime toyDay(DateTime d) => DateTime(d.year, d.month, d.day);

bool toySameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "12 avgust" — til lug'atidan oy nomi bilan.
String toyDateShort(DateTime d) => '${d.day} ${tyMonth(d.month)}';

/// "12 avgust 2026"
String toyDateLong(DateTime d) => '${d.day} ${tyMonth(d.month)} ${d.year}';

DateTime toyMonthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime toyMonthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

int _int(dynamic v, [int fb = 0]) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? fb);
int? _intOrNull(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

// ===================== Modellar =====================

/// Slotlar — kalitlar backend bilan bir xil, KALENDAR tartibida.
const List<String> kToySlots = ['nahor', 'tushlik', 'kechki'];

/// Holatlar — backend bilan bir xil.
const List<String> kToyStatuses = ['band', 'tasdiq', 'yakun', 'bekor'];

/// To'lov turlari (migratsiya 021: faqat shu ikkitasi).
const List<String> kToyPayKinds = ['avans', 'yakuniy'];

/// Tez qo'shiladigan xizmatlar — yorliqlar l10n kalitlari orqali.
const List<String> kToyQuickServiceKeys = [
  'svcMusic', 'svcPhoto', 'svcVideo', 'svcCake', 'svcDecor', 'svcFire',
];

/// Narx toifasi (hall_menus) — "Oddiy — 150 000", "Lyuks — 200 000".
class Menu {
  final String id;
  final String hallId;
  final String title;
  final int pricePerGuest;
  final int sort;
  final bool archived;
  const Menu({
    required this.id,
    required this.title,
    required this.pricePerGuest,
    this.hallId = '',
    this.sort = 0,
    this.archived = false,
  });

  factory Menu.fromJson(Map<String, dynamic> j) => Menu(
        id: '${j['id']}',
        hallId: '${j['hall_id'] ?? ''}',
        title: (j['title'] as String?) ?? '',
        pricePerGuest: _int(j['price_per_guest']),
        sort: _int(j['sort']),
        archived: j['archived'] == true,
      );
}

/// To'yxona (halls) — narx toifalari ICHIDA keladi (backend embed qiladi).
class Hall {
  final String id;
  final String name;
  final int? capacity;
  final int pricePerGuest; // toifasiz egalar uchun zaxira/default narx
  final int sort;
  final bool archived;
  final List<Menu> menus;
  const Hall({
    required this.id,
    required this.name,
    this.capacity,
    this.pricePerGuest = 0,
    this.sort = 0,
    this.archived = false,
    this.menus = const [],
  });

  factory Hall.fromJson(Map<String, dynamic> j) => Hall(
        id: '${j['id']}',
        name: (j['name'] as String?) ?? '',
        capacity: _intOrNull(j['capacity']),
        pricePerGuest: _int(j['price_per_guest']),
        sort: _int(j['sort']),
        archived: j['archived'] == true,
        // menus HAR DOIM massiv (backend kafolati) — shartsiz o'qiymiz.
        menus: ((j['menus'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Menu.fromJson)
            .toList(),
      );

  /// Faol (arxivlanmagan) narx toifalari, tartib bo'yicha.
  List<Menu> get tiers {
    final list = menus.where((m) => !m.archived).toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.title.compareTo(b.title));
    return list;
  }
}

class BookingItem {
  final String id;
  final String title;
  final int amount; // BIR DONA narxi
  final int qty;
  const BookingItem({required this.id, required this.title, required this.amount, this.qty = 1});

  factory BookingItem.fromJson(Map<String, dynamic> j) {
    final q = _int(j['qty'], 1);
    return BookingItem(
      id: '${j['id']}',
      title: (j['title'] as String?) ?? '',
      amount: _int(j['amount']),
      qty: q <= 0 ? 1 : q,
    );
  }

  int get total => amount * qty;
}

class BookingPayment {
  final String id;
  final int amount;
  final String kind; // avans | yakuniy
  final String paidAt;
  final String note;
  const BookingPayment({
    required this.id,
    required this.amount,
    this.kind = 'avans',
    this.paidAt = '',
    this.note = '',
  });

  factory BookingPayment.fromJson(Map<String, dynamic> j) => BookingPayment(
        id: '${j['id']}',
        amount: _int(j['amount']),
        kind: (j['kind'] as String?) ?? 'avans',
        paidAt: '${j['paid_at'] ?? ''}',
        note: (j['note'] as String?) ?? '',
      );

  DateTime? get date => paidAt.isEmpty ? null : toyParseYmd(paidAt);
}

class Booking {
  final String id;
  final String? hallId;
  final String hallName;
  final String? menuId;
  final String menuTitle; // SNAPSHOT
  final DateTime eventDate;
  final String slot;
  final String clientName;
  final String clientPhone;
  final int guests;
  final int pricePerGuest; // SNAPSHOT
  final String note;
  final String status;
  final List<BookingItem> items;
  final List<BookingPayment> payments;
  final Map<String, int> totals; // server hisoblagan yakunlar

  const Booking({
    required this.id,
    required this.eventDate,
    required this.slot,
    required this.clientName,
    this.hallId,
    this.hallName = '',
    this.menuId,
    this.menuTitle = '',
    this.clientPhone = '',
    this.guests = 0,
    this.pricePerGuest = 0,
    this.note = '',
    this.status = 'band',
    this.items = const [],
    this.payments = const [],
    this.totals = const {},
  });

  factory Booking.fromJson(Map<String, dynamic> j) {
    final rawTotals = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Booking(
      id: '${j['id']}',
      hallId: j['hall_id'] == null ? null : '${j['hall_id']}',
      hallName: (j['hall_name'] as String?) ?? '',
      menuId: j['menu_id'] == null ? null : '${j['menu_id']}',
      menuTitle: (j['menu_title'] as String?) ?? '',
      eventDate: toyParseYmd('${j['event_date'] ?? ''}'),
      slot: (j['slot'] as String?) ?? 'kechki',
      clientName: (j['client_name'] as String?) ?? '',
      clientPhone: (j['client_phone'] as String?) ?? '',
      guests: _int(j['guests']),
      pricePerGuest: _int(j['price_per_guest']),
      note: (j['note'] as String?) ?? '',
      status: (j['status'] as String?) ?? 'band',
      items: ((j['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BookingItem.fromJson)
          .toList(),
      payments: ((j['payments'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BookingPayment.fromJson)
          .toList(),
      totals: {
        for (final k in ['food', 'extras', 'total', 'paid', 'left'])
          if (rawTotals[k] != null) k: _int(rawTotals[k]),
      },
    );
  }

  // Server bergan yakunlar ustuvor; bo'lmasa klientda hisoblanadi (snapshotdan).
  int get food => totals['food'] ?? guests * pricePerGuest;
  int get extras => totals['extras'] ?? items.fold(0, (s, i) => s + i.total);
  int get total => totals['total'] ?? (food + extras);
  int get paid => totals['paid'] ?? payments.fold(0, (s, p) => s + p.amount);
  /// Ortiqcha to'lovda MANFIY bo'lishi mumkin — clamp QILINMAYDI (backend shartnomasi).
  int get left => totals['left'] ?? (total - paid);

  bool get cancelled => status == 'bekor';
}

class ToySummary {
  /// Oraliqdagi BARCHA bandlar (bekor qilinganlar ham).
  final int count;

  /// total/paid/left AYNAN shu bandlardan hisoblangan (bekor qilinganlarsiz) —
  /// sarlavhadagi "N to'y · <summa>" o'zaro mos bo'lishi uchun shu ishlatiladi.
  final int countActive;

  final int total, paid, left;

  /// BEKOR QILINGAN bronlardan olingan va EGADA QOLGAN pul (odatda avans).
  /// `paid` ICHIGA KIRMAYDI va hech qanday boshqa raqamga qo'shilmaydi — bu
  /// bo'lib o'tgan to'ydan tushgan daromad emas. Ilgari bu pul oylik hisobdan
  /// butunlay yo'qolib, ilova raqamlari eganing kassasiga mos kelmasdi.
  final int cancelledPaid;

  final Map<String, int> byStatus;
  const ToySummary({
    this.count = 0,
    this.countActive = 0,
    this.total = 0,
    this.paid = 0,
    this.left = 0,
    this.cancelledPaid = 0,
    this.byStatus = const {},
  });

  factory ToySummary.fromJson(Map<String, dynamic> j) {
    final count = _int(j['count']);
    final byStatus = {
      for (final e in ((j['byStatus'] as Map?) ?? const {}).entries) '${e.key}': _int(e.value),
    };
    return ToySummary(
      count: count,
      // Zaxira: countActive yubormaydigan ESKI backend (Render hali yangilanmagan
      // bo'lishi mumkin) — o'sha eski qoida bo'yicha hisoblaymiz.
      countActive: j['countActive'] != null
          ? _int(j['countActive'])
          : (count - (byStatus['bekor'] ?? 0)).clamp(0, count),
      total: _int(j['total']),
      paid: _int(j['paid']),
      left: _int(j['left']),
      // Eski deploy bu maydonni yubormaydi -> 0 (qator umuman ko'rinmaydi).
      cancelledPaid: _int(j['cancelledPaid']),
      byStatus: byStatus,
    );
  }
}

// ===================== Repozitoriy =====================

/// Tarmoqli repozitoriy. Ekranlar `ListenableBuilder(listenable: toyRepo, ...)`
/// bilan ulanadi. Xatolar `error` maydonida — UI toast + qayta urinish beradi.
class ToyxonaRepo extends ChangeNotifier {
  final List<Hall> _halls = [];
  final List<Booking> _month = [];
  final List<Booking> _upcoming = [];

  DateTime month = toyMonthStart(DateTime.now());
  ToySummary summary = const ToySummary();

  /// Tanlangan to'yxona. null = "Hammasi" (birlashtirilgan ko'rinish).
  String? selectedHallId;
  bool _selectionRestored = false;

  bool loading = false;
  bool loaded = false;
  bool hallsLoaded = false;
  String? error;
  int errorStatus = 0;
  /// Oxirgi so'rovning server xato KODI ('SLOT_TAKEN', 'SUB_EXPIRED', ...).
  String lastCode = '';
  /// Oxirgi xatoning qo'shimcha tafsiloti (SLOT_TAKEN'da "Band: <mijoz>").
  String lastDetail = '';

  /// Arxivlanmagan to'yxonalar (tartib bo'yicha).
  List<Hall> get halls {
    final list = _halls.where((h) => !h.archived).toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.name.compareTo(b.name));
    return list;
  }

  bool get hasHalls => halls.isNotEmpty;

  Hall? hallById(String? id) {
    if (id == null) return null;
    for (final h in _halls) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Tanlangan to'yxona ("Hammasi" bo'lsa null).
  Hall? get currentHall => hallById(selectedHallId);

  /// Tanlangan to'yxonaning faol narx toifalari ("Hammasi"da bo'sh).
  List<Menu> get currentTiers => currentHall?.tiers ?? const [];

  /// Berilgan to'yxonaning faol narx toifalari.
  List<Menu> tiersOf(String? hallId) => hallById(hallId)?.tiers ?? const [];

  /// Oy bronlari — SERVER TARTIBIDA (event_date, keyin slot kalendar tartibida).
  List<Booking> get monthBookings => List.unmodifiable(_month);

  /// Kalendar nuqtalari uchun: bekor qilinganlar hisobga olinmaydi.
  List<Booking> get activeMonthBookings => _month.where((b) => !b.cancelled).toList();

  Booking? byId(String? id) {
    if (id == null) return null;
    for (final b in _month) {
      if (b.id == id) return b;
    }
    for (final b in _upcoming) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Berilgan kun + slotdagi bron (yo'q bo'lsa null).
  Booking? at(DateTime day, String slot) {
    for (final b in _month) {
      if (!b.cancelled && b.slot == slot && toySameDay(b.eventDate, day)) return b;
    }
    return null;
  }

  /// Kundagi band slotlar to'plami.
  Set<String> bookedSlots(DateTime day) => {
        for (final b in _month)
          if (!b.cancelled && toySameDay(b.eventDate, day)) b.slot,
      };

  /// Bugundan boshlab eng yaqin bronlar (server tartibi saqlanadi).
  List<Booking> upcoming([int limit = 6]) {
    final today = toyDay(DateTime.now());
    return _upcoming
        .where((b) => !b.cancelled && !b.eventDate.isBefore(today))
        .take(limit)
        .toList();
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
  }

  List<Booking> _parseBookings(dynamic data) => data is List
      ? data.cast<Map<String, dynamic>>().map(Booking.fromJson).toList()
      : <Booking>[];

  /// hall_id so'rov parametri: "Hammasi" bo'lsa umuman yuborilmaydi.
  String get _hallQuery => selectedHallId == null ? '' : '&hall_id=$selectedHallId';

  // ---------------- Tanlov (to'yxona) ----------------

  /// Saqlangan tanlovni tiklash. Zallar yuklangach chaqiriladi: saqlangan id
  /// endi mavjud bo'lmasa (arxivlangan/o'chgan) — BIRINCHI to'yxonaga tushadi.
  Future<void> _restoreSelection() async {
    if (_selectionRestored) return;
    _selectionRestored = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_prefHall);
      if (saved == _allSentinel) {
        selectedHallId = null;
        return;
      }
      if (saved != null && hallById(saved) != null && hallById(saved)?.archived != true) {
        selectedHallId = saved;
        return;
      }
    } catch (_) {
      // SharedPreferences ishlamasa — standart tanlovga tushamiz
    }
    // Standart: BIRINCHI to'yxona (ega odatda bittasi bilan ishlaydi).
    selectedHallId = halls.isNotEmpty ? halls.first.id : null;
  }

  /// To'yxonani almashtirish — butun ekran (kalendar, xulosa, yaqin to'ylar)
  /// shu tanlov bo'yicha qayta yuklanadi. null = "Hammasi".
  Future<void> selectHall(String? id) async {
    if (selectedHallId == id) return;
    selectedHallId = id;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_prefHall, id ?? _allSentinel);
    } catch (_) {
      // saqlanmasa ham sessiya davomida ishlaydi
    }
    await load(month);
  }

  // ---------------- Yuklash ----------------

  /// Oy ko'rinishi uchun hamma narsa: to'yxonalar (bir marta, narxlari bilan),
  /// oy bronlari, xulosa, yaqin to'ylar. Ekran faqat shuni biladi.
  Future<void> load(DateTime m, {bool silent = false}) async {
    month = toyMonthStart(m);
    if (!silent) {
      loading = true;
      _clearErr();
      notifyListeners();
    }
    if (!hallsLoaded) {
      await loadHalls(notify: false);
      await _restoreSelection();
    }
    await Future.wait([
      _loadMonth(notify: false),
      _loadSummary(notify: false),
      _loadUpcoming(notify: false),
    ]);
    loading = false;
    if (error == null) loaded = true;
    notifyListeners();
  }

  /// Joriy oyni jimgina qayta o'qish (mutatsiyalardan keyin).
  Future<void> refresh() => load(month, silent: true);

  /// To'yxonalar + ularning narx toifalari (backend menus[] ni ichida yuboradi).
  Future<void> loadHalls({bool notify = true}) async {
    final r = await _req('GET', '/halls');
    if (r.ok) {
      _halls
        ..clear()
        ..addAll((r.data is List ? r.data as List : const [])
            .cast<Map<String, dynamic>>()
            .map(Hall.fromJson));
      hallsLoaded = true;
      // Tanlangan to'yxona ARXIVLANGAN yoki o'chgan bo'lsa — birinchisiga tushamiz
      // (hall_id null bo'lsa "Hammasi"). hallById arxivlanganlarni ham topadi,
      // shuning uchun `== null` YETARLI EMAS: arxivlangandan keyin tanlov unda
      // osilib qolardi va header hali ham o'sha to'yxona nomini ko'rsatardi.
      // Bitta akkaunt = bitta to'yxona bo'lgani uchun arxivlash — to'yxonani
      // ALMASHTIRISHNING yagona yo'li, ya'ni bu yo'l endi odatiy holat.
      final sel = hallById(selectedHallId);
      if (selectedHallId != null && (sel == null || sel.archived)) {
        selectedHallId = halls.isNotEmpty ? halls.first.id : null;
      }
    } else {
      _fail(r);
    }
    if (notify) notifyListeners();
  }

  Future<void> _loadMonth({bool notify = true}) async {
    final from = toyYmd(toyMonthStart(month));
    final to = toyYmd(toyMonthEnd(month));
    final r = await _req('GET', '/bookings?from=$from&to=$to$_hallQuery');
    if (r.ok) {
      // Server tartibini SAQLAYMIZ (event_date, keyin slot kalendar tartibida).
      _month
        ..clear()
        ..addAll(_parseBookings(r.data));
    } else {
      _fail(r);
    }
    if (notify) notifyListeners();
  }

  Future<void> _loadSummary({bool notify = true}) async {
    final from = toyYmd(toyMonthStart(month));
    final to = toyYmd(toyMonthEnd(month));
    final r = await _req('GET', '/summary?from=$from&to=$to$_hallQuery');
    if (r.ok && r.data is Map) {
      summary = ToySummary.fromJson(Map<String, dynamic>.from(r.data as Map));
    } else if (!r.ok) {
      _fail(r);
    }
    if (notify) notifyListeners();
  }

  /// Bugundan +180 kun — "yaqin to'ylar" bloki uchun.
  Future<void> _loadUpcoming({bool notify = true}) async {
    final today = toyDay(DateTime.now());
    final from = toyYmd(today);
    final to = toyYmd(today.add(const Duration(days: 180)));
    final r = await _req('GET', '/bookings?from=$from&to=$to$_hallQuery');
    if (r.ok) {
      _upcoming
        ..clear()
        ..addAll(_parseBookings(r.data));
    }
    // Xato bo'lsa jim o'tamiz: bu yordamchi blok, asosiy ko'rinishni buzmasin.
    if (notify) notifyListeners();
  }

  /// Mutatsiya qaytargan TO'LIQ bandni ro'yxatlarda almashtirish (refetch shart emas).
  void _upsertBooking(dynamic data) {
    if (data is! Map || data['id'] == null) return;
    final b = Booking.fromJson(Map<String, dynamic>.from(data));
    for (final list in [_month, _upcoming]) {
      final i = list.indexWhere((x) => x.id == b.id);
      if (i >= 0) list[i] = b;
    }
  }

  // ---------------- Bronlar ----------------

  /// Yangi bron. Muvaffaqiyatda Booking, aks holda null.
  /// `lastCode == 'SLOT_TAKEN'` — o'sha sana/vaqt/to'yxona band (409):
  /// UI toast beradi va FORMANI OCHIQ QOLDIRADI.
  /// `lastCode == 'SUB_EXPIRED'` — 5 ta bepul bron tugagan (402).
  ///
  /// MUHIM: menu_id yuborilsa price_per_guest YUBORILMASIN — server narx va
  /// nomni o'sha toifadan nusxalaydi. price_per_guest faqat QO'LDA narx uchun.
  Future<Booking?> createBooking(Map<String, dynamic> body) async {
    _clearErr();
    final r = await _req('POST', '/bookings', body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return null;
    }
    final b = r.data is Map ? Booking.fromJson(Map<String, dynamic>.from(r.data as Map)) : null;
    await refresh(); // xulosa/soni ham yangilansin
    return b;
  }

  Future<bool> patchBooking(String id, Map<String, dynamic> body) async {
    _clearErr();
    final r = await _req('PATCH', '/bookings/$id', body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    await refresh();
    return true;
  }

  Future<bool> deleteBooking(String id) async {
    _clearErr();
    final r = await _req('DELETE', '/bookings/$id');
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    _month.removeWhere((b) => b.id == id);
    _upcoming.removeWhere((b) => b.id == id);
    await refresh();
    return true;
  }

  Future<bool> setStatus(String id, String status) => patchBooking(id, {'status': status});

  // ---------------- Xizmatlar (items) ----------------
  // POST/DELETE TO'LIQ bandni qaytaradi — qatorni almashtiramiz, xulosani yangilaymiz.

  Future<bool> addItem(String bookingId, String title, int amount, {int qty = 1}) =>
      _bookingMutation('POST', '/bookings/$bookingId/items',
          body: {'title': title, 'amount': amount, if (qty != 1) 'qty': qty});

  Future<bool> deleteItem(String itemId) => _bookingMutation('DELETE', '/items/$itemId');

  // ---------------- To'lovlar ----------------

  Future<bool> addPayment(String bookingId, int amount,
          {String kind = 'avans', String note = ''}) =>
      _bookingMutation('POST', '/bookings/$bookingId/payments',
          body: {'amount': amount, 'kind': kind, if (note.isNotEmpty) 'note': note});

  Future<bool> deletePayment(String paymentId) =>
      _bookingMutation('DELETE', '/payments/$paymentId');

  /// Bandning ichki elementini o'zgartiruvchi so'rov: javobdagi to'liq band
  /// ro'yxatga yoziladi, so'ng oylik xulosa jimgina yangilanadi.
  Future<bool> _bookingMutation(String method, String path, {Map<String, dynamic>? body}) async {
    _clearErr();
    final r = await _req(method, path, body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    _upsertBooking(r.data);
    notifyListeners();
    await _loadSummary();
    return true;
  }

  // ---------------- To'yxonalar (halls) ----------------

  Future<bool> createHall(String name, {int? capacity, int? pricePerGuest}) async {
    _clearErr();
    final r = await _req('POST', '/halls', body: {
      'name': name,
      if (capacity != null) 'capacity': capacity,
      if (pricePerGuest != null) 'price_per_guest': pricePerGuest,
    });
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    final wasEmpty = halls.isEmpty;
    await loadHalls(notify: false);
    // Birinchi to'yxona qo'shilganda darhol o'shanga o'tamiz (bo'sh ekran qolmasin).
    if (wasEmpty && halls.isNotEmpty) {
      selectedHallId = halls.first.id;
      try {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_prefHall, selectedHallId!);
      } catch (_) {/* saqlanmasa ham ishlaydi */}
      await load(month, silent: true);
    } else {
      notifyListeners();
    }
    return true;
  }

  Future<bool> patchHall(String id, Map<String, dynamic> body) async {
    _clearErr();
    final r = await _req('PATCH', '/halls/$id', body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    await loadHalls(notify: false);
    // Arxivlangan bo'lsa tanlov boshqasiga o'tgan bo'lishi mumkin — qayta yuklaymiz.
    await load(month, silent: true);
    return true;
  }

  // ---------------- Narx toifalari (hall_menus) ----------------
  // Har mutatsiyadan keyin /halls qayta o'qiladi: menus[] ichida keladi,
  // shuning uchun bitta so'rov butun holatni yangilaydi.

  Future<bool> createMenu(String hallId, String title, int pricePerGuest) =>
      _menuMutation('POST', '/halls/$hallId/menus',
          body: {'title': title, 'price_per_guest': pricePerGuest});

  Future<bool> patchMenu(String menuId, Map<String, dynamic> body) =>
      _menuMutation('PATCH', '/menus/$menuId', body: body);

  Future<bool> deleteMenu(String menuId) => _menuMutation('DELETE', '/menus/$menuId');

  Future<bool> _menuMutation(String method, String path, {Map<String, dynamic>? body}) async {
    _clearErr();
    final r = await _req(method, path, body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    await loadHalls();
    return true;
  }
}

/// Yagona nusxa — ekranlar shunga ulanadi.
final ToyxonaRepo toyRepo = ToyxonaRepo();
