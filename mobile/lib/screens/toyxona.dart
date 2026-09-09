// To'yxona — to'y zali boshqaruvi (oy kalendari, bron, hisob-kitob, narxlar).
// Dizayn: prototype/redesign/DESIGN_SPEC.md §5.13 ("dark glass + gradient",
// 2026-09-07): ScreenHeader + PRO badge, oy sarlavhasi 22/600 + legenda,
// kalendar GlassCard (bugun — brend gradient, tanlangan — violet chegara,
// 3 slot nuqtasi), kun slotlari GlassCard h68 (nahor amber / tushlik cyan /
// kechki violet), bron tafsiloti / forma / to'yxonalar — GlassCard + GlassField
// + PillChip + PillBadge, modallar SheetShell.
//
// TUZILISH (bitta ildiz ekran + to'liq-ekran qatlamlar, main.dart Stack idiomasi):
//   1) OY KO'RINISHI  — to'yxona tanlagich, oylik xulosa, kalendar, kun/yaqin to'ylar
//   2) BRON TAFSILOTI — mijoz, hisob (ovqat + xizmatlar), to'lovlar, holat, amallar
//   3) YANGI/TAHRIR   — sana, vaqt, to'yxona, narx toifasi, mijoz, jonli hisob
//   4) TO'YXONALAR    — ro'yxat -> bitta to'yxonaning narxlari (ikki qavat)
//
// HAMMA matn toyxona_l10n.dart dan (6 til). HAMMA HTTP toyxona_data.dart da.
//
// REDIZAYN (2026-09-08): faqat VIZUAL qatlam almashdi. Holat mashinasi
// (_detailId / _form / _venuesOpen / _tiersHallId / _cancelledOpen / _searchOpen /
// modallar), store.setModuleBack_ hook'i, onBack, toyRepo chaqiruvlari va matn
// kalitlari AYNAN saqlangan.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, TextInputFormatter, TextEditingValue, TextSelection;
import 'package:image_picker/image_picker.dart';   // 025: servis item rasmi
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import '../toyxona_data.dart';
import '../toyxona_l10n.dart';
import '../toyxona_receipt.dart';
import 'paywall_sheet.dart' show modDefPrice;

/// Summani jonli "x xxx xxx" ko'rinishida guruhlovchi formatter —
/// client_screen.dart nusxasi (F13): KURSOR O'RNINI SAQLAYDI. Eski variant
/// har bosishda kursorni satr oxiriga uloqtirardi — summa o'rtasini tahrirlab
/// bo'lmasdi. Chegara: _digits() 15 xonadan ortig'ini kesadi (int oshmaydi).
class _GroupFmt extends TextInputFormatter {
  static final _d = RegExp(r'\d');

  String _group(String digits) {
    final b = StringBuffer();
    for (var k = 0; k < digits.length; k++) {
      if (k > 0 && (digits.length - k) % 3 == 0) b.write(' ');
      b.write(digits[k]);
    }
    return b.toString();
  }

  bool _isGroupSpace(String s, int i) =>
      s[i] == ' ' && i > 0 && i + 1 < s.length && _d.hasMatch(s[i - 1]) && _d.hasMatch(s[i + 1]);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = newV.text;
    if (t.isEmpty || !_d.hasMatch(t)) return newV;
    var meaningfulBefore = 0;
    final selEnd = newV.selection.end.clamp(0, t.length);
    for (var i = 0; i < selEnd; i++) {
      if (!_isGroupSpace(t, i)) meaningfulBefore++;
    }
    final out = StringBuffer();
    var i = 0;
    while (i < t.length) {
      if (_d.hasMatch(t[i])) {
        final run = StringBuffer();
        var j = i;
        while (j < t.length) {
          if (_d.hasMatch(t[j])) {
            run.write(t[j]);
            j++;
          } else if (t[j] == ' ' && j + 1 < t.length && _d.hasMatch(t[j + 1])) {
            j++;
          } else {
            break;
          }
        }
        out.write(_group(run.toString()));
        i = j;
      } else {
        out.write(t[i]);
        i++;
      }
    }
    final res = out.toString();
    var pos = 0, seen = 0;
    while (pos < res.length && seen < meaningfulBefore) {
      if (!_isGroupSpace(res, pos)) seen++;
      pos++;
    }
    return TextEditingValue(text: res, selection: TextSelection.collapsed(offset: pos));
  }
}

int _digits(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return 0;
  return int.tryParse(d.length > 15 ? d.substring(0, 15) : d) ?? 0;
}

/// O'zbekiston telefon maskasi — ijara.dart (023) bilan bir xil qoida:
/// milliy 9 raqam, "+998 90 123 45 67". Kursor har doim oxirda (prefiks
/// ichiga tushmasin). "998" faqat BIR marta kesiladi.
String _phoneNat(String s) {
  var d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('998')) d = d.substring(3);
  return d.length > 9 ? d.substring(0, 9) : d;
}

String _phoneMask(String s) {
  final d = _phoneNat(s);
  if (d.isEmpty) return '';
  final b = StringBuffer('+998 ');
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 5 || i == 7) b.write(' ');
    b.write(d[i]);
  }
  return b.toString();
}

/// Saqlangan raqamni ko'rsatish: O'zbekiston shaklida bo'lsa maska, aks holda
/// (chet el / eski yozuv) matn O'ZGARMAYDI.
String _phoneShow(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  final uz = d.length == 9 || (d.length == 12 && d.startsWith('998'));
  return uz ? _phoneMask(s) : s.trim();
}

class _PhoneFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = _phoneMask(newV.text);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Ro'yxatdan id bo'yicha narx toifasi (topilmasa null).
Menu? _tierById(List<Menu> tiers, String? id) {
  if (id == null) return null;
  for (final t in tiers) {
    if (t.id == id) return t;
  }
  return null;
}

/// Ism -> bosh harflar ("Alisher aka" -> "AA"), avatar uchun.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final a = parts.first.substring(0, 1);
  final b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}

/// Kechki to'y slotining yumshoq binafsha matni (§5.13: #B4A2FF).
const Color _kLavender = Color(0xFFB4A2FF);

/// Qatorga sig'adigan ixcham pill tugma (h36, px14). GradientBtn/GlassBtn
/// to'liq kenglik uchun mo'ljallangan (ichki chet yo'q) — banner/qator ichida
/// bu ishlatiladi. kind: 'gradient' | 'glass' | 'mint'.
class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final String kind;
  const _MiniBtn(this.label, {required this.onTap, this.kind = 'glass'});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final gradient = kind == 'gradient';
    final mint = kind == 'mint';
    final fg = gradient ? Colors.white : (mint ? p.onMint : p.ink);
    return Tap(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient ? Tb.brand : null,
          color: gradient ? null : (mint ? p.mint : p.glass2),
          border: gradient || mint ? null : Border.all(color: p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: Tx(label, size: 13, w: FontWeight.w600, color: fg, maxLines: 1, font: TbFont.body),
      ),
    );
  }
}

/// Yangi/tahrir formasining holati (ekran-lokal, store'ga tegilmaydi).
class _FormData {
  String? id; // null = yangi bron
  DateTime date;
  String slot;
  String? hallId;
  String? menuId;
  bool priceManual; // narx qo'lda o'zgartirildi -> toifadan ustun
  String name;
  String phone;
  String guests;
  String price;
  String note;
  /// Avans — faqat YANGI bronda ko'rinadi, foydalanuvchi kiritadi (ctor'da berilmaydi).
  String advance = '';
  // ---- 024 ----
  String priceMode; // 'guest' | 'total'
  String totalPrice = ''; // 'total' rejimida butun to'yxona narxi
  /// Yangi bronda katalogdan tanlangan servislar: service_id -> bonus?
  final Map<String, bool> services = {};
  /// Telefon bo'yicha topilgan mijoz (autofill). nameAuto — ism hali qo'lda
  /// o'zgartirilmagan (keyingi topilma uni almashtirishi mumkin).
  ClientHint? hint;
  bool nameAuto = false;
  /// Telefon to'liq terilib baza SO'RALDI (natija hint'da; null = yangi mijoz).
  bool hintChecked = false;
  _FormData({
    this.id,
    required this.date,
    required this.slot,
    this.hallId,
    this.menuId,
    this.priceManual = false,
    this.name = '',
    this.phone = '',
    this.guests = '',
    this.price = '',
    this.note = '',
    this.priceMode = 'guest',
    this.totalPrice = '',
  });
}

class ToyxonaScreen extends StatefulWidget {
  /// Hub'ga qaytish. null bo'lsa orqaga tugmasi ko'rinmaydi (preview rejimi).
  final VoidCallback? onBack;

  /// Apparat "orqaga" tugmasini SHU ekran boshqarsinmi. Hub ichida FALSE
  /// bo'lishi kerak — u yerda main.dart'dagi Root PopScope boshqaradi
  /// (ikkita PopScope bir vaqtda ishlab, ikki qavat orqaga ketib qolmasin).
  final bool handleSystemBack;

  const ToyxonaScreen({super.key, this.onBack, this.handleSystemBack = false});

  @override
  State<ToyxonaScreen> createState() => _ToyxonaScreenState();
}

class _ToyxonaScreenState extends State<ToyxonaScreen> {
  DateTime _month = toyMonthStart(DateTime.now());
  DateTime? _selDay;

  // To'liq-ekran qatlamlar
  String? _detailId;
  _FormData? _form;
  bool _venuesOpen = false;
  String? _tiersHallId;

  /// Bekor qilingan, lekin puli egada qolgan bronlar ro'yxati (faqat o'qish).
  /// Oylik xulosadagi "Bekor qilingan bronlardan: X" qatoridan ochiladi.
  bool _cancelledOpen = false;

  // Anchored menyu / modallar
  bool _monthMenu = false;
  Map<String, dynamic>? _confirm; // {title, body, danger, run}
  Map<String, dynamic>? _hallEdit; // {id?, hallId?, name, cap, price}
  Map<String, dynamic>? _tierEdit; // {hallId, id?, title, price, priceManual, seats, rows}
  Menu? _tableInfo; // 027: bronda stol tarkibi varag'i
  String? _imgBusyMenuId; // 028: katalog kartasidan rasm yuklanmoqda (qaysi stol)
  int? _sumDay; // 028: xulosa kartasida tanlangan band kun
  bool _venueHelp = false; // 029: to'yxonalar ekrani yordam modali
  // ---- 024 ----
  bool _servicesOpen = false; // servislar katalogi qatlami
  // 025: ochilgan kategoriya slug'i (null = kategoriya grid'i). Servislar
  // qatlamining IKKINCHI pog'onasi — alohida Positioned emas, chunki u ayni
  // o'sha qatlam ichida almashadi (orqaga bosilganda grid'ga qaytadi).
  String? _catOpen;
  bool _imgBusy = false;      // rasm yuklanmoqda (forma tugmalari bloklanadi)
  Map<String, dynamic>? _svcEdit; // {id?, title, price}
  Map<String, dynamic>? _cancelSheet; // {id, preview?, penalty, reason, refundNow}
  /// Forma bosqichi: 0 = mijoz·vaqt·summa, 1 = servislar (faqat yangi bron).
  int _formStep = 0;
  String? _svcCatFilter; // 2-bosqich: tanlangan kategoriya (null = hammasi)
  final Set<String> _svcExpanded = {}; // 2-bosqich: "yana N ta" ochilgan guruhlar
  Timer? _phoneT; // telefon → mijoz autofill debounce
  int _phoneSeq = 0;
  bool _svcBonus = false; // tafsilotdagi xizmat formasi: bonus
  String? _svcServiceId; // tafsilotdagi xizmat formasi: katalog id

  // Tafsilotdagi kichik formalar
  bool _svcOpen = false;
  String _svcTitle = '';
  String _svcAmount = '';
  int _svcQty = 1; // U3: xizmat soni (1..kToyMaxSvcQty)
  bool _payOpen = false;
  String _payAmount = '';
  String _payKind = 'avans';
  String _payNote = '';
  DateTime _payDate = toyDay(DateTime.now()); // U2: kechagi naqd bugun yoziladi

  // Qidiruv (U7) — header lupasidan ochiladigan ichki qidiruv holati
  bool _searchOpen = false;
  String _searchQ = '';
  Timer? _searchT; // 400ms debounce
  List<Booking>? _searchServer; // null = server javobi yo'q (kutilmoqda/oflayn)
  bool _searchBusy = false;
  bool _searchOffline = false;
  int _searchSeq = 0; // eskirgan qidiruv javobi tashlanadi

  // Yaqin bronlar kengaytmasi (U6): 6 tadan 30 tagacha
  bool _upcomingAll = false;

  // Forma kunining bandligi (U1): 'YYYY-MM-DD' -> o'sha kunning BARCHA bandlari
  // (to'yxona filtrisiz — formada boshqa zal tanlansa ham belgilar to'g'ri).
  final Map<String, List<Booking>> _dayRows = {};
  final Set<String> _dayFetched = {};

  // Zallar sahifasidagi "Arxiv (N)" bo'limi (U10)

  // Oy menyusi 31 oyni qamraydi (F11) — ochilganda tanlangan oy ko'rinib
  // turishi uchun boshlang'ich siljish bilan yaratiladigan controller.
  ScrollController? _monthMenuCtl;

  bool _busy = false;
  String _toast = '';
  Timer? _toastT;

  /// Apparat "orqaga" ilgagi (store.moduleBack). `late final` SHART: har safar
  /// `_closeTop` tear-off'i YANGI obyekt yaratadi, clearModuleBack_ esa identity
  /// bo'yicha solishtiradi — bir xil nusxa bo'lmasa dispose o'zinikini tozalay
  /// olmay, boshqa modulnikini o'chirib yuborishi yoki osilib qolishi mumkin.
  late final bool Function() _backHook = _closeTop;

  @override
  void initState() {
    super.initState();
    // F11: modulga kirilganda ko'riladigan oy HAR DOIM joriy oy — o'tgan
    // sessiyada qaralgan uzoq oy yopishib qolmasin (repo.enter() ham shuni qiladi).
    _month = toyMonthStart(DateTime.now());
    // Hub ichida (handleSystemBack: false) apparat "orqaga" Root PopScope'ga
    // boradi — u hub'ga qaytishdan OLDIN shu ilgakni chaqiradi, ya'ni ochiq
    // forma/tafsilot bir bosishda butun modulni yopib, kiritilganni YO'QOTMAYDI.
    // Preview'da ekranning O'Z PopScope'i bor — u yerda ro'yxatdan o'tmaymiz,
    // aks holda bitta bosishda ikki qavat orqaga ketardi.
    if (!widget.handleSystemBack) store.setModuleBack_(_backHook);
    // Birinchi kadrdan keyin yuklaymiz (initState ichida setState bo'lmasin).
    // enter() (F4): zallar keshi darhol ko'rsatiladi, ro'yxat orqa fonda yangilanadi.
    WidgetsBinding.instance.addPostFrameCallback((_) => toyRepo.enter());
  }

  @override
  void dispose() {
    // FAQAT o'zimiznikini tozalaymiz (store identity bo'yicha tekshiradi):
    // yangi ekranning initState'i eskisining dispose'idan OLDIN ishlashi mumkin.
    if (!widget.handleSystemBack) store.clearModuleBack_(_backHook);
    _toastT?.cancel();
    _searchT?.cancel();
    _phoneT?.cancel();
    _monthMenuCtl?.dispose();
    super.dispose();
  }

  // ---------------- Yordamchilar ----------------

  void _toastMsg(String msg) {
    if (!mounted || msg.isEmpty) return;
    _toastT?.cancel();
    setState(() => _toast = msg);
    _toastT = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  /// Repo xatosini ko'rsatish (ijara.dart _toastErr bilan bir qoida, F6):
  /// serverning xato matnlari FAQAT o'zbekcha (src/routes/toyxona.js) — ruscha
  /// yoki inglizcha ishlatayotgan ega ularni tushunmasdi. TANILGAN kodlar
  /// modulning O'Z (6 tilli) matniga aylantiriladi:
  ///   SLOT_TAKEN   -> slotTaken (+ serverning "Band: <mijoz>" tafsiloti),
  ///   HALL_LIMIT   -> oneVenueNote (403 — PAYWALL EMAS, sotiladigan narsa yo'q),
  ///   SUB_EXPIRED  -> errSubExpired (paywall'ni _req allaqachon ochgan),
  ///   HAS_PAYMENTS -> delHasPayments (qat'iy o'chirish taqiqlangan — 'bekor' bor).
  /// Tanilmagan kodda serverning matni (bo'lmasa zaxira) qoladi: validatsiya
  /// xabarlari aniqroq bo'lgani uchun ular yashirilmaydi.
  void _toastErr([String? fallback]) {
    switch (toyRepo.lastCode) {
      case 'SLOT_TAKEN':
        final d = toyRepo.lastDetail;
        _toastMsg(d.isEmpty ? ty('slotTaken') : '${ty('slotTaken')} · $d');
        return;
      case 'HALL_LIMIT':
        _toastMsg(ty('perHallNote', {'price': '${modDefPrice('toyxona')}'}));
        return;
      case 'SUB_EXPIRED':
        _toastMsg(ty('errSubExpired'));
        return;
      case 'HAS_PAYMENTS':
        _toastMsg(ty('delHasPayments'));
        return;
    }
    final e = toyRepo.error;
    final detail = toyRepo.lastDetail;
    final base = (e == null || e.isEmpty) ? (fallback ?? ty('errGeneric')) : e;
    _toastMsg(detail.isEmpty ? base : '$base · $detail');
  }

  /// Holat rangi (§5.13): band amber, tasdiqlangan mint, yakunlangan muted, bekor coral.
  Color _statusColor(String s, Pal p) => switch (s) {
        'tasdiq' => p.mint,
        'yakun' => p.t2,
        'bekor' => p.coral,
        _ => p.amber,
      };

  /// Holat nishoni (PillBadge) — ro'yxat qatorlari va tafsilot uchun.
  Widget _statusBadge(String s, {double h = 20}) => switch (s) {
        'tasdiq' => PillBadge.mint(tyStatus(s), h: h),
        'yakun' => PillBadge.muted(tyStatus(s), h: h),
        'bekor' => PillBadge.coral(tyStatus(s), h: h),
        _ => PillBadge.amber(tyStatus(s), h: h),
      };

  /// Qoldiq rangi: to'lanmagan qism coral, yopilgan (yoki ortiqcha) mint.
  Color _leftColor(int left, Pal p) => left > 0 ? p.coral : p.mint;

  /// Slot ikonkasi / rangi (§5.13): nahor — quyosh amber; tushlik — restoran
  /// cyan; kechki — oy violet (matn #B4A2FF).
  IconData _slotIcon(String slot) => switch (slot) {
        'nahor' => Icons.wb_sunny_outlined,
        'tushlik' => Icons.restaurant_outlined,
        _ => Icons.dark_mode_outlined,
      };

  Color _slotColor(String slot, Pal p) => switch (slot) {
        'nahor' => p.amber,
        'tushlik' => p.cyan,
        _ => (p.isDark ? _kLavender : p.violet),
      };

  Color _slotBg(String slot, Pal p) => switch (slot) {
        'nahor' => p.amber.withValues(alpha: .15),
        'tushlik' => p.cyan.withValues(alpha: .15),
        _ => p.violet.withValues(alpha: .20),
      };

  /// 44px r14 slot ikonka qutisi.
  Widget _slotIconBox(String slot, Pal p, {double size = 44}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _slotBg(slot, p), borderRadius: BorderRadius.circular(Tb.rIcon)),
        child: Icon(_slotIcon(slot), size: size * 0.5, color: _slotColor(slot, p)),
      );

  bool get _anyLayer =>
      _detailId != null ||
      _form != null ||
      _venuesOpen ||
      _tiersHallId != null ||
      _cancelledOpen ||
      _searchOpen;

