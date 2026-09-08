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
//
// QOLDIQ QOIDASI (backend izohi bilan bir xil): qoldiq HAR DOIM totals.left
// bo'yicha ko'rsatiladi, hech qachon statusdan hosil qilinmaydi — 'yakun'
// bandga keyin xizmat qo'shilsa left > 0 bo'lishi NORMAL holat.
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
    // Ulanish xatosi: asosiy manzil ochilmasa zaxiraga o'tamiz (api.dart) — keyingi so'rov o'sha yerga
    Api.useFallback();
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

/// 'YYYY-MM-DD' (yoki to'liq ISO) -> mahalliy DateTime, buzuq sana -> NULL.
/// DateTime.parse ISHLATILMAYDI: 'Z' bilan kelgan sana mahalliy zonada ±1 kunga
/// siljib ketardi (qarz daftaridagi ma'lum xato) — shu sabab qo'lda ajratamiz.
/// NULL (ijParseYmd bilan bir xil): ilgari buzuq sana DateTime.now() bo'lib
/// qaytardi va yaroqsiz qator kalendarda BUGUNGI bron bo'lib ko'rinardi —
/// endi chaqiruvchi bunday qatorni tashlab ketadi.
DateTime? toyParseYmd(String raw) {
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

/// Faqat Map bo'lgan elementlarni oladi (buzuq element ro'yxatni YIQITMAYDI).
List<Map<String, dynamic>> _rowsOf(dynamic v) => v is List
    ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
    : const <Map<String, dynamic>>[];

// ===================== Modellar =====================

/// Slotlar — kalitlar backend bilan bir xil, KALENDAR tartibida.
const List<String> kToySlots = ['nahor', 'tushlik', 'kechki'];

/// Holatlar — backend bilan bir xil.
const List<String> kToyStatuses = ['band', 'tasdiq', 'yakun', 'bekor'];

/// To'lov turlari (migratsiya 021: faqat shu ikkitasi).
const List<String> kToyPayKinds = ['avans', 'yakuniy'];

/// Xizmat sonining formadagi yuqori chegarasi (server 10 000 gacha qabul
/// qiladi, lekin bitta to'yda 20 tadan ortiq bir xil xizmat bo'lmaydi).
const int kToyMaxSvcQty = 20;

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
        title: '${j['title'] ?? ''}',
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
        name: '${j['name'] ?? ''}',
        capacity: _intOrNull(j['capacity']),
        pricePerGuest: _int(j['price_per_guest']),
        sort: _int(j['sort']),
        archived: j['archived'] == true,
        // menus HAR DOIM massiv (backend kafolati), lekin baribir ELEMENTMA-
        // ELEMENT ajratamiz: bitta buzuq toifa butun zallar ro'yxatini yiqitmasin.
        menus: [
          for (final m in _rowsOf(j['menus']))
            if (m['id'] != null) Menu.fromJson(m),
        ],
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
      title: '${j['title'] ?? ''}',
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
        kind: '${j['kind'] ?? 'avans'}',
        paidAt: '${j['paid_at'] ?? ''}',
        note: '${j['note'] ?? ''}',
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

  /// XAVFSIZ ajratish. Qoidalar:
  ///   * qator Map emas / id yo'q / event_date buzuq -> NULL (chaqiruvchi
  ///     tashlab ketadi — ilgari buzuq sana DateTime.now() bo'lib, qator
  ///     kalendarda BUGUNGI soxta bron bo'lib ko'rinardi);
  ///   * items/payments ELEMENTMA-ELEMENT o'qiladi — bitta buzuq element
  ///     faqat o'zi tushib qoladi (ilgari .cast + fromJson otilib, butun oy
  ///     abadiy skeletda qolardi);
  ///   * kutilmagan har qanday otilish ham NULL — hech qachon throw yo'q.
  static Booking? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final j = Map<String, dynamic>.from(raw);
      if (j['id'] == null) return null;
      final date = toyParseYmd('${j['event_date'] ?? ''}');
      if (date == null) return null;
      final rawTotals = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
      final items = <BookingItem>[];
      for (final e in _rowsOf(j['items'])) {
        try {
          if (e['id'] != null) items.add(BookingItem.fromJson(e));
        } catch (_) {/* buzuq xizmat qatori tashlab ketiladi */}
      }
      final pays = <BookingPayment>[];
      for (final e in _rowsOf(j['payments'])) {
        try {
          if (e['id'] != null) pays.add(BookingPayment.fromJson(e));
        } catch (_) {/* buzuq to'lov qatori tashlab ketiladi */}
      }
      return Booking(
        id: '${j['id']}',
        hallId: j['hall_id'] == null ? null : '${j['hall_id']}',
        hallName: '${j['hall_name'] ?? ''}',
        menuId: j['menu_id'] == null ? null : '${j['menu_id']}',
        menuTitle: '${j['menu_title'] ?? ''}',
        eventDate: date,
        slot: '${j['slot'] ?? 'kechki'}',
        clientName: '${j['client_name'] ?? ''}',
        clientPhone: '${j['client_phone'] ?? ''}',
        guests: _int(j['guests']),
        pricePerGuest: _int(j['price_per_guest']),
        note: '${j['note'] ?? ''}',
        status: '${j['status'] ?? 'band'}',
        items: items,
        payments: pays,
        totals: {
          for (final k in ['food', 'extras', 'total', 'paid', 'left'])
            if (rawTotals[k] != null) k: _int(rawTotals[k]),
        },
      );
    } catch (_) {
      return null;
    }
  }

  // Server bergan yakunlar ustuvor; bo'lmasa klientda hisoblanadi (snapshotdan).
  int get food => totals['food'] ?? guests * pricePerGuest;
  int get extras => totals['extras'] ?? items.fold(0, (s, i) => s + i.total);
  int get total => totals['total'] ?? (food + extras);
  int get paid => totals['paid'] ?? payments.fold(0, (s, p) => s + p.amount);
  /// Ortiqcha to'lovda MANFIY bo'lishi mumkin — clamp QILINMAYDI (backend shartnomasi).
  int get left => totals['left'] ?? (total - paid);

  bool get cancelled => status == 'bekor';

  /// Narx kelishilmagan band (U5): narx ham, xizmat ham yo'q. O'zbekistonda bu
  /// NORMAL holat — avans sanani ushlaydi, menyu keyin kelishiladi. Saqlash
  /// hech qachon bloklanmaydi, faqat yumshoq belgi ko'rsatiladi.
  bool get priceMissing => pricePerGuest == 0 && items.isEmpty;
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

