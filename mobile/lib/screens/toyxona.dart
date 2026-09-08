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
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import '../toyxona_data.dart';
import '../toyxona_l10n.dart';

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
  final IconData? icon;
  final bool loading;
  final double h;
  const _MiniBtn(this.label, {required this.onTap, this.kind = 'glass', this.icon, this.loading = false, this.h = 36});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final gradient = kind == 'gradient';
    final mint = kind == 'mint';
    final fg = gradient ? Colors.white : (mint ? p.onMint : p.ink);
    return Tap(
      onTap: loading ? null : onTap,
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient ? Tb.brand : null,
          color: gradient ? null : (mint ? p.mint : p.glass2),
          border: gradient || mint ? null : Border.all(color: p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                  Tx(label, size: 13, w: FontWeight.w600, color: fg, maxLines: 1, font: TbFont.body),
                ],
              ),
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
  Map<String, dynamic>? _tierEdit; // {hallId, id?, title, price}

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
  bool _archOpen = false;

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
        _toastMsg(ty('oneVenueNote'));
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
            if (_venuesOpen && _tiersHallId == null) Positioned.fill(child: ScreenBg(child: _venuesView(p))),
            if (_tiersHallId != null) Positioned.fill(child: ScreenBg(child: _tiersView(p))),
            if (_monthMenu) _monthMenuCard(p),
            if (_confirm != null) _confirmModal(p),
            if (_hallEdit != null) _hallEditModal(p),
            if (_tierEdit != null) _tierEditModal(p),
            ToastView(open: _toast.isNotEmpty, text: _toast),
          ],
        );
      },
    );
    if (!widget.handleSystemBack) return body;
    // Preview rejimi: apparat "orqaga" ochiq qatlamni yopadi.
    return PopScope(
      canPop: !_anyLayer && _confirm == null && _hallEdit == null && _tierEdit == null && !_monthMenu,
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
          if (toyRepo.loading && toyRepo.loaded) ...[
            _loadingHint(p),
            const SizedBox(height: 12),
          ],
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
        const SizedBox(width: 14),
        dot(p.ink.withValues(alpha: .2)),
        const SizedBox(width: 6),
        Tx(ty('free'), size: 13, color: p.t2),
      ],
    );
  }

  /// Yengil yuklanish belgisi (F1) — skelet emas, kontent ustidagi bir qator.
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
                          Tx(ty('guestsN', {'n': '${b.guests}'}), size: 12, color: p.t4),
                          Tx(' · ', size: 12, color: p.t4),
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
    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // countActive — total/paid/left AYNAN shu bandlardan (bekor qilinganlarsiz),
          // ya'ni sarlavhadagi son pastdagi summa bilan kafolatli mos keladi.
          Cap(ty('summaryCap', {'month': '${tyMonth(_month.month)} ${_month.year}', 'n': '${s.countActive}'})),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Tx(toyMoney(s.total), size: 30, w: FontWeight.w600, color: p.mint, tab: true),
          ),
          const SizedBox(height: 6),
          Tx(ty('advanceLine', {'paid': toyMoney(s.paid), 'left': toyMoney(s.left)}), size: 13, color: p.t2, lh: 18),
          // Bekor qilingan bronlardan qolgan pul — ALOHIDA qator, faqat bor bo'lsa.
          // Yuqoridagi raqamlardan TINCHROQ (t3): bu bo'lib o'tgan to'y daromadi
          // emas, lekin egada qolgan pul — kassaga mos kelishi uchun ko'rinadi.
          if (s.cancelledPaid > 0) ...[
            const SizedBox(height: 8),
            // Bosiladigan: "qaysi bron edi?" — kassani solishtirayotgan ega
            // birinchi navbatda shuni so'raydi.
            Tap(
              onTap: () => setState(() => _cancelledOpen = true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Tx(ty('cancelledPaidLine', {'sum': toyMoney(s.cancelledPaid)}), size: 13, color: p.t3, lh: 18),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: p.t4),
                ],
              ),
            ),
          ],
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
    final numColor = today ? Colors.white : (past ? p.t6 : p.ink);
    return Tap(
      onTap: () => setState(() => _selDay = sel ? null : day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 52,
        decoration: BoxDecoration(
          gradient: today ? Tb.brandDiag : null,
          color: today ? null : (sel ? p.glass2 : p.ink.withValues(alpha: .03)),
          border: sel ? Border.all(color: p.violet, width: 1.5) : null,
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
                      color: booked.contains(s)
                          ? (today ? Colors.white : p.violet)
                          : (today ? Colors.white.withValues(alpha: .4) : p.ink.withValues(alpha: .15)),
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
        ? '${b.hallName} · ${tySlot(b.slot)} · ${ty('guestsN', {'n': '${b.guests}'})}'
        : '${tySlot(b.slot)} · ${ty('guestsN', {'n': '${b.guests}'})}';
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
                        ? '${b.hallName} · ${tySlot(b.slot)} · ${ty('guestsN', {'n': '${b.guests}'})}'
                        : '${tySlot(b.slot)} · ${ty('guestsN', {'n': '${b.guests}'})}',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 20),
      child: GradientBtn(
        label: ty('newBooking'),
        onTap: () => _openNewBooking(_selDay ?? _defaultDate(), 'kechki'),
      ),
    );
  }

  /// Yangi bron uchun standart sana: joriy oy ko'rilayotgan bo'lsa bugun,
  /// aks holda ko'rilayotgan oyning 1-kuni.
  DateTime _defaultDate() {
    final now = toyDay(DateTime.now());
    if (now.year == _month.year && now.month == _month.month) return now;
    return toyMonthStart(_month);
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
      _form = _FormData(
        date: date,
        slot: slot,
        hallId: hid,
        menuId: tiers.isNotEmpty ? tiers.first.id : null,
        price: tiers.isNotEmpty
            ? toyFx(tiers.first.pricePerGuest)
            : (hall != null && hall.pricePerGuest > 0 ? toyFx(hall.pricePerGuest) : ''),
      );
    });
    // U1: har ochilishda shu kun QAYTA so'raladi (kesh eskirgan bo'lishi
    // mumkin — masalan hozirgina yaratilgan/bekor qilingan bron).
    _dayFetched.remove(toyYmd(date));
    _ensureDay(date);
  }

  void _openEditBooking(Booking b) {
    setState(() {
      _form = _FormData(
        id: b.id,
        date: b.eventDate,
        slot: b.slot,
        hallId: b.hallId,
        menuId: b.menuId,
        // Tahrirda narx SNAPSHOT'dan keladi — toifa narxi keyin o'zgargan bo'lishi mumkin
        priceManual: true,
        name: b.clientName,
        phone: b.clientPhone,
        guests: '${b.guests}',
        price: toyFx(b.pricePerGuest),
        note: b.note,
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
                      b.menuTitle.isEmpty
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
              ] else ...[
                _totalRow(p, ty('totalLabel'), toyMoney(b.total), p.ink, big: true),
                const SizedBox(height: 8),
                _totalRow(p, ty('paidLabel'), toyMoney(b.paid), p.mint),
                const SizedBox(height: 8),
                _totalRow(p, ty('leftLabel'), toyMoney(b.left), _leftColor(b.left, p), big: true),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 'nom × soni' — summa esa amount × qty (U3; BookingItem.total)
          Expanded(
            flex: 3,
            child: Tx(it.qty > 1 ? '${it.title} × ${it.qty}' : it.title,
                size: 14, color: p.ink, maxLines: 1, ellipsis: true),
          ),
          const SizedBox(width: 8),
          // Pul kesilmaydi (F14)
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Tx(toyMoney(it.total), size: 14, w: FontWeight.w600, color: p.ink, tab: true),
            ),
          ),
          _xBtn(p, () => _askDeleteItem(it)),
        ],
      ),
    );
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in kToyQuickServiceKeys)
                _smallChip(p, ty(k), _svcTitle == ty(k), () => setState(() => _svcTitle = ty(k))),
            ],
          ),
          const SizedBox(height: 12),
          _field(p, ty('svcTitleLabel'), _svcTitle, (v) => setState(() => _svcTitle = v),
              hint: ty('svcTitlePh')),
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
    if (amount <= 0) {
      _toastMsg(ty('needTierPrice'));
      return;
    }
    setState(() => _busy = true);
    final ok = await toyRepo.addItem(b.id, title, amount, qty: _svcQty);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _svcOpen = false;
        _svcTitle = '';
        _svcAmount = '';
        _svcQty = 1;
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
        b.cancelled
            ? SolidBtn.coral(ty('deleteBooking'), () => _askDeleteBooking(b), icon: Icons.delete_outline_rounded)
            : TextBtn(label: ty('cancelBooking'), color: p.coral, onTap: () => _askCancelBooking(b)),
      ],
    );
  }

  void _askCancelBooking(Booking b) {
    setState(() => _confirm = {
          'title': ty('confirmCancelTitle'),
          'body': ty('confirmCancelBody', {
            'name': b.clientName,
            'date': toyDateLong(b.eventDate),
            'slot': tySlot(b.slot),
          }),
          'danger': true,
          'run': () async {
            final ok = await toyRepo.setStatus(b.id, 'bekor');
            if (!mounted) return;
            ok ? _toastMsg(ty('cancelled')) : _toastErr();
          },
        });
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

  Widget _formView(Pal p) {
    final f = _form!;
    final isNew = f.id == null;
    final halls = toyRepo.halls;
    final tiers = toyRepo.tiersOf(f.hallId);
    final guests = _digits(f.guests);
    final price = _digits(f.price);
    final total = guests * price;
    final tier = _tierById(tiers, f.menuId);

    return Column(
      children: [
        ScreenHeader(
          title: isNew ? ty('newTitle') : ty('editTitle'),
          onBack: () => setState(() => _form = null),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Sana ----
                Cap(ty('dateLabel')),
                const SizedBox(height: 10),
                _dateField(p, toyDateLong(f.date), () => _pickDate(f)),
                const SizedBox(height: 20),
                // ---- Vaqt (slot) ----
                // U1: band slot O'CHIQ chip + ostida mijoz nomi — ega telefonda
                // gaplashib turib "qaysi vaqt bo'sh"ni formadan chiqmay ko'radi.
                Cap(ty('slotLabel')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    for (final s in kToySlots) _slotPick(p, f, s),
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
                // ---- Narx toifasi ----
                if (tiers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Cap(ty('tierLabel')),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tiers)
                        _chip(
                          p,
                          ty('tierChip', {'title': t.title, 'price': toyFx(t.pricePerGuest)}),
                          f.menuId == t.id && !f.priceManual,
                          () => setState(() {
                            f.menuId = t.id;
                            f.priceManual = false;
                            f.price = toyFx(t.pricePerGuest);
                          }),
                        ),
                    ],
                  ),
                ] else if (f.hallId != null) ...[
                  const SizedBox(height: 10),
                  Tx(ty('noTiersHint'), size: 13, color: p.t4),
                ],
                const SizedBox(height: 20),
                // ---- Mijoz ----
                _field(p, ty('nameLabel'), f.name, (v) => setState(() => f.name = v),
                    hint: ty('namePh'), icon: Icons.person_outline_rounded),
                const SizedBox(height: 16),
                _field(p, ty('phoneLabel'), f.phone, (v) => setState(() => f.phone = v),
                    phone: true, icon: Icons.smartphone_rounded),
                const SizedBox(height: 16),
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
                // U4: sig'imdan oshsa OGOHLANTIRISH — bloklamaydi (qo'shimcha
                // stol qo'yish egalarning odatiy amaliyoti), faqat eslatadi.
                if (_capacityOver(f, guests) != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: p.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Tx(ty('overCapacity', {'n': '${_capacityOver(f, guests)}'}),
                            size: 13, w: FontWeight.w600, color: p.amber),
                      ),
                    ],
                  ),
                ],
                if (isNew) ...[
                  const SizedBox(height: 16),
                  _field(p, ty('advanceLabel'), f.advance, (v) => setState(() => f.advance = v),
                      number: true, icon: Icons.payments_outlined),
                ],
                const SizedBox(height: 16),
                _field(p, ty('noteLabel'), f.note, (v) => setState(() => f.note = v),
                    hint: ty('notePh'), lines: 3),
                const SizedBox(height: 24),
                // ---- Jonli hisob ----
                GlassCard(
                  r: Tb.rCard,
                  pad: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Cap(ty('previewCap')),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Tx(toyMoney(total), size: 32, w: FontWeight.w600, color: p.mint, tab: true),
                      ),
                      const SizedBox(height: 6),
                      Tx(
                        ty('foodLine', {
                          'guests': '$guests',
                          'price': toyFx(price),
                          'total': toyFx(total),
                        }),
                        size: 13, color: p.t2, lh: 18, tab: true,
                      ),
                      if (tier != null && !f.priceManual) ...[
                        const SizedBox(height: 3),
                        Tx(tier.title, size: 13, color: p.t4),
                      ],
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

  /// Slot chipi (U1): bo'sh slot — odatiy tanlanadigan chip (slot ikonkasi
  /// bilan); band slot — bosilmaydigan xira chip + ostida band qilgan mijoz
  /// nomi. Tahrirda bandning O'Z sloti tanlanadigan bo'lib qoladi (exceptId).
  Widget _slotPick(Pal p, _FormData f, String s) {
    final taken = toySlotTakenBy(
      _dayRows[toyYmd(f.date)] ?? const [],
      hallId: f.hallId,
      slot: s,
      exceptId: f.id,
    );
    if (taken == null) {
      final on = f.slot == s;
      return PillChip(
        label: tySlot(s),
        selected: on,
        leading: Icon(_slotIcon(s), size: 16, color: on ? p.bg : _slotColor(s, p)),
        onTap: () => setState(() => f.slot = s),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: p.glass2,
            border: Border.all(color: p.glassBd),
            borderRadius: BorderRadius.circular(Tb.rPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: p.t5),
              const SizedBox(width: 6),
              Tx(tySlot(s), size: 14, w: FontWeight.w600, color: p.t5, maxLines: 1, font: TbFont.body),
            ],
          ),
        ),
        const SizedBox(height: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Tx(taken.clientName, size: 11, color: p.t4, maxLines: 1, ellipsis: true),
          ),
        ),
      ],
    );
  }

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
    final name = f.name.trim();
    final guests = _digits(f.guests);
    if (name.isEmpty) {
      _toastMsg(ty('needName'));
      return;
    }
    if (guests <= 0) {
      _toastMsg(ty('needGuests'));
      return;
    }
    if (toyRepo.hasHalls && f.hallId == null) {
      _toastMsg(ty('needVenue'));
      return;
    }
    final price = _digits(f.price);
    final advance = _digits(f.advance);
    final body = <String, dynamic>{
      if (f.hallId != null) 'hall_id': f.hallId,
      'event_date': toyYmd(f.date),
      'slot': f.slot,
      'client_name': name,
      if (f.phone.trim().isNotEmpty) 'client_phone': f.phone.trim(),
      'guests': guests,
      // Narx ustuvorligi (backend shartnomasi, F10): aniq price_per_guest >
      // menu > to'yxona defaulti. menu_id + price_per_guest BIRGA yuborilishi
      // TO'G'RI — aniq narx g'olib, menu esa toifa NOMINI snapshot qiladi
      // (tahrir/qo'lda narx holati). Toifa tanlanib narx QO'LDA o'zgartirilmagan
      // bo'lsa faqat menu_id ketadi — narxni server toifadan o'zi nusxalaydi.
      if (f.menuId != null) 'menu_id': f.menuId,
      if (f.menuId == null || f.priceManual) 'price_per_guest': price,
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
          trailing: [
            if (halls.isEmpty) GlassIconBtn(icon: Icons.add_rounded, onTap: _openNewHall),
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
                  // Ishlamaydigan tugma o'rniga tinch tushuntirish
                  GlassCard(
                    r: Tb.rRow,
                    pad: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: p.t4),
                        const SizedBox(width: 8),
                        Expanded(child: Tx(ty('oneVenueNote'), size: 13, color: p.t2, lh: 18)),
                      ],
                    ),
                  ),
                ],
                // U10: arxivlangan to'yxonalar — yig'ilgan bo'lim. if/else'dan
                // TASHQARIDA: yagona to'yxona arxivlanganda ro'yxat bo'sh bo'ladi,
                // lekin qaytarish yo'li aynan shu yerda ochiq qolishi shart.
                if (toyRepo.archivedHalls.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Tap(
                    onTap: () => setState(() => _archOpen = !_archOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Cap(ty('archivedN', {'n': '${toyRepo.archivedHalls.length}'}))),
                          Icon(_archOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 20, color: p.t4),
                        ],
                      ),
                    ),
                  ),
                  if (_archOpen) ...[
                    const SizedBox(height: 10),
                    for (final h in toyRepo.archivedHalls) ...[
                      _archivedRow(p, h),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
                const SizedBox(height: 16),
                Tx(ty('priceSnapshotNote'), size: 13, color: p.t4, lh: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Arxivlangan to'yxona qatori (U10): nom xira + "Arxivdan qaytarish".
  /// Chegaradan oshsa server 403 HALL_LIMIT beradi — _toastErr uni 6 tilli
  /// oneVenueNote'ga aylantiradi, PAYWALL OCHILMAYDI (sotiladigan narsa yo'q).
  Widget _archivedRow(Pal p, Hall h) {
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: const Color(0x00000000),
      child: Row(
        children: [
          Icon(Icons.archive_outlined, size: 20, color: p.t4),
          const SizedBox(width: 12),
          Expanded(
            child: Tx(h.name, size: 14, w: FontWeight.w600, color: p.t3, maxLines: 1, ellipsis: true),
          ),
          const SizedBox(width: 10),
          _MiniBtn(ty('unarchive'), onTap: _busy ? null : () => _unarchiveHall(h)),
        ],
      ),
    );
  }

  Future<void> _unarchiveHall(Hall h) async {
    setState(() => _busy = true);
    final ok = await toyRepo.patchHall(h.id, {'archived': false});
    if (!mounted) return;
    setState(() => _busy = false);
    ok ? _toastMsg(ty('hallSaved')) : _toastErr();
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

  // ================= BITTA TO'YXONA: NARXLAR =================

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
    final tiers = h.tiers;
    return Column(
      children: [
        ScreenHeader(
          title: h.name,
          subtitle: tiers.isEmpty ? ty('noTiersN') : ty('tiersN', {'n': '${tiers.length}'}),
          onBack: () => setState(() => _tiersHallId = null),
          trailing: [
            GlassIconBtn(icon: Icons.edit_outlined, iconSize: 20, onTap: () => _openEditHall(h)),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Cap(ty('tiersCap')),
                const SizedBox(height: 12),
                GlassCard(
                  r: Tb.rCard,
                  child: tiers.isEmpty
                      ? SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                            child: Tx(ty('noTiers'), size: 14, color: p.t4, align: TextAlign.center, lh: 20),
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < tiers.length; i++)
                              _tierRow(p, h, tiers[i], last: i == tiers.length - 1),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                GlassBtn(label: ty('addTier'), h: 44, onTap: () => _openNewTier(h)),
                const SizedBox(height: 16),
                Tx(ty('priceSnapshotNote'), size: 13, color: p.t4, lh: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tierRow(Pal p, Hall h, Menu m, {required bool last}) {
    return ListRow(
      title: m.title,
      last: last,
      h: 60,
      onTap: () => _openEditTier(h, m),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Tx(toyMoney(m.pricePerGuest), size: 15, w: FontWeight.w600, color: p.ink, tab: true),
        ),
      ),
    );
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

  void _openNewHall() => setState(() => _hallEdit = {'name': '', 'cap': '', 'price': ''});

  void _openEditHall(Hall h) => setState(() => _hallEdit = {
        'id': h.id,
        'name': h.name,
        'cap': h.capacity == null ? '' : '${h.capacity}',
        'price': h.pricePerGuest > 0 ? toyFx(h.pricePerGuest) : '',
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
          _field(p, ty('priceLabel'), '${e['price']}', (v) => setState(() => e['price'] = v),
              number: true, icon: Icons.payments_outlined),
          const SizedBox(height: 24),
          GradientBtn(label: ty('save'), loading: _busy, onTap: () => _saveHall(e)),
          if (!isNew) ...[
            const SizedBox(height: 6),
            TextBtn(
              label: ty('archiveHall'),
              color: p.coral,
              onTap: () => _askArchiveHall('${e['id']}', '${e['name']}'),
            ),
          ],
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
    setState(() => _busy = true);
    final ok = e['id'] == null
        ? await toyRepo.createHall(name, capacity: cap > 0 ? cap : null, pricePerGuest: price)
        : await toyRepo.patchHall('${e['id']}', {
            'name': name,
            'capacity': cap > 0 ? cap : null,
            'price_per_guest': price,
          });
    if (!mounted) return;
    // 403 HALL_LIMIT — poyga holati: boshqa qurilmada to'yxona qo'shilgan.
    // Modalni yopamiz (qayta urinish foydasiz), server xabarini toast qilamiz va
    // ro'yxatni qayta o'qiymiz — ekran haqiqiy holatni ko'rsatsin. Paywall YO'Q.
    if (!ok && toyRepo.lastCode == 'HALL_LIMIT') {
      setState(() {
        _busy = false;
        _hallEdit = null;
      });
      _toastErr(ty('oneVenueNote'));
      await toyRepo.loadHalls();
      return;
    }
    setState(() {
      _busy = false;
      if (ok) _hallEdit = null;
    });
    ok ? _toastMsg(ty('hallSaved')) : _toastErr();
  }

  void _askArchiveHall(String id, String name) {
    setState(() {
      _hallEdit = null;
      _confirm = {
        'title': ty('archiveHall'),
        'body': name,
        'danger': true,
        'run': () async {
          final ok = await toyRepo.patchHall(id, {'archived': true});
          if (!mounted) return;
          if (ok) {
            setState(() => _tiersHallId = null);
            _toastMsg(ty('saved'));
          } else {
            _toastErr();
          }
        },
      };
    });
  }

  // ---- Narx toifasi qo'shish / tahrirlash ----

  void _openNewTier(Hall h) =>
      setState(() => _tierEdit = {'hallId': h.id, 'title': '', 'price': ''});

  void _openEditTier(Hall h, Menu m) => setState(() => _tierEdit = {
        'hallId': h.id,
        'id': m.id,
        'title': m.title,
        'price': toyFx(m.pricePerGuest),
      });

  Widget _tierEditModal(Pal p) {
    final e = _tierEdit!;
    final isNew = e['id'] == null;
    void close() => setState(() => _tierEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, isNew ? ty('newTier') : ty('editTier'), close),
          const SizedBox(height: 20),
          _field(p, ty('tierTitleLabel'), '${e['title']}', (v) => setState(() => e['title'] = v),
              hint: ty('tierTitlePh'), icon: Icons.star_rounded),
          const SizedBox(height: 16),
          _field(p, ty('tierPriceLabel'), '${e['price']}', (v) => setState(() => e['price'] = v),
              number: true, icon: Icons.payments_outlined),
          const SizedBox(height: 24),
          GradientBtn(label: ty('save'), loading: _busy, onTap: () => _saveTier(e)),
          if (!isNew) ...[
            const SizedBox(height: 6),
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

  Future<void> _saveTier(Map<String, dynamic> e) async {
    final title = '${e['title']}'.trim();
    final price = _digits('${e['price']}');
    if (title.isEmpty) {
      _toastMsg(ty('needTierTitle'));
      return;
    }
    if (price <= 0) {
      _toastMsg(ty('needTierPrice'));
      return;
    }
    setState(() => _busy = true);
    final ok = e['id'] == null
        ? await toyRepo.createMenu('${e['hallId']}', title, price)
        : await toyRepo.patchMenu('${e['id']}', {'title': title, 'price_per_guest': price});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _tierEdit = null;
    });
    ok ? _toastMsg(ty('tierSaved')) : _toastErr();
  }

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
    int lines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(label),
        const SizedBox(height: 10),
        _inputBox(p, hint ?? '', value, onChanged,
            number: number, group: group, phone: phone, lines: lines, icon: icon),
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
            : (number ? TextInputType.number : TextInputType.text),
        inputFormatters: number && group ? [_GroupFmt()] : null,
        maxLines: lines,
        minLines: lines > 1 ? lines : 1,
        style: tbStyle(size: 15, color: p.ink, w: FontWeight.w500, tab: number || phone),
        hintColor: p.t5,
      ),
    );
  }
}