  /// Eng ustki qatlamni yopadi. true — nimadir yopildi.
  bool _closeTop() {
    if (_confirm != null) {
      setState(() => _confirm = null);
      return true;
    }
    if (_hallEdit != null) {
      setState(() => _hallEdit = null);
      return true;
    }
    if (_tierEdit != null) {
      setState(() => _tierEdit = null);
      return true;
    }
    if (_tableInfo != null) {
      setState(() => _tableInfo = null);
      return true;
    }
    if (_venueHelp) {
      setState(() => _venueHelp = false);
      return true;
    }
    if (_svcEdit != null) {
      setState(() => _svcEdit = null);
      return true;
    }
    if (_cancelSheet != null) {
      setState(() => _cancelSheet = null);
      return true;
    }
    if (_monthMenu) {
      setState(() => _monthMenu = false);
      return true;
    }
    // Tartib build()'dagi Stack z-tartibi bilan BIR XIL: eng ustki qatlam avval
    // yopiladi (tiers -> venues -> forma -> tafsilot). Aks holda ko'rinmayotgan
    // qatlam yopilib, foydalanuvchi "orqaga bosdim, hech nima o'zgarmadi" derdi.
    if (_tiersHallId != null) {
      setState(() => _tiersHallId = null);
      return true;
    }
    if (_servicesOpen) {
      // 025: kategoriya ichidan avval grid'ga, keyin qatlamdan chiqish
      if (_catOpen != null) {
        setState(() => _catOpen = null);
      } else {
        setState(() => _servicesOpen = false);
      }
      return true;
    }
    if (_venuesOpen) {
      setState(() => _venuesOpen = false);
      return true;
    }
    if (_form != null) {
      setState(() => _form = null);
      return true;
    }
    if (_detailId != null) {
      _closeDetail();
      return true;
    }
    // Tafsilotdan KEYIN: bekor qilinganlar ro'yxatidan tafsilot ochilgan bo'lsa,
    // orqaga avval tafsilotni yopadi va ro'yxatga qaytaradi, keyingi bosishda
    // oy ko'rinishiga, undan keyingisida hub'ga (false qaytadi).
    if (_cancelledOpen) {
      setState(() => _cancelledOpen = false);
      return true;
    }
    // Qidiruv ildiz gavdasida yashaydi (qatlam emas): natijadan ochilgan
    // tafsilot yuqorida yopiladi, undan keyingi "orqaga" qidiruvni yopadi.
    if (_searchOpen) {
      _closeSearch();
      return true;
    }
    return false;
  }

  /// Tafsilotni yopish — ichki kichik formalar ham tozalanadi (keyingi bron
  /// ochilganda oldingi yozuvning matni qolib ketmasin).
  void _closeDetail() {
    setState(() {
      _detailId = null;
      _svcOpen = false;
      _svcTitle = '';
      _svcAmount = '';
      _svcQty = 1;
      _payOpen = false;
      _payAmount = '';
      _payNote = '';
      _payKind = 'avans';
      _payDate = toyDay(DateTime.now());
      _svcBonus = false;
      _svcServiceId = null;
    });
  }

  // ---------------- Qidiruv holati (U7) ----------------

  void _openSearch() => setState(() => _searchOpen = true);

  void _closeSearch() {
    _searchT?.cancel();
    _searchSeq++; // yo'ldagi javob eskirsin
    setState(() {
      _searchOpen = false;
      _searchQ = '';
      _searchServer = null;
      _searchBusy = false;
      _searchOffline = false;
    });
  }

  void _onSearchChanged(String v) {
    _searchT?.cancel();
    final q = v.trim();
    setState(() {
      _searchQ = v;
      if (q.length < 2) {
        // 2 belgidan kam — server bezovta qilinmaydi, natijalar tozalanadi
        _searchSeq++;
        _searchServer = null;
        _searchBusy = false;
        _searchOffline = false;
      }
    });
    if (q.length < 2) return;
    _searchT = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    setState(() => _searchBusy = true);
    final res = await toyRepo.searchBookings(q);
    if (!mounted || seq != _searchSeq) return; // eskirgan javob
    setState(() {
      _searchBusy = false;
      _searchServer = res; // null = tarmoq yiqildi -> klient mosliklari + belgi
      _searchOffline = res == null;
    });
  }