// ===================== Sof funksiyalar (testlanadi) =====================

/// GET /bookings javobini ajratish: massiv bo'lmasa yoki qatorlar buzuq bo'lsa
/// — bo'sh/qisqartirilgan ro'yxat, HECH QACHON throw yo'q (bitta buzuq qator
/// butun oyni abadiy skeletda qoldirmasin).
List<Booking> toyParseBookings(dynamic data) {
  if (data is! List) return <Booking>[];
  final out = <Booking>[];
  for (final e in data) {
    final b = Booking.tryParse(e);
    if (b != null) out.add(b);
  }
  return out;
}

/// Mijoz tomonidagi oy xulosasi — backend foldSummary bilan BIR XIL qoidalar:
/// pul yig'indilari 'bekor'ni sanamaydi, bekor puli cancelledPaid'da alohida,
/// countActive = pul yig'indisiga kirgan bandlar soni. /summary yiqilganda
/// shownSummary shu funksiya orqali YUKLANGAN qatorlardan hisoblaydi (F3) —
/// eski oyning raqami hech qachon ko'rsatilmaydi.
ToySummary toyLocalSummary(Iterable<Booking> rows) {
  final byStatus = {for (final s in kToyStatuses) s: 0};
  var count = 0;
  var total = 0;
  var paid = 0;
  var cancelledPaid = 0;
  for (final b in rows) {
    count++;
    if (byStatus.containsKey(b.status)) byStatus[b.status] = byStatus[b.status]! + 1;
    if (b.cancelled) {
      cancelledPaid += b.paid;
      continue;
    }
    total += b.total;
    paid += b.paid;
  }
  return ToySummary(
    count: count,
    countActive: count - (byStatus['bekor'] ?? 0),
    total: total,
    paid: paid,
    left: total - paid,
    cancelledPaid: cancelledPaid,
    byStatus: byStatus,
  );
}

