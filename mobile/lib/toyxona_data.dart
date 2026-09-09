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
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/material.dart' show Color, IconData, Icons;
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

/// To'lov turlari (024: 'qaytarim' — mijozga QAYTARILGAN pul, paid'dan ayiriladi).
const List<String> kToyPayKinds = ['avans', 'yakuniy', 'qaytarim'];

/// Narx rejimlari (024): 'guest' — kishi boshiga (mehmon × narx),
/// 'total' — butun to'yxona "podklyuch" (bitta kelishilgan summa).
const List<String> kToyPriceModes = ['guest', 'total'];

/// Bekor siyosati pog'onalari (024): to'ygacha ≥30 kun / ≥7 kun / <7 kun.
/// Ega har pog'onaga TUSHGAN puldan (avans) qancha foiz ushlab qolishini kiritadi.
const List<int> kToyPolicyDays = [30, 7, 0];

/// Bir zal narxi ($/oy) — PO 2026-09-08: HAR ZAL $21, pog'onali SKU (1..5 zal).
const int kToyMaxUnits = 5;

/// Xizmat sonining formadagi yuqori chegarasi (server 10 000 gacha qabul
/// qiladi, lekin bitta to'yda 20 tadan ortiq bir xil xizmat bo'lmaydi).
const int kToyMaxSvcQty = 20;

/// Tez qo'shiladigan xizmatlar — yorliqlar l10n kalitlari orqali.
const List<String> kToyQuickServiceKeys = [
  'svcMusic', 'svcPhoto', 'svcVideo', 'svcCake', 'svcDecor', 'svcFire',
];

// ==================== SERVIS KATEGORIYALARI (025) ====================
//
// PLATFORMA ro'yxati — to'yxonachi kategoriya YARATA OLMAYDI, faqat ichini
// to'ldiradi ("Musiqa" biznikidir, ichidagi "Ansambl Navro'z" eganiki).
//
// Slug'lar backend'dagi `src/lib/toyxonaCategories.js` bilan AYNAN bir xil
// bo'lishi SHART (server validatsiya qiladi). Nom / rang / ikonka esa FAQAT
// shu yerda: ular ilova resurslari, DB ularni saqlay olmaydi.
//
// TANIMAGAN SLUG: server kelajakda yangi kategoriya qo'shsa, eski ilova uni
// 'boshqa' sifatida ko'rsatadi — qator hech qachon YO'QOLMAYDI (catOf).

/// Bitta kategoriya: gradient + ikonka + illyustratsiya (Storyset PNG).
class ToyServiceCat {
  final String slug;
  /// l10n kaliti: 'catTaomnoma' ... (toyxona_l10n.dart, 6 til)
  final String key;
  /// Karta gradienti (Spotify janr plitkalari uslubi) — [0] to'q, [1] och
  final Color c1, c2;
  /// Illyustratsiya kelmaguncha ko'rinadigan zaxira ikonka
  final IconData icon;
  const ToyServiceCat(this.slug, this.key, this.c1, this.c2, this.icon);

  /// Storyset PNG yo'li. Fayl BO'LMASA Image.asset errorBuilder ikonkaga
  /// qaytadi — shuning uchun rasmlar kelmaguncha ham ekran to'liq ishlaydi.
  String get asset => 'assets/toyxona/cat/$slug.png';
}