  // ---------------- Ildiz ----------------

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: toyRepo,
      builder: (context, _) {
        final p = curPal();
        return Stack(
          children: [
            Column(
              children: [
                _header(p),
                // Qidiruv rejimida chiplar yashirinadi — butun gavda natijalarga
                if (!_searchOpen && toyRepo.halls.length > 1) _venueChips(p),
                Expanded(child: _searchOpen ? _searchBody(p) : _monthBody(p)),
              ],
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar(p)),
            // Bekor qilinganlar ro'yxati oy ko'rinishi USTIDA, lekin tafsilotdan
            // PASTDA: qatordan tafsilot ochilganda u yuqorida chiziladi, orqaga
            // bosilganda ro'yxatga qaytiladi (_closeTop tartibi ham shunga mos).
            // To'liq-ekran qatlamlar o'z foni bilan (ScreenBg).
            if (_cancelledOpen) Positioned.fill(child: ScreenBg(child: _cancelledView(p))),
            if (_detailId != null) Positioned.fill(child: ScreenBg(child: _detail(p))),
            if (_form != null) Positioned.fill(child: ScreenBg(child: _formView(p))),
            if (_venuesOpen && _tiersHallId == null && !_servicesOpen) Positioned.fill(child: ScreenBg(child: _venuesView(p))),
            if (_servicesOpen && _tiersHallId == null) Positioned.fill(child: ScreenBg(child: _servicesView(p))),
            if (_tiersHallId != null) Positioned.fill(child: ScreenBg(child: _tiersView(p))),
            if (_monthMenu) _monthMenuCard(p),
            if (_confirm != null) _confirmModal(p),
            if (_hallEdit != null) _hallEditModal(p),
            if (_tierEdit != null) _tierEditModal(p),
            if (_tableInfo != null) _tableSheet(p),
            if (_venueHelp) _venueHelpModal(p),
            if (_svcEdit != null) _svcEditModal(p),
            if (_cancelSheet != null) _cancelModal(p),
            ToastView(open: _toast.isNotEmpty, text: _toast),
          ],
        );
      },
    );
    if (!widget.handleSystemBack) return body;
    // Preview rejimi: apparat "orqaga" ochiq qatlamni yopadi.
    return PopScope(
      canPop: !_anyLayer && _confirm == null && _hallEdit == null && _tierEdit == null && _tableInfo == null && !_venueHelp && _svcEdit == null && _cancelSheet == null && !_servicesOpen && !_monthMenu,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeTop();
      },
      child: body,
    );
  }

  // ================= SARLAVHA =================

  /// ScreenHeader: "To'yxona" + PRO badge, sub — tanlangan to'yxona (yoki oy),
  /// o'ngda qidiruv (U7) va to'yxonalar/narxlar (sozlamalar) tugmalari.
  Widget _header(Pal p) {
    // Qidiruv rejimi (U7): header o'rnida qidiruv maydoni
    if (_searchOpen) return _searchHeader(p);
    final hall = toyRepo.currentHall;
    final sub = toyRepo.halls.isEmpty
        ? '${tyMonth(_month.month)} ${_month.year}'
        : (hall?.name ?? ty('allVenues'));
    return ScreenHeader(
      title: ty('title'),
      subtitle: sub,
      titleTrailing: PillBadge.pro(),
      onBack: widget.onBack,
      trailing: [
        // Qidiruv (U7) — mijoz/telefon bo'yicha bronni topish
        GlassIconBtn(icon: Icons.search_rounded, onTap: _openSearch),
        // To'yxonalar va narxlar (sozlamalar)
        GlassIconBtn(icon: Icons.tune, iconSize: 20, onTap: () => setState(() => _venuesOpen = true)),
      ],
    );
  }

  /// Qidiruv headeri: orqaga + shisha pill maydon (avtofokus).
  Widget _searchHeader(Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
      child: Row(
        children: [
          BackBtn(onTap: _closeSearch),
          const SizedBox(width: 12),
          Expanded(
            child: GlassField(
              h: 44,
              icon: Icons.search_rounded,
              focused: true,
              trailing: _searchQ.isNotEmpty
                  ? GlassIconBtn(icon: Icons.close_rounded, size: 32, iconSize: 16, onTap: () => _onSearchChanged(''))
                  : null,
              child: StoreField(
                value: _searchQ,
                onChanged: _onSearchChanged,
                hint: ty('searchPh'),
                autofocus: true,
                style: tbStyle(size: 15, color: p.ink),
                hintColor: p.t5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Oy menyusini ochish: tanlangan oy (indeks 12) karta o'rtasida ko'rinsin —
  /// qator balandligi ~45px, karta 330px. Controller har ochilishda yangi
  /// (initialScrollOffset attach'dan OLDIN berilishi kerak).
  void _openMonthMenu() {
    _monthMenuCtl?.dispose();
    _monthMenuCtl = ScrollController(initialScrollOffset: 12 * 45.0 - 140);
    setState(() => _monthMenu = true);
  }

  /// Oy tanlash — oy sarlavhasi ostidagi anchored shisha menyu.
  /// F11: bronlar oldinga OYLAB ketadi (kuzgi cho'qqi) — oraliq tanlangan
  /// oydan −12 orqaga va +18 oldinga; joriy oy halqa-nuqta bilan belgilanadi.
  Widget _monthMenuCard(Pal p) {
    final now = DateTime.now();
    final opts = [for (var i = -12; i <= 18; i++) DateTime(_month.year, _month.month + i, 1)];
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _monthMenu = false),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: 120,
            left: Tb.padX,
            child: GlassCard(
              r: Tb.rRow,
              color: p.surface,
              shadow: Tb.panelShadow,
              child: Container(
                constraints: const BoxConstraints(minWidth: 200, maxHeight: 330),
                child: IntrinsicWidth(
                  child: SingleChildScrollView(
                    controller: _monthMenuCtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < opts.length; i++)
                          _menuRow(
                            p,
                            '${tyMonth(opts[i].month)} ${opts[i].year}',
                            opts[i].year == _month.year && opts[i].month == _month.month,
                            i == 0,
                            () => _pickMonth(opts[i]),
                            isNow: opts[i].year == now.year && opts[i].month == now.month,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Menyu qatori — tanlanganida w600 + o'ngda gradient nuqta.
  /// isNow (F11): JORIY oy ichi bo'sh halqa bilan belgilanadi — ega ro'yxatda
  /// "bugun qayerdaman" ni bir qarashda topadi (tanlangan oy to'la nuqta).
  Widget _menuRow(Pal p, String label, bool on, bool first, VoidCallback onTap,
      {bool isNow = false}) {
    return Tap(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 14, w: on || isNow ? FontWeight.w600 : FontWeight.w500, color: on ? p.ink : p.t1),
            if (on) ...[
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(gradient: Tb.brandDiag, shape: BoxShape.circle),
              ),
            ] else if (isNow) ...[
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(border: Border.all(color: p.t3, width: 1.2), shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pickMonth(DateTime m) {
    setState(() {
      _monthMenu = false;
      _month = toyMonthStart(m);
      _selDay = null;
    });
    toyRepo.load(_month);
  }

  // ================= TO'YXONA TANLAGICH =================

  Widget _venueChips(Pal p) {
    final halls = toyRepo.halls;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
        children: [
          _chip(p, ty('allVenues'), toyRepo.selectedHallId == null, () => _selectHall(null)),
          for (final h in halls) ...[
            const SizedBox(width: 8),
            _chip(p, h.name, toyRepo.selectedHallId == h.id, () => _selectHall(h.id)),
          ],
        ],
      ),
    );
  }

  Future<void> _selectHall(String? id) async {
    setState(() => _selDay = null);
    await toyRepo.selectHall(id);
    if (mounted && toyRepo.error != null) _toastErr(ty('loadFailed'));
  }

  /// Tanlov chipi (h40) — PillChip.
  Widget _chip(Pal p, String label, bool on, VoidCallback onTap) =>
      PillChip(label: label, selected: on, onTap: onTap);

  // ================= OY KO'RINISHI =================

  Widget _monthBody(Pal p) {
    if (toyRepo.loading && !toyRepo.loaded) return _skeleton(p);
    if (toyRepo.error != null && !toyRepo.loaded) return _errorState(p);
    // U9: joriy oyga qaralayotganda "Bugun" lentasi — eganing ertalabki qarashi
    final now = DateTime.now();
    final todayRows = (_month.year == now.year && _month.month == now.month)
        ? [for (final s in kToySlots) ...toyRepo.allAt(toyDay(now), s)]
        : const <Booking>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // F1: birinchi yuklashdan keyin oy almashtirilsa skelet o'rniga
          // yengil "yuklanmoqda" belgisi — kontekst yo'qolmaydi.
          // F1: oy yuklanmay qolsa ESKI OY JIMGINA TURMAYDI — repo ro'yxatni
          // tozalagan, bu yerda banner + qayta urinish.
          if (toyRepo.monthError != null && !toyRepo.loading) ...[
            _monthErrorBanner(p),
            const SizedBox(height: 16),
          ],
          if (toyRepo.hallsLoaded && toyRepo.halls.isEmpty) ...[
            _noVenueCard(p),
            const SizedBox(height: 16),
          ],
          if (todayRows.isNotEmpty) ...[
            _todayStrip(p, todayRows),
            const SizedBox(height: 20),
          ],
          _monthTitle(p),
          const SizedBox(height: 14),
          _summary(p),
          const SizedBox(height: 16),
          _calendar(p),
          const SizedBox(height: 20),
          if (_selDay != null) _dayPanel(p, _selDay!) else _upcomingPanel(p),
        ],
      ),
    );
  }

  /// Oy sarlavhasi (§5.13): "Sentabr 2026" 22/600 head (bosilsa oy menyusi) ·
  /// o'ngda oldingi/keyingi oy tugmalari (36px).
  Widget _monthTitle(Pal p) {
    return Row(
      children: [
        Expanded(
          child: Tap(
            onTap: _openMonthMenu,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Tx('${tyMonth(_month.month)} ${_month.year}',
                      size: 22, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 1, ellipsis: true),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: p.t3),
              ],
            ),
          ),
        ),
        // F1/028: oy almashganda yuklanish belgisi SHU YERDA — sarlavha qatori
        // balandligi o'zgarmaydi, kalendar va kartalar joyidan siljimaydi.
        SizedBox(
          width: 24,
          height: 24,
          child: toyRepo.loading && toyRepo.loaded
              ? Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation<Color>(p.cyan)),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        GlassIconBtn(
          icon: Icons.chevron_left_rounded,
          size: 36,
          iconSize: 22,
          onTap: () => _pickMonth(DateTime(_month.year, _month.month - 1, 1)),
        ),
        const SizedBox(width: 8),
        GlassIconBtn(
          icon: Icons.chevron_right_rounded,
          size: 36,
          iconSize: 22,
          onTap: () => _pickMonth(DateTime(_month.year, _month.month + 1, 1)),
        ),
      ],
    );
  }

  /// Legenda: ● violet Band · ● ink20 Bo'sh (13 t2).
  Widget _legend(Pal p) {
    Widget dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        dot(p.violet),
        const SizedBox(width: 6),
        Tx(ty('stBand'), size: 13, color: p.t2),
      ],
    );
  }

  /// Yengil yuklanish belgisi (F1) — qidiruvda ishlatiladi (oy almashishida
  /// endi sarlavha qatoridagi kichik spinner, 028).
  Widget _loadingHint(Pal p) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation<Color>(p.cyan)),
        ),
        const SizedBox(width: 8),
        Tx(ty('loadingHint'), size: 13, color: p.t3),
      ],
    );
  }

  /// Oy yuklanmaganda ichki banner (F1): ro'yxat bo'sh, sabab va qayta urinish.
  Widget _monthErrorBanner(Pal p) {
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: p.coral.withValues(alpha: .10),
      border: p.coral.withValues(alpha: .30),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: p.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(ty('loadFailed'), size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2),
                if ('${toyRepo.monthError ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Tx(toyRepo.monthError ?? '', size: 12, color: p.t4, lh: 16, maxLines: 2, ellipsis: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniBtn(ty('retry'), onTap: () => toyRepo.load(_month)),
        ],
      ),
    );
  }

  /// "Bugun" lentasi (U9): bugungi bandlar — slot, mijoz, mehmon, qoldiq.
  /// Bosilsa tafsilot ochiladi. Egaga ertalab bitta qarash yetadi.
  Widget _todayStrip(Pal p, List<Booking> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ty('today')),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _todayCard(p, rows[i]),
                if (i < rows.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _todayCard(Pal p, Booking b) {
    return Tap(
      onTap: () => setState(() => _detailId = b.id),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: SizedBox(
          width: 210,
          child: Row(
            children: [
              _slotIconBox(b.slot, p, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(b.clientName, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                    const SizedBox(height: 2),
                    Tx(tySlot(b.slot), size: 12, color: p.t2, maxLines: 1, ellipsis: true),
                    const SizedBox(height: 2),
                    // Pul kesilmaydi — butun qator FittedBox ichida (F14 qoidasi)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          if (b.guests > 0) ...[
                            Tx(ty('guestsN', {'n': '${b.guests}'}), size: 12, color: p.t4),
                            Tx(' · ', size: 12, color: p.t4),
                          ],
                          Tx(toyMoney(b.left), size: 12, w: FontWeight.w600, color: _leftColor(b.left, p), tab: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeleton(Pal p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skel(w: 160, h: 24, r: 8),
          SizedBox(height: 14),
          Skel(h: 130, r: 24),
          SizedBox(height: 16),
          Skel(h: 340, r: 24),
          SizedBox(height: 20),
          Skel(w: 120, h: 13, r: 6),
          SizedBox(height: 12),
          Skel(h: 68, r: 20),
          SizedBox(height: 8),
          Skel(h: 68, r: 20),
        ],
      ),
    );
  }

  Widget _errorState(Pal p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 32, color: p.coral),
            const SizedBox(height: 12),
            Tx(ty('loadFailed'), size: 15, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(toyRepo.error ?? '', size: 13, color: p.t4, align: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: 170,
              child: GlassBtn(label: ty('retry'), onTap: () => toyRepo.load(_month), h: 44),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noVenueCard(Pal p) {
    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.all(16),
      color: p.violet.withValues(alpha: .10),
      border: p.violet.withValues(alpha: .30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_outlined, size: 20, color: p.violet),
              const SizedBox(width: 8),
              Expanded(child: Tx(ty('noVenueTitle'), size: 15, w: FontWeight.w600, color: p.ink, maxLines: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Tx(ty('noVenueSub'), size: 13, color: p.t2, lh: 18),
          const SizedBox(height: 12),
          GradientBtn(label: ty('addFirstVenue'), onTap: _openNewHall, h: 44, fs: 14, glow: false),
        ],
      ),
    );
  }

  /// Oylik xulosa kartasi: Cap "{oy} · N TO'Y", jami 30/600 mint, avans/qoldiq
  /// qatori, bekor qilinganlardan qolgan pul (bosiladigan).
  Widget _summary(Pal p) {
    // F3: server xulosasi shu yuklashda kelmagan bo'lsa — yuklangan qatorlardan
    // hisob (shownSummary). Eski oyning raqami hech qachon ko'rsatilmaydi.
    final s = toyRepo.shownSummary;
    // 028: BAND KUNLAR — oy ichida bron bor kunlar (bekorlarsiz), kun → bronlar.
    final byDay = <int, List<Booking>>{};
    for (final b in toyRepo.activeMonthBookings) {
      if (b.eventDate.year != _month.year || b.eventDate.month != _month.month) continue;
      (byDay[b.eventDate.day] ??= []).add(b);
    }
    final days = byDay.keys.toList()..sort();
    for (final l in byDay.values) {
      l.sort((a, b) => kToySlots.indexOf(a.slot).compareTo(kToySlots.indexOf(b.slot)));
    }
    final sel = _sumDay != null && byDay.containsKey(_sumDay) ? _sumDay : null;
    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // countActive — total/paid/left AYNAN shu bandlardan (bekor qilinganlarsiz)
            Cap(ty('summaryCap', {'month': '${tyMonth(_month.month)} ${_month.year}', 'n': '${s.countActive}'})),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(toyMoney(s.total), size: 30, w: FontWeight.w600, color: p.mint, tab: true),
            ),
            const SizedBox(height: 6),
            _totalRow(p, ty('advanceTakenLabel'), toyMoney(s.paid), p.t2),
            const SizedBox(height: 4),
            _totalRow(p, ty('leftLabel'), toyMoney(s.left), s.left > 0 ? p.amber : p.t2),
            if (days.isNotEmpty) ...[
              const SizedBox(height: 14),
              Cap(ty('bookedDaysCap')),
              const SizedBox(height: 8),
              // Kun belgilari — ko'p bo'lsa gorizontal aylanadi, karta kengaymaydi
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final d in days) ...[
                      _dayBadge(p, d, byDay[d]!, sel == d),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (sel != null) ...[
                const SizedBox(height: 10),
                for (var i = 0; i < byDay[sel]!.length; i++) _sumBookingRow(p, byDay[sel]![i], first: i == 0),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Kun belgisi: kun raqami + shu kundagi bronlarning slot ikonkalari
  /// (osh / tushlik / to'y). Bosilsa ostida mijozlar ro'yxati ochiladi.
  Widget _dayBadge(Pal p, int day, List<Booking> rows, bool on) {
    return Tap(
      onTap: () => setState(() => _sumDay = on ? null : day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? p.ink : p.glass2,
          border: Border.all(color: on ? p.ink : p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rIcon),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tx('$day', size: 16, w: FontWeight.w700, color: on ? p.bg : p.ink, tab: true),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Icon(_slotIcon(rows[i].slot), size: 12, color: on ? p.bg.withValues(alpha: .85) : _slotColor(rows[i].slot, p)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tanlangan kundagi bron qatori: slot ikonkasi · mijoz ismi · ostida telefon;
  /// bosilsa bron tafsiloti ochiladi.
  Widget _sumBookingRow(Pal p, Booking b, {required bool first}) {
    return Tap(
      onTap: () => setState(() => _detailId = b.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(
          children: [
            _slotIconBox(b.slot, p, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(b.clientName, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  Tx(
                    b.clientPhone.isNotEmpty ? _phoneShow(b.clientPhone) : tySlot(b.slot),
                    size: 12, color: p.t4, maxLines: 1, tab: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tx(toyFx(b.total), size: 13, w: FontWeight.w600, color: p.t2, tab: true),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.t4),
          ],
        ),
      ),
    );
  }

  // ================= KALENDAR =================

  /// Kalendar (§5.13): GlassCard r24 pad12; hafta kunlari 12/700 t4; kun
  /// tugmasi h52 r12 — bugun brend gradient, tanlangan glass2 + violet chegara,
  /// o'tgan t6 matn, oddiy ink 3%; ostida 3 slot nuqtasi (band violet / bo'sh ink15).
  Widget _calendar(Pal p) {
    final first = toyMonthStart(_month);
    final daysInMonth = toyMonthEnd(_month).day;
    final lead = first.weekday - 1; // 1=dushanba
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(
        children: [
          for (var c = 0; c < 7; c++) ...[
            Expanded(child: cells[i + c] == null ? const SizedBox(height: 52) : _dayCell(p, cells[i + c]!)),
            if (c < 6) const SizedBox(width: 4),
          ],
        ],
      ));
      if (i + 7 < cells.length) rows.add(const SizedBox(height: 4));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legend(p),
        const SizedBox(height: 10),
        GlassCard(
          r: Tb.rCard,
          pad: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  for (var w = 1; w <= 7; w++) ...[
                    Expanded(
                      child: Center(
                        child: Tx(tyWeekday(w), size: 12, w: FontWeight.w700, color: p.t4, maxLines: 1, font: TbFont.body),
                      ),
                    ),
                    if (w < 7) const SizedBox(width: 4),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ...rows,
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayCell(Pal p, DateTime day) {
    final booked = toyRepo.bookedSlots(day);
    final now = DateTime.now();
    final today = toySameDay(day, now);
    final past = !today && day.isBefore(toyDay(now));
    final sel = _selDay != null && toySameDay(day, _selDay!);
    // 029: bugun — faqat CHEGARA brend rangda, ichi bo'yalmaydi
    final numColor = past ? p.t6 : p.ink;
    return Tap(
      onTap: () => setState(() => _selDay = sel ? null : day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        decoration: BoxDecoration(
          color: sel ? p.glass2 : p.ink.withValues(alpha: .03),
          border: sel
              ? Border.all(color: p.violet, width: 1.5)
              : (today ? Border.all(color: p.violet.withValues(alpha: .7), width: 1.5) : null),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tx('${day.day}', size: 14, w: FontWeight.w600, color: numColor, tab: true),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final s in kToySlots) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: booked.contains(s) ? p.violet : p.ink.withValues(alpha: .15),
                    ),
                  ),
                  if (s != kToySlots.last) const SizedBox(width: 3),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= KUN PANELI =================

  Widget _dayPanel(Pal p, DateTime day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(
          toySameDay(day, DateTime.now())
              ? '${ty('today')} · ${toyDateLong(day)}'
              : toyDateLong(day),
        ),
        const SizedBox(height: 12),
        for (final slot in kToySlots) ...[
          _slotGroup(p, day, slot),
          if (slot != kToySlots.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// Bitta slot bo'limi (U8): "Hammasi" ko'rinishida bir slotda HAR to'yxonadan
  /// alohida band bo'ladi — ilgari at() faqat birinchisini ko'rsatib, qolgan
  /// zallarning to'ylari kun panelidan YO'QOLARDI. Endi hammasi chiqadi, bo'sh
  /// zal qolgan bo'lsa o'sha zal uchun "bo'sh" qatori ham beriladi.
  Widget _slotGroup(Pal p, DateTime day, String slot) {
    final list = toyRepo.allAt(day, slot);
    final multi = toyRepo.selectedHallId == null && toyRepo.halls.length > 1;
    if (list.isEmpty) return _freeSlotRow(p, day, slot);
    final freeHalls = multi
        ? [for (final h in toyRepo.halls) if (!list.any((b) => b.hallId == h.id)) h]
        : const <Hall>[];
    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          _slotBookingRow(p, list[i], showHall: multi),
          if (i < list.length - 1) const SizedBox(height: 8),
        ],
        if (freeHalls.isNotEmpty) ...[
          const SizedBox(height: 8),
          _slotFreeHalls(p, day, slot, freeHalls),
        ],
      ],
    );
  }

  /// Bo'sh slot (h68 GlassCard r20): slot ikonkasi · nom 15/600 · "Bo'sh" mint ·
  /// o'ngda "+ band qilish" gradient mini tugma. Bosilsa to'ldirilgan forma.
  Widget _freeSlotRow(Pal p, DateTime day, String slot) {
    return Tap(
      onTap: () => _openNewBooking(day, slot),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            _slotIconBox(slot, p),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(tySlot(slot), size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(ty('free'), size: 14, w: FontWeight.w600, color: p.mint, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _MiniBtn(ty('bookIt'), kind: 'gradient', onTap: () => _openNewBooking(day, slot)),
          ],
        ),
      ),
    );
  }

  /// Slotda band bo'lmagan zallar qatori (U8): zal nomi bosilsa AYNAN o'sha
  /// zalga forma ochiladi — ega telefonda gaplashib turib bo'sh zalni sotadi.
  Widget _slotFreeHalls(Pal p, DateTime day, String slot, List<Hall> freeHalls) {
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tx(ty('free'), size: 13, w: FontWeight.w600, color: p.mint),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in freeHalls)
                  _smallChip(p, h.name, false, () => _openNewBooking(day, slot, hallId: h.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Band slot (h68 GlassCard r20): slot ikonkasi · mijoz 15/600 + zal/slot/mehmon
  /// 13 t2 (+ "Narx kiritilmagan" nishoni) · qoldiq 15/600 num + holat nishoni.
  Widget _slotBookingRow(Pal p, Booking b, {bool showHall = false}) {
    final sub = showHall && b.hallName.isNotEmpty
        ? '${b.hallName} · ${tySlot(b.slot)}${_guestsSuffix(b)}'
        : '${tySlot(b.slot)}${_guestsSuffix(b)}';
    return Tap(
      onTap: () => setState(() => _detailId = b.id),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            _slotIconBox(b.slot, p),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(b.clientName, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(sub, size: 13, color: p.t2, maxLines: 1, ellipsis: true),
                  if (b.priceMissing) ...[
                    const SizedBox(height: 4),
                    _noPriceTag(p),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Pul kesilmaydi (F14) — FittedBox, ijara qatori bilan bir naqsh
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tx(toyMoney(b.left), size: 15, w: FontWeight.w600, color: _leftColor(b.left, p), tab: true),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: _statusBadge(b.status)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Narx kiritilmagan" belgisi (U5): avansli, lekin menyusi hali
  /// kelishilmagan bron O'zbekistonda NORMAL — bu bloklamaydi, faqat eslatadi.
  Widget _noPriceTag(Pal p) => PillBadge.amber(ty('noPriceChip'), h: 20, icon: Icons.warning_amber_rounded);

  // ================= YAQIN TO'YLAR =================

  Widget _upcomingPanel(Pal p) {
    // U6: standart 6 ta; "Hammasi (N)" bosilsa 30 tagacha ochiladi.
    final full = toyRepo.upcoming(30);
    final list = _upcomingAll ? full : full.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ty('upcomingCap')),
        const SizedBox(height: 12),
        if (full.isEmpty)
          // F9: uch xil bo'shliq farqlanadi —
          //   * hisobda umuman bron yo'q  -> birinchi ishga tushirish holati,
          //   * bron bor, bu OY bo'sh     -> "bu oyda bron yo'q",
          //   * bu oyda bor, oldinda yo'q -> tinch "yaqin to'y yo'q".
          (toyRepo.monthBookings.isEmpty
              ? (toyRepo.hasAnyKnownBookings ? _monthEmptyBlock(p) : _emptyBlock(p))
              : _noUpcomingBlock(p))
        else ...[
          for (var i = 0; i < list.length; i++) ...[
            _upcomingRow(p, list[i]),
            if (i < list.length - 1) const SizedBox(height: 8),
          ],
          if (full.length > 6) ...[
            const SizedBox(height: 12),
            GlassBtn(
              label: _upcomingAll ? ty('showLess') : ty('showAll', {'n': '${full.length}'}),
              h: 44,
              fs: 14,
              icon: _upcomingAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              onTap: () => setState(() => _upcomingAll = !_upcomingAll),
            ),
          ],
        ],
      ],
    );
  }

  /// Tinch bo'sh holat kartasi (bir qatorli matn, markazda).
  Widget _quietCard(Pal p, String text) => GlassCard(
        r: Tb.rCard,
        pad: const EdgeInsets.symmetric(vertical: 26, horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: Tx(text, size: 14, color: p.t4, align: TextAlign.center, lh: 20),
        ),
      );

  Widget _noUpcomingBlock(Pal p) => _quietCard(p, ty('noUpcoming'));

  /// "Bu oyda bron yo'q" (F9): hisobda bron BOR, faqat qaralayotgan oy bo'sh —
  /// "Hali bron yo'q" degan yolg'on birinchi-ishga-tushirish matni chiqmasin.
  Widget _monthEmptyBlock(Pal p) => _quietCard(p, ty('emptyMonth'));

  Widget _emptyBlock(Pal p) {
    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: p.glass2,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.favorite_border_rounded, size: 26, color: p.t2),
            ),
            const SizedBox(height: 16),
            Tx(ty('emptyTitle'), size: 15, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(ty('emptySub'), size: 13, color: p.t4, align: TextAlign.center),
            // F9: haqiqiy birinchi ishga tushirishda qisqa yo'l-yo'riq — avval
            // to'yxona va narx toifalari, keyin bron (daftardan ko'chib kelayotgan
            // ega qayerdan boshlashni bilsin).
            if (!toyRepo.hasHalls) ...[
              const SizedBox(height: 10),
              Tx(ty('emptyOnboard'), size: 13, color: p.t4, align: TextAlign.center, lh: 18),
            ],
          ],
        ),
      ),
    );
  }

  /// Sana rozetkasi (44px r12 glass2): kun 16/600 num + oy 10 t4.
  Widget _dateBadge(Pal p, DateTime d) => Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: p.glass2,
          border: Border.all(color: p.glassBd),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Tx('${d.day}', size: 16, w: FontWeight.w600, color: p.ink, tab: true),
            Tx(tyMonth(d.month), size: 10, color: p.t4, maxLines: 1, ellipsis: true, font: TbFont.body),
          ],
        ),
      );

  /// showPaid — bekor qilinganlar ro'yxati uchun: o'ngda QOLDIQ emas, EGADA
  /// QOLGAN pul ko'rsatiladi. Bekor qilingan bronda `left` = total − paid katta
  /// musbat son bo'lib qoladi va coral rangda "mijoz qarzdor" degan XATO ma'no
  /// berardi — aslida u yerda hech kim hech kimga qarzdor emas.
  Widget _upcomingRow(Pal p, Booking b, {bool showPaid = false}) {
    final showVenue = toyRepo.selectedHallId == null && b.hallName.isNotEmpty;
    return Tap(
      onTap: () => setState(() => _detailId = b.id),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            _dateBadge(p, b.eventDate),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(b.clientName, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(
                    showVenue
                        ? '${b.hallName} · ${tySlot(b.slot)}${_guestsSuffix(b)}'
                        : '${tySlot(b.slot)}${_guestsSuffix(b)}',
                    size: 13, color: p.t2, maxLines: 1, ellipsis: true,
                  ),
                  if (!showPaid && b.priceMissing) ...[
                    const SizedBox(height: 4),
                    _noPriceTag(p),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Pul kesilmaydi (F14) — FittedBox (ijara naqshi)
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Tx(
                  showPaid ? toyMoney(b.paid) : toyMoney(b.left),
                  size: 15,
                  w: FontWeight.w600,
                  color: showPaid ? p.mint : _leftColor(b.left, p),
                  tab: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= BEKOR QILINGANLAR (faqat o'qish) =================

  /// Oylik xulosadagi "Bekor qilingan bronlardan: X" qatoridan ochiladi.
  /// Manba — `monthBookings` (repo bekor qilinganlarni SAQLAYDI; faqat kalendar
  /// aksessorlari — at()/bookedSlots()/upcoming() — ularni filtrlaydi, va bu
  /// to'g'ri: bekor qilingan slot qayta sotilishi kerak). Shu sabab bu ekran
  /// ma'lumot qatlamiga umuman tegmaydi.
  Widget _cancelledView(Pal p) {
    final list = toyRepo.monthBookings.where((b) => b.cancelled && b.paid > 0).toList();
    final kept = list.fold<int>(0, (s, b) => s + b.paid);
    return Column(
      children: [
        ScreenHeader(
          title: ty('cancelledTitle'),
          subtitle: toyMoney(kept),
          onBack: () => setState(() => _cancelledOpen = false),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bo'sh holat yuz bermasligi kerak (qator faqat > 0 da chiziladi),
                // lekin himoyalangan: ro'yxat bo'sh bo'lsa ham ekran o'lik qolmaydi.
                if (list.isEmpty)
                  _quietCard(p, ty('noPayments'))
                else
                  for (var i = 0; i < list.length; i++) ...[
                    _upcomingRow(p, list[i], showPaid: true),
                    if (i < list.length - 1) const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= PASTKI TUGMA =================

  /// Suzuvchi gradient CTA "+ Yangi bron". Chetlardagi bo'shliq bosishni
  /// ro'yxatga o'tkazadi (Padding hit-test'ni yutmaydi) — gavdaning pastida
  /// 120px bo'sh joy bor.
  Widget _bottomBar(Pal p) {
    if (_anyLayer) return const SizedBox.shrink();
    // 029: dumaloq "Bron" tugmasi pastki o'ng burchakda; kun tanlanmaguncha
    // O'CHIQ — ega avval kalendardan kunni bosadi, keyin bron ochiladi.
    final day = _selDay;
    final on = day != null;
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 20, 24),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: on ? 1 : .45,
          child: Tap(
            onTap: on ? () => _openNewBooking(day, _firstFreeSlot(day)) : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: on ? Tb.brandDiag : null,
                color: on ? null : p.glass2,
                border: on ? null : Border.all(color: p.glassBd),
                shape: BoxShape.circle,
                boxShadow: on
                    ? [BoxShadow(color: p.violet.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 22, color: on ? Colors.white : p.t4),
                  Tx(ty('bookFab'), size: 11, w: FontWeight.w700, color: on ? Colors.white : p.t4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tanlangan kunning birinchi BO'SH sloti (hammasi band bo'lsa — kechki;
  /// forma baribir slotni ko'rsatadi va ega o'zgartira oladi).
  String _firstFreeSlot(DateTime day) {
    final booked = toyRepo.bookedSlots(day);
    for (final s in kToySlots) {
      if (!booked.contains(s)) return s;
    }
    return 'kechki';
  }

  // ================= BRON TAFSILOTI =================

  /// hallId (U8) — kun panelidagi "bo'sh zal" chipidan AYNAN o'sha zal bilan
  /// ochish; berilmasa tanlangan (yoki yagona) to'yxona.
  void _openNewBooking(DateTime date, String slot, {String? hallId}) {
    final hid = hallId ??
        toyRepo.selectedHallId ??
        (toyRepo.halls.length == 1 ? toyRepo.halls.first.id : null);
    final tiers = toyRepo.tiersOf(hid);
    final hall = toyRepo.hallById(hid);
    setState(() {
      _formStep = 0;
      _svcCatFilter = null;
      _svcExpanded.clear();
      _form = _FormData(
        date: date,
        slot: slot,
        hallId: hid,
        guests: '200', // 027: o'rtacha to'y — ega faqat farqini tuzatadi
        menuId: tiers.isNotEmpty ? tiers.first.id : null,
        price: tiers.isNotEmpty
            ? toyFx(tiers.first.pricePerGuest)
            : (hall != null && hall.pricePerGuest > 0 ? toyFx(hall.pricePerGuest) : ''),
        // 024: rejim va podklyuch narxi to'yxona defaultidan
        priceMode: hall?.priceMode ?? 'guest',
        totalPrice: hall != null && hall.totalPrice > 0 ? toyFx(hall.totalPrice) : '',
      );
    });
    // U1: har ochilishda shu kun QAYTA so'raladi (kesh eskirgan bo'lishi
    // mumkin — masalan hozirgina yaratilgan/bekor qilingan bron).
    _dayFetched.remove(toyYmd(date));
    _ensureDay(date);
  }

  void _openEditBooking(Booking b) {
    setState(() {
      _formStep = 0;
      _form = _FormData(
        id: b.id,
        date: b.eventDate,
        slot: b.slot,
        hallId: b.hallId,
        menuId: b.menuId,
        // Tahrirda narx SNAPSHOT'dan keladi — toifa narxi keyin o'zgargan bo'lishi mumkin
        priceManual: true,
        name: b.clientName,
        phone: _phoneShow(b.clientPhone),
        guests: '${b.guests}',
        price: toyFx(b.pricePerGuest),
        note: b.note,
        priceMode: b.priceMode,
        totalPrice: b.totalPrice > 0 ? toyFx(b.totalPrice) : '',
      );
    });
    _dayFetched.remove(toyYmd(b.eventDate)); // U1: yangi ochilishda qayta so'raladi
    _ensureDay(b.eventDate);
  }

  /// Forma kuni uchun bandlik ma'lumoti (U1): avval yuklangan oydan urug'lanadi
  /// (darhol ko'rinadi), so'ng bitta-kun so'rovi bilan ANIQLANADI — u to'yxona
  /// filtrisiz, ya'ni formada boshqa zal tanlansa ham belgilar to'g'ri.
  /// Tarmoq yiqilsa jim: belgilar shunchalik, forma bloklanmaydi (server
  /// baribir 409 SLOT_TAKEN bilan himoya qiladi).
  Future<void> _ensureDay(DateTime day) async {
    final key = toyYmd(day);
    _dayRows.putIfAbsent(key, () => [
          for (final b in toyRepo.monthBookings)
            if (toySameDay(b.eventDate, day)) b,
        ]);
    if (!_dayFetched.add(key)) return; // bu kun allaqachon so'ralgan
    final rows = await toyRepo.bookingsOn(day);
    if (!mounted) return;
    if (rows == null) {
      _dayFetched.remove(key); // keyingi ochilishda qayta uriniladi
      return;
    }
    setState(() => _dayRows[key] = rows);
  }

  Widget _detail(Pal p) {
    final b = toyRepo.byId(_detailId);
    if (b == null) {
      // Bron o'chirilgan/yo'qolgan — qatlamni yopamiz
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _detailId != null && toyRepo.byId(_detailId) == null) {
          _closeDetail(); // mini-formalar ham tozalansin (2026-08-10 review)
        }
      });
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        ScreenHeader(
          title: toyDateLong(b.eventDate),
          // To'yxonasi yo'q band (bitta obyektli ega yoki o'chirilgan to'yxona)
          subtitle: '${tySlot(b.slot)} · ${b.hallName.isEmpty ? ty('noHallLabel') : b.hallName}',
          onBack: _closeDetail,
          trailing: [_slotIconBox(b.slot, p)],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _clientBlock(p, b),
                const SizedBox(height: 24),
                _moneyBlock(p, b),
                const SizedBox(height: 24),
                _paymentsBlock(p, b),
                const SizedBox(height: 24),
                _statusBlock(p, b),
                const SizedBox(height: 24),
                _detailActions(p, b),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Mijoz kartasi: RingAvatar · ism 17/600 + telefon (bosilsa nusxalanadi) ·
  /// o'ngda holat nishoni; izoh — glass2 quti.
  Widget _clientBlock(Pal p, Booking b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ty('clientCap')),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          pad: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RingAvatar(initials: _initials(b.clientName), size: 48, seed: b.clientName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tx(b.clientName, size: 17, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 2, ellipsis: true),
                        const SizedBox(height: 3),
                        if (b.clientPhone.isEmpty)
                          Tx(ty('noPhone'), size: 13, color: p.t4)
                        else
                          Tap(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: b.clientPhone));
                              _toastMsg(ty('phoneCopied'));
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Tx(b.clientPhone, size: 13, color: p.t2, tab: true, maxLines: 1, ellipsis: true),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.copy_rounded, size: 14, color: p.t4),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(b.status, h: 24),
                ],
              ),
              // 024: mijoz Trustbook'da / avans kutilmoqda (hold)
              if (b.inTrustbook || b.onHold) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (b.inTrustbook) PillBadge.mint(ty('inTrustbook'), h: 22, icon: Icons.verified_rounded),
                    if (b.onHold)
                      PillBadge.amber(ty('holdUntil', {'t': _holdLeft(b.holdUntil!)}), h: 22, icon: Icons.timer_outlined),
                  ],
                ),
              ],
              if (b.cancelled && b.cancelReason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Tx(ty('cancelReasonLine', {'r': b.cancelReason}), size: 13, color: p.t3, lh: 18),
              ],
              if (b.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.glass2, borderRadius: BorderRadius.circular(Tb.rIcon)),
                  child: Tx(b.note, size: 13, color: p.t1, lh: 18),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _moneyBlock(Pal p, Booking b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Cap(ty('moneyCap')),
            const Spacer(),
            // U5: narx ham, xizmat ham kiritilmagan — yumshoq eslatma belgisi
            if (b.priceMissing) _noPriceTag(p),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          pad: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ovqat qatori — narx SNAPSHOT (toifa keyin o'zgarsa ham o'zgarmaydi)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant_outlined, size: 18, color: p.t2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tx(
                      b.isTotalMode
                          ? (b.guests > 0 ? ty('totalModeLine', {'guests': '${b.guests}'}) : ty('priceModeTotal'))
                          : b.menuTitle.isEmpty
                          ? ty('guestsMath', {'guests': '${b.guests}', 'price': toyFx(b.pricePerGuest)})
                          : ty('tierMath', {
                              'title': b.menuTitle,
                              'guests': '${b.guests}',
                              'price': toyFx(b.pricePerGuest),
                            }),
                      size: 14, color: p.t1, lh: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tx(toyMoney(b.food), size: 14, w: FontWeight.w600, color: p.ink, tab: true),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: p.hairline),
              const SizedBox(height: 14),
              Cap(ty('extrasCap')),
              const SizedBox(height: 8),
              if (b.items.isEmpty)
                Tx(ty('noExtras'), size: 13, color: p.t4)
              else
                for (final it in b.items) _itemRow(p, it),
              const SizedBox(height: 10),
              if (_svcOpen)
                _svcForm(p, b)
              else
                GlassBtn(label: ty('addService'), h: 40, fs: 14, onTap: () => setState(() => _svcOpen = true)),
              const SizedBox(height: 14),
              Container(height: 1, color: p.hairline),
              const SizedBox(height: 14),
              if (b.cancelled) ...[
                // F7: bekor qilingan bronda CORAL "Qoldiq" YO'Q — bu yerda hech
                // kim hech kimga qarzdor emas. Jami xira (bu daromad emas),
                // olingan pul esa "Olingan to'lov (bekor)" nomi bilan qoladi
                // (avans egada qolishi O'zbekistonda odatiy holat).
                _totalRow(p, ty('totalLabel'), toyMoney(b.total), p.t4, big: true),
                const SizedBox(height: 8),
                _totalRow(p, ty('cancelledKept'), toyMoney(b.paid), p.mint),
                // 024: jarima (ushlab qolingan) va qaytarilishi kerak bo'lgan qoldiq
                if (b.cancelPenalty > 0) ...[
                  const SizedBox(height: 8),
                  _totalRow(p, ty('penaltyLabel'), toyMoney(b.cancelPenalty), p.coral),
                ],
                if (b.refundDue > 0) ...[
                  const SizedBox(height: 8),
                  _totalRow(p, ty('refundDueLabel'), toyMoney(b.refundDue), p.amber, big: true),
                ],
              ] else ...[
                _totalRow(p, ty('totalLabel'), toyMoney(b.total), p.ink, big: true),
                if (b.bonus > 0) ...[
                  const SizedBox(height: 8),
                  _totalRow(p, ty('bonusLabel'), toyMoney(b.bonus), p.t3),
                ],
                const SizedBox(height: 8),
                _totalRow(p, ty('paidLabel'), toyMoney(b.paid), p.mint),
                if (b.refunded > 0) ...[
                  const SizedBox(height: 8),
                  _totalRow(p, ty('refundedLabel'), toyMoney(b.refunded), p.t3),
                ],
                const SizedBox(height: 8),
                _totalRow(p, ty('leftLabel'), toyMoney(b.left), _leftColor(b.left, p), big: true),
                // 024: minimal avans (to'yxona sozlamasi) hali to'lanmagan bo'lsa
                if (_depositShort(b) > 0) ...[
                  const SizedBox(height: 6),
                  Tx(ty('depositShort', {'sum': toyMoney(_depositShort(b))}), size: 12, color: p.amber),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(Pal p, String label, String value, Color c, {bool big = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Tx(label, size: big ? 15 : 14, w: big ? FontWeight.w600 : FontWeight.w400, color: big ? p.t1 : p.t2),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Tx(value, size: big ? 20 : 15, w: FontWeight.w600, color: c, tab: true),
          ),
        ),
      ],
    );
  }

  Widget _itemRow(Pal p, BookingItem it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // 025: SNAPSHOT muqova — katalogdagi item o'chsa ham qoladi
          _svcThumb(catOf(it.category), it.image, 34),
          const SizedBox(width: 10),
          // 'nom × soni' — summa esa amount × qty (U3; BookingItem.total)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Tx(it.qty > 1 ? '${it.title} × ${it.qty}' : it.title,
                      size: 14, color: it.isBonus ? p.t3 : p.ink, maxLines: 1, ellipsis: true),
                ),
                // 024: bonus belgisi — bosilsa bonus yechiladi/qo'yiladi
                const SizedBox(width: 6),
                Tap(
                  onTap: _busy ? null : () => _toggleBonus(it),
                  child: it.isBonus
                      ? PillBadge.mint(ty('bonusBadge'), h: 20, icon: Icons.card_giftcard_rounded)
                      : Icon(Icons.card_giftcard_outlined, size: 16, color: p.t5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Pul kesilmaydi (F14)
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Tx(toyMoney(it.total), size: 14, w: FontWeight.w600,
                  color: it.isBonus ? p.t4 : p.ink, tab: true, strike: it.isBonus),
            ),
          ),
          _xBtn(p, () => _askDeleteItem(it)),
        ],
      ),
    );
  }

  Future<void> _toggleBonus(BookingItem it) async {
    setState(() => _busy = true);
    final ok = await toyRepo.setItemBonus(it.id, !it.isBonus);
    if (!mounted) return;
    setState(() => _busy = false);
    ok ? _toastMsg(ty('saved')) : _toastErr();
  }

  /// O'chirish (×) tugmasi — bosish maydoni kamida 40×40 (F14): to'y kuni
  /// shoshib turgan ega 26px nishonni ko'zlab o'tirmaydi.
  Widget _xBtn(Pal p, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: Icon(Icons.close_rounded, size: 18, color: p.t4)),
      ),
    );
  }

  // ---- Xizmat qo'shish formasi (tez chiplar bilan) ----
  Widget _svcForm(Pal p, Booking b) {
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.all(12),
      color: p.glass2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 024: avval EGA KATALOGI (narxi bilan), keyin tez chiplar
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sv in toyRepo.servicesFor(b.hallId))
                _smallChip(
                  p,
                  sv.price > 0 ? '${sv.title} · ${toyFx(sv.price)}' : sv.title,
                  _svcServiceId == sv.id,
                  () => setState(() {
                    _svcServiceId = sv.id;
                    _svcTitle = sv.title;
                    _svcAmount = sv.price > 0 ? toyFx(sv.price) : '';
                  }),
                ),
              for (final k in kToyQuickServiceKeys)
                _smallChip(p, ty(k), _svcServiceId == null && _svcTitle == ty(k), () => setState(() {
                      _svcServiceId = null;
                      _svcTitle = ty(k);
                    })),
            ],
          ),
          const SizedBox(height: 12),
          _field(p, ty('svcTitleLabel'), _svcTitle, (v) => setState(() {
                _svcTitle = v;
                if (_svcServiceId != null && v != toyRepo.serviceById(_svcServiceId)?.title) _svcServiceId = null;
              }),
              hint: ty('svcTitlePh')),
          const SizedBox(height: 12),
          // 024: bonus — bepul beriladi, narxi ko'rinadi, jamiga kirmaydi
          Tap(
            onTap: () => setState(() => _svcBonus = !_svcBonus),
            child: Row(
              children: [
                Icon(_svcBonus ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 20, color: _svcBonus ? p.mint : p.t4),
                const SizedBox(width: 8),
                Expanded(child: Tx(ty('bonusToggle'), size: 14, color: p.t1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Summa + soni (U3): "6 ta salyut", "3 ta artist" — bir dona narxi
          // yoziladi, soni stepper bilan; ro'yxatda 'nom × soni' va jami chiqadi.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(p, ty('svcAmountLabel'), _svcAmount,
                    (v) => setState(() => _svcAmount = v), number: true),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cap(ty('svcQtyLabel')),
                  const SizedBox(height: 10),
                  _qtyStepper(p),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassBtn(
                  label: ty('no'),
                  h: 44,
                  fs: 14,
                  onTap: () => setState(() {
                    _svcOpen = false;
                    _svcTitle = '';
                    _svcAmount = '';
                    _svcQty = 1;
                    _svcBonus = false;
                    _svcServiceId = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GradientBtn(
                  label: ty('addBtn'),
                  h: 44,
                  fs: 14,
                  glow: false,
                  loading: _busy,
                  onTap: () => _addService(b),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Soni tanlagichi (U3): 1..kToyMaxSvcQty, chegarada tugma o'chadi.
  Widget _qtyStepper(Pal p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassIconBtn(
          icon: Icons.remove_rounded,
          size: 40,
          iconSize: 20,
          color: _svcQty > 1 ? p.ink : p.t5,
          onTap: _svcQty > 1 ? () => setState(() => _svcQty--) : null,
        ),
        SizedBox(
          width: 36,
          child: Center(child: Tx('$_svcQty', size: 15, w: FontWeight.w700, color: p.ink, tab: true)),
        ),
        GlassIconBtn(
          icon: Icons.add_rounded,
          size: 40,
          iconSize: 20,
          color: _svcQty < kToyMaxSvcQty ? p.ink : p.t5,
          onTap: _svcQty < kToyMaxSvcQty ? () => setState(() => _svcQty++) : null,
        ),
      ],
    );
  }

  Future<void> _addService(Booking b) async {
    final title = _svcTitle.trim();
    final amount = _digits(_svcAmount);
    // F16: nom va summa xatosi ALOHIDA aytiladi — ilgari ikkalasiga ham
    // "Narxni kiriting" chiqib, ega nima yetishmayotganini topolmasdi.
    if (title.isEmpty) {
      _toastMsg(ty('needSvcTitle'));
      return;
    }
    if (amount <= 0 && !_svcBonus) {
      _toastMsg(ty('needTierPrice'));
      return;
    }
    setState(() => _busy = true);
    final ok = await toyRepo.addItem(b.id, title, amount,
        qty: _svcQty, serviceId: _svcServiceId, bonus: _svcBonus);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _svcOpen = false;
        _svcTitle = '';
        _svcAmount = '';
        _svcQty = 1;
        _svcBonus = false;
        _svcServiceId = null;
      }
    });
    if (ok) {
      _toastMsg(ty('saved'));
    } else {
      _toastErr();
    }
  }

  void _askDeleteItem(BookingItem it) {
    setState(() => _confirm = {
          'title': ty('confirmDeleteTitle'),
          'body': '${it.title} · ${toyMoney(it.total)}',
          'danger': true,
          'run': () async {
            final ok = await toyRepo.deleteItem(it.id);
            if (!mounted) return;
            ok ? _toastMsg(ty('deleted')) : _toastErr();
          },
        });
  }

  // ---- To'lovlar ----
  Widget _paymentsBlock(Pal p, Booking b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ty('paymentsCap')),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          child: b.payments.isEmpty
              ? SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Tx(ty('noPayments'), size: 14, color: p.t4),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < b.payments.length; i++)
                      _paymentRow(p, b.payments[i], last: i == b.payments.length - 1),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        if (_payOpen)
          _payForm(p, b)
        else
          GlassBtn(
            label: ty('addPayment'),
            h: 44,
            onTap: () => setState(() {
              _payOpen = true;
              _payDate = toyDay(DateTime.now()); // U2: standart — bugun
            }),
          ),
      ],
    );
  }

  Widget _paymentRow(Pal p, BookingPayment pay, {required bool last}) {
    final d = pay.date;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hairline))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.mint.withValues(alpha: .15)),
            child: Icon(Icons.payments_outlined, size: 18, color: p.mint),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(tyPayKind(pay.kind), size: 15, w: FontWeight.w600, color: p.ink),
                if (d != null || pay.note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Tx(
                    pay.note.isEmpty
                        ? (d == null ? '' : toyDateShort(d))
                        : (d == null ? pay.note : '${toyDateShort(d)} · ${pay.note}'),
                    size: 13, color: p.t2, maxLines: 1, ellipsis: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Pul kesilmaydi (F14)
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Tx('+${toyMoney(pay.amount)}', size: 15, w: FontWeight.w600, color: p.mint, tab: true),
            ),
          ),
          const SizedBox(width: 4),
          _xBtn(p, () => _askDeletePayment(pay)),
        ],
      ),
    );
  }

  Widget _payForm(Pal p, Booking b) {
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.all(12),
      color: p.glass2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final k in kToyPayKinds) ...[
                _smallChip(p, tyPayKind(k), _payKind == k, () => setState(() => _payKind = k)),
                if (k != kToyPayKinds.last) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _field(p, ty('payAmountLabel'), _payAmount, (v) => setState(() => _payAmount = v),
              number: true, icon: Icons.payments_outlined),
          const SizedBox(height: 12),
          // U2: to'lov sanasi — egalar kechagi naqdni bugun yozadi (ijara
          // to'lov modali naqshi). Standart — bugun.
          Cap(ty('payDateLabel')),
          const SizedBox(height: 10),
          _dateField(p, toyDateLong(_payDate), _pickPayDate),
          const SizedBox(height: 12),
          _field(p, ty('payNoteLabel'), _payNote, (v) => setState(() => _payNote = v), icon: Icons.edit_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassBtn(
                  label: ty('no'),
                  h: 44,
                  fs: 14,
                  onTap: () => setState(() {
                    _payOpen = false;
                    _payAmount = '';
                    _payNote = '';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SolidBtn.mint(ty('addBtn'), () => _addPayment(b),
                    h: 44, fs: 14, icon: Icons.check_rounded, loading: _busy),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickPayDate() async {
    final now = DateTime.now();
    final picked = await _showAppDatePicker(
      initial: _payDate,
      first: DateTime(now.year - 2, 1, 1),
      last: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _payDate = picked);
  }

  Future<void> _addPayment(Booking b) async {
    final amount = _digits(_payAmount);
    if (amount <= 0) {
      _toastMsg(ty('needTierPrice'));
      return;
    }
    setState(() => _busy = true);
    final ok = await toyRepo.addPayment(b.id, amount,
        kind: _payKind, note: _payNote.trim(), paidAt: _payDate);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _payOpen = false;
        _payAmount = '';
        _payNote = '';
        _payDate = toyDay(DateTime.now());
      }
    });
    if (ok) {
      _toastMsg(ty('saved'));
    } else {
      _toastErr();
    }
  }

  void _askDeletePayment(BookingPayment pay) {
    setState(() => _confirm = {
          'title': ty('confirmDeleteTitle'),
          'body': '${tyPayKind(pay.kind)} · ${toyMoney(pay.amount)}',
          'danger': true,
          'run': () async {
            final ok = await toyRepo.deletePayment(pay.id);
            if (!mounted) return;
            ok ? _toastMsg(ty('deleted')) : _toastErr();
          },
        });
  }

  // ---- Holat ----
  /// Holat chiplari: tanlangani holat rangida (band amber / tasdiq mint /
  /// yakun muted / bekor coral).
  Widget _statusBlock(Pal p, Booking b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ty('statusCap')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kToyStatuses)
              if (s != 'bekor' || b.status == 'bekor')
                PillChip(
                  label: tyStatus(s),
                  selected: b.status == s,
                  selectedBg: _statusColor(s, p).withValues(alpha: .18),
                  selectedFg: _statusColor(s, p),
                  onTap: () => _setStatus(b, s),
                ),
          ],
        ),
      ],
    );
  }

  Future<void> _setStatus(Booking b, String s) async {
    if (b.status == s) return;
    final ok = await toyRepo.setStatus(b.id, s);
    if (!mounted) return;
    ok ? _toastMsg(ty('saved')) : _toastErr();
  }

  Widget _detailActions(Pal p, Booking b) {
    return Column(
      children: [
        GlassBtn(label: ty('edit'), icon: Icons.edit_outlined, h: 52, onTap: () => _openEditBooking(b)),
        const SizedBox(height: 10),
        // 024: chek/PDF — mijozga ulashish (stol, servislar, avans, qoldiq, shartlar)
        GlassBtn(label: ty('receiptBtn'), icon: Icons.receipt_long_outlined, h: 52, onTap: () => _shareReceipt(b)),
        const SizedBox(height: 10),
        b.cancelled
            ? SolidBtn.coral(ty('deleteBooking'), () => _askDeleteBooking(b), icon: Icons.delete_outline_rounded)
            : TextBtn(label: ty('cancelBooking'), color: p.coral, onTap: () => _askCancelBooking(b)),
      ],
    );
  }

  /// 024: bekor varag'i — jarima (siyosat bo'yicha, ega o'zgartira oladi),
  /// qaytariladigan summa, sabab, "pulni darhol qaytardim".
  void _askCancelBooking(Booking b) {
    final hall = toyRepo.hallById(b.hallId);
    final daysLeft = toyDay(b.eventDate).difference(toyDay(DateTime.now())).inDays;
    final localPen = toyCancelPenalty(hall?.cancelPolicy ?? const [], b.paid, daysLeft);
    setState(() => _cancelSheet = {
          'id': b.id,
          'paid': b.paid,
          'daysLeft': daysLeft,
          'penalty': localPen > 0 ? toyFx(localPen) : '',
          'reason': '',
          'refundNow': false,
          'loading': true,
        });
    // Server hisobi (to'yxona siyosati serverda ham) — kelsa lokalni almashtiradi
    toyRepo.cancelPreview(b.id).then((pv) {
      if (!mounted || _cancelSheet == null || _cancelSheet!['id'] != b.id) return;
      setState(() {
        _cancelSheet!['loading'] = false;
        if (pv != null) {
          _cancelSheet!['paid'] = pv.paid;
          _cancelSheet!['daysLeft'] = pv.daysLeft;
          _cancelSheet!['penalty'] = pv.penalty > 0 ? toyFx(pv.penalty) : '';
        }
      });
    });
  }

  Widget _cancelModal(Pal p) {
    final c = _cancelSheet!;
    final b = toyRepo.byId('${c['id']}');
    void close() => setState(() => _cancelSheet = null);
    if (b == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _cancelSheet != null) close();
      });
      return const SizedBox.shrink();
    }
    final paid = (c['paid'] as int?) ?? 0;
    final penalty = _digits('${c['penalty']}').clamp(0, paid).toInt();
    final refund = paid - penalty;
    final daysLeft = (c['daysLeft'] as int?) ?? 0;
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, ty('confirmCancelTitle'), close),
          const SizedBox(height: 8),
          Tx(ty('confirmCancelBody', {
            'name': b.clientName,
            'date': toyDateLong(b.eventDate),
            'slot': tySlot(b.slot),
          }), size: 14, color: p.t2, lh: 20),
          const SizedBox(height: 16),
          GlassCard(
            r: Tb.rRow,
            pad: const EdgeInsets.all(14),
            color: p.glass2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _totalRow(p, ty('daysLeftLabel'), '$daysLeft', p.t1),
                const SizedBox(height: 6),
                _totalRow(p, ty('cancelPaidLabel'), toyMoney(paid), p.mint),
                const SizedBox(height: 6),
                _totalRow(p, ty('penaltyLabel'), toyMoney(penalty), p.coral),
                const SizedBox(height: 6),
                _totalRow(p, ty('refundDueLabel'), toyMoney(refund), p.amber, big: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (paid > 0) ...[
            _field(p, ty('penaltyEditLabel'), '${c['penalty']}', (v) => setState(() => c['penalty'] = v),
                number: true, icon: Icons.gavel_rounded),
            const SizedBox(height: 12),
            Tap(
              onTap: () => setState(() => c['refundNow'] = c['refundNow'] != true),
              child: Row(
                children: [
                  Icon(c['refundNow'] == true ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 20, color: c['refundNow'] == true ? p.mint : p.t4),
                  const SizedBox(width: 8),
                  Expanded(child: Tx(ty('refundNowToggle', {'sum': toyMoney(refund)}), size: 14, color: p.t1)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _field(p, ty('cancelReasonLabel'), '${c['reason']}', (v) => setState(() => c['reason'] = v),
              hint: ty('cancelReasonPh'), icon: Icons.edit_outlined),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: GlassBtn(label: ty('no'), h: 52, onTap: close)),
              const SizedBox(width: 12),
              Expanded(
                child: SolidBtn.coral(ty('cancelBooking'), _busy ? null : () => _runCancel(b, c),
                    h: 52, loading: _busy),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runCancel(Booking b, Map<String, dynamic> c) async {
    setState(() => _busy = true);
    final paid = (c['paid'] as int?) ?? 0;
    final ok = await toyRepo.cancelBooking(
      b.id,
      reason: '${c['reason']}'.trim(),
      penalty: paid > 0 ? _digits('${c['penalty']}').clamp(0, paid).toInt() : null,
      refundNow: c['refundNow'] == true,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _cancelSheet = null;
    });
    ok ? _toastMsg(ty('cancelled')) : _toastErr();
  }

  /// 024: minimal avans (to'yxona deposit_pct) hali qoplanmagan qismi.
  int _depositShort(Booking b) {
    if (b.cancelled || b.status == 'yakun') return 0;
    final pct = toyRepo.hallById(b.hallId)?.depositPct ?? 0;
    final min = toyDepositMin(b.total, pct);
    return min > b.paid ? min - b.paid : 0;
  }

  /// "2 kun 5 soat" / "3 soat" — hold qolgan vaqti.
  String _holdLeft(DateTime until) {
    final d = until.difference(DateTime.now());
    if (d.inHours >= 24) return ty('holdDaysHours', {'d': '${d.inDays}', 'h': '${d.inHours % 24}'});
    if (d.inHours >= 1) return ty('holdHours', {'h': '${d.inHours}'});
    return ty('holdMinutes', {'m': '${d.inMinutes.clamp(1, 59)}'});
  }

  Future<void> _shareReceipt(Booking b) async {
    setState(() => _busy = true);
    try {
      await shareBookingReceipt(b, hall: toyRepo.hallById(b.hallId), ownerName: '${store.S['meName'] ?? ''}');
    } catch (_) {
      if (mounted) _toastMsg(ty('receiptFailed'));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _askDeleteBooking(Booking b) {
    setState(() => _confirm = {
          'title': ty('confirmDeleteTitle'),
          'body': ty('confirmDeleteBody'),
          'danger': true,
          'run': () async {
            final ok = await toyRepo.deleteBooking(b.id);
            if (!mounted) return;
            if (ok) {
              // _closeDetail: ichki xizmat/to'lov mini-formalari ham tozalanadi —
              // aks holda keyingi ochilgan bronda oldingi matn qolib ketardi
              // (2026-08-10 review).
              _closeDetail();
              _toastMsg(ty('deleted'));
            } else {
              _toastErr();
            }
          },
        });
  }

  // ================= YANGI / TAHRIR FORMASI =================
  //
  // 2 BOSQICH (2026-09-09): 1) mijoz · vaqt · summa, 2) qo'shimcha servislar.
  // Bitta uzun forma servislar ko'payganda (20+ item) mijoz ma'lumotlarini
  // ekrandan surib yuborardi va ega summa kelishmay turib servis tanlardi.
  // Tahrirda (id != null) katalog yo'q — bitta bosqich, tugma "Saqlash".

  Widget _formView(Pal p) {
    final f = _form!;
    final catalog = f.id == null ? toyRepo.servicesFor(f.hallId) : const <HallService>[];
    if (_formStep == 1 && catalog.isNotEmpty) return _formServicesStep(p, f, catalog);
    return _formMainStep(p, f, hasStep2: catalog.isNotEmpty);
  }

  /// Formaning jonli hisobi (ikkala bosqich bir manbadan o'qiydi).
  ({int guests, int price, int food, int extras, int total}) _formSums(_FormData f) {
    final guests = _digits(f.guests);
    final price = _digits(f.price);
    final food = f.priceMode == 'total' ? _digits(f.totalPrice) : guests * price;
    var extras = 0;
    for (final e in f.services.entries) {
      if (e.value) continue; // bonus jamiga kirmaydi
      extras += toyRepo.serviceById(e.key)?.price ?? 0;
    }
    return (guests: guests, price: price, food: food, extras: extras, total: food + extras);
  }

  Widget _stepPill(Pal p, int step) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.glass,
          border: Border.all(color: p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: Tx('$step / 2', size: 12, w: FontWeight.w700, color: p.t2, tab: true, font: TbFont.body),
      );

  // ---------- 1-bosqich: mijoz · vaqt · summa ----------

  Widget _formMainStep(Pal p, _FormData f, {required bool hasStep2}) {
    final isNew = f.id == null;
    final halls = toyRepo.halls;
    final tiers = toyRepo.tiersOf(f.hallId);
    final totalMode = f.priceMode == 'total';
    final s = _formSums(f);
    final tier = _tierById(tiers, f.menuId);
    final hall = toyRepo.hallById(f.hallId);
    final depMin = toyDepositMin(s.total, hall?.depositPct ?? 0);
    final over = totalMode ? null : _capacityOver(f, s.guests);
    final phoneFull = _phoneNat(f.phone).length == 9;

    return Column(
      children: [
        // Sarlavha — SANA (bosilsa tanlagich). "Yangi bron" yozuvi pastga,
        // subtitle'ga tushdi: ega formada birinchi bo'lib QAYSI KUNga bron
        // qilayotganini ko'radi.
        ScreenHeader(
          title: toyDateLong(f.date),
          subtitle: '${tyWeekday(f.date.weekday)} · ${isNew ? ty('newTitle') : ty('editTitle')}',
          onBack: () => setState(() => _form = null),
          titleTrailing: Tap(
            onTap: () => _pickDate(f),
            child: Icon(Icons.edit_calendar_rounded, size: 20, color: p.amber),
          ),
          trailing: [if (hasStep2) _stepPill(p, 1)],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Mijoz: AVVAL telefon (maska) — bazadan ism avto-to'ladi ----
                _field(p, ty('phoneLabel'), f.phone, (v) => _onPhoneChanged(f, v),
                    phone: true, hint: '+998 90 123 45 67', icon: Icons.smartphone_rounded),
                if (f.hint != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: p.cyan),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Tx(ty('clientKnown', {'name': f.hint!.name, 'n': '${f.hint!.bookings}'}),
                            size: 12, color: p.cyan, maxLines: 1, ellipsis: true),
                      ),
                      if (f.hint!.inTrustbook) PillBadge.mint(ty('inTrustbook'), h: 18),
                    ],
                  ),
                ] else if (phoneFull && f.hintChecked) ...[
                  const SizedBox(height: 6),
                  Tx(ty('newClient'), size: 12, color: p.t4),
                ],
                const SizedBox(height: 16),
                // Ism: placeholder YO'Q — bazada bo'lsa to'ladi, bo'lmasa bo'sh.
                _field(p, ty('nameLabel'), f.name, (v) => setState(() {
                      f.name = v;
                      f.nameAuto = false; // qo'lda tahrir — autofill endi ustidan yozmaydi
                    }),
                    icon: Icons.person_outline_rounded),
                // ---- Vaqt: 3 karta yonma-yon (band slot qulf + mijoz nomi) ----
                const SizedBox(height: 20),
                Cap(ty('slotLabel')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < kToySlots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _slotCard(p, f, kToySlots[i])),
                    ],
                  ],
                ),
                // ---- To'yxona ----
                if (halls.length > 1) ...[
                  const SizedBox(height: 20),
                  Cap(ty('hallLabel')),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final h in halls)
                        _chip(p, h.name, f.hallId == h.id, () => _pickHallInForm(f, h)),
                    ],
                  ),
                ],
                // ---- Narx rejimi (024) + OSTIDA shu rejimning narxi ----
                const SizedBox(height: 20),
                Cap(ty('priceModeLabel')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final m in kToyPriceModes) ...[
                      Expanded(
                        child: PillChip(
                          label: tyPriceMode(m),
                          selected: f.priceMode == m,
                          leading: Icon(m == 'total' ? Icons.home_work_outlined : Icons.person_outline_rounded,
                              size: 16, color: f.priceMode == m ? p.bg : p.t2),
                          onTap: () => setState(() => f.priceMode = m),
                        ),
                      ),
                      if (m != kToyPriceModes.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                GlassCard(
                  r: Tb.rCard,
                  pad: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (totalMode)
                        // Butun to'yxona: bitta summa, mehmonlar soni SO'RALMAYDI
                        _field(p, ty('totalPriceLabel'), f.totalPrice,
                            (v) => setState(() => f.totalPrice = v), number: true)
                      else ...[
                        if (tiers.isNotEmpty) ...[
                          // 027: stol kartalari — tanlansa narx/kishi avto to'ladi
                          Cap(ty('tierLabel')),
                          const SizedBox(height: 10),
                          _tableCards(p, f, tiers),
                          const SizedBox(height: 14),
                        ] else if (f.hallId != null) ...[
                          Tx(ty('noTiersHint'), size: 13, color: p.t4),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _field(p, ty('guestsLabel'), f.guests,
                                  (v) => setState(() => f.guests = v), number: true, group: false),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _field(
                                p,
                                tiers.isEmpty ? ty('priceLabel') : ty('priceManualLabel'),
                                f.price,
                                (v) => setState(() {
                                  f.price = v;
                                  // Qo'lda o'zgartirilgan narx toifa narxidan USTUN turadi
                                  f.priceManual = tier == null || _digits(v) != tier.pricePerGuest;
                                }),
                                number: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(height: 1, color: p.glassBd),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: Cap(ty('agreedSum'))),
                          const SizedBox(width: 10),
                          Tx(toyMoney(s.food), size: 20, w: FontWeight.w600, color: p.mint, tab: true),
                        ],
                      ),
                      if (!totalMode && s.guests > 0 && s.price > 0) ...[
                        const SizedBox(height: 4),
                        Tx(ty('foodLine', {'guests': '${s.guests}', 'price': toyFx(s.price), 'total': toyFx(s.food)}),
                            size: 12, color: p.t4, tab: true),
                      ],
                    ],
                  ),
                ),
                // U4: sig'imdan oshsa OGOHLANTIRISH — bloklamaydi.
                if (over != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: p.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Tx(ty('overCapacity', {'n': '$over'}), size: 13, w: FontWeight.w600, color: p.amber),
                      ),
                    ],
                  ),
                ],
                // ---- Avans (faqat yangi bronda) ----
                if (isNew) ...[
                  const SizedBox(height: 20),
                  _field(p, ty('advanceLabel'), f.advance, (v) => setState(() => f.advance = v),
                      number: true, icon: Icons.payments_outlined),
                  if (depMin > 0) ...[
                    const SizedBox(height: 6),
                    Tx(
                      ty('depositMinLine', {'sum': toyMoney(depMin), 'pct': '${hall?.depositPct ?? 0}'}),
                      size: 12, color: _digits(f.advance) >= depMin ? p.mint : p.amber, lh: 16,
                    ),
                  ] else if (_digits(f.advance) > 0 && s.food > _digits(f.advance)) ...[
                    const SizedBox(height: 6),
                    Tx(ty('leftAfterAdvance', {'sum': toyMoney(s.food - _digits(f.advance))}),
                        size: 12, color: p.t4, lh: 16, tab: true),
                  ],
                  if (_digits(f.advance) <= 0) ...[
                    const SizedBox(height: 6),
                    Tx(ty('holdNote', {'h': '48'}), size: 12, color: p.t4, lh: 16),
                  ],
                ],
                // ---- Izoh: ko'p qatorli — pill EMAS, to'g'ri burchakli ----
                const SizedBox(height: 20),
                Cap(ty('noteLabel')),
                const SizedBox(height: 10),
                _noteBox(p, f),
                const SizedBox(height: 24),
                if (hasStep2)
                  GradientBtn(
                    label: ty('nextServices'),
                    icon: Icons.arrow_forward_rounded,
                    onTap: () {
                      if (!_validateMain(f)) return;
                      setState(() {
                        _formStep = 1;
                        _svcCatFilter = null;
                      });
                    },
                  )
                else
                  GradientBtn(label: ty('save'), icon: Icons.check_rounded, loading: _busy, onTap: () => _saveBooking(f)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Izoh maydoni: ko'p qatorli matn pill (rPill) ichida qiyshiq ko'rinardi —
  /// kichik radiusli to'g'ri burchakli quti.
  Widget _noteBox(Pal p, _FormData f) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: p.glass,
          border: Border.all(color: f.note.isNotEmpty ? p.violet.withValues(alpha: .6) : p.glassBd),
          borderRadius: BorderRadius.circular(10),
        ),
        child: StoreField(
          value: f.note,
          onChanged: (v) => setState(() => f.note = v),
          hint: ty('notePh'),
          maxLines: 4,
          minLines: 3,
          style: tbStyle(size: 15, color: p.ink, w: FontWeight.w500),
          hintColor: p.t5,
        ),
      );

  /// 1-bosqich tekshiruvi (Davom etish / Saqlash oldidan).
  bool _validateMain(_FormData f) {
    if (f.name.trim().isEmpty) {
      _toastMsg(ty('needName'));
      return false;
    }
    // Butun to'yxona rejimida mehmonlar soni so'ralmaydi (0 bo'lishi mumkin)
    if (f.priceMode != 'total' && _digits(f.guests) <= 0) {
      _toastMsg(ty('needGuests'));
      return false;
    }
    if (toyRepo.hasHalls && f.hallId == null) {
      _toastMsg(ty('needVenue'));
      return false;
    }
    return true;
  }

  // ---------- 2-bosqich: servislar ----------

  /// Katalogni kategoriya bo'yicha guruhlaydi: ITEMLI kategoriyalar avval
  /// (kToyServiceCats tartibida), bo'shlari umuman chizilmaydi.
  List<(ToyServiceCat, List<HallService>)> _svcGroups(List<HallService> catalog) => [
        for (final cat in kToyServiceCats)
          if (catalog.any((sv) => sv.category == cat.slug))
            (cat, catalog.where((sv) => sv.category == cat.slug).toList()),
      ];

  Widget _formServicesStep(Pal p, _FormData f, List<HallService> catalog) {
    final s = _formSums(f);
    final groups = _svcGroups(catalog);
    final filter = _svcCatFilter;
    final selected = [
      for (final sv in catalog)
        if (f.services.containsKey(sv.id)) sv,
    ];
    return Column(
      children: [
        ScreenHeader(
          title: ty('servicesTitle'),
          subtitle: '${toyDateLong(f.date)} · ${tySlot(f.slot)}',
          onBack: () => setState(() => _formStep = 0),
          trailing: [_stepPill(p, 2)],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 14, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mijoz xulosasi — kim uchun va qancha kelishilgani ko'z oldida
                GlassCard(
                  r: Tb.rCard,
                  pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.violet.withValues(alpha: .15), shape: BoxShape.circle),
                        child: Tx(_initials(f.name), size: 13, w: FontWeight.w700, color: p.violet),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx(f.name.trim(), size: 14, w: FontWeight.w700, color: p.ink, maxLines: 1, ellipsis: true),
                            if (f.phone.trim().isNotEmpty)
                              Tx(f.phone.trim(), size: 12, color: p.t4, maxLines: 1, tab: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tx(toyMoney(s.food), size: 14, w: FontWeight.w700, color: p.mint, tab: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Kategoriya lentasi — chip bosilsa faqat shu guruh (to'liq) ko'rinadi
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _smallChip(p, ty('allCats'), filter == null, () => setState(() => _svcCatFilter = null)),
                      for (final g in groups) ...[
                        const SizedBox(width: 8),
                        _svcCatChip(p, f, g.$1, g.$2, filter == g.$1.slug),
                      ],
                    ],
                  ),
                ),
                for (final g in groups)
                  if (filter == null || filter == g.$1.slug) _svcGroup(p, f, g.$1, g.$2, full: filter != null),
                if (f.services.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Tx(ty('bonusHint'), size: 12, color: p.t4, lh: 16),
                ],
                // ---- Tanlanganlar + jami ----
                const SizedBox(height: 22),
                Cap(ty('selectedCap')),
                const SizedBox(height: 10),
                GlassCard(
                  r: Tb.rCard,
                  pad: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selected.isEmpty)
                        Tx(ty('noneSelected'), size: 13, color: p.t4)
                      else
                        for (final sv in selected) ...[
                          Row(
                            children: [
                              Expanded(child: Tx(sv.title, size: 13, color: p.t2, maxLines: 1, ellipsis: true)),
                              const SizedBox(width: 10),
                              Tx(
                                f.services[sv.id] == true ? ty('bonusBadge') : (sv.price > 0 ? toyFx(sv.price) : ty('freePrice')),
                                size: 13, w: FontWeight.w600,
                                color: f.services[sv.id] == true ? p.mint : p.ink, tab: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      const SizedBox(height: 8),
                      Container(height: 1, color: p.glassBd),
                      const SizedBox(height: 10),
                      _totalRow(p, ty('agreedSum'), toyFx(s.food), p.t2),
                      if (s.extras > 0) ...[
                        const SizedBox(height: 4),
                        _totalRow(p, ty('extrasCap'), toyFx(s.extras), p.t2),
                      ],
                      const SizedBox(height: 6),
                      _totalRow(p, ty('previewCap'), toyMoney(s.total), p.mint, big: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GradientBtn(label: ty('save'), icon: Icons.check_rounded, loading: _busy, onTap: () => _saveBooking(f)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _svcCatChip(Pal p, _FormData f, ToyServiceCat cat, List<HallService> items, bool on) {
    final n = items.where((sv) => f.services.containsKey(sv.id)).length;
    return Tap(
      onTap: () => setState(() => _svcCatFilter = on ? null : cat.slug),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? p.ink : p.glass,
          border: Border.all(color: on ? p.ink : p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icon, size: 14, color: on ? p.bg : cat.c2),
            const SizedBox(width: 6),
            Tx(tyCat(cat.slug), size: 13, w: FontWeight.w600, color: on ? p.bg : p.t1, maxLines: 1, font: TbFont.body),
            if (n > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? p.bg : p.mint, shape: BoxShape.circle),
                child: Tx('$n', size: 10, w: FontWeight.w700, color: on ? p.ink : p.onMint, tab: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Kategoriya guruhi: sarlavha + ixcham qatorlar. Sukutda 3 ta item,
  /// qolgani "Yana N ta" bilan ochiladi (filtrda — hammasi). Shunda 30 ta
  /// servisli katalog ham bir ekranga sig'adi.
  Widget _svcGroup(Pal p, _FormData f, ToyServiceCat cat, List<HallService> items, {required bool full}) {
    final open = full || _svcExpanded.contains(cat.slug);
    final shown = open ? items : items.take(3).toList();
    final n = items.where((sv) => f.services.containsKey(sv.id)).length;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: cat.c2, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Tx(tyCat(cat.slug), size: 15, w: FontWeight.w700, color: p.ink, maxLines: 1, ellipsis: true)),
              Tx(n > 0 ? ty('nSelected', {'n': '$n'}) : ty('nItems', {'n': '${items.length}'}),
                  size: 12, w: FontWeight.w600, color: n > 0 ? p.mint : p.t4, tab: true),
            ],
          ),
          const SizedBox(height: 8),
          for (final sv in shown) ...[
            _svcRow(p, f, cat, sv),
            const SizedBox(height: 6),
          ],
          if (!full && items.length > 3)
            Tap(
              onTap: () => setState(() => open ? _svcExpanded.remove(cat.slug) : _svcExpanded.add(cat.slug)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Tx(open ? ty('showLess') : ty('showMore', {'n': '${items.length - 3}'}),
                    size: 13, w: FontWeight.w700, color: p.violet),
              ),
            ),
        ],
      ),
    );
  }

  /// 025→026: bron formasidagi servis QATORI — muqova 48px, nom, narx, belgi.
  /// Bosish sikli eski karta bilan BIR XIL: tanlanmagan -> pullik -> bonus -> yechildi.
  Widget _svcRow(Pal p, _FormData f, ToyServiceCat cat, HallService sv) {
    final sel = f.services.containsKey(sv.id);
    final bonus = sel && f.services[sv.id] == true;
    final accent = bonus ? p.mint : p.violet;
    return Tap(
      onTap: () => setState(() {
        if (!sel) {
          f.services[sv.id] = false;
        } else if (!bonus) {
          f.services[sv.id] = true;
        } else {
          f.services.remove(sv.id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          color: p.glass,
          border: Border.all(color: sel ? accent : p.glassBd, width: sel ? 1.5 : 1),
          borderRadius: BorderRadius.circular(Tb.rIcon + 4),
        ),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(Tb.rIcon), child: _svcThumb(cat, sv.cover, 48)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(sv.title, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(
                    bonus ? ty('bonusBadge') : (sv.price > 0 ? toyFx(sv.price) : ty('freePrice')),
                    size: 12, w: FontWeight.w600, color: bonus ? p.mint : p.t4, tab: true, strike: bonus,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: sel ? accent : Colors.transparent,
                border: Border.all(color: sel ? accent : p.glassBd, width: 2),
                shape: BoxShape.circle,
              ),
              child: sel
                  ? Icon(bonus ? Icons.card_giftcard_rounded : Icons.check_rounded, size: 15, color: p.bg)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 024: telefon o'zgardi — 500ms dan keyin bazadan mijoz qidiriladi;
  /// topilsa ism (agar qo'lda yozilmagan bo'lsa) avto-to'ladi, TOPILMASA
  /// avto-to'lgan ism tozalanadi (boshqa mijozning ismi qolib ketmasin).
  void _onPhoneChanged(_FormData f, String v) {
    setState(() {
      f.phone = v;
      f.hint = null;
      f.hintChecked = false;
    });
    _phoneT?.cancel();
    if (_phoneNat(v).length < 9) return;
    final seq = ++_phoneSeq;
    _phoneT = Timer(const Duration(milliseconds: 500), () async {
      final h = await toyRepo.lookupClient(v);
      if (!mounted || seq != _phoneSeq || _form != f) return;
      setState(() {
        f.hint = h;
        f.hintChecked = true;
        if (h != null && (f.name.trim().isEmpty || f.nameAuto)) {
          f.name = h.name;
          f.nameAuto = true;
        } else if (h == null && f.nameAuto) {
          f.name = '';
          f.nameAuto = false;
        }
      });
    });
  }

  /// Vaqt kartasi (3 ta yonma-yon): bo'sh — ikonka + "Bo'sh"; tanlangan —
  /// to'q fon; band — qulf + band qilgan mijoz nomi, bosilmaydi. Tahrirda
  /// bandning O'Z sloti tanlanadigan bo'lib qoladi (exceptId).
  Widget _slotCard(Pal p, _FormData f, String s) {
    final taken = toySlotTakenBy(
      _dayRows[toyYmd(f.date)] ?? const [],
      hallId: f.hallId,
      slot: s,
      exceptId: f.id,
    );
    final locked = taken != null;
    final on = !locked && f.slot == s;
    final fg = locked ? p.t5 : (on ? p.bg : p.ink);
    final sub = locked ? p.t4 : (on ? p.bg.withValues(alpha: .7) : p.t4);
    return Tap(
      onTap: locked ? null : () => setState(() => f.slot = s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 88,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
        decoration: BoxDecoration(
          color: on ? p.ink : (locked ? p.glass2 : p.glass),
          border: Border.all(color: on ? p.ink : p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(locked ? Icons.lock_outline_rounded : _slotIcon(s),
                size: 18, color: locked ? p.t5 : (on ? p.bg : _slotColor(s, p))),
            const Spacer(),
            Tx(tySlot(s), size: 13, w: FontWeight.w700, color: fg, maxLines: 1, ellipsis: true, font: TbFont.body),
            const SizedBox(height: 2),
            Tx(taken != null ? taken.clientName : (on ? ty('slotPicked') : ty('free')),
                size: 11, color: sub, maxLines: 1, ellipsis: true),
          ],
        ),
      ),
    );
  }

  /// Qator dumi " · N mehmon" — butun to'yxona rejimida mehmon so'ralmagan
  /// (0) bo'lsa hech narsa (026).
  String _guestsSuffix(Booking b) => b.guests > 0 ? ' · ${ty('guestsN', {'n': '${b.guests}'})}' : '';

  /// U4: tanlangan to'yxona sig'imidan oshgan mehmon soni (oshmagan bo'lsa null).
  int? _capacityOver(_FormData f, int guests) {
    final cap = toyRepo.hallById(f.hallId)?.capacity;
    if (cap == null || cap <= 0 || guests <= cap) return null;
    return cap;
  }

  void _pickHallInForm(_FormData f, Hall h) {
    final tiers = h.tiers;
    setState(() {
      f.hallId = h.id;
      // Toifa boshqa to'yxonaga tegishli bo'lib qolmasin (server 400 qaytaradi)
      f.menuId = tiers.isNotEmpty ? tiers.first.id : null;
      if (!f.priceManual) {
        f.price = tiers.isNotEmpty
            ? toyFx(tiers.first.pricePerGuest)
            : (h.pricePerGuest > 0 ? toyFx(h.pricePerGuest) : '');
      }
    });
  }

  /// Ilova palitrasidagi sana tanlagich (F12): brend violet urg'u; initialDate
  /// ORALIQQA QISILADI — ilgari oraliqdan tashqari boshlang'ich sana picker'ni
  /// yiqitardi.
  Future<DateTime?> _showAppDatePicker({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) async {
    final p = curPal();
    final dark = ThemeData.estimateBrightnessForColor(p.bg) == Brightness.dark;
    var init = initial;
    if (init.isBefore(first)) init = first;
    if (init.isAfter(last)) init = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
            primary: p.violet,
            onPrimary: Colors.white,
            surface: p.surface,
            onSurface: p.ink,
          ),
        ),
        child: child!,
      ),
    );
    return picked == null ? null : toyDay(picked);
  }

  Future<void> _pickDate(_FormData f) async {
    final now = DateTime.now();
    // F12: bronlar tarixi 2023 dan, oldinga 3 yil (kuzgi sanalar yillab oldin
    // band qilinadi).
    final picked = await _showAppDatePicker(
      initial: f.date,
      first: DateTime(2023, 1, 1),
      last: DateTime(now.year + 3, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() => f.date = picked);
    _ensureDay(picked); // U1: yangi kunning band slotlari belgilansin
  }

  Future<void> _saveBooking(_FormData f) async {
    if (!_validateMain(f)) return;
    final name = f.name.trim();
    // 026: butun to'yxona rejimida mehmonlar soni ixtiyoriy (0 = so'ralmagan)
    final guests = _digits(f.guests);
    final price = _digits(f.price);
    final advance = _digits(f.advance);
    final totalMode = f.priceMode == 'total';
    if (totalMode && _digits(f.totalPrice) <= 0 && f.id == null) {
      // Podklyuch narxi kelishilmagan — saqlash bloklanmaydi (avans avval kelishi
      // normal), faqat eslatma (U5 bilan bir xil siyosat).
    }
    final body = <String, dynamic>{
      if (f.hallId != null) 'hall_id': f.hallId,
      'event_date': toyYmd(f.date),
      'slot': f.slot,
      'client_name': name,
      if (f.phone.trim().isNotEmpty) 'client_phone': toyPhoneDigits(f.phone),
      'guests': guests,
      // 024: narx rejimi + podklyuch summasi
      'price_mode': f.priceMode,
      if (totalMode) 'total_price': _digits(f.totalPrice),
      if (f.id == null && f.services.isNotEmpty)
        'items': [
          for (final e in f.services.entries) {'service_id': e.key, if (e.value) 'is_bonus': true},
        ],
      // Narx ustuvorligi (backend shartnomasi, F10): aniq price_per_guest >
      // menu > to'yxona defaulti. menu_id + price_per_guest BIRGA yuborilishi
      // TO'G'RI — aniq narx g'olib, menu esa toifa NOMINI snapshot qiladi
      // (tahrir/qo'lda narx holati). Toifa tanlanib narx QO'LDA o'zgartirilmagan
      // bo'lsa faqat menu_id ketadi — narxni server toifadan o'zi nusxalaydi.
      if (!totalMode && f.menuId != null) 'menu_id': f.menuId,
      if (!totalMode && (f.menuId == null || f.priceManual)) 'price_per_guest': price,
      if (f.note.trim().isNotEmpty) 'note': f.note.trim(),
      if (f.id == null && advance > 0) 'advance': advance,
    };

    setState(() => _busy = true);
    final isNew = f.id == null;
    Booking? created;
    bool ok;
    if (isNew) {
      created = await toyRepo.createBooking(body);
      ok = created != null;
    } else {
      ok = await toyRepo.patchBooking(f.id!, body);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      // SLOT_TAKEN (409) — forma OCHIQ qoladi, ega boshqa vaqt/to'yxona
      // tanlaydi (_toastErr kodni 6 tilli matnga o'zi aylantiradi, F6).
      // Belgilar yangilanadi (U1): parallel qurilmadan band qilingan slot
      // formada darhol xira bo'lib ko'rinsin.
      if (toyRepo.lastCode == 'SLOT_TAKEN') {
        _dayFetched.remove(toyYmd(f.date));
        _ensureDay(f.date);
      }
      _toastErr();
      return;
    }
    final day = f.date;
    // U1: shu kunning bandlik keshi endi eskirdi — keyingi forma qayta so'raydi
    _dayRows.remove(toyYmd(day));
    _dayFetched.remove(toyYmd(day));
    setState(() {
      _form = null;
      // Yangi bron ko'rinib tursin: uning oyiga o'tib, kunini ochamiz
      if (isNew) {
        _month = toyMonthStart(day);
        _selDay = day;
      }
    });
    _toastMsg(isNew ? ty('created') : ty('saved'));
    if (isNew && (toyRepo.month.year != day.year || toyRepo.month.month != day.month)) {
      await toyRepo.load(_month);
    }
  }

  // ================= TO'YXONALAR (ro'yxat) =================

  Widget _venuesView(Pal p) {
    final halls = toyRepo.halls;
    return Column(
      children: [
        ScreenHeader(
          title: ty('hallsTitle'),
          onBack: () => setState(() => _venuesOpen = false),
          // Bitta akkaunt = bitta to'yxona (MODULES.toyxona.max_units = 1).
          // To'yxona bor ekan "+" KO'RSATILMAYDI: server 403 HALL_LIMIT qaytaradi,
          // ya'ni bu tugma kafolatlangan xatolik bo'lardi. Arxivlangach qaytadi.
          // 024 / PO: HAR ZAL $21 — "+" doim ko'rinadi; obuna qoplamasa server
          // 403 HALL_LIMIT beradi va paywall (zal soni bilan) ochiladi.
          // 029: yordam "?" — izohlar alohida modalda (ro'yxat ostida turmaydi)
          trailing: [
            GlassIconBtn(icon: Icons.help_outline_rounded, iconSize: 20, onTap: () => setState(() => _venueHelp = true)),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (halls.isEmpty) ...[
                  GlassCard(
                    r: Tb.rCard,
                    pad: const EdgeInsets.symmetric(vertical: 40, horizontal: 26),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: p.glass2,
                              border: Border.all(color: p.glassBd),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(Icons.home_outlined, size: 26, color: p.t2),
                          ),
                          const SizedBox(height: 16),
                          Tx(ty('noHalls'), size: 15, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
                          const SizedBox(height: 6),
                          Tx(ty('noVenueSub'), size: 13, color: p.t4, align: TextAlign.center, lh: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GradientBtn(label: ty('addHall'), onTap: _openNewHall),
                ] else ...[
                  for (var i = 0; i < halls.length; i++) ...[
                    _venueRow(p, halls[i]),
                    if (i < halls.length - 1) const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 14),
                  // 029: amallar — har biri o'z qatorida KARTA (tugma emas)
                  _actionCard(p, Icons.add_home_outlined, ty('addHall'), ty('addHallSub'), _openNewHall),
                  const SizedBox(height: 8),
                  _actionCard(p, Icons.room_service_outlined, ty('servicesListTitle'),
                      ty('servicesCountSub', {'n': '${toyRepo.allServices.length}'}), () => setState(() => _servicesOpen = true)),
                  const SizedBox(height: 8),
                  _actionCard(p, Icons.table_restaurant_outlined, ty('tablesTitle'),
                      ty('tablesN', {'n': '${halls.fold<int>(0, (n, h) => n + h.tiers.length)}'}), _openTables),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Amal kartasi (029): ikonka qutisi · sarlavha · ostida izoh · o'ngda strelka.
  Widget _actionCard(Pal p, IconData icon, String title, String sub, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.glass2,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(Tb.rIcon),
              ),
              child: Icon(icon, size: 22, color: p.t1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(title, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(sub, size: 13, color: p.t2, maxLines: 1, ellipsis: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.t6),
          ],
        ),
      ),
    );
  }

  /// Yordam modali (029): izohlar alohida soyali kartalarda.
  Widget _venueHelpModal(Pal p) {
    void close() => setState(() => _venueHelp = false);
    final notes = <(IconData, String)>[
      (Icons.payments_outlined, ty('perHallNote', {'price': '${modDefPrice('toyxona')}'})),
      (Icons.table_restaurant_outlined, ty('tablesNote')),
      (Icons.lock_clock_outlined, ty('priceSnapshotNote')),
    ];
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, ty('helpTitle'), close),
          const SizedBox(height: 16),
          for (final n in notes) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(Tb.rRow),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .14), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(n.$1, size: 18, color: p.violet),
                  const SizedBox(width: 10),
                  Expanded(child: Tx(n.$2, size: 13.5, color: p.t1, lh: 19)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _venueRow(Pal p, Hall h) {
    final n = h.tiers.length;
    final tiersTxt = n == 0 ? ty('noTiersN') : ty('tiersN', {'n': '$n'});
    return Tap(
      onTap: () => setState(() => _tiersHallId = h.id),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.glass2,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(Tb.rIcon),
              ),
              child: Icon(Icons.home_outlined, size: 22, color: p.t1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(h.name, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(
                    h.capacity == null
                        ? ty('hallLineNoCap', {'n': tiersTxt})
                        : ty('hallLine', {'cap': '${h.capacity}', 'n': tiersTxt}),
                    size: 13, color: p.t2, maxLines: 1, ellipsis: true,
                  ),
                  // 024: rejim · minimal avans
                  const SizedBox(height: 2),
                  Tx(
                    '${tyPriceMode(h.priceMode)}${h.depositPct > 0 ? ' · ${ty('depositPctShort', {'pct': '${h.depositPct}'})}' : ''}',
                    size: 12, color: p.t4, maxLines: 1, ellipsis: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 028: to'yxona ma'lumotini tahrirlash SHU YERDAN (stollar ekranidan emas)
            GlassIconBtn(icon: Icons.edit_outlined, iconSize: 18, size: 36, onTap: () => _openEditHall(h)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.t6),
          ],
        ),
      ),
    );
  }

  // ================= BITTA TO'YXONA: NARXLAR =================

  // ================= STOL KO'RINISHI (027/028) =================
  //
  // hall_menus = STOL. Ega bir marta N kishilik stolga qo'yiladigan hamma
  // mahsulotni (miqdor × birlik × birlik narxi) kiritadi — ilova stol jamini
  // va 1 KISHIGA narxni chiqaradi. 028: stolga 5 tagacha rasm — karta rasm
  // fonida, ma'lumot soya ustida. Bronda shu stol tanlanadi.

  /// Sozlamalardan "Stol ko'rinishi": tanlangan (yoki birinchi) to'yxona stollari.
  void _openTables() {
    final halls = toyRepo.halls;
    if (halls.isEmpty) {
      _toastMsg(ty('needVenue'));
      return;
    }
    final sel = toyRepo.selectedHallId;
    setState(() => _tiersHallId = halls.any((h) => h.id == sel) ? sel : halls.first.id);
  }

  Widget _tiersView(Pal p) {
    final h = toyRepo.hallById(_tiersHallId);
    if (h == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tiersHallId != null && toyRepo.hallById(_tiersHallId) == null) {
          setState(() => _tiersHallId = null);
        }
      });
      return const SizedBox.shrink();
    }
    final halls = toyRepo.halls;
    final tiers = h.tiers;
    return Column(
      children: [
        ScreenHeader(
          title: ty('tablesTitle'),
          subtitle: halls.length > 1
              ? h.name
              : (tiers.isEmpty ? ty('noTiersN') : ty('tablesN', {'n': '${tiers.length}'})),
          onBack: () => setState(() => _tiersHallId = null),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (halls.length > 1) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final x in halls)
                        _smallChip(p, x.name, x.id == h.id, () => setState(() => _tiersHallId = x.id)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (tiers.isEmpty)
                  GlassCard(
                    r: Tb.rCard,
                    pad: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Icon(Icons.table_restaurant_outlined, size: 28, color: p.t3),
                          const SizedBox(height: 10),
                          Tx(ty('noTiers'), size: 14, color: p.t4, align: TextAlign.center, lh: 20),
                        ],
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < tiers.length; i++) ...[
                    _tablePhotoCard(
                      p,
                      tiers[i],
                      onTap: () => _openEditTier(h, tiers[i]),
                      onAddPhoto: tiers[i].images.length < kToyMaxSvcImages ? () => _quickAddTablePhoto(tiers[i]) : null,
                    ),
                    if (i < tiers.length - 1) const SizedBox(height: 10),
                  ],
                const SizedBox(height: 12),
                GlassBtn(label: ty('addTier'), h: 44, icon: Icons.add_rounded, onTap: () => _openNewTier(h)),
                const SizedBox(height: 16),
                Tx(ty('tablesNote'), size: 13, color: p.t4, lh: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Rasmli stol kartasi (katalog va bron — bitta ko'rinish, h180).
  /// Rasmlar PageView (chapga surib almashadi), pastdan qora soya, ustida:
  /// nom · N kishilik · stol jami · o'ngda 1 kishiga. Rasm yo'q — brend gradient.
  /// onAddPhoto (katalog): yuqori o'ngda "Rasm" chipi. selected (bron): mint chegara + belgi.
  Widget _tablePhotoCard(
    Pal p,
    Menu m, {
    required VoidCallback onTap,
    VoidCallback? onAddPhoto,
    bool selected = false,
    double h = 180,
  }) {
    final imgs = m.images;
    final busy = _imgBusyMenuId == m.id;
    return Tap(
      onTap: onTap,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tb.rCard),
          border: Border.all(color: selected ? p.mint : p.glassBd, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imgs.isEmpty)
              Container(
                decoration: const BoxDecoration(gradient: Tb.brandDiag),
                child: Center(child: Icon(Icons.table_restaurant_outlined, size: 44, color: Colors.white.withValues(alpha: .35))),
              )
            else
              PageView(
                children: [
                  for (final u in imgs)
                    Image.network(
                      u,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: p.glass2),
                      loadingBuilder: (_, child, prog) => prog == null ? child : Container(color: p.glass2),
                    ),
                ],
              ),
            // Soya — matn rasm ustida o'qilsin
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: .05), Colors.black.withValues(alpha: .15), Colors.black.withValues(alpha: .78)],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
            ),
            // Yuqori: rasm qo'shish / rasm soni / tanlangan belgisi
            Positioned(
              top: 10,
              left: 12,
              right: 10,
              child: Row(
                children: [
                  if (imgs.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), borderRadius: BorderRadius.circular(Tb.rPill)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Tx('${imgs.length}', size: 11, w: FontWeight.w700, color: Colors.white, tab: true),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (selected)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: p.mint, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 16, color: p.onMint),
                    )
                  else if (onAddPhoto != null)
                    Tap(
                      onTap: busy ? null : onAddPhoto,
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(Tb.rPill)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (busy)
                              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white))
                            else
                              const Icon(Icons.add_photo_alternate_outlined, size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                            Tx(busy ? ty('uploading') : ty('tableAddPhoto'), size: 12, w: FontWeight.w600, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Pastki ma'lumot
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tx(m.title, size: 17, w: FontWeight.w700, color: Colors.white, maxLines: 1, ellipsis: true, font: TbFont.head),
                        const SizedBox(height: 3),
                        Tx(
                          [
                            if (m.seats != null) ty('seatsShort', {'n': '${m.seats}'}),
                            if (m.tableTotal > 0) ty('tableTotalLine', {'sum': toyFx(m.tableTotal)}) else ty('productsN', {'n': '${m.items.length}'}),
                          ].join(' · '),
                          size: 12.5, color: Colors.white.withValues(alpha: .85), maxLines: 1, ellipsis: true, tab: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Tx(toyFx(m.pricePerGuest), size: 18, w: FontWeight.w800, color: Colors.white, tab: true, font: TbFont.head),
                      Tx(ty('perGuestShort'), size: 11, color: Colors.white.withValues(alpha: .75)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Rasmlar (028) ----------

  /// Galereyadan rasm tanlab yuklaydi, URL qaytaradi (xato — null + toast).
  /// Servis rasmlari bilan bir xil siqish/chegara (1440px, q80, 3 MB).
  Future<String?> _pickAndUploadPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1440, maxHeight: 1440, imageQuality: 80);
      if (x == null || !mounted) return null;
      final bytes = await x.readAsBytes();
      if (!mounted) return null;
      if (bytes.lengthInBytes > 3 * 1024 * 1024) {
        _toastMsg(ty('imgTooBig'));
        return null;
      }
      final lower = x.path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      final url = await toyRepo.uploadServiceImage(bytes, mime);
      if (url == null && mounted) _toastMsg(toyRepo.error ?? ty('imgFailed'));
      return url;
    } catch (_) {
      if (mounted) _toastMsg(ty('imgFailed'));
      return null;
    }
  }

  /// Katalog kartasidagi "Rasm" chipi: tanlash → yuklash → darhol saqlash.
  Future<void> _quickAddTablePhoto(Menu m) async {
    if (_imgBusyMenuId != null) return;
    setState(() => _imgBusyMenuId = m.id);
    final url = await _pickAndUploadPhoto();
    if (!mounted) return;
    if (url == null) {
      setState(() => _imgBusyMenuId = null);
      return;
    }
    final ok = await toyRepo.patchMenu(m.id, {'images': [...m.images, url]});
    if (!mounted) return;
    setState(() => _imgBusyMenuId = null);
    if (!ok) _toastErr();
  }

  /// Muharrir ichidagi rasm qatori: mavjudlar (o'chirish bilan) + qo'shish.
  Future<void> _pickTablePhotoInto(List<String> list) async {
    if (_imgBusy) return;
    setState(() => _imgBusy = true);
    final url = await _pickAndUploadPhoto();
    if (!mounted) return;
    setState(() {
      _imgBusy = false;
      if (url != null && list.length < kToyMaxSvcImages) list.add(url);
    });
  }

  Widget _tablePhotoStrip(Pal p, List<String> imgs) => SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < imgs.length; i++) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Tb.rIcon),
                    child: Image.network(imgs[i], width: 84, height: 84, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 84, height: 84, color: p.glass2)),
                  ),
                  if (i == 0)
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(6)),
                        child: Tx(ty('coverBadge'), size: 9.5, w: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Tap(
                      onTap: () => setState(() => imgs.removeAt(i)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            if (imgs.length < kToyMaxSvcImages)
              Tap(
                onTap: _imgBusy ? null : () => _pickTablePhotoInto(imgs),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: p.glass,
                    border: Border.all(color: p.glassBd),
                    borderRadius: BorderRadius.circular(Tb.rIcon),
                  ),
                  child: _imgBusy
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 22, color: p.t3),
                            const SizedBox(height: 4),
                            Tx(ty('addPhoto'), size: 10.5, color: p.t4, align: TextAlign.center, maxLines: 2),
                          ],
                        ),
                ),
              ),
          ],
        ),
      );

  // ---------- Stol muharriri ----------

  Map<String, dynamic> _emptyRow() => {'title': '', 'amount': '', 'unit': 'kg', 'price': ''};

  void _openNewTier(Hall h) => setState(() => _tierEdit = {
        'hallId': h.id,
        'title': '',
        'price': '',
        'priceManual': false,
        'seats': '12',
        'images': <String>[],
        'rows': <Map<String, dynamic>>[_emptyRow()],
      });

  void _openEditTier(Hall h, Menu m) => setState(() => _tierEdit = {
        'hallId': h.id,
        'id': m.id,
        'menu': m,
        'title': m.title,
        'price': toyFx(m.pricePerGuest),
        // Narx hisobdan farq qilsa — ega qo'lda qo'ygan, ustidan yozmaymiz
        'priceManual': m.perGuestCalc == 0 || m.pricePerGuest != m.perGuestCalc,
        'seats': m.seats == null ? '' : '${m.seats}',
        'images': <String>[...m.images],
        'rows': <Map<String, dynamic>>[
          for (final it in m.items)
            {
              'title': it.title,
              'amount': it.amount != null ? toyAmountStr(it.amount) : (it.qty.isNotEmpty ? it.qty : ''),
              'unit': it.unit.isNotEmpty && kToyUnits.contains(it.unit) ? it.unit : 'kg',
              'price': it.unitPrice > 0 ? toyFx(it.unitPrice) : '',
              'legacy': it.amount == null && it.qty.isNotEmpty, // eski matnli qator
            },
          if (m.items.isEmpty) _emptyRow(),
        ],
      });

  /// Muharrir qatorlaridan stol jami (faqat to'liq to'ldirilgan qatorlar).
  int _rowsTotal(List rows) {
    var t = 0;
    for (final r in rows) {
      if (r['legacy'] == true) continue;
      t += toyLineTotal(_amountOf('${r['amount']}'), _digits('${r['price']}'));
    }
    return t;
  }

  double? _amountOf(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Widget _tierEditModal(Pal p) {
    final e = _tierEdit!;
    final isNew = e['id'] == null;
    final rows = e['rows'] as List<Map<String, dynamic>>;
    final imgs = (e['images'] as List).cast<String>();
    final seats = _digits('${e['seats']}');
    final total = _rowsTotal(rows);
    final calc = toyPerGuest(total, seats > 0 ? seats : null);
    final manual = e['priceManual'] == true;
    // Avto narx: qo'lda o'zgartirilmagan bo'lsa hisob bilan jonli yuradi
    final priceShown = manual ? '${e['price']}' : (calc > 0 ? toyFx(calc) : '${e['price']}');
    void close() => setState(() => _tierEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, isNew ? ty('newTier') : ty('editTier'), close),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _field(p, ty('tierTitleLabel'), '${e['title']}', (v) => setState(() => e['title'] = v),
                    icon: Icons.table_restaurant_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _field(p, ty('seatsLabel'), '${e['seats']}', (v) => setState(() => e['seats'] = v),
                    number: true, group: false, icon: Icons.chair_outlined),
              ),
            ],
          ),
          // ---- Rasmlar (faqat saqlangan stolda) ----
          const SizedBox(height: 20),
          Cap(ty('tablePhotosCap')),
          const SizedBox(height: 10),
          if (isNew)
            Tx(ty('photosAfterSave'), size: 12, color: p.t4, lh: 16)
          else ...[
            _tablePhotoStrip(p, imgs),
            const SizedBox(height: 6),
            Tx(ty('photoHint', {'n': '$kToyMaxSvcImages'}), size: 12, color: p.t4, lh: 16),
          ],
          // ---- Mahsulotlar ----
          const SizedBox(height: 20),
          Cap(ty('productsCap')),
          const SizedBox(height: 6),
          Tx(ty('productsHint'), size: 12, color: p.t4, lh: 16),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _productRow(p, rows, i),
            const SizedBox(height: 8),
          ],
          GlassBtn(
            label: ty('addProduct'),
            h: 40,
            fs: 14,
            icon: Icons.add_rounded,
            onTap: () => setState(() => rows.add(_emptyRow())),
          ),
          const SizedBox(height: 20),
          // ---- Hisob ----
          GlassCard(
            r: Tb.rCard,
            pad: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _totalRow(p, ty('tableTotalCap'), toyMoney(total), p.t2),
                const SizedBox(height: 4),
                _totalRow(
                  p,
                  seats > 0 ? ty('perGuestCalcCap', {'n': '$seats'}) : ty('perGuestNoSeats'),
                  calc > 0 ? toyMoney(calc) : '—',
                  p.mint,
                  big: true,
                ),
                const SizedBox(height: 14),
                _field(
                  p,
                  manual ? ty('tierPriceLabel') : ty('tierPriceAutoLabel'),
                  priceShown,
                  (v) => setState(() {
                    e['price'] = v;
                    e['priceManual'] = _digits(v) != calc;
                  }),
                  number: true,
                  icon: Icons.payments_outlined,
                ),
                if (manual && calc > 0) ...[
                  const SizedBox(height: 8),
                  Tap(
                    onTap: () => setState(() {
                      e['priceManual'] = false;
                      e['price'] = toyFx(calc);
                    }),
                    child: Tx(ty('useCalcPrice', {'sum': toyFx(calc)}), size: 12, w: FontWeight.w600, color: p.violet),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientBtn(label: _imgBusy ? ty('uploading') : ty('save'), loading: _busy || _imgBusy, onTap: () => _saveTier(e)),
          if (!isNew) ...[
            const SizedBox(height: 8),
            GlassBtn(
              label: ty('tablePdf'),
              h: 44,
              icon: Icons.picture_as_pdf_outlined,
              onTap: () => _shareTablePdf(e['menu'] as Menu),
            ),
            const SizedBox(height: 4),
            TextBtn(
              label: ty('archiveTier'),
              color: p.coral,
              onTap: () => _askArchiveTier('${e['id']}', '${e['title']}'),
            ),
          ],
        ],
      ),
    );
  }

  /// Bitta mahsulot qatori: nom · miqdor + birlik · birlik narxi → qator jami.
  /// Har maydon YORLIQLI (placeholder emas — ega nima kiritishini ko'rib tursin).
  Widget _productRow(Pal p, List<Map<String, dynamic>> rows, int i) {
    final r = rows[i];
    final legacy = r['legacy'] == true;
    final lt = legacy ? 0 : toyLineTotal(_amountOf('${r['amount']}'), _digits('${r['price']}'));
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _field(p, ty('productTitleLabel'), '${r['title']}', (v) => setState(() => r['title'] = v)),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GlassIconBtn(
                  icon: Icons.close_rounded,
                  iconSize: 18,
                  onTap: () => setState(() {
                    rows.removeAt(i);
                    if (rows.isEmpty) rows.add(_emptyRow());
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _field(p, ty('amountLabel'), '${r['amount']}', (v) => setState(() {
                      r['amount'] = v;
                      r['legacy'] = false; // eski matnli qator qayta terildi — endi hisoblanadi
                    }),
                    decimal: true, group: false),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _field(p, ty('unitPriceLabel'), '${r['price']}', (v) => setState(() {
                      r['price'] = v;
                      r['legacy'] = false;
                    }),
                    number: true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Cap(ty('unitLabel')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final u in kToyUnits) ...[
                        PillChip(
                          label: tyUnit(u),
                          selected: r['unit'] == u,
                          h: 30,
                          onTap: () => setState(() {
                            r['unit'] = u;
                            r['legacy'] = false;
                          }),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
              if (lt > 0) ...[
                const SizedBox(width: 8),
                Tx('= ${toyFx(lt)}', size: 13, w: FontWeight.w700, color: p.mint, tab: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveTier(Map<String, dynamic> e) async {
    if (_imgBusy) return;
    final title = '${e['title']}'.trim();
    final rows = e['rows'] as List<Map<String, dynamic>>;
    final seats = _digits('${e['seats']}');
    final total = _rowsTotal(rows);
    final calc = toyPerGuest(total, seats > 0 ? seats : null);
    final price = e['priceManual'] == true ? _digits('${e['price']}') : (calc > 0 ? calc : _digits('${e['price']}'));
    if (title.isEmpty) {
      _toastMsg(ty('needTierTitle'));
      return;
    }
    if (price <= 0) {
      _toastMsg(ty('needTierPrice'));
      return;
    }
    if (seats > 100) {
      _toastMsg(ty('badSeats'));
      return;
    }
    final items = [
      for (final r in rows)
        if ('${r['title']}'.trim().isNotEmpty)
          r['legacy'] == true
              ? {'title': '${r['title']}'.trim(), 'qty': '${r['amount']}'.trim()}
              : {
                  'title': '${r['title']}'.trim(),
                  if (_amountOf('${r['amount']}') != null) 'amount': _amountOf('${r['amount']}'),
                  if (_amountOf('${r['amount']}') != null) 'unit': r['unit'],
                  'unit_price': _digits('${r['price']}'),
                },
    ];
    final body = {
      'title': title,
      'price_per_guest': price,
      'seats': seats > 0 ? seats : null,
      'items': items,
      if (e['id'] != null) 'images': (e['images'] as List).cast<String>(),
    };
    setState(() => _busy = true);
    final ok = e['id'] == null
        ? await toyRepo.createMenu('${e['hallId']}', body)
        : await toyRepo.patchMenu('${e['id']}', body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _tierEdit = null;
    });
    ok ? _toastMsg(ty('tierSaved')) : _toastErr();
  }

  Future<void> _shareTablePdf(Menu m) async {
    setState(() => _busy = true);
    try {
      await shareTableSheet(m, hall: toyRepo.hallById(m.hallId), ownerName: '${store.S['meName'] ?? ''}');
    } catch (_) {
      if (mounted) _toastMsg(ty('receiptFailed'));
    }
    if (mounted) setState(() => _busy = false);
  }

  // ---------- Bronda stol tanlash ----------

  /// Bron formasida stol kartalari (rasmli, to'liq kenglik). Bosilsa tarkib
  /// varag'i ochiladi — tanlash o'sha yerda ("Shu stolni tanlash").
  Widget _tableCards(Pal p, _FormData f, List<Menu> tiers) => Column(
        children: [
          for (var i = 0; i < tiers.length; i++) ...[
            _tablePhotoCard(
              p,
              tiers[i],
              h: 150,
              selected: f.menuId == tiers[i].id && !f.priceManual,
              onTap: () => setState(() => _tableInfo = tiers[i]),
            ),
            if (i < tiers.length - 1) const SizedBox(height: 10),
          ],
        ],
      );

  /// Stol tarkibi varag'i: rasm lentasi, mahsulot · miqdor · birlik narxi · qator jami; PDF; tanlash.
  Widget _tableSheet(Pal p) {
    final m = _tableInfo!;
    final f = _form;
    final canPick = f != null && f.id == null && f.priceMode != 'total';
    final picked = f != null && f.menuId == m.id && !f.priceManual;
    void close() => setState(() => _tableInfo = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, m.title, close),
          const SizedBox(height: 4),
          Tx(
            [
              if (m.seats != null) ty('seatsShort', {'n': '${m.seats}'}),
              ty('productsN', {'n': '${m.items.length}'}),
            ].join(' · '),
            size: 13, color: p.t4,
          ),
          if (m.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tb.rCard),
                child: PageView(
                  children: [
                    for (final u in m.images)
                      Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: p.glass2)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GlassCard(
            r: Tb.rCard,
            pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                if (m.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Tx(ty('noProducts'), size: 13, color: p.t4),
                  ),
                for (var i = 0; i < m.items.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tx(m.items[i].title, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                              if (m.items[i].qtyText.isNotEmpty || m.items[i].unitPrice > 0)
                                Tx(
                                  [
                                    if (m.items[i].qtyText.isNotEmpty) m.items[i].qtyText,
                                    if (m.items[i].unitPrice > 0) '${toyFx(m.items[i].unitPrice)}/${tyUnit(m.items[i].unit)}',
                                  ].join(' × '),
                                  size: 12, color: p.t4, tab: true,
                                ),
                            ],
                          ),
                        ),
                        if (m.items[i].lineTotal > 0) ...[
                          const SizedBox(width: 10),
                          Tx(toyFx(m.items[i].lineTotal), size: 14, w: FontWeight.w600, color: p.ink, tab: true),
                        ],
                      ],
                    ),
                  ),
                if (m.tableTotal > 0) ...[
                  Container(height: 1, color: p.glassBd),
                  const SizedBox(height: 10),
                  _totalRow(p, ty('tableTotalCap'), toyFx(m.tableTotal), p.t2),
                  const SizedBox(height: 4),
                ],
                _totalRow(p, ty('perGuestCap'), toyMoney(m.pricePerGuest), p.mint, big: true),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (canPick)
            GradientBtn(
              label: picked ? ty('tablePicked') : ty('pickTable'),
              icon: Icons.check_rounded,
              onTap: () => setState(() {
                f.menuId = m.id;
                f.priceManual = false;
                f.price = toyFx(m.pricePerGuest);
                _tableInfo = null;
              }),
            ),
          const SizedBox(height: 8),
          GlassBtn(label: ty('tablePdf'), h: 44, icon: Icons.picture_as_pdf_outlined, loading: _busy, onTap: () => _shareTablePdf(m)),
        ],
      ),
    );
  }

  // ================= SERVISLAR KATALOGI (024) =================

  // ================= SERVISLAR: KATEGORIYA GRID (025) =================
  //
  // Ikki pog'ona, bitta qatlam:
  //   _catOpen == null -> KATEGORIYA GRID (biz belgilagan 18 ta, shisha kartalar + illyustratsiya)
  //   _catOpen != null -> o'sha kategoriya ICHI (eganing item'lari, rasm bilan)
  //
  // BO'SH kategoriya ham grid'da ko'rinadi (xira, "bo'sh" chipi bilan): ega
  // "bu yerga ham qo'shsam bo'lar ekan" deb ko'rishi kerak. Faqat to'lganini
  // ko'rsatish yangi egaga BO'SH ekran berardi va u nima qilishni bilmasdi.

  Widget _servicesView(Pal p) =>
      _catOpen == null ? _catsGrid(p) : _catItemsView(p, catOf(_catOpen));

  Widget _catsGrid(Pal p) {
    final counts = toyRepo.catCounts(toyRepo.selectedHallId);
    return Column(
      children: [
        ScreenHeader(
          title: ty('servicesTitle'),
          subtitle: ty('catsSub'),
          onBack: () => setState(() => _servicesOpen = false),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 14, Tb.padX, 40),
            child: LayoutBuilder(
              builder: (_, c) {
                // Ikki ustun. Kenglik 380 dan oshsa (planshet/katta telefon) uch —
                // aks holda kartalar cho'zilib, rasm juda katta ko'rinardi.
                final cols = c.maxWidth >= 380 ? 3 : 2;
                const gap = 10.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    // Itemli kategoriyalar AVVAL, bo'shlari pastga tushib boradi —
                    // ega o'z to'ldirgan bo'limlarini birinchi ko'radi (026).
                    for (final cat in [
                      ...kToyServiceCats.where((c) => (counts[c.slug] ?? 0) > 0),
                      ...kToyServiceCats.where((c) => (counts[c.slug] ?? 0) == 0),
                    ])
                      SizedBox(width: w, child: _catCard(p, cat, counts[cat.slug] ?? 0)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Kategoriya kartasi.
  ///
  /// Illyustratsiyalar (Storyset) MONOXROM KO'K (#4F7DF3) — shuning uchun karta
  /// foni to'q shisha (loyihaning "dark glass" spec'i), kategoriya rangi esa
  /// faqat YUMSHOQ NUR (yuqori-chap radial glow) + hisoblagich rangida.
  /// Rangli to'liq gradient fon ko'k rasm bilan urishardi (Spotify plitkalari
  /// fotosurat bilan ishlaydi, bir rangli illyustratsiya bilan emas).
  /// Rasm pastki o'ngda, kesilmagan (contain) — sahna butun ko'rinadi.
  Widget _catCard(Pal p, ToyServiceCat cat, int n) {
    final empty = n == 0;
    return Tap(
      onTap: () => setState(() => _catOpen = cat.slug),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(Tb.rRow),
          border: Border.all(color: p.glassBd),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tb.rRow),
          child: Stack(
            children: [
              // Kategoriya rangi — yuqori-chap burchakdan tarqaladigan nur
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-1.0, -1.0),
                      radius: 1.25,
                      colors: [
                        cat.c2.withValues(alpha: p.isDark ? .40 : .30),
                        cat.c2.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Illyustratsiya — pastki o'ng, sal tashqariga chiqib turadi
              Positioned(
                right: -4,
                bottom: -2,
                child: Opacity(
                  opacity: empty ? 0.55 : 1,
                  child: Illustration(asset: cat.asset, fallback: cat.icon, size: 86),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: empty ? p.glass2 : cat.c2.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(Tb.rPill),
                      ),
                      child: Tx(empty ? ty('catEmptyChip') : '$n',
                          size: 11, w: FontWeight.w700, color: empty ? p.t4 : cat.c2),
                    ),
                    // Nom — rasm ustiga chiqmasin: o'ngdan 54px joy qoldiriladi
                    Padding(
                      padding: const EdgeInsets.only(right: 54),
                      child: Tx(tyCat(cat.slug),
                          size: 13.5, w: FontWeight.w700, color: p.ink, lh: 16, maxLines: 2, ellipsis: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Kategoriya ichi: eganing item'lari ----

  Widget _catItemsView(Pal p, ToyServiceCat cat) {
    final list = toyRepo.servicesInCat(cat.slug, toyRepo.selectedHallId);
    return Column(
      children: [
        ScreenHeader(
          title: tyCat(cat.slug),
          subtitle: list.isEmpty ? null : '${list.length}',
          onBack: () => setState(() => _catOpen = null),
          trailing: [GlassIconBtn(icon: Icons.add_rounded, onTap: () => _openNewService(cat.slug))],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 14, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (list.isEmpty)
                  _catEmpty(p, cat)
                else
                  for (var i = 0; i < list.length; i++) ...[
                    _svcCard(p, cat, list[i]),
                    if (i < list.length - 1) const SizedBox(height: 10),
                  ],
                const SizedBox(height: 14),
                GlassBtn(
                  label: ty('addToCat', {'cat': tyCat(cat.slug)}),
                  h: 44,
                  onTap: () => _openNewService(cat.slug),
                ),
                const SizedBox(height: 16),
                Tx(ty('servicesNote'), size: 13, color: p.t4, lh: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _catEmpty(Pal p, ToyServiceCat cat) => GlassCard(
        r: Tb.rCard,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: Column(
            children: [
              Illustration(asset: cat.asset, fallback: cat.icon, size: 84),
              const SizedBox(height: 14),
              Tx(ty('catEmptyTitle'), size: 16, w: FontWeight.w700, color: p.ink, align: TextAlign.center),
              const SizedBox(height: 6),
              Tx(ty('catEmptySub', {'cat': tyCat(cat.slug)}),
                  size: 13, color: p.t4, align: TextAlign.center, lh: 19),
            ],
          ),
        ),
      );

  /// Item kartasi: chapda kvadrat rasm (yo'q bo'lsa kategoriya gradienti +
  /// ikonka), o'ngda nom, tavsif va narx. Bosilsa tahrirlash.
  Widget _svcCard(Pal p, ToyServiceCat cat, HallService sv) {
    final hall = sv.hallId == null ? null : toyRepo.hallById(sv.hallId)?.name;
    return Tap(
      onTap: () => _openEditService(sv),
      child: GlassCard(
        r: Tb.rRow,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _svcThumb(cat, sv.cover, 76),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Tx(sv.title, size: 15, w: FontWeight.w700, color: p.ink, maxLines: 1, ellipsis: true),
                    if (sv.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Tx(sv.description, size: 12.5, color: p.t4, lh: 17, maxLines: 2, ellipsis: true),
                    ] else if (hall != null) ...[
                      const SizedBox(height: 4),
                      Tx(hall, size: 12.5, color: p.t4, maxLines: 1, ellipsis: true),
                    ],
                    const SizedBox(height: 8),
                    Tx(sv.price > 0 ? toyMoney(sv.price) : ty('freePrice'),
                        size: 15, w: FontWeight.w700, color: p.ink, tab: true),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ChevRight(color: p.t5),
            ],
          ),
        ),
      ),
    );
  }

  /// Kvadrat muqova. URL bo'lsa tarmoqdan, bo'lmasa (yoki yuklanmasa)
  /// kategoriya gradienti + ikonka — bo'sh kulrang quti HECH QACHON ko'rinmaydi.
  Widget _svcThumb(ToyServiceCat cat, String? url, double size) {
    final ph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cat.c1, cat.c2],
        ),
        borderRadius: BorderRadius.circular(Tb.rIcon),
      ),
      child: Icon(cat.icon, size: size * 0.42, color: Colors.white),
    );
    if (url == null || url.isEmpty) return ph;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tb.rIcon),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => ph,
        loadingBuilder: (_, child, ev) => ev == null ? child : ph,
      ),
    );
  }

  void _openNewService([String? cat]) => setState(() => _svcEdit = {
        'title': '',
        'price': '',
        'category': cat ?? _catOpen ?? kToyDefaultCat,
        'description': '',
        'images': <String>[],
      });

  void _openEditService(HallService sv) => setState(() => _svcEdit = {
        'id': sv.id,
        'title': sv.title,
        'price': sv.price > 0 ? toyFx(sv.price) : '',
        'category': sv.category,
        'description': sv.description,
        'images': List<String>.from(sv.images),
      });

  Widget _svcEditModal(Pal p) {
    final e = _svcEdit!;
    final isNew = e['id'] == null;
    final cat = catOf('${e['category']}');
    final imgs = (e['images'] as List).cast<String>();
    void close() => setState(() => _svcEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, isNew ? ty('newService') : ty('editService'), close),
          const SizedBox(height: 18),
          // ---- Kategoriya (chip qatori) ----
          Cap(ty('svcCatLabel')),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kToyServiceCats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = kToyServiceCats[i];
                return _smallChip(p, tyCat(c.slug), c.slug == cat.slug,
                    () => setState(() => e['category'] = c.slug));
              },
            ),
          ),
          const SizedBox(height: 16),
          // ---- Rasmlar ----
          Cap(ty('svcPhotosCap')),
          const SizedBox(height: 8),
          _photoStrip(p, cat, imgs),
          const SizedBox(height: 6),
          Tx(ty('photoHint', {'n': '$kToyMaxSvcImages'}), size: 12, color: p.t4),
          const SizedBox(height: 16),
          _field(p, ty('svcTitleLabel'), '${e['title']}', (v) => setState(() => e['title'] = v),
              hint: ty('svcTitlePh'), icon: Icons.room_service_outlined),
          const SizedBox(height: 14),
          _field(p, ty('svcAmountLabel'), '${e['price']}', (v) => setState(() => e['price'] = v),
              number: true, icon: Icons.payments_outlined),
          const SizedBox(height: 14),
          _field(p, ty('svcDescLabel'), '${e['description']}',
              (v) => setState(() => e['description'] = v),
              hint: ty('svcDescPh'), icon: Icons.notes_rounded, lines: 3),
          const SizedBox(height: 22),
          GradientBtn(
              label: _imgBusy ? ty('uploading') : ty('save'),
              loading: _busy || _imgBusy,
              onTap: () => _saveService(e)),
          if (!isNew) ...[
            const SizedBox(height: 6),
            TextBtn(
              label: ty('deleteService'),
              color: p.coral,
              onTap: () => _askDeleteService('${e['id']}', '${e['title']}'),
            ),
          ],
        ],
      ),
    );
  }

  /// Rasm lentasi: mavjud rasmlar + oxirida "qo'shish" katagi.
  /// Birinchi rasm MUQOVA — kartochkada va bron varaqasida ko'rinadigan aynan u.
  Widget _photoStrip(Pal p, ToyServiceCat cat, List<String> imgs) => SizedBox(
        height: 84,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < imgs.length; i++) ...[
              Stack(
                children: [
                  _svcThumb(cat, imgs[i], 84),
                  // O'chirish tugmasi — rasm ustida, o'ng yuqorida
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Tap(
                      onTap: () => setState(() => imgs.removeAt(i)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            if (imgs.length < kToyMaxSvcImages)
              Tap(
                onTap: _imgBusy ? null : _pickServicePhoto,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: p.glass,
                    border: Border.all(color: p.glassBd),
                    borderRadius: BorderRadius.circular(Tb.rIcon),
                  ),
                  child: _imgBusy
                      ? const Center(
                          child: SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 22, color: p.t3),
                            const SizedBox(height: 4),
                            Tx(ty('addPhoto'), size: 10.5, color: p.t4, align: TextAlign.center, maxLines: 2),
                          ],
                        ),
                ),
              ),
          ],
        ),
      );

  /// Galereyadan rasm tanlab, DARHOL serverga yuklaydi va URL'ni formaga qo'shadi.
  ///
  /// NEGA DARHOL: forma saqlanmaguncha kutilsa, saqlash bosilganda 5 ta rasm
  /// ketma-ket yuklanib, ega 30 soniya "Saqlanmoqda" ni kuzatardi va bittasi
  /// yiqilsa qaysi biri ekani noma'lum qolardi. Yuklangan rasm formaga
  /// qo'shilgach, saqlash oddiy JSON so'rovi bo'lib qoladi.
  ///
  /// SIQISH: maxWidth 1440 + quality 80 -> ~200-400 KB. Server chegarasi 3 MB;
  /// undan katta fayl (siqilmaydigan PNG) bo'lsa aniq xabar beramiz.
  Future<void> _pickServicePhoto() async {
    if (_imgBusy || _svcEdit == null) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 80,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 3 * 1024 * 1024) {
        _toastMsg(ty('imgTooBig'));
        return;
      }
      // Kengaytmadan MIME: picker JPEG qaytaradi, lekin PNG/WEBP ham bo'lishi
      // mumkin (server faqat shu uchtasini qabul qiladi).
      final lower = x.path.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      setState(() => _imgBusy = true);
      final url = await toyRepo.uploadServiceImage(bytes, mime);
      if (!mounted) return;
      setState(() {
        _imgBusy = false;
        if (url != null && _svcEdit != null) {
          final list = (_svcEdit!['images'] as List).cast<String>();
          if (list.length < kToyMaxSvcImages) list.add(url);
        }
      });
      if (url == null) _toastMsg(toyRepo.error ?? ty('imgFailed'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _imgBusy = false);
      _toastMsg(ty('imgFailed'));
    }
  }

  Future<void> _saveService(Map<String, dynamic> e) async {
    if (_imgBusy) return;   // rasm yuklanayotganda saqlash — URL yo'qolardi
    final title = '${e['title']}'.trim();
    final price = _digits('${e['price']}');
    if (title.isEmpty) {
      _toastMsg(ty('needSvcTitle'));
      return;
    }
    final cat = catOf('${e['category']}').slug;
    final desc = '${e['description']}'.trim();
    final imgs = (e['images'] as List).cast<String>();
    setState(() => _busy = true);
    final ok = e['id'] == null
        ? await toyRepo.createService(title, price,
            category: cat, description: desc, images: imgs)
        // PATCH: rasmlar TO'LIQ ro'yxat sifatida ketadi — server ro'yxatdan
        // chiqqan fayllarni Storage'dan ham o'chiradi.
        : await toyRepo.patchService('${e['id']}', {
            'title': title,
            'price': price,
            'category': cat,
            'description': desc,
            'images': imgs,
          });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _svcEdit = null;
    });
    ok ? _toastMsg(ty('saved')) : _toastErr();
  }

  void _askDeleteService(String id, String title) {
    setState(() {
      _svcEdit = null;
      _confirm = {
        'title': ty('confirmDeleteTitle'),
        'body': '$title\n${ty('servicesNote')}',
        'danger': true,
        'run': () async {
          final ok = await toyRepo.deleteService(id);
          if (!mounted) return;
          ok ? _toastMsg(ty('deleted')) : _toastErr();
        },
      };
    });
  }

  // ================= QIDIRUV (U7) =================

  /// Qidiruv gavdasi: ≥2 belgi — server natijasi (event_date DESC) + yuklangan
  /// oy/yaqin bronlardagi klient mosliklari (id dedup). Tarmoq yiqilsa faqat
  /// klient mosliklari + sokin oflayn belgisi. Qator bosilsa tafsilot ochiladi.
  Widget _searchBody(Pal p) {
    final q = _searchQ.trim();
    if (q.length < 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Tb.padX, 18, Tb.padX, 0),
        child: Tx(ty('searchPh'), size: 14, color: p.t4),
      );
    }
    final local = toyRepo.localMatches(q);
    final list = _searchServer == null ? local : toyMergeSearch(_searchServer!, local);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchBusy) ...[
            _loadingHint(p),
            const SizedBox(height: 12),
          ] else if (_searchOffline) ...[
            Tx(ty('searchOffline'), size: 12, color: p.t4, lh: 16),
            const SizedBox(height: 12),
          ],
          if (list.isEmpty && !_searchBusy)
            _quietCard(p, ty('searchEmpty'))
          else
            for (var i = 0; i < list.length; i++) ...[
              _searchRow(p, list[i]),
              if (i < list.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  /// Natija qatori: sana rozetkasi · yil/vaqt/to'yxona · mijoz · holat · qoldiq.
  /// Bekor qilinganda o'ngda EGADA QOLGAN pul (F7 qoidasi bilan bir xil).
  Widget _searchRow(Pal p, Booking b) {
    final sub = [
      '${b.eventDate.year}',
      tySlot(b.slot),
      if (b.hallName.isNotEmpty) b.hallName,
    ].join(' · ');
    return Tap(
      onTap: () => setState(() => _detailId = b.id),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          children: [
            _dateBadge(p, b.eventDate),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(b.clientName, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                  const SizedBox(height: 2),
                  Tx(sub, size: 13, color: p.t2, maxLines: 1, ellipsis: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tx(
                      b.cancelled ? toyMoney(b.paid) : toyMoney(b.left),
                      size: 15,
                      w: FontWeight.w600,
                      color: b.cancelled ? p.t4 : _leftColor(b.left, p),
                      tab: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: _statusBadge(b.status)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MODALLAR =================

  /// Barcha modallar — pastdan chiqadigan SheetShell. Yozish ketayotganda
  /// (_busy) dim'ga bosish yopmaydi (eski _scrimCard xatti-harakati).
  Widget _sheet(VoidCallback close, Widget child) {
    return SheetShell(
      onClose: () {
        if (!_busy) close();
      },
      child: child,
    );
  }

  /// Sheet sarlavhasi 20/600 + o'ngda yopish tugmasi.
  Widget _sheetTitle(Pal p, String title, VoidCallback close) {
    return Row(
      children: [
        Expanded(
          child: Tx(title, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 2, ellipsis: true),
        ),
        const SizedBox(width: 8),
        GlassIconBtn(icon: Icons.close_rounded, onTap: _busy ? null : close),
      ],
    );
  }

  Widget _confirmModal(Pal p) {
    final c = _confirm!;
    void close() => setState(() => _confirm = null);
    final danger = c['danger'] == true;
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, '${c['title']}', close),
          const SizedBox(height: 10),
          Tx('${c['body']}', size: 14, color: p.t2, lh: 20),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: GlassBtn(label: ty('no'), h: 52, onTap: close)),
              const SizedBox(width: 12),
              Expanded(
                child: danger
                    ? SolidBtn.coral(ty('yes'), _busy ? null : () => _runConfirm(c), h: 52, loading: _busy)
                    : GradientBtn(label: ty('yes'), h: 52, loading: _busy, glow: false, onTap: () => _runConfirm(c)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runConfirm(Map<String, dynamic> c) async {
    setState(() => _busy = true);
    final run = c['run'] as Function;
    await run();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirm = null;
    });
  }

  // ---- To'yxona qo'shish / tahrirlash ----

  void _openNewHall() => setState(() => _hallEdit = {
        'name': '', 'cap': '', 'price': '',
        'mode': 'guest', 'total': '', 'dep': '',
        'pol': {for (final d in kToyPolicyDays) d: ''},
      });

  void _openEditHall(Hall h) => setState(() => _hallEdit = {
        'id': h.id,
        'name': h.name,
        'cap': h.capacity == null ? '' : '${h.capacity}',
        'price': h.pricePerGuest > 0 ? toyFx(h.pricePerGuest) : '',
        'mode': h.priceMode,
        'total': h.totalPrice > 0 ? toyFx(h.totalPrice) : '',
        'dep': h.depositPct > 0 ? '${h.depositPct}' : '',
        'pol': {
          for (final d in kToyPolicyDays)
            d: () {
              for (final r in h.cancelPolicy) {
                if (r.days == d) return '${r.pct}';
              }
              return '';
            }(),
        },
      });

  Widget _hallEditModal(Pal p) {
    final e = _hallEdit!;
    final isNew = e['id'] == null;
    void close() => setState(() => _hallEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, isNew ? ty('newHall') : ty('editHall'), close),
          const SizedBox(height: 20),
          _field(p, ty('hallNameLabel'), '${e['name']}', (v) => setState(() => e['name'] = v),
              icon: Icons.home_outlined),
          const SizedBox(height: 16),
          _field(p, ty('capacityLabel'), '${e['cap']}', (v) => setState(() => e['cap'] = v),
              number: true, group: false, icon: Icons.people_outline_rounded),
          const SizedBox(height: 16),
          GradientBtn(label: ty('save'), loading: _busy, onTap: () => _saveHall(e)),
        ],
      ),
    );
  }

  Future<void> _saveHall(Map<String, dynamic> e) async {
    final name = '${e['name']}'.trim();
    if (name.isEmpty) {
      _toastMsg(ty('needHallName'));
      return;
    }
    final cap = _digits('${e['cap']}');
    final price = _digits('${e['price']}');
    final dep = _digits('${e['dep']}');
    if (dep > 100) {
      _toastMsg(ty('badPct'));
      return;
    }
    final pol = <Map<String, int>>[];
    for (final d in kToyPolicyDays) {
      final raw = '${(e['pol'] as Map)[d]}'.trim();
      if (raw.isEmpty) continue;
      final pct = _digits(raw);
      if (pct > 100) {
        _toastMsg(ty('badPct'));
        return;
      }
      pol.add({'days': d, 'pct': pct});
    }
    final extra = <String, dynamic>{
      'price_mode': e['mode'] == 'total' ? 'total' : 'guest',
      'total_price': _digits('${e['total']}'),
      'deposit_pct': dep,
      'cancel_policy': pol,
    };
    setState(() => _busy = true);
    final ok = e['id'] == null
        ? await toyRepo.createHall(name, capacity: cap > 0 ? cap : null, pricePerGuest: price, extra: extra)
        : await toyRepo.patchHall('${e['id']}', {
            'name': name,
            'capacity': cap > 0 ? cap : null,
            'price_per_guest': price,
            ...extra,
          });
    if (!mounted) return;
    // 403 HALL_LIMIT (024/PO: har zal $21) — obuna bu zal sonini qoplamaydi:
    // modal yopiladi, PAYWALL zal soni bilan ochiladi (yana bir zal = +$21).
    if (!ok && toyRepo.lastCode == 'HALL_LIMIT') {
      setState(() {
        _busy = false;
        _hallEdit = null;
      });
      final want = toyRepo.halls.length + 1;
      if (want <= kToyMaxUnits) {
        store.openPaywallUnits_('toyxona', want);
      } else {
        _toastErr(ty('maxHallsNote', {'n': '$kToyMaxUnits'}));
      }
      await toyRepo.loadHalls();
      return;
    }
    setState(() {
      _busy = false;
      if (ok) _hallEdit = null;
    });
    ok ? _toastMsg(ty('hallSaved')) : _toastErr();
  }

  // ---- Narx toifasi qo'shish / tahrirlash ----

  void _askArchiveTier(String id, String title) {
    setState(() {
      _tierEdit = null;
      _confirm = {
        'title': ty('archiveTier'),
        'body': '$title\n${ty('priceSnapshotNote')}',
        'danger': true,
        'run': () async {
          final ok = await toyRepo.patchMenu(id, {'archived': true});
          if (!mounted) return;
          ok ? _toastMsg(ty('saved')) : _toastErr();
        },
      };
    });
  }

  // ================= KICHIK ELEMENTLAR =================

  /// Kichik chip (h32) — tez xizmatlar, to'lov turi, bo'sh zallar.
  Widget _smallChip(Pal p, String label, bool on, VoidCallback onTap) =>
      PillChip(label: label, selected: on, onTap: onTap, h: 32);

  /// Sana tanlash maydoni (GlassField ko'rinishida, bosilsa tanlagich).
  Widget _dateField(Pal p, String text, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: GlassField(
        h: 52,
        icon: Icons.calendar_today_rounded,
        iconColor: p.amber,
        trailing: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: p.t4),
        child: Tx(text, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
      ),
    );
  }

  /// Yorliqli maydon (Cap + GlassField ichida StoreField).
  Widget _field(
    Pal p,
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? hint,
    bool number = false,
    bool group = true,
    bool phone = false,
    bool decimal = false,
    int lines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(label),
        const SizedBox(height: 10),
        _inputBox(p, hint ?? '', value, onChanged,
            number: number, group: group, phone: phone, decimal: decimal, lines: lines, icon: icon),
      ],
    );
  }

  Widget _inputBox(
    Pal p,
    String hint,
    String value,
    ValueChanged<String> onChanged, {
    bool number = false,
    bool group = true,
    bool phone = false,
    bool decimal = false,
    int lines = 1,
    IconData? icon,
  }) {
    return GlassField(
      h: lines > 1 ? 52.0 + 22.0 * (lines - 1) : 52.0,
      icon: icon,
      focused: value.isNotEmpty,
      child: StoreField(
        value: value,
        onChanged: onChanged,
        hint: hint.isEmpty ? null : hint,
        keyboardType: phone
            ? TextInputType.phone
            : (decimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : (number ? TextInputType.number : TextInputType.text)),
        inputFormatters: phone ? [_PhoneFmt()] : (number && group ? [_GroupFmt()] : null),
        maxLines: lines,
        minLines: lines > 1 ? lines : 1,
        style: tbStyle(size: 15, color: p.ink, w: FontWeight.w500, tab: number || phone || decimal),
        hintColor: p.t5,
      ),
    );
  }
}