/// Qidiruv mosligi (U7): registrsiz, mijoz ismi / izoh / to'yxona / toifa
/// nomi bo'yicha; telefon uchun faqat RAQAMLAR solishtiriladi ("90 123" ham
/// "+998901234567" ni topadi).
bool toyMatches(Booking b, String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return false;
  if (b.clientName.toLowerCase().contains(s)) return true;
  if (b.note.toLowerCase().contains(s)) return true;
  if (b.hallName.toLowerCase().contains(s)) return true;
  if (b.menuTitle.toLowerCase().contains(s)) return true;
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 2 &&
      b.clientPhone.replaceAll(RegExp(r'[^0-9]'), '').contains(digits)) {
    return true;
  }
  return false;
}

/// Server qidiruvi + klient mosliklarini birlashtirish (U7): id bo'yicha dedup.
/// Tartib: avval server (u event_date DESC kafolatlab beradi), keyin faqat
/// klientda topilganlar o'z tartibida.
List<Booking> toyMergeSearch(List<Booking> server, List<Booking> local) {
  final seen = {for (final b in server) b.id};
  return [...server, for (final b in local) if (seen.add(b.id)) b];
}

/// Formadagi slot bandligi (U1): kun qatorlari ichidan AYNAN shu to'yxona va
/// slot bo'yicha bekor qilinmagan bandni topadi. hall_id NULL — ALOHIDA guruh
/// (backend qoidasi: to'yxonasiz bandlar o'zaro to'qnashadi, zallilarga emas).
/// exceptId — tahrirlanayotgan bandning O'ZI band deb ko'rsatilmasin.
Booking? toySlotTakenBy(Iterable<Booking> dayRows,
    {String? hallId, required String slot, String? exceptId}) {
  for (final b in dayRows) {
    if (b.cancelled || b.slot != slot) continue;
    if ((b.hallId ?? '') != (hallId ?? '')) continue;
    if (exceptId != null && b.id == exceptId) continue;
    return b;
  }
  return null;
}

/// Monoton so'rov-nomer (F2). Har yangi yuklash `begin()` bilan nomer oladi;
/// javob kelganda `isCurrent` false bo'lsa u ESKIRGAN — holatga yozilmaydi.
/// Tez oy almashtirishda "oxirgi kelgan yozadi" (last-write-wins) o'rniga
/// "faqat OXIRGI so'ralgan yozadi" — sekin kelgan eski oy tezkorini bosolmaydi.
class ToySeq {
  int _n = 0;
  int get current => _n;
  int begin() => ++_n;
  bool isCurrent(int token) => token == _n;
}

// ===================== Repozitoriy =====================

/// Tarmoqli repozitoriy. Ekranlar `ListenableBuilder(listenable: toyRepo, ...)`
/// bilan ulanadi. Xatolar `error` maydonida — UI toast + qayta urinish beradi.
class ToyxonaRepo extends ChangeNotifier {
  final List<Hall> _halls = [];
  final List<Booking> _month = [];
  final List<Booking> _upcoming = [];