/// 17 ta kategoriya + 'boshqa' (HAR DOIM oxirgi). Tartib = grid tartibi.
const List<ToyServiceCat> kToyServiceCats = [
  ToyServiceCat('taomnoma',   'catTaomnoma',   Color(0xFFF97316), Color(0xFFFB923C), Icons.restaurant_rounded),
  ToyServiceCat('tort',       'catTort',       Color(0xFFEC4899), Color(0xFFF472B6), Icons.cake_rounded),
  ToyServiceCat('ichimlik',   'catIchimlik',   Color(0xFF06B6D4), Color(0xFF22D3EE), Icons.local_bar_rounded),
  ToyServiceCat('musiqa',     'catMusiqa',     Color(0xFF8B5CF6), Color(0xFFA78BFA), Icons.music_note_rounded),
  ToyServiceCat('boshlovchi', 'catBoshlovchi', Color(0xFFF59E0B), Color(0xFFFBBF24), Icons.mic_rounded),
  ToyServiceCat('shou',       'catShou',       Color(0xFFEF4444), Color(0xFFF87171), Icons.theater_comedy_rounded),
  ToyServiceCat('foto',       'catFoto',       Color(0xFF3B82F6), Color(0xFF60A5FA), Icons.photo_camera_rounded),
  ToyServiceCat('bezak',      'catBezak',      Color(0xFF10B981), Color(0xFF34D399), Icons.local_florist_rounded),
  ToyServiceCat('yoruglik',   'catYoruglik',   Color(0xFF6366F1), Color(0xFF818CF8), Icons.lightbulb_rounded),
  ToyServiceCat('salyut',     'catSalyut',     Color(0xFFF43F5E), Color(0xFFFB7185), Icons.celebration_rounded),
  ToyServiceCat('gozallik',   'catGozallik',   Color(0xFFD946EF), Color(0xFFE879F9), Icons.face_retouching_natural_rounded),
  ToyServiceCat('transport',  'catTransport',  Color(0xFF0EA5E9), Color(0xFF38BDF8), Icons.directions_car_rounded),
  ToyServiceCat('taklifnoma', 'catTaklifnoma', Color(0xFF14B8A6), Color(0xFF2DD4BF), Icons.mail_rounded),
  ToyServiceCat('sovga',      'catSovga',      Color(0xFFA855F7), Color(0xFFC084FC), Icons.card_giftcard_rounded),
  ToyServiceCat('xizmat',     'catXizmat',     Color(0xFF64748B), Color(0xFF94A3B8), Icons.room_service_rounded),
  ToyServiceCat('bolalar',    'catBolalar',    Color(0xFFEAB308), Color(0xFFFACC15), Icons.toys_rounded),
  ToyServiceCat('zal',        'catZal',        Color(0xFF78716C), Color(0xFFA8A29E), Icons.table_bar_rounded),
  ToyServiceCat('boshqa',     'catBoshqa',     Color(0xFF475569), Color(0xFF64748B), Icons.more_horiz_rounded),
];

/// Zaxira kategoriya (server bilan bir xil).
const String kToyDefaultCat = 'boshqa';

/// Slug -> kategoriya. Tanimasa 'boshqa' (eski/yangi server bilan moslik).
ToyServiceCat catOf(String? slug) {
  for (final c in kToyServiceCats) {
    if (c.slug == slug) return c;
  }
  return kToyServiceCats.last;
}

/// Bir item'ga ruxsat etilgan rasmlar soni (backend ham 5 tekshiradi).
const int kToyMaxSvcImages = 5;

/// Stol ustidagi taom/mahsulot qatori (024, hall_menu_items) — pulsiz, faqat matn.
/// 027: stol mahsuloti birliklari (backend MENU_UNITS va DB CHECK bilan bir xil).
/// Mobil tanlovda 'g' YO'Q (ega kg'da o'ylaydi); eski 'g' qatorlar o'qiladi.
const List<String> kToyUnits = ['kg', 'dona', 'l', 'porsiya', 'paket'];

/// 027: qator jami — miqdor × birlik narxi, butun so'mga yaxlitlab (backend lineTotal nusxasi).
int toyLineTotal(double? amount, int unitPrice) {
  if (amount == null || amount <= 0 || unitPrice <= 0) return 0;
  return (amount * unitPrice).round();
}

/// 027: 1 kishiga narx — stol jami ÷ o'rindiq, YUQORIGA yaxlitlab. seats yo'q = 0.
int toyPerGuest(int tableTotal, int? seats) {
  if (tableTotal <= 0 || seats == null || seats <= 0) return 0;
  return (tableTotal / seats).ceil();
}