  /// Qidiruvdan ochilgan, joriy oy/180-kun ro'yxatlarida BO'LMAGAN bandlar
  /// keshi (U7): tafsilot ekrani byId() bilan ishlaydi — bu kesh bo'lmasa
  /// uzoq sanali natija bosilganda qatlam darhol yopilib qolardi.
  final Map<String, Booking> _loose = {};

  DateTime month = toyMonthStart(DateTime.now());
  ToySummary summary = const ToySummary();

  /// summary AYNAN joriy yuklashda serverdan kelganmi (F3). False bo'lsa
  /// `shownSummary` yuklangan qatorlardan o'zi hisoblaydi — hech qachon
  /// oldingi oyning raqami ko'rsatilmaydi.
  bool summaryFresh = false;

  /// Tanlangan to'yxona. null = "Hammasi" (birlashtirilgan ko'rinish).
  String? selectedHallId;
  bool _selectionRestored = false;

  bool loading = false;
  bool loaded = false;
  bool hallsLoaded = false;
  String? error;

  /// FAQAT oy ro'yxati yuklanmay qolgan xato (F1) — mutatsiya xatolaridan
  /// AJRATILGAN: ekran bannerini faqat ro'yxat haqiqatan bo'sh qolganda
  /// ko'rsatadi (aks holda formadagi SLOT_TAKEN ham banner chiqarardi).
  String? monthError;

  int errorStatus = 0;
  /// Oxirgi so'rovning server xato KODI ('SLOT_TAKEN', 'HAS_PAYMENTS', ...).
  String lastCode = '';
  /// Oxirgi xatoning qo'shimcha tafsiloti (SLOT_TAKEN'da "Band: <mijoz>").
  String lastDetail = '';

  /// Shu sessiyada birorta bron KO'RILGANMI (F9): bo'sh oyga qarab turgan ega
  /// "umuman bron yo'q" bilan "bu oyda yo'q"ni farqlab ko'rsin.
  bool everSawBooking = false;

  /// So'rov-nomer qulfi (F2).
  final ToySeq _seq = ToySeq();

  /// Reset-avlodi (2026-08-10 review): _seq har oddiy yuklashda ham o'sadi,
  /// shu sabab u bilan loadHalls/search/mutatsiyalarni qo'riqlab bo'lmaydi
  /// (odatiy parallel ish ham bekor bo'lib qolardi). Bu hisoblagich esa FAQAT
  /// reset()'da o'sadi: logout paytida yo'lda qolgan javob kelsa, eski avlod
  /// belgisi bilan tashlab yuboriladi — yangi akkauntga oldingi egasining
  /// zallari/bronlari yozilib qolmaydi.
  int _resetGen = 0;

  /// Arxivlanmagan to'yxonalar (tartib bo'yicha).
  List<Hall> get halls {
    final list = _halls.where((h) => !h.archived).toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.name.compareTo(b.name));
    return list;
  }

  /// Arxivlangan to'yxonalar (U10 — zallar sahifasidagi "Arxiv" bo'limi).
  List<Hall> get archivedHalls {
    final list = _halls.where((h) => h.archived).toList()
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

  /// Ekran ko'rsatadigan oy xulosasi (F3): server javobi shu yuklashda kelgan
  /// bo'lsa — o'sha; aks holda yuklangan qatorlardan hisob. Eski oy raqami
  /// hech qachon qolib ketmaydi.
  ToySummary get shownSummary => summaryFresh ? summary : toyLocalSummary(_month);

  /// Bo'sh oy ekrani uchun (F9): hisobda umuman bron BORLIGI ma'lummi.
  bool get hasAnyKnownBookings =>
      everSawBooking || _month.isNotEmpty || _upcoming.isNotEmpty;

  Booking? byId(String? id) {
    if (id == null) return null;
    for (final b in _month) {
      if (b.id == id) return b;
    }
    for (final b in _upcoming) {
      if (b.id == id) return b;
    }
    return _loose[id];
  }

  /// Berilgan kun + slotdagi BIRINCHI bron (yo'q bo'lsa null).
  /// DIQQAT: "Hammasi" ko'rinishida bir slotda bir nechta zal bandi bo'ladi —
  /// kun paneli uchun allAt() ishlatiladi (U8), bu esa tezkor tekshiruvlarga.
  Booking? at(DateTime day, String slot) {
    for (final b in _month) {
      if (!b.cancelled && b.slot == slot && toySameDay(b.eventDate, day)) return b;
    }
    return null;
  }

  /// Kun + slotdagi BARCHA faol bandlar (U8): har zalniki alohida qator.
  List<Booking> allAt(DateTime day, String slot) => [
        for (final b in _month)
          if (!b.cancelled && b.slot == slot && toySameDay(b.eventDate, day)) b,
      ];

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

  /// Klient tomonidagi qidiruv (U7): yuklangan oy + yaqin bronlar ichidan,
  /// id bo'yicha dedup, server bilan bir xil tartib (event_date DESC).
  List<Booking> localMatches(String q) {
    final out = <String, Booking>{};
    for (final b in [..._month, ..._upcoming]) {
      if (toyMatches(b, q)) out.putIfAbsent(b.id, () => b);
    }
    final list = out.values.toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return list;
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

  /// hall_id so'rov parametri: "Hammasi" bo'lsa umuman yuborilmaydi.
  String get _hallQuery => selectedHallId == null ? '' : '&hall_id=$selectedHallId';

  // ---------------- Hayot sikli ----------------

  /// MODULGA KIRISH (ekran initState'i chaqiradi, F4 + F11):
  ///   * ko'riladigan oy JORIYGA qaytadi — bronlar oldinga oylab ketadi,
  ///     o'tgan sessiyada qaralgan noyabr yopishib qolmasin;
  ///   * zallar HAR KIRISHDA yangilanadi — kesh darhol ko'rsatiladi,
  ///     yangilanish orqa fonda (boshqa qurilmada zal/narx o'zgargan bo'lishi
  ///     mumkin). Birinchi kirishda load() o'zi yuklaydi.
  Future<void> enter() {
    if (hallsLoaded) unawaited(loadHalls());
    return load(toyMonthStart(DateTime.now()));
  }

  /// LOGOUT tozalashi (store.dart `toyRepo.reset()` deb chaqiradi, F5):
  /// BARCHA kesh — zallar, oy, yaqin bronlar, xulosa, qidiruv keshi, TANLANGAN
  /// TO'YXONA va uning saqlangan 'toy_hall' kaliti ham. Aks holda keyingi
  /// akkaunt oldingi eganing zallari va tanlovini ko'rib qolardi.
  void reset() {
    _seq.begin(); // yo'ldagi javoblar eskirsin — yangi akkauntga yozilmasin
    _resetGen++; // seq'siz yo'llar (loadHalls/search/mutatsiyalar) ham eskirsin
    _halls.clear();
    _month.clear();
    _upcoming.clear();
    _loose.clear();
    month = toyMonthStart(DateTime.now());
    summary = const ToySummary();
    summaryFresh = false;
    selectedHallId = null;
    _selectionRestored = false;
    loading = false;
    loaded = false;
    hallsLoaded = false;
    everSawBooking = false;
    monthError = null;
    _clearErr();
    // Saqlangan tanlov ham o'chadi — fire-and-forget (logout uni kutmaydi).
    SharedPreferences.getInstance()
        .then((sp) => sp.remove(_prefHall))
        .catchError((_) => false);
    notifyListeners();
  }

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

  /// Oy ko'rinishi uchun hamma narsa: to'yxonalar (birinchi marta), oy
  /// bronlari, xulosa, yaqin to'ylar. Ekran faqat shuni biladi.
  ///
  /// F2: har chaqiruv yangi so'rov-nomer oladi — undan keyin yana load()
  /// chaqirilsa, ESKI chaqiruvning javoblari holatga yozilmaydi.
  Future<void> load(DateTime m, {bool silent = false}) async {
    month = toyMonthStart(m);
    final seq = _seq.begin();
    monthError = null;
    // F3: xulosa har yuklashda NOLdan — /summary yiqilsa ham eski oy raqami
    // ko'rsatilmaydi (shownSummary qatorlardan hisoblab beradi).
    summaryFresh = false;
    if (!silent) {
      loading = true;
      _clearErr();
      notifyListeners();
    }
    if (!hallsLoaded) {
      await loadHalls(notify: false);
      await _restoreSelection();
      if (!_seq.isCurrent(seq)) return; // orada yangi yuklash boshlangan
    }
    await Future.wait([
      _loadMonth(seq),
      _loadSummary(seq),
      _loadUpcoming(seq),
    ]);
    if (!_seq.isCurrent(seq)) return; // eskirgan — yangisi o'zi notify qiladi
    loading = false;
    if (error == null) loaded = true;
    notifyListeners();
  }

  /// Joriy oyni jimgina qayta o'qish (mutatsiyalardan keyin).
  Future<void> refresh() => load(month, silent: true);

  /// To'yxonalar + ularning narx toifalari (backend menus[] ni ichida yuboradi).
  ///
  /// F4: modulga qayta kirishda ham chaqiriladi — kesh ko'rsatilib turadi,
  /// ro'yxat orqa fonda yangilanadi. Orqa fon yangilanishi YIQILSA jim
  /// o'tiladi (kesh bor — yordamchi oqim asosiy ko'rinishni buzmasin).
  Future<void> loadHalls({bool notify = true}) async {
    final hadCache = hallsLoaded;
    final prevSel = selectedHallId;
    final gen = _resetGen; // logout oralig'ida kelgan javob yangi akkauntga yozilmasin
    final r = await _req('GET', '/halls');
    if (gen != _resetGen) return; // orada reset() bo'ldi — javob eskirgan
    if (r.ok) {
      _halls
        ..clear()
        ..addAll([
          for (final h in _rowsOf(r.data))
            if (h['id'] != null) Hall.fromJson(h),
        ]);
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
      // Orqa fon yangilanishida tanlov MAJBURAN almashgan bo'lsa (masalan zal
      // boshqa qurilmada arxivlangan) — ko'rinayotgan oy yangi tanlov bilan
      // qayta o'qiladi, aks holda ekran yo'q zalning bronlarini ko'rsatardi.
      if (hadCache && loaded && selectedHallId != prevSel) {
        await load(month, silent: true); // o'zi notify qiladi
        return;
      }
    } else if (!hadCache) {
      _fail(r);
    }
    // hadCache && !r.ok: jim — kesh ko'rsatilib turaveradi.
    if (notify) notifyListeners();
  }

  Future<void> _loadMonth(int seq) async {
    final from = toyYmd(toyMonthStart(month));
    final to = toyYmd(toyMonthEnd(month));
    final r = await _req('GET', '/bookings?from=$from&to=$to$_hallQuery');
    if (!_seq.isCurrent(seq)) return; // eskirgan javob tashlanadi (F2)
    if (r.ok) {
      // Server tartibini SAQLAYMIZ (event_date, keyin slot kalendar tartibida).
      _month
        ..clear()
        ..addAll(toyParseBookings(r.data));
      if (_month.isNotEmpty) everSawBooking = true;
      monthError = null;
    } else {
      // F1: oy almashtirilganda yuklash yiqilsa ESKI OY QATORLARI QOLMAYDI —
      // ro'yxat tozalanadi, ekran banner + qayta urinish ko'rsatadi. Ilgari
      // oldingi oy jimgina ko'rinib turardi va ega noto'g'ri oyga qarab
      // "bo'sh sana bor" deb va'da berib yuborishi mumkin edi.
      _month.clear();
      monthError = r.error;
      _fail(r);
    }
  }

  /// notify — mutatsiyadan keyin alohida chaqirilganda true (load() o'zi
  /// oxirida notify qiladi).
  Future<void> _loadSummary(int seq, {bool notify = false}) async {
    final from = toyYmd(toyMonthStart(month));
    final to = toyYmd(toyMonthEnd(month));
    final r = await _req('GET', '/summary?from=$from&to=$to$_hallQuery');
    if (!_seq.isCurrent(seq)) return;
    if (r.ok && r.data is Map) {
      summary = ToySummary.fromJson(Map<String, dynamic>.from(r.data as Map));
      summaryFresh = true;
    }
    // Yiqilsa JIM (F3): shownSummary yuklangan qatorlardan o'zi hisoblaydi —
    // butun ekranni xatoga o'tkazmaymiz, eski oy raqami ham chiqmaydi.
    if (notify) notifyListeners();
  }

  /// Bugundan +180 kun — "yaqin to'ylar" bloki uchun.
  Future<void> _loadUpcoming(int seq) async {
    final today = toyDay(DateTime.now());
    final from = toyYmd(today);
    final to = toyYmd(today.add(const Duration(days: 180)));
    final r = await _req('GET', '/bookings?from=$from&to=$to$_hallQuery');
    if (!_seq.isCurrent(seq)) return;
    if (r.ok) {
      _upcoming
        ..clear()
        ..addAll(toyParseBookings(r.data));
      if (_upcoming.isNotEmpty) everSawBooking = true;
    }
    // Xato bo'lsa jim o'tamiz: bu yordamchi blok, asosiy ko'rinishni buzmasin.
  }

  /// Bitta kunning bandlari — forma slot belgilari uchun (U1). To'yxona
  /// FILTRISIZ: formada boshqa zal tanlansa ham belgilar to'g'ri bo'ladi.
  /// Xato — null (belgilar shunchaki ko'rsatilmaydi, forma bloklanmaydi);
  /// error/lastCode ATAYLAB tegilmaydi — yordamchi so'rov toast/banner
  /// zanjirini ishga tushirmasin.
  Future<List<Booking>?> bookingsOn(DateTime day) async {
    final d = toyYmd(day);
    final r = await _req('GET', '/bookings?from=$d&to=$d');
    if (!r.ok) return null;
    return toyParseBookings(r.data);
  }

  /// YANGI backend qidiruvi (U7): GET /bookings/search?q=&limit= — javob
  /// GET /bookings bilan bir xil shakl, event_date DESC. Muvaffaqiyatsizlikda
  /// NULL — ekran klient tomonidagi mosliklarga tushadi (offlayn belgisi
  /// bilan). error/lastCode tegilmaydi (yordamchi oqim).
  Future<List<Booking>?> searchBookings(String q, {int limit = 20}) async {
    final query = q.trim();
    if (query.length < 2) return const <Booking>[];
    final gen = _resetGen; // reset()'dan keyin kelgan javob keshga yozilmasin
    final r = await _req(
        'GET', '/bookings/search?q=${Uri.encodeQueryComponent(query)}&limit=$limit');
    if (gen != _resetGen) return null;
    if (!r.ok) return null;
    final list = toyParseBookings(r.data);
    // Natijalar keshga olinadi: tafsilot (byId) joriy oy/180-kun ro'yxatida
    // bo'lmagan bandni ham ocha olsin. Kesh chegaralangan — eski qidiruvlar
    // to'planib ketmasin.
    if (_loose.length > 200) _loose.clear();
    for (final b in list) {
      _loose[b.id] = b;
    }
    if (list.isNotEmpty) everSawBooking = true;
    return list;
  }

  /// Mutatsiya qaytargan TO'LIQ bandni ro'yxatlarda almashtirish (refetch shart emas).
  void _upsertBooking(dynamic data) {
    final b = Booking.tryParse(data);
    if (b == null) return;
    for (final list in [_month, _upcoming]) {
      final i = list.indexWhere((x) => x.id == b.id);
      if (i >= 0) list[i] = b;
    }
    if (_loose.containsKey(b.id)) _loose[b.id] = b;
  }

  // ---------------- Bronlar ----------------

  /// Yangi bron. Muvaffaqiyatda Booking, aks holda null.
  /// `lastCode == 'SLOT_TAKEN'` — o'sha sana/vaqt/to'yxona band (409):
  /// UI toast beradi va FORMANI OCHIQ QOLDIRADI.
  /// `lastCode == 'SUB_EXPIRED'` — 5 ta bepul bron tugagan (402).
  ///
  /// NARX USTUVORLIGI (backend shartnomasi, F10 tuzatilgan izoh):
  /// aniq price_per_guest > menu > to'yxona defaulti. menu_id va
  /// price_per_guest ni BIRGA yuborish TO'G'RI: aniq narx g'olib bo'ladi,
  /// menu esa baribir toifa NOMINI snapshot qiladi. Faqat ega toifani tanlab,
  /// narxni QO'LDA O'ZGARTIRMAGAN bo'lsa price yuborilmaydi — narxni server
  /// toifadan nusxalaydi (formadagi yaxlitlash/eskirgan kesh narxi emas).
  Future<Booking?> createBooking(Map<String, dynamic> body) async {
    _clearErr();
    final gen = _resetGen; // reset()'dan keyingi javob holatga tegmasin
    final r = await _req('POST', '/bookings', body: body);
    if (gen != _resetGen) return null;
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return null;
    }
    final b = Booking.tryParse(r.data);
    if (b != null) everSawBooking = true;
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
    // Javobdagi to'liq band darhol qo'llanadi (qidiruv keshidagi — joriy
    // oy tashqarisidagi — band ham yangilansin), keyin oy jimgina qayta o'qiladi.
    _upsertBooking(r.data);
    await refresh();
    return true;
  }

  /// QAT'IY o'chirish. Backend: to'lovi BOR band o'chirilmaydi — 409
  /// {code:'HAS_PAYMENTS'} qaytadi (tarix saqlansin, 'bekor' ishlatilsin).
  /// UI bu kodni delHasPayments matniga aylantiradi (F6).
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
    _loose.remove(id);
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

  /// paidAt (U2) — egalar kechagi naqdni bugun yozadi; berilmasa server
  /// "hozir"ni qo'yadi. Backend 90 soniyalik oynada TAKROR to'lovni o'zi
  /// yutib yuboradi (javob shakli o'zgarmaydi, deduped:true kelishi mumkin) —
  /// mijozga qo'shimcha ish yo'q.
  Future<bool> addPayment(String bookingId, int amount,
          {String kind = 'avans', String note = '', DateTime? paidAt}) =>
      _bookingMutation('POST', '/bookings/$bookingId/payments', body: {
        'amount': amount,
        'kind': kind,
        if (note.isNotEmpty) 'note': note,
        if (paidAt != null) 'paid_at': toyYmd(paidAt),
      });

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
    await _loadSummary(_seq.current, notify: true);
    return true;
  }

  // ---------------- To'yxonalar (halls) ----------------

  Future<bool> createHall(String name, {int? capacity, int? pricePerGuest}) async {
    _clearErr();
    final gen = _resetGen; // reset()'dan keyingi javob holatga tegmasin
    final r = await _req('POST', '/halls', body: {
      'name': name,
      if (capacity != null) 'capacity': capacity,
      if (pricePerGuest != null) 'price_per_guest': pricePerGuest,
    });
    if (gen != _resetGen) return false;
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

  /// PATCH /halls/:id. Arxivdan QAYTARISH ({archived:false}) chegaradan oshsa
  /// server 403 HALL_LIMIT beradi — UI buni lokalizatsiyalangan izohga
  /// aylantiradi, PAYWALL OCHILMAYDI (sotib olinadigan narsa yo'q).
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