/// Miqdor ko'rinishi: 2 -> "2", 2.5 -> "2.5", 0.25 -> "0.25".
String toyAmountStr(double? a) {
  if (a == null) return '';
  if (a == a.roundToDouble()) return '${a.toInt()}';
  var s = a.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

class MenuItemRow {
  final String id;
  final String title;
  final String qty; // "2 dona", "1 kg" — erkin matn (024, eski qatorlar)
  // 027: hisoblanadigan mahsulot — miqdor × birlik × birlik narxi
  final double? amount;
  final String unit; // '' = berilmagan
  final int unitPrice;
  const MenuItemRow({
    required this.id,
    required this.title,
    this.qty = '',
    this.amount,
    this.unit = '',
    this.unitPrice = 0,
  });

  factory MenuItemRow.fromJson(Map<String, dynamic> j) => MenuItemRow(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        qty: '${j['qty'] ?? ''}',
        amount: j['amount'] == null ? null : double.tryParse('${j['amount']}'),
        unit: '${j['unit'] ?? ''}',
        unitPrice: _int(j['unit_price']),
      );

  int get lineTotal => toyLineTotal(amount, unitPrice);

  /// Miqdor matni: 027 qatorda "2 kg", eski qatorda qty matni.
  String get qtyText => amount != null ? '${toyAmountStr(amount)} $unit'.trim() : qty;

  /// Ko'rinish: "Osh · 2 kg" / "Salat".
  String get label => qtyText.isEmpty ? title : '$title · $qtyText';
}

/// STOL TURI (hall_menus) — "Oddiy — 150 000", "Lyuks — 200 000". Narx KISHI
/// BOSHIGA; 024: stol sig'imi (seats) + stol ustidagi taomlar ro'yxati (items).
class Menu {
  final String id;
  final String hallId;
  final String title;
  final int pricePerGuest;
  final int? seats; // bir stolda necha kishi (024)
  final String note;
  final List<MenuItemRow> items; // stol ustidagi taomlar (024)
  final int sort;
  final bool archived;
  /// 028: stol rasmlari (5 tagacha), birinchisi muqova.
  final List<String> images;
  String? get cover => images.isEmpty ? null : images.first;

  /// 027: stol jami (Σ mahsulot qatorlari) va shundan 1 kishiga hisob.
  int get tableTotal => items.fold(0, (s, it) => s + it.lineTotal);
  int get perGuestCalc => toyPerGuest(tableTotal, seats);

  const Menu({
    required this.id,
    required this.title,
    required this.pricePerGuest,
    this.hallId = '',
    this.seats,
    this.note = '',
    this.items = const [],
    this.sort = 0,
    this.archived = false,
    this.images = const [],
  });

  factory Menu.fromJson(Map<String, dynamic> j) => Menu(
        id: '${j['id']}',
        hallId: '${j['hall_id'] ?? ''}',
        title: '${j['title'] ?? ''}',
        pricePerGuest: _int(j['price_per_guest']),
        seats: _intOrNull(j['seats']),
        note: '${j['note'] ?? ''}',
        items: [
          for (final it in _rowsOf(j['items']))
            if (it['id'] != null) MenuItemRow.fromJson(it),
        ],
        sort: _int(j['sort']),
        archived: j['archived'] == true,
        images: [
          for (final u in (j['images'] is List ? j['images'] as List : const []))
            if (u is String && u.isNotEmpty) u,
        ],
      );
}

/// Bekor siyosati pog'onasi (024): to'ygacha kamida `days` kun qolganda
/// tushgan pulning `pct` foizi ushlab qolinadi.
class CancelRule {
  final int days;
  final int pct;
  const CancelRule(this.days, this.pct);
  Map<String, int> toJson() => {'days': days, 'pct': pct};
}

/// Servis katalogi qatori (024, hall_services): video, sahna bezagi, shou...
class HallService {
  final String id;
  final String? hallId; // null = barcha to'yxonalar uchun
  /// 025: PLATFORMA kategoriyasi slug'i (kToyServiceCats). Eski server bermasa 'boshqa'.
  final String category;
  final String title;
  final int price;
  /// Ega uchun ichki eslatma (mijozga ko'rsatilmaydi)
  final String note;
  /// 025: mijoz ko'radigan to'liq tavsif (repertuar, nima kiradi)
  final String description;
  /// 025: rasm URL'lari, [0] = muqova. Bo'sh bo'lishi normal.
  final List<String> images;
  final int sort;
  final bool archived;
  const HallService({
    required this.id,
    required this.title,
    this.hallId,
    this.category = kToyDefaultCat,
    this.price = 0,
    this.note = '',
    this.description = '',
    this.images = const [],
    this.sort = 0,
    this.archived = false,
  });

  /// Muqova rasmi (yo'q bo'lsa null — UI gradient + ikonka chizadi).
  String? get cover => images.isEmpty ? null : images.first;

  ToyServiceCat get cat => catOf(category);

  factory HallService.fromJson(Map<String, dynamic> j) => HallService(
        id: '${j['id']}',
        hallId: j['hall_id'] == null ? null : '${j['hall_id']}',
        category: '${j['category'] ?? kToyDefaultCat}',
        title: '${j['title'] ?? ''}',
        price: _int(j['price']),
        note: '${j['note'] ?? ''}',
        description: '${j['description'] ?? ''}',
        images: [
          for (final u in (j['images'] is List ? j['images'] as List : const []))
            if (u is String && u.isNotEmpty) u,
        ],
        sort: _int(j['sort']),
        archived: j['archived'] == true,
      );
}

/// Bekor hisob-kitobi (024, GET /bookings/:id/cancel-preview).
class CancelPreview {
  final int paid, penalty, refund, daysLeft, total;
  const CancelPreview({this.paid = 0, this.penalty = 0, this.refund = 0, this.daysLeft = 0, this.total = 0});
  factory CancelPreview.fromJson(Map<String, dynamic> j) => CancelPreview(
        paid: _int(j['paid']),
        penalty: _int(j['penalty']),
        refund: _int(j['refund']),
        daysLeft: _int(j['daysLeft']),
        total: _int(j['total']),
      );
}

/// Telefon bo'yicha topilgan mijoz (024, GET /clients?phone=).
class ClientHint {
  final String name;
  final int bookings;
  final bool inTrustbook;
  const ClientHint({required this.name, this.bookings = 0, this.inTrustbook = false});
}

/// Bekor siyosatini backend ko'rinishidan o'qiydi (sof; testlanadi).
List<CancelRule> toyParsePolicy(dynamic raw) {
  final out = <CancelRule>[];
  for (final r in _rowsOf(raw)) {
    final d = _int(r['days'], -1);
    final pct = _int(r['pct'], -1);
    if (d < 0 || pct < 0 || pct > 100) continue;
    out.add(CancelRule(d, pct));
  }
  out.sort((a, b) => b.days.compareTo(a.days));
  return out;
}

/// Mijoz tomonidagi jarima hisobi — backend cancelPenalty bilan BIR XIL:
/// qolgan kunga MOS eng katta `days` pog'onasi; topilmasa 0; o'tgan to'y → 0 kun.
int toyCancelPenalty(List<CancelRule> policy, int paid, int daysLeft) {
  if (paid <= 0 || policy.isEmpty) return 0;
  final d = daysLeft < 0 ? 0 : daysLeft;
  final rows = [...policy]..sort((a, b) => b.days.compareTo(a.days));
  for (final r in rows) {
    if (r.days <= d) {
      final v = (paid * r.pct / 100).round();
      return v > paid ? paid : v;
    }
  }
  return 0;
}

/// Minimal avans (024): jamining deposit_pct foizi, yuqoriga yaxlitlab.
int toyDepositMin(int total, int pct) {
  if (pct <= 0 || total <= 0) return 0;
  return (total * pct / 100).ceil();
}

/// Telefonni faqat raqamga keltiradi (backend normPhone bilan bir xil).
String toyPhoneDigits(String v) => v.replaceAll(RegExp(r'\D'), '');

/// To'yxona (halls) — narx toifalari ICHIDA keladi (backend embed qiladi).
class Hall {
  final String id;
  final String name;
  final int? capacity;
  final int pricePerGuest; // toifasiz egalar uchun zaxira/default narx
  final int sort;
  final bool archived;
  final List<Menu> menus;
  // ---- 024 ----
  final String priceMode; // 'guest' | 'total' — bandlar uchun DEFAULT
  final int totalPrice; // 'total' rejimida butun to'yxona narxi (default)
  final int depositPct; // minimal avans, jamidan % (0 = talab yo'q)
  final List<CancelRule> cancelPolicy;
  const Hall({
    required this.id,
    required this.name,
    this.capacity,
    this.pricePerGuest = 0,
    this.sort = 0,
    this.archived = false,
    this.menus = const [],
    this.priceMode = 'guest',
    this.totalPrice = 0,
    this.depositPct = 0,
    this.cancelPolicy = const [],
  });

  factory Hall.fromJson(Map<String, dynamic> j) => Hall(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        capacity: _intOrNull(j['capacity']),
        pricePerGuest: _int(j['price_per_guest']),
        sort: _int(j['sort']),
        archived: j['archived'] == true,
        priceMode: j['price_mode'] == 'total' ? 'total' : 'guest',
        totalPrice: _int(j['total_price']),
        depositPct: _int(j['deposit_pct']).clamp(0, 100).toInt(),
        cancelPolicy: toyParsePolicy(j['cancel_policy']),
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
  final String? serviceId; // 024: katalogdan (snapshot)
  final bool isBonus; // 024: bepul berildi — jamiga KIRMAYDI
  /// 025 SNAPSHOT: bandga qo'shilgan paytdagi kategoriya va muqova rasmi.
  /// Katalogdagi item keyin o'chsa yoki rasmi almashsa ham bron varaqasi
  /// O'ZGARMAYDI — shuning uchun bular serviceId orqali qidirilmaydi.
  final String category;
  final String? image;
  const BookingItem({
    required this.id,
    required this.title,
    required this.amount,
    this.qty = 1,
    this.serviceId,
    this.isBonus = false,
    this.category = kToyDefaultCat,
    this.image,
  });

  factory BookingItem.fromJson(Map<String, dynamic> j) {
    final q = _int(j['qty'], 1);
    final img = '${j['image'] ?? ''}';
    return BookingItem(
      id: '${j['id']}',
      title: '${j['title'] ?? ''}',
      amount: _int(j['amount']),
      qty: q <= 0 ? 1 : q,
      serviceId: j['service_id'] == null ? null : '${j['service_id']}',
      isBonus: j['is_bonus'] == true,
      category: '${j['category'] ?? kToyDefaultCat}',
      image: img.isEmpty ? null : img,
    );
  }

  /// Qiymati (bonusda ham ko'rinadi); jamiga faqat pullik kiradi.
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
  // ---- 024 ----
  final String priceMode; // 'guest' | 'total'
  final int totalPrice; // 'total' rejimida SNAPSHOT summa
  final DateTime? holdUntil; // avans kutish muddati (o'tsa server avto-bekor)
  final String cancelReason;
  final int cancelPenalty; // bekorda ushlab qolingan jarima (SNAPSHOT)
  final bool inTrustbook; // mijoz Trustbook'da (client_user_id bor)

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
    this.priceMode = 'guest',
    this.totalPrice = 0,
    this.holdUntil,
    this.cancelReason = '',
    this.cancelPenalty = 0,
    this.inTrustbook = false,
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
          for (final k in ['food', 'extras', 'total', 'paid', 'left', 'bonus', 'refunded', 'penalty', 'refundDue'])
            if (rawTotals[k] != null) k: _int(rawTotals[k]),
        },
        priceMode: j['price_mode'] == 'total' ? 'total' : 'guest',
        totalPrice: _int(j['total_price']),
        holdUntil: j['hold_until'] == null ? null : DateTime.tryParse('${j['hold_until']}')?.toLocal(),
        cancelReason: '${j['cancel_reason'] ?? ''}',
        cancelPenalty: _int(j['cancel_penalty']),
        inTrustbook: j['client_user_id'] != null,
      );
    } catch (_) {
      return null;
    }
  }

  // Server bergan yakunlar ustuvor; bo'lmasa klientda hisoblanadi (snapshotdan).
  int get food => totals['food'] ?? (priceMode == 'total' ? totalPrice : guests * pricePerGuest);
  int get extras => totals['extras'] ?? items.where((i) => !i.isBonus).fold(0, (s, i) => s + i.total);
  /// Bonus (bepul) servislar qiymati — ko'rinadi, jamiga kirmaydi (024).
  int get bonus => totals['bonus'] ?? items.where((i) => i.isBonus).fold(0, (s, i) => s + i.total);
  int get total => totals['total'] ?? (food + extras);
  /// Mijozga qaytarilgan pul (024, 'qaytarim').
  int get refunded => totals['refunded'] ?? payments.where((p) => p.kind == 'qaytarim').fold(0, (s, p) => s + p.amount);
  int get paid => totals['paid'] ?? (payments.where((p) => p.kind != 'qaytarim').fold(0, (s, p) => s + p.amount) - refunded);
  /// Bekor qilingan bandda mijozga QAYTARILISHI kerak bo'lgan pul (jarimadan keyin).
  int get refundDue => totals['refundDue'] ?? (cancelled ? (paid - cancelPenalty < 0 ? 0 : paid - cancelPenalty) : 0);
  bool get isTotalMode => priceMode == 'total';
  /// Avans kutilmoqda va muddat hali o'tmagan.
  bool get onHold => holdUntil != null && status == 'band' && holdUntil!.isAfter(DateTime.now());
  /// Ortiqcha to'lovda MANFIY bo'lishi mumkin — clamp QILINMAYDI (backend shartnomasi).
  int get left => totals['left'] ?? (total - paid);

  bool get cancelled => status == 'bekor';

  /// Narx kelishilmagan band (U5): narx ham, xizmat ham yo'q. O'zbekistonda bu
  /// NORMAL holat — avans sanani ushlaydi, menyu keyin kelishiladi. Saqlash
  /// hech qachon bloklanmaydi, faqat yumshoq belgi ko'rsatiladi.
  bool get priceMissing => (isTotalMode ? totalPrice == 0 : pricePerGuest == 0) && items.isEmpty;
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
  // ---- 024 analitika ----
  final int penalties, refunded, bonus, guests, avgCheck;
  final double occupancyPct;
  final List<Map<String, dynamic>> topServices; // [{title, count, amount, bonus}]
  const ToySummary({
    this.count = 0,
    this.countActive = 0,
    this.total = 0,
    this.paid = 0,
    this.left = 0,
    this.cancelledPaid = 0,
    this.byStatus = const {},
    this.penalties = 0,
    this.refunded = 0,
    this.bonus = 0,
    this.guests = 0,
    this.avgCheck = 0,
    this.occupancyPct = 0,
    this.topServices = const [],
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
      penalties: _int(j['penalties']),
      refunded: _int(j['refunded']),
      bonus: _int(j['bonus']),
      guests: _int(j['guests']),
      avgCheck: _int(j['avgCheck']),
      occupancyPct: (j['occupancyPct'] is num) ? (j['occupancyPct'] as num).toDouble() : 0,
      topServices: [
        for (final t in _rowsOf(j['topServices']))
          {'title': '${t['title'] ?? ''}', 'count': _int(t['count']), 'amount': _int(t['amount']), 'bonus': _int(t['bonus'])},
      ],
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
  /// Servislar katalogi (024) — /halls bilan birga yuklanadi.
  final List<HallService> _services = [];
  bool servicesLoaded = false;
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

  /// Faol servislar (024): umumiy (hall_id null) + berilgan to'yxonaniki.
  List<HallService> servicesFor(String? hallId) {
    final list = _services
        .where((s) => !s.archived && (s.hallId == null || s.hallId == hallId))
        .toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.title.compareTo(b.title));
    return list;
  }

  List<HallService> get allServices {
    final list = _services.where((s) => !s.archived).toList()
      ..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.title.compareTo(b.title));
    return list;
  }

  /// 025: kategoriya ichidagi faol servislar (umumiy + shu to'yxonaniki).
  List<HallService> servicesInCat(String slug, String? hallId) =>
      servicesFor(hallId).where((s) => s.category == slug).toList();

  /// 025: har kategoriyada nechta item bor (grid kartasidagi hisoblagich).
  /// Kategoriya BO'SH bo'lsa ham grid'da ko'rinadi — ega "bu yerga qo'shsam
  /// bo'lar ekan" deb tushunishi uchun (bo'sh ro'yxat hech narsa o'rgatmaydi).
  Map<String, int> catCounts(String? hallId) {
    final m = <String, int>{};
    for (final s in servicesFor(hallId)) {
      m[s.category] = (m[s.category] ?? 0) + 1;
    }
    return m;
  }

  HallService? serviceById(String? id) {
    if (id == null) return null;
    for (final s in _services) {
      if (s.id == id) return s;
    }
    return null;
  }

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
    _services.clear();
    servicesLoaded = false;
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
    // 024: servislar katalogi — eski server 404 bersa jim (katalog bo'sh qoladi)
    _req('GET', '/services').then((sr) {
      if (gen != _resetGen || !sr.ok) return;
      _services
        ..clear()
        ..addAll([
          for (final e in _rowsOf(sr.data))
            if (e['id'] != null) HallService.fromJson(e),
        ]);
      servicesLoaded = true;
      notifyListeners();
    });
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

  Future<bool> addItem(String bookingId, String title, int amount,
          {int qty = 1, String? serviceId, bool bonus = false}) =>
      _bookingMutation('POST', '/bookings/$bookingId/items', body: {
        if (serviceId != null) 'service_id': serviceId,
        'title': title,
        'amount': amount,
        if (qty != 1) 'qty': qty,
        if (bonus) 'is_bonus': true,
      });

  /// 024: bonusni yoqish/o'chirish.
  Future<bool> setItemBonus(String itemId, bool bonus) =>
      _bookingMutation('PATCH', '/items/$itemId', body: {'is_bonus': bonus});

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

  // ---------------- Bekor qilish (024) ----------------

  /// Bekor qilsak nima bo'ladi: tushgan pul, jarima, qaytariladigan summa.
  /// Eski server (route yo'q) → null; UI o'zi hisoblaydi (toyCancelPenalty).
  Future<CancelPreview?> cancelPreview(String id) async {
    final r = await _req('GET', '/bookings/$id/cancel-preview');
    if (!r.ok || r.data is! Map) return null;
    return CancelPreview.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// Bekor qilish: jarima (siyosat yoki ega qo'lda), sabab, qaytarimni darhol yozish.
  /// Eski serverda (404) oddiy status='bekor' PATCH'iga tushadi.
  Future<bool> cancelBooking(String id, {String reason = '', int? penalty, bool refundNow = false}) async {
    _clearErr();
    final r = await _req('POST', '/bookings/$id/cancel', body: {
      if (reason.isNotEmpty) 'reason': reason,
      if (penalty != null) 'penalty': penalty,
      if (refundNow) 'refund_now': true,
    });
    if (!r.ok && r.status == 404) return setStatus(id, 'bekor');
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    _upsertBooking(r.data);
    await refresh();
    return true;
  }

  // ---------------- Mijoz autofill (024) ----------------

  /// Telefon bo'yicha oldingi mijoz. Topilmasa/eski server → null.
  Future<ClientHint?> lookupClient(String phone) async {
    final d = toyPhoneDigits(phone);
    if (d.length < 7) return null;
    final r = await _req('GET', '/clients?phone=$d');
    if (!r.ok || r.data is! Map) return null;
    final m = (r.data as Map).cast<String, dynamic>();
    final name = '${m['client_name'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    return ClientHint(name: name, bookings: _int(m['bookings']), inTrustbook: m['in_trustbook'] == true);
  }

  // ---------------- Servislar katalogi (024) ----------------

  Future<bool> createService(
    String title,
    int price, {
    String? hallId,
    String note = '',
    String category = kToyDefaultCat,
    String description = '',
    List<String> images = const [],
  }) =>
      _serviceMutation('POST', '/services', body: {
        'title': title,
        'price': price,
        'category': category,
        if (hallId != null) 'hall_id': hallId,
        if (note.isNotEmpty) 'note': note,
        if (description.isNotEmpty) 'description': description,
        if (images.isNotEmpty) 'images': images,
      });

  Future<bool> patchService(String id, Map<String, dynamic> body) =>
      _serviceMutation('PATCH', '/services/$id', body: body);

  Future<bool> deleteService(String id) => _serviceMutation('DELETE', '/services/$id');

  /// 025: servis rasmini yuklash. Tana = rasm BAYTLARI (base64 emas — hajm 33%
  /// oshib, server chegarasidan oshib ketardi). Muvaffaqiyatda ochiq URL,
  /// xatoda null (sabab `error` da — chaqiruvchi toast qiladi).
  ///
  /// Yuklash BACKEND orqali: klient Supabase Storage'ga to'g'ridan-to'g'ri
  /// chiqmaydi (O'zbekiston tarmoqlari supabase.co ga ba'zan ulanolmaydi —
  /// api.trustbook.uz / Cloudflare shu sabab qo'yilgan).
  ///
  /// Timeout 60s: rasm ~300 KB, sekin mobil internetda 20s yetmasligi mumkin.
  Future<String?> uploadServiceImage(Uint8List bytes, String mime) async {
    _clearErr();
    try {
      final uri = Uri.parse('$apiUrl$_base/uploads/service-image');
      final res = await http
          .post(uri,
              headers: {
                'Content-Type': mime,
                if (Api.token != null) 'Authorization': 'Bearer ${Api.token}',
              },
              body: bytes)
          .timeout(const Duration(seconds: 60));
      Map<String, dynamic> map;
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        map = d is Map<String, dynamic> ? d : <String, dynamic>{};
      } catch (_) {
        map = <String, dynamic>{};
      }
      if (res.statusCode >= 400 || map['success'] == false) {
        if (res.statusCode == 401 && Api.token != null) Api.onUnauthorized?.call();
        error = (map['error'] as String?) ?? 'Server xatosi (${res.statusCode})';
        errorStatus = res.statusCode;
        notifyListeners();
        return null;
      }
      final url = '${(map['data'] as Map?)?['url'] ?? ''}';
      if (url.isEmpty) {
        error = ty('imgFailed');
        notifyListeners();
        return null;
      }
      return url;
    } on TimeoutException {
      error = Api.errWaking ?? "Server uyg'onmoqda — biroz kuting";
      notifyListeners();
      return null;
    } catch (_) {
      error = Api.errNetwork ?? "Server bilan aloqa yo'q — internetni tekshiring";
      notifyListeners();
      return null;
    }
  }

  Future<bool> _serviceMutation(String method, String path, {Map<String, dynamic>? body}) async {
    _clearErr();
    final r = await _req(method, path, body: body);
    if (!r.ok) {
      _fail(r);
      notifyListeners();
      return false;
    }
    final sr = await _req('GET', '/services');
    if (sr.ok) {
      _services
        ..clear()
        ..addAll([
          for (final e in _rowsOf(sr.data))
            if (e['id'] != null) HallService.fromJson(e),
        ]);
      servicesLoaded = true;
    }
    notifyListeners();
    return true;
  }

  // ---------------- To'yxonalar (halls) ----------------

  Future<bool> createHall(String name,
      {int? capacity, int? pricePerGuest, Map<String, dynamic> extra = const {}}) async {
    _clearErr();
    final gen = _resetGen; // reset()'dan keyingi javob holatga tegmasin
    final r = await _req('POST', '/halls', body: {
      'name': name,
      if (capacity != null) 'capacity': capacity,
      if (pricePerGuest != null) 'price_per_guest': pricePerGuest,
      ...extra, // 024: price_mode, total_price, deposit_pct, cancel_policy
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

  /// 027: body — {title, price_per_guest, seats?, note?, items: [{title, amount?, unit?, unit_price?}]}
  Future<bool> createMenu(String hallId, Map<String, dynamic> body) =>
      _menuMutation('POST', '/halls/$hallId/menus', body: body);

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
