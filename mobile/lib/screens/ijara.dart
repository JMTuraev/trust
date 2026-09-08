// Ijaradagi uylar — ijaraga berilgan uylar, oylik hisoblar (ijara/kommunal/boshqa),
// to'lovlar va qoldiq. Dizayn: prototype/redesign/DESIGN_SPEC.md §5.12
// ("dark glass + gradient", 2026-09-07): ScreenHeader + PRO badge, oy chiplari,
// xulosa GlassCard (Kutilgan/Kelgan + progress), uylar 2 ustunli GlassCard grid,
// uy tafsiloti (asosiy karta 36/600 summa, TO'LOVLAR ro'yxati, pastda mint CTA),
// modallar SheetShell ichida.
//
// TUZILISH (bitta ildiz ekran + to'liq-ekran qatlam, main.dart Stack idiomasi):
//   1) UYLAR RO'YXATI — oylik xulosa, har uy: ijarachi, qoldiq, muddati o'tgan
//   2) UY TAFSILOTI   — ijarachi, balans, davr hisoblari, to'lovlar
//   3) MODALLAR       — uy / hisob / to'lov formasi, tasdiq, chegara xabari
//
// PUL QOIDASI (loyiha talabi): summalar HECH QACHON "..." bilan kesilmaydi —
// FittedBox(scaleDown); nom va sarlavhalar 2 qatorga o'raladi (maxLines: 2).
//
// HAMMA matn ijara_l10n.dart dan (6 til). HAMMA HTTP ijara_data.dart da.
// 402 (bepul limit) modulda EMAS — Api.onPaymentRequired(code, 'ijarachi')
// umumiy paywall'ni ochadi (ijara_data.dart _req ichida).
//
// REDIZAYN (2026-09-08): faqat VIZUAL qatlam almashdi. Holat mashinasi
// (_detailId / modallar / _monthMenu), store.setModuleBack_ hook'i, onBack,
// ijaraRepo chaqiruvlari va matn kalitlari AYNAN saqlangan.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        TextInputFormatter,
        TextEditingValue,
        TextSelection;
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../ui.dart';
import '../store.dart';
import '../ijara_data.dart';
import '../ijara_l10n.dart';

/// Summani jonli "x xxx xxx" ko'rinishida guruhlovchi formatter — KURSORNI
/// SAQLAYDI (F10): client_screen.dart dagi tekshirilgan implementatsiyaning
/// lokal nusxasi (ekranlar bir-birini import qilmaydi — loyiha qoidasi).
/// Eski variant kursorni doim satr oxiriga otib yuborardi — o'rtadan
/// tahrirlashda raqam "sakrab" ketardi.
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

/// 023 — O'zbekiston telefon maskasi: "+998 90 123 45 67".
///
/// KURSOR HAR DOIM OXIRDA. _GroupFmt dagi kursor saqlash hiylasi bu yerda
/// ATAYLAB ISHLATILMADI: prefiks ("+998 ") majburiy qo'yilgani uchun kursorni
/// o'rtaga tiklash foydalanuvchini prefiks ichiga tushirib qo'yardi va u
/// terganida raqam prefiksdan oldin paydo bo'lardi. Telefon raqami ketma-ket
/// teriladi — o'rtadan tahrirlash real ehtiyoj emas.
///
/// "998" ni FAQAT BIR MARTA olib tashlaydi: milliy raqam ham 998 bilan
/// boshlanishi mumkin (99 8xx xx xx) — ikki marta kesilsa raqam yo'qolardi.
class _PhoneFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final t = ijPhoneMask(newV.text);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Xom matndan milliy 9 ta raqam ("901234567"). To'liq bo'lmasa qisqaroq.
String ijPhoneNat(String s) {
  var d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('998')) d = d.substring(3);
  return d.length > 9 ? d.substring(0, 9) : d;
}

/// "+998 90 123 45 67" ko'rinishi. Bo'sh kirsa — bo'sh chiqadi (maydon
/// "+998 " bilan to'lib turmasin, aks holda hint ko'rinmaydi va bo'sh
/// raqam "kiritilgan" bo'lib serverga ketardi).
String ijPhoneMask(String s) {
  final d = ijPhoneNat(s);
  if (d.isEmpty) return '';
  final b = StringBuffer('+998 ');
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 5 || i == 7) b.write(' ');
    b.write(d[i]);
  }
  return b.toString();
}

/// Raqam O'ZBEKISTON shaklidami: 9 ta milliy raqam yoki 998 + 9 ta.
///
/// NEGA shunchaki "9 ta raqam bormi" DEB TEKSHIRILMAYDI: chet el raqamida
/// ham 9 dan ortiq raqam bo'ladi va uni kesib maskaga solish boshqa odamning
/// telefonini BUZIB YUBORARDI (+7 495 123 45 67 -> +998 74 951 23 45).
bool ijPhoneIsUz(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  return d.length == 9 || (d.length == 12 && d.startsWith('998'));
}

/// Saqlangan raqamni ko'rsatishga tayyorlaydi: O'zbekiston shaklida bo'lsa
/// maska qo'llanadi, aks holda (chet el raqami, eski yozuv) MATN O'ZGARMAYDI.
String ijPhoneShow(String s) {
  final raw = s.trim();
  if (raw.isEmpty) return '';
  return ijPhoneIsUz(raw) ? ijPhoneMask(raw) : raw;
}

/// Saqlashga tayyorlaydi. '' = raqam kiritilmagan (bu ham to'g'ri holat),
/// null = CHALA raqam — saqlanmaydi, ega xabar ko'radi.
String? ijPhoneNorm(String s) {
  final raw = s.trim();
  if (raw.isEmpty) return '';
  if (ijPhoneIsUz(raw)) return ijPhoneMask(raw);
  final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  // Maska bilan terilayotgan, hali tugallanmagan raqam
  if (raw.startsWith('+998') || d.length < 9) return null;
  // Chet el / eski yozuv — TEGILMAYDI
  return raw;
}

int _digits(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return 0;
  return int.tryParse(d.length > 15 ? d.substring(0, 15) : d) ?? 0;
}

/// Ism -> bosh harflar ("Alisher aka" -> "AA"), avatar uchun.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final a = parts.first.substring(0, 1);
  final b = parts.length > 1 ? parts[1].substring(0, 1) : '';
  return (a + b).toUpperCase();
}

/// Qatorga sig'adigan ixcham pill tugma (h36, px14). GradientBtn/GlassBtn/SolidBtn
/// to'liq kenglik uchun mo'ljallangan (ichki chet yo'q) — banner/qator ichida
/// bu ishlatiladi. kind: 'gradient' | 'glass' | 'mint'.
class _MiniBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final String kind;
  final IconData? icon;
  final bool loading;
  const _MiniBtn(this.label, {required this.onTap, this.kind = 'glass', this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final gradient = kind == 'gradient';
    final mint = kind == 'mint';
    final fg = gradient ? Colors.white : (mint ? p.onMint : p.ink);
    return Tap(
      onTap: loading ? null : onTap,
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

class IjaraScreen extends StatefulWidget {
  /// Hub'ga qaytish. null bo'lsa orqaga tugmasi ko'rinmaydi (preview rejimi).
  final VoidCallback? onBack;

  /// Apparat "orqaga" tugmasini SHU ekran boshqarsinmi. Hub ichida FALSE
  /// bo'lishi kerak — u yerda main.dart'dagi Root PopScope boshqaradi
  /// (ikkita PopScope bir vaqtda ishlab, ikki qavat orqaga ketib qolmasin).
  final bool handleSystemBack;

  const IjaraScreen({super.key, this.onBack, this.handleSystemBack = false});

  @override
  State<IjaraScreen> createState() => _IjaraScreenState();
}

class _IjaraScreenState extends State<IjaraScreen> {
  DateTime _month = ijMonthStart(DateTime.now());

  // To'liq-ekran qatlam
  String? _detailId;

  // Anchored menyu / modallar
  bool _monthMenu = false;
  bool _capOpen = false; // 5 ta uy chegarasi xabari
  Map<String, dynamic>? _confirm; // {title, body, danger, run}
  Map<String, dynamic>? _houseEdit; // {id?, name}
  // 023: ijarachi ALOHIDA forma — uy avval kiritiladi, ijarachi kartochka
  // ichidan qo'shiladi (uy ijarachisiz ham bo'ladi).
  Map<String, dynamic>? _tenantEdit; // {houseId, name, phone, rent, cur, dueDay, had}
  Map<String, dynamic>? _chargeEdit; // {houseId, id?, kind, title, amount, due}
  Map<String, dynamic>? _payEdit; // {houseId, chargeId, amount, date, note}

  // U2: oy generatori tasdiqlash varag'i (null = yopiq) va yozish jarayoni
  List<House>? _gen;
  bool _genBusy = false;
  int _genDone = 0;

  // U4: sarlavha pill filtri ('pending' | 'overdue' | 'paid' | null = hammasi)
  String? _pillFilter;

  // U7: arxiv bo'limi ochiq-yopiqligi va qaytarilayotgan uy id'si
  bool _archOpen = false;
  String _unarchBusy = '';

  bool _busy = false;
  String _toast = '';
  Timer? _toastT;

  /// Store'ga beriladigan qatlam-yopgich. AYNAN shu obyekt saqlanadi
  /// (dispose'da store.clearModuleBack_ uni tenglik bo'yicha topsin).
  late final bool Function() _backHook = _closeTop;

  @override
  void initState() {
    super.initState();
    // F9: modulga har kirishda ko'riladigan oy JORIY oyga qaytadi — ega kecha
    // qaysi oyni ko'rgani bugungi ishiga xalaqit bermasin.
    _month = ijMonthStart(DateTime.now());
    // Apparat "orqaga": modul QATLAMLARI (uy tafsiloti, forma modallari, oy
    // menyusi) State ichida yashaydi va store ularni ko'rmaydi. Root PopScope
    // (main.dart) shu hook orqali AVVAL ularni yopadi, keyingina hub'ga
    // qaytaradi — aks holda ochiq forma bilan birga kiritilgan summa yo'qolardi
    // (review 2026-08-04, FINDING 2). PopScope BU YERDA qo'yilmaydi: ikkita
    // PopScope bir bosishda ikki qavat orqaga ketardi.
    store.setModuleBack_(_backHook);
    // Birinchi kadrdan keyin yuklaymiz (initState ichida setState bo'lmasin).
    // enter() (F5): uylar KESHDAN darhol ko'rinadi, ro'yxat esa har kirishda
    // serverdan yangilanadi — kesh bo'lsa skelet emas, yupqa progress chiziladi.
    WidgetsBinding.instance.addPostFrameCallback((_) => ijaraRepo.enter());
  }

  @override
  void dispose() {
    store.clearModuleBack_(_backHook);
    _toastT?.cancel();
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

  /// Repo xatosini ko'rsatish.
  ///
  /// MUHIM (review 2026-08-04, FINDING 7): serverning chegara/obuna matnlari
  /// FAQAT o'zbekcha yoziladi (src/routes/ijara.js) — ruscha yoki inglizcha
  /// ishlatayotgan ega ularni tushunmasdi. Shuning uchun TANILGAN kodlar
  /// modulning O'Z (6 tilli) matniga aylantiriladi:
  ///   HOUSE_LIMIT (403, QAT'IY chegara) -> uylar chegarasi modali,
  ///   SUB_EXPIRED (402, bepul limit)    -> lokalizatsiyalangan xabar
  ///                                        (paywall'ni _req allaqachon ochgan).
  /// Tanilmagan kodda — serverning matni (bo'lmasa umumiy xato) qoladi:
  /// validatsiya xabarlari aniqroq bo'lgani uchun ular yashirilmaydi.
  void _toastErr([String? fallback]) {
    switch (ijaraRepo.lastCode) {
      case 'HOUSE_LIMIT':
        setState(() {
          _houseEdit = null; // forma yopiladi — bu chegarani obuna OCHMAYDI
          _capOpen = true;
        });
        return;
      case 'SUB_EXPIRED':
        _toastMsg(ij('errSubExpired'));
        return;
    }
    final e = ijaraRepo.error;
    final detail = ijaraRepo.lastDetail;
    final base = (e == null || e.isEmpty) ? (fallback ?? ij('errGeneric')) : e;
    _toastMsg(detail.isEmpty ? base : '$base · $detail');
  }

  /// Hisob holati rangi: to'langan mint, kechikkan coral, kutilmoqda/qisman amber.
  Color _stateColor(String state, Pal p) => switch (state) {
        'tolangan' => p.mint,
        'kechikkan' => p.coral,
        'bekor' => p.t4,
        'qisman' => p.amber,
        'kutish' => p.amber,
        _ => p.t1,
      };

  IconData _stateIcon(String state) => switch (state) {
        'tolangan' => Icons.check_rounded,
        'kechikkan' => Icons.error_outline_rounded,
        'bekor' => Icons.close_rounded,
        _ => Icons.schedule_rounded,
      };

  /// Qoldiq rangi: to'lanmagan qism coral, yopilgan (yoki ortiqcha) mint.
  Color _leftColor(int left, Pal p) => left > 0 ? p.coral : p.mint;

  bool get _anyLayer => _detailId != null;

  bool get _anyModal =>
      _confirm != null ||
      _houseEdit != null ||
      _tenantEdit != null ||
      _chargeEdit != null ||
      _payEdit != null ||
      _gen != null ||
      _capOpen ||
      _monthMenu;

  /// Eng ustki qatlamni yopadi. true — nimadir yopildi.
  bool _closeTop() {
    if (_confirm != null) {
      setState(() => _confirm = null);
      return true;
    }
    if (_capOpen) {
      setState(() => _capOpen = false);
      return true;
    }
    if (_gen != null) {
      // Yozish KETAYOTGANDA yopilmaydi (bosish yutiladi) — yarim yozilgan
      // oy bilan modal g'oyib bo'lib qolmasin.
      if (!_genBusy) setState(() => _gen = null);
      return true;
    }
    if (_payEdit != null) {
      setState(() => _payEdit = null);
      return true;
    }
    if (_chargeEdit != null) {
      setState(() => _chargeEdit = null);
      return true;
    }
    if (_tenantEdit != null) {
      setState(() => _tenantEdit = null);
      return true;
    }
    if (_houseEdit != null) {
      setState(() => _houseEdit = null);
      return true;
    }
    if (_monthMenu) {
      setState(() => _monthMenu = false);
      return true;
    }
    if (_detailId != null) {
      setState(() => _detailId = null);
      return true;
    }
    return false;
  }

  // ---------------- Ildiz ----------------

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: ijaraRepo,
      builder: (context, _) {
        final p = curPal();
        return Stack(
          children: [
            Column(
              children: [
                _header(p),
                Expanded(child: _listBody(p)),
              ],
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar(p)),
            // Uy tafsiloti — to'liq-ekran qatlam (o'z foni: ScreenBg)
            if (_detailId != null) Positioned.fill(child: ScreenBg(child: _detail(p))),
            if (_monthMenu) _monthMenuCard(p),
            if (_capOpen) _capModal(p),
            if (_gen != null) _genModal(p),
            if (_confirm != null) _confirmModal(p),
            if (_houseEdit != null) _houseModal(p),
            if (_tenantEdit != null) _tenantModal(p),
            if (_chargeEdit != null) _chargeModal(p),
            if (_payEdit != null) _payModal(p),
            ToastView(open: _toast.isNotEmpty, text: _toast),
          ],
        );
      },
    );
    if (!widget.handleSystemBack) return body;
    // Preview rejimi: apparat "orqaga" ochiq qatlamni yopadi.
    return PopScope(
      canPop: !_anyLayer && !_anyModal,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeTop();
      },
      child: body,
    );
  }

  // ================= SARLAVHA =================

  /// ScreenHeader (nom + PRO badge, sub: "3 / 5" uylar soni/chegara) va ostida
  /// oy chiplari (oxirgi 3 oy + tanlangan oy + kalendar tugmasi -> to'liq menyu).
  Widget _header(Pal p) {
    final n = ijaraRepo.houses.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: ij('title'),
          // Uylar soni / chegara — "3 / 5" (faqat raqam, tarjima talab qilmaydi)
          subtitle: '$n / ${ijaraRepo.maxHouses}',
          titleTrailing: PillBadge.pro(),
          onBack: widget.onBack,
        ),
        const SizedBox(height: 14),
        _monthChips(p),
      ],
    );
  }

  /// Oy chiplari: joriy oy va undan oldingi 2 oy; tanlangan oy ular orasida
  /// bo'lmasa chetiga qo'shiladi. Oxirida kalendar tugmasi — to'liq oy menyusi
  /// (24 oy orqaga / 6 oldinga, F9).
  Widget _monthChips(Pal p) {
    final now = ijMonthStart(DateTime.now());
    final recent = [for (var i = -2; i <= 0; i++) DateTime(now.year, now.month + i, 1)];
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
    final selIn = recent.any((d) => same(d, _month));
    final chips = selIn
        ? recent
        : (_month.isBefore(recent.first) ? [_month, ...recent] : [...recent, _month]);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Tb.padX),
      child: Row(
        children: [
          for (final m in chips) ...[
            PillChip(
              label: '${ijMonth(m.month)} ${m.year}',
              selected: same(m, _month),
              onTap: () => _pickMonth(m),
            ),
            const SizedBox(width: 8),
          ],
          GlassIconBtn(
            icon: Icons.calendar_today_rounded,
            size: 40,
            iconSize: 18,
            onTap: () => setState(() => _monthMenu = true),
          ),
        ],
      ),
    );
  }

  /// Oy tanlash — header trigger ostidagi anchored shisha menyu.
  /// F9: variantlar TANLANGAN oy atrofida (24 oy orqaga / 6 oldinga) quriladi,
  /// joriy oy esa doim ro'yxatda (kerak bo'lsa chetiga qadaladi) va halqa
  /// belgisi bilan ajralib turadi — bir bosishda bugunga qaytish oson.
  Widget _monthMenuCard(Pal p) {
    final now = DateTime.now();
    final opts = ijMonthOptions(_month, now: now);
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _monthMenu = false),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: 112,
            right: Tb.padX,
            child: GlassCard(
              r: Tb.rRow,
              color: p.surface,
              shadow: Tb.panelShadow,
              child: Container(
                constraints: const BoxConstraints(minWidth: 196, maxHeight: 330),
                child: IntrinsicWidth(
                  child: SingleChildScrollView(
                    reverse: true, // tanlangan oy (oxiriga yaqin) ko'rinib tursin
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < opts.length; i++)
                          _menuRow(
                            p,
                            '${ijMonth(opts[i].month)} ${opts[i].year}',
                            opts[i].year == _month.year && opts[i].month == _month.month,
                            i == 0,
                            () => _pickMonth(opts[i]),
                            current: opts[i].year == now.year && opts[i].month == now.month,
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
  /// `current` (joriy oy, tanlanmagan bo'lsa) — to'ldirilmagan halqa belgisi.
  Widget _menuRow(Pal p, String label, bool on, bool first, VoidCallback onTap,
      {bool current = false}) {
    return Tap(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 14, w: on || current ? FontWeight.w600 : FontWeight.w500, color: on ? p.ink : p.t1),
            if (on) ...[
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(gradient: Tb.brandDiag, shape: BoxShape.circle),
              ),
            ] else if (current) ...[
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
      _month = ijMonthStart(m);
      _pillFilter = null; // filtr oyga bog'liq edi — yangi oyda chalg'itmasin
    });
    ijaraRepo.load(_month);
  }

  // ================= UYLAR RO'YXATI =================

  Widget _listBody(Pal p) {
    if (ijaraRepo.loading && !ijaraRepo.loaded) return _skeleton(p);
    // Backend yo'q (404) bo'lsa error null qoladi — bu yerga TUSHMAYDI, pastda
    // odatdagi "hali uy qo'shilmagan" bo'sh holati chiziladi.
    if (ijaraRepo.error != null && !ijaraRepo.loaded) return _errorState(p);
    // F1: oy almashayotganda (kesh bor, yangi davr yuklanmoqda) ro'yxat xira
    // bo'ladi va tepada yupqa progress chizig'i ko'rinadi — almashish sezilsin.
    final refreshing = ijaraRepo.loading && ijaraRepo.loaded;
    final all = ijaraRepo.houses;
    // U4: pill filtri — faqat shu holatdagi hisobi bor uylar qoladi.
    final houses = _pillFilter == null
        ? all
        : [
            for (final h in all)
              if (ijHouseMatchesPill(_pillFilter!, ijaraRepo.chargesOf(h.id))) h,
          ];
    // U2: shu oy uchun ijara hisobi yozilmagan uylar (banner uchun).
    final missing = ijMissingRentHouses(all, ijaraRepo.charges);
    final archived = ijaraRepo.archivedHouses;
    final list = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(p),
          // F1: davr yuklanmadi — eski oy sonlari o'rniga banner + qayta urinish
          if (ijaraRepo.loaded && ijaraRepo.loadError != null) ...[
            const SizedBox(height: 12),
            _periodErrorBanner(p),
          ] else if (missing.isNotEmpty && !refreshing) ...[
            const SizedBox(height: 12),
            _genBanner(p, missing),
          ],
          const SizedBox(height: 24),
          if (all.isEmpty)
            _noHousesCard(p)
          else ...[
            Cap(ij('housesCap')),
            const SizedBox(height: 12),
            // Filtr faol-u mos uy yo'q — ro'yxat o'rniga qisqa izoh
            if (houses.isEmpty && _pillFilter != null)
              Tx(ij('pillEmpty'), size: 14, color: p.t4)
            else
              _houseGrid(p, houses),
            if (!ijaraRepo.canAddHouse) ...[
              const SizedBox(height: 12),
              Tx(ij('capNote', {'n': '${ijaraRepo.maxHouses}'}), size: 13, color: p.t4, lh: 18),
            ],
          ],
          // U7: arxivlangan uylar — ro'yxat oxirida yig'ma bo'lim
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 28),
            Tap(
              onTap: () => setState(() => _archOpen = !_archOpen),
              child: Row(
                children: [
                  Expanded(
                    child: Tx(ij('archivedSection', {'n': '${archived.length}'}).toUpperCase(),
                        size: 13, w: FontWeight.w700, color: p.t4, ls: 1.5, maxLines: 1, ellipsis: true,
                        font: TbFont.body),
                  ),
                  Icon(_archOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20, color: p.t4),
                ],
              ),
            ),
            if (_archOpen) ...[
              const SizedBox(height: 12),
              for (final h in archived) _archivedRow(p, h),
            ],
          ],
        ],
      ),
    );
    return Stack(
      children: [
        AnimatedOpacity(
          opacity: refreshing ? 0.55 : 1,
          duration: const Duration(milliseconds: 150),
          child: list,
        ),
        if (refreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: const Color(0x00000000),
              valueColor: AlwaysStoppedAnimation<Color>(p.cyan),
            ),
          ),
      ],
    );
  }

  /// F1: oy hisoblari yuklanmadi — sarlavha ishlayveradi, ro'yxat tanasida
  /// sabab + qayta urinish (eski oy qatorlari allaqachon tozalangan).
  Widget _periodErrorBanner(Pal p) {
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
                Tx(ij('periodLoadFailed'), size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2, lh: 18),
                if ('${ijaraRepo.loadError}'.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Tx('${ijaraRepo.loadError}', size: 12, color: p.t4, maxLines: 2, ellipsis: true, lh: 16),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniBtn(ij('retry'), onTap: () => ijaraRepo.load(_month)),
        ],
      ),
    );
  }

  /// U2: "bu oyda N ta uyga hisob yozilmagan" banneri — tasdiqlash varag'ini ochadi.
  Widget _genBanner(Pal p, List<House> missing) {
    return GlassCard(
      r: Tb.rRow,
      pad: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: p.violet.withValues(alpha: .10),
      border: p.violet.withValues(alpha: .30),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, size: 20, color: p.violet),
          const SizedBox(width: 10),
          Expanded(
            child: Tx(ij('genChargesBanner', {'n': '${missing.length}'}),
                size: 14, color: p.ink, lh: 18, maxLines: 3, ellipsis: true),
          ),
          const SizedBox(width: 10),
          _MiniBtn(
            ij('genChargesBtn'),
            kind: 'gradient',
            onTap: () => setState(() {
              _gen = missing;
              _genDone = 0;
            }),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(Pal p) {
    Widget pair() => const Row(
          children: [
            Expanded(child: Skel(h: 172, r: 20)),
            SizedBox(width: 12),
            Expanded(child: Skel(h: 172, r: 20)),
          ],
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skel(h: 150, r: 24),
          const SizedBox(height: 24),
          const Skel(w: 72, h: 13, r: 6),
          const SizedBox(height: 12),
          pair(),
          const SizedBox(height: 12),
          pair(),
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
            Tx(ij('loadFailed'), size: 15, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(ijaraRepo.error ?? '', size: 13, color: p.t4, align: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: 170,
              child: GlassBtn(label: ij('retry'), onTap: () => ijaraRepo.load(_month), h: 44),
            ),
          ],
        ),
      ),
    );
  }

  /// Xulosa kartasi (§5.12): 2 ustun "Hisoblandi" / "To'langan" (mint), progress
  /// bar (to'langan ulushi), ostida qoldiq qatori (ortiqcha to'lov / kechikkan
  /// hisoblar soni), keyin holat filtri chiplari (U4).
  Widget _summary(Pal p) {
    final n = ijaraRepo.houses.length;
    final curs = ijaraRepo.currenciesInUse;
    // 023: bir nechta valyuta ishlatilsa yakunlar QO'SHILMAYDI — har valyuta
    // uchun alohida karta chiziladi (so'm + dollar bitta songa aylansa bu
    // ekrandagi eng katta pul xatosi bo'lardi).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ij('summaryCap', {'month': '${ijMonth(_month.month)} ${_month.year}', 'n': '$n'})),
        for (var i = 0; i < curs.length; i++) ...[
          const SizedBox(height: 12),
          _summaryCard(p, curs[i], curs.length > 1),
        ],
        _summaryPills(p),
      ],
    );
  }

  /// Bitta valyuta uchun xulosa kartasi.
  Widget _summaryCard(Pal p, String cur, bool multi) {
    final t = multi ? ijaraRepo.periodTotalsOf(cur) : ijaraRepo.periodTotals;
    // F3: manfiy qoldiq = ORTIQCHA to'lov. Yalang'och absolyut son chiqmaydi:
    // '+' belgisi + mint + "Oldindan to'langan" izohi (qarz bilan adashmasin).
    final over = t.left < 0;
    final overdueN = ijaraRepo.houses
        .where((h) => !multi || h.currency == cur)
        .fold<int>(0, (s, h) => s + ijaraRepo.overdueOf(h.id));
    final ratio = t.charged > 0 ? (t.paid / t.charged).clamp(0.0, 1.0) : 0.0;
    final leftTxt = over ? '+${ijFx(t.left)} ${ijCurSym(cur)}' : ijMoneyCur(t.left, cur);

    Widget col(String label, String value, Color c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(label, size: 14, color: p.t2, maxLines: 1, ellipsis: true),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(value, size: 24, w: FontWeight.w600, color: c, tab: true),
            ),
          ],
        );

    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: col(ij('chargedLabel'), ijMoneyCur(t.charged, cur), p.ink)),
              const SizedBox(width: 16),
              Expanded(child: col(ij('paidLabel'), ijMoneyCur(t.paid, cur), p.mint)),
            ],
          ),
          const SizedBox(height: 16),
          // Progress: to'langan / hisoblangan (mint -> cyan)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: p.ink.withValues(alpha: .10)),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    alignment: Alignment.centerLeft,
                    child: Container(decoration: const BoxDecoration(gradient: Tb.mintCyan)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Sarlavha raqami — QOLDIQ (ega uchun eng muhim son: yig'ilmagan pul).
          Row(
            children: [
              Tx('${ij('leftLabel')} ', size: 13, color: p.t2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Tx(leftTxt, size: 13, w: FontWeight.w600, color: _leftColor(t.left, p), tab: true),
                ),
              ),
              if (over) ...[
                Tx(' · ', size: 13, color: p.t2),
                Flexible(
                  child: Tx(ij('overpaidNote'), size: 13, w: FontWeight.w600, color: p.mint, maxLines: 1, ellipsis: true),
                ),
              ] else if (overdueN > 0) ...[
                Tx(' · ', size: 13, color: p.t2),
                Flexible(
                  child: Tx(overdueN == 1 ? ij('overdue') : ij('overdueN', {'n': '$overdueN'}),
                      size: 13, w: FontWeight.w600, color: p.coral, maxLines: 1, ellipsis: true),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// U4: oy holat chiplari — bosilsa ro'yxat shu holat bo'yicha filtrlanadi.
  /// 023: aralash valyutada chip yig'indisi ma'nosiz bo'lardi, shuning uchun
  /// unda faqat YORLIQ ko'rsatiladi (filtr o'zi avvalgidek ishlaydi).
  Widget _summaryPills(Pal p) {
    final multi = ijaraRepo.mixedCurrency;
    final pills = ijPillSums(ijaraRepo.charges, ijaraRepo.payments);
    final anyPill =
        (pills['pending'] ?? 0) != 0 || (pills['overdue'] ?? 0) != 0 || (pills['paid'] ?? 0) != 0;
    if (!anyPill) return const SizedBox.shrink();
    final cur = ijaraRepo.currenciesInUse.first;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(p, 'pending', ij('pillPending'), multi ? null : pills['pending'] ?? 0, p.amber, cur),
          _pill(p, 'overdue', ij('pillOverdue'), multi ? null : pills['overdue'] ?? 0, p.coral, cur),
          _pill(p, 'paid', ij('pillPaid'), multi ? null : pills['paid'] ?? 0, p.mint, cur),
        ],
      ),
    );
  }

  /// U4: bitta holat chipi (PillChip h36). Rang nuqtasi holatni bildiradi
  /// (kechikkan — coral, to'langan — mint, kutilmoqda — amber).
  Widget _pill(Pal p, String key, String label, int? sum, Color accent, String cur) {
    final on = _pillFilter == key;
    return PillChip(
      h: 36,
      label: sum == null ? label : '$label · ${ijFx(sum)} ${ijCurSym(cur)}',
      selected: on,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: on ? p.bg : accent, shape: BoxShape.circle),
      ),
      onTap: () => setState(() => _pillFilter = on ? null : key),
    );
  }

  Widget _noHousesCard(Pal p) {
    return GlassCard(
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
              child: Icon(Icons.apartment_rounded, size: 26, color: p.t2),
            ),
            const SizedBox(height: 16),
            Tx(ij('noHousesTitle'), size: 15, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(ij('noHousesSub'), size: 13, color: p.t4, align: TextAlign.center, lh: 18),
          ],
        ),
      ),
    );
  }

  /// Uylar — 2 ustunli grid (gap 12); har qatordagi kartalar bo'yi teng
  /// (IntrinsicHeight + stretch).
  Widget _houseGrid(Pal p, List<House> houses) {
    final rows = <Widget>[];
    for (var i = 0; i < houses.length; i += 2) {
      final a = houses[i];
      final b = i + 1 < houses.length ? houses[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _houseCard(p, a)),
            const SizedBox(width: 12),
            Expanded(child: b == null ? const SizedBox.shrink() : _houseCard(p, b)),
          ],
        ),
      ));
      if (i + 2 < houses.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  /// Uyning oylik holat nishoni (ro'yxat kartasi va tafsilot kartasi uchun bir xil).
  Widget _houseBadge(Pal p, House h) {
    final t = ijaraRepo.totalsOf(h.id);
    final overdue = ijaraRepo.overdueOf(h.id);
    final hasCharges = ijaraRepo.chargesOf(h.id).isNotEmpty;
    if (overdue > 0) {
      return PillBadge.coral(overdue == 1 ? ij('overdue') : ij('overdueN', {'n': '$overdue'}),
          icon: Icons.error_outline_rounded);
    }
    if (!hasCharges) return PillBadge.muted(ij('noChargeMonth'));
    if (t.left <= 0) return PillBadge.mint(ij('pillPaid'), icon: Icons.check_rounded);
    if (t.paid > 0) return PillBadge.amber(ij('stQisman'), icon: Icons.schedule_rounded);
    return PillBadge.amber(ij('pillPending'), icon: Icons.schedule_rounded);
  }

  /// Uy kartasi (§5.12): 40px r14 ikonka · nom 15/600 · ijarachi 13 t2 ·
  /// qoldiq 16/600 num (mint/coral/amber) · holat badge · ixcham harakat
  /// (U1 "To'lov keldi" / U6 "+ Hisob").
  Widget _houseCard(Pal p, House h) {
    final t = ijaraRepo.totalsOf(h.id);
    final overdue = ijaraRepo.overdueOf(h.id);
    final hasCharges = ijaraRepo.chargesOf(h.id).isNotEmpty;
    // Summa rangi: kechikkan coral · to'langan mint · kutilmoqda/qisman amber
    final sumColor = overdue > 0 ? p.coral : (!hasCharges ? p.t3 : (t.left <= 0 ? p.mint : p.amber));
    return Tap(
      onTap: () => setState(() => _detailId = h.id),
      child: GlassCard(
        key: ValueKey('ijHouse_${h.id}'),
        r: Tb.rRow,
        pad: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.glass2,
                border: Border.all(color: p.glassBd),
                borderRadius: BorderRadius.circular(Tb.rIcon),
              ),
              child: Icon(Icons.apartment_rounded, size: 20, color: p.t1),
            ),
            const SizedBox(height: 12),
            // Nom 2 qatorga o'raladi, undan uzuni "..." (F11)
            Tx(h.name, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 2, ellipsis: true, lh: 20),
            const SizedBox(height: 2),
            Tx(h.tenantName.isEmpty ? ij('noTenant') : h.tenantName,
                size: 13, color: p.t2, maxLines: 1, ellipsis: true),
            const SizedBox(height: 10),
            // Pul — FittedBox: hech qachon "..." bo'lmaydi
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(ijMoneyCur(t.left, h.currency),
                  size: 16, w: FontWeight.w600, color: sumColor, tab: true),
            ),
            const SizedBox(height: 3),
            // U6: "Bu oyda hisob yo'q" qatori BOSILADI — hisob formasi
            // shu uy va shu oy uchun tayyor holda ochiladi.
            !hasCharges
                ? Tap(
                    onTap: () => _openNewCharge(h),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Tx(ij('noChargeMonth'), size: 12, color: p.t4, maxLines: 1),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Tx(
                      t.left <= 0
                          ? ij('allPaid')
                          : ij('paidOf', {'paid': ijFx(t.paid), 'total': ijFx(t.charged)}),
                      size: 12,
                      color: p.t4,
                      maxLines: 1,
                      tab: true,
                    ),
                  ),
            const Spacer(),
            const SizedBox(height: 10),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _houseBadge(p, h)),
            // U1: bir bosishda "pul keldi" — to'lov formasi to'ldirilgan
            // holda ochiladi. U6: hisob yo'q oyda — "+ Hisob" tugmasi.
            if (hasCharges && t.left > 0) ...[
              const SizedBox(height: 12),
              SolidBtn.mint(ij('quickPay'), () => _openQuickPay(h), h: 36, fs: 13, icon: Icons.check_rounded),
            ] else if (!hasCharges) ...[
              const SizedBox(height: 12),
              GlassBtn(label: ij('addCharge'), onTap: () => _openNewCharge(h), h: 36, fs: 13),
            ],
          ],
        ),
      ),
    );
  }

  /// U1: BIR BOSISHDA ijara qabul qilish. Mavjud to'lov modali ochiladi, lekin
  /// hammasi tayyor: uy tanlangan, summa — shu oyning ochiq qoldig'i, hisob —
  /// YAGONA ochiq 'ijara' hisobi bo'lsa unga bog'lanadi (aks holda umumiy).
  /// Ega faqat "Qo'shish"ni bosadi.
  void _openQuickPay(House h) {
    final t = ijaraRepo.totalsOf(h.id);
    final open = ijaraRepo
        .chargesOf(h.id)
        .where((c) => !c.cancelled && c.left > 0)
        .toList();
    final single = (open.length == 1 && open.first.kind == 'ijara') ? open.first : null;
    setState(() => _payEdit = {
          'houseId': h.id,
          'chargeId': single?.id ?? '',
          'amount': t.left > 0 ? ijFx(t.left) : '',
          'date': ijDay(DateTime.now()),
          'note': '',
          // Faqat sheet sarlavhasi uchun ("To'lov keldi"); serverga yuborilmaydi.
          'quick': true,
        });
  }

  /// U7: arxivlangan uy qatori — xira ko'rinish + "Arxivdan chiqarish".
  Widget _archivedRow(Pal p, House h) {
    final busy = _unarchBusy == h.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        color: const Color(0x00000000),
        child: Row(
          children: [
            Icon(Icons.archive_outlined, size: 20, color: p.t4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(h.name, size: 14, w: FontWeight.w600, color: p.t3, maxLines: 1, ellipsis: true),
                  if (h.tenantName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Tx(h.tenantName, size: 12, color: p.t4, maxLines: 1, ellipsis: true),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MiniBtn(
              ij('unarchive'),
              loading: busy,
              onTap: busy || _unarchBusy.isNotEmpty ? null : () => _unarchive(h),
            ),
          ],
        ),
      ),
    );
  }

  /// U7: arxivdan qaytarish. Server chegara sabab rad etsa (403 HOUSE_LIMIT)
  /// _toastErr mavjud lokalizatsiyalangan chegara modalini ochadi.
  Future<void> _unarchive(House h) async {
    setState(() => _unarchBusy = h.id);
    final ok = await ijaraRepo.patchHouse(h.id, {'archived': false});
    if (!mounted) return;
    setState(() => _unarchBusy = '');
    ok ? _toastMsg(ij('unarchived')) : _toastErr();
  }

  // ================= PASTKI TUGMA =================

  /// Suzuvchi gradient CTA "+ Uy qo'shish". Chetlardagi bo'shliq bosishni
  /// ro'yxatga o'tkazadi (Padding hit-test'ni yutmaydi) — ro'yxatning pastki
  /// chetida 120px bo'sh joy bor.
  Widget _bottomBar(Pal p) {
    if (_anyLayer) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 20),
      child: GradientBtn(label: ij('addHouse'), onTap: _openNewHouse),
    );
  }

  // ================= UY TAFSILOTI =================

  Widget _detail(Pal p) {
    final h = ijaraRepo.houseById(_detailId);
    if (h == null) {
      // Uy arxivlangan/yo'qolgan — qatlamni yopamiz
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _detailId != null && ijaraRepo.houseById(_detailId) == null) {
          setState(() => _detailId = null);
        }
      });
      return const SizedBox.shrink();
    }
    final cta = _detailCta(p, h);
    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: h.name,
              subtitle: h.tenantName.isEmpty ? ij('noTenant') : h.tenantName,
              onBack: () => setState(() => _detailId = null),
              trailing: [
                GlassIconBtn(icon: Icons.edit_outlined, iconSize: 20, onTap: () => _openEditHouse(h)),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, cta == null ? 40 : 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _mainCard(p, h),
                    const SizedBox(height: 24),
                    _tenantBlock(p, h),
                    const SizedBox(height: 24),
                    _balanceBlock(p, h),
                    const SizedBox(height: 24),
                    _chargesBlock(p, h),
                    const SizedBox(height: 24),
                    _paymentsBlock(p, h),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (cta != null) Positioned(bottom: 16, left: Tb.padX, right: Tb.padX, child: cta),
      ],
    );
  }

  /// Pastki CTA: ochiq qoldiq bor -> mint "To'lov keldi" (U1); to'liq to'langan
  /// -> shisha "To'langan ✓"; hisob yo'q -> CTA yo'q (HISOBLAR blokida "+ Hisob").
  Widget? _detailCta(Pal p, House h) {
    final t = ijaraRepo.totalsOf(h.id);
    final hasCharges = ijaraRepo.chargesOf(h.id).isNotEmpty;
    if (!hasCharges) return null;
    if (t.left > 0) {
      return SolidBtn.mint(ij('quickPay'), () => _openQuickPay(h),
          h: 56, fs: 16, icon: Icons.payments_outlined, glow: true);
    }
    return GlassBtn(label: '${ij('pillPaid')} ✓', onTap: null, h: 56, fs: 16, fg: p.mint);
  }

  /// Asosiy karta: "Oylik ijara" 14 t2 + holat badge · summa 36/600 num ·
  /// davr (oy) 14 t2.
  Widget _mainCard(Pal p, House h) {
    return GlassCard(
      r: Tb.rCard,
      pad: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Tx(ij('rentAmountLabel'), size: 14, color: p.t2, maxLines: 1, ellipsis: true)),
              const SizedBox(width: 8),
              FittedBox(fit: BoxFit.scaleDown, child: _houseBadge(p, h)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: h.rentAmount > 0
                ? Tx(ijMoneyCur(h.rentAmount, h.currency),
                    size: 36, w: FontWeight.w600, color: p.ink, tab: true)
                : Tx(ij('noRent'), size: 20, w: FontWeight.w600, color: p.t3),
          ),
          const SizedBox(height: 6),
          Tx(
            h.dueDay > 0
                ? '${ijMonth(_month.month)} ${_month.year} · ${ij('dueDayShort', {'d': '${h.dueDay}'})}'
                : '${ijMonth(_month.month)} ${_month.year}',
            size: 14,
            color: p.t2,
            maxLines: 2,
            ellipsis: true,
          ),
        ],
      ),
    );
  }

  Widget _tenantBlock(Pal p, House h) {
    final noTenant = h.tenantName.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Cap(ij('tenantCap'))),
            // Ijarachi bor bo'lsa — tahrirlash; yo'q bo'lsa pastdagi CTA.
            if (!noTenant)
              _MiniBtn(ij('edit'), icon: Icons.edit_outlined, onTap: () => _openTenant(h)),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          pad: const EdgeInsets.all(16),
          child: Row(
            children: [
              RingAvatar(initials: noTenant ? '?' : _initials(h.tenantName), size: 44, seed: h.tenantName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(noTenant ? ij('noTenant') : h.tenantName,
                        size: 15, w: FontWeight.w600, color: noTenant ? p.t3 : p.ink, maxLines: 2, ellipsis: true),
                    const SizedBox(height: 3),
                    if (h.tenantPhone.isEmpty)
                      Tx(noTenant ? ij('emptyHouse') : ij('noPhone'), size: 13, color: p.t4)
                    else
                      // Raqamga bosish — nusxalash (eski xatti-harakat saqlanadi)
                      Tap(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: h.tenantPhone));
                          _toastMsg(ij('phoneCopied'));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Tx(ijPhoneShow(h.tenantPhone),
                                  size: 13, color: p.t2, maxLines: 1, ellipsis: true, tab: true),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.copy_rounded, size: 14, color: p.t4),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // U3: egan har kuni qiladigan ish — ijarachiga QO'NG'IROQ
              if (h.tenantPhone.isNotEmpty) ...[
                const SizedBox(width: 10),
                _MiniBtn(ij('call'), kind: 'mint', icon: Icons.call_rounded, onTap: () => _callTenant(h.tenantPhone)),
              ],
            ],
          ),
        ),
        // 023: uy ijarachisiz ham bo'ladi — kartochka ichidan qo'shiladi.
        if (noTenant) ...[
          const SizedBox(height: 12),
          GradientBtn(
            label: ij('addTenant'),
            h: 48,
            icon: Icons.person_add_alt_1_rounded,
            onTap: () => _openTenant(h),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 15, color: p.t4),
              const SizedBox(width: 7),
              Expanded(
                child: Tx(
                  h.dueDay > 0 ? ij('dueDayShort', {'d': '${h.dueDay}'}) : ij('dueDayNone'),
                  size: 13,
                  color: p.t4,
                  maxLines: 1,
                  ellipsis: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// U3: `tel:` orqali qo'ng'iroq (profil/paywall _openUrl naqshi) — ochilmasa
  /// jim yiqilmaydi, xabar ko'rsatiladi.
  Future<void> _callTenant(String phone) async {
    try {
      final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _toastMsg(ij('callFailed'));
      }
    } catch (_) {
      _toastMsg(ij('callFailed'));
    }
  }

  Widget _balanceBlock(Pal p, House h) {
    final t = ijaraRepo.totalsOf(h.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ij('balanceCap')),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          pad: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _totalRow(p, ij('chargedLabel'), ijMoneyCur(t.charged, h.currency), p.ink),
              const SizedBox(height: 8),
              _totalRow(p, ij('paidLabel'), ijMoneyCur(t.paid, h.currency), p.mint),
              const SizedBox(height: 12),
              Container(height: 1, color: p.hairline),
              const SizedBox(height: 12),
              _totalRow(p, ij('leftLabel'), ijMoneyCur(t.left, h.currency), _leftColor(t.left, p), big: true),
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

  /// 36px dumaloq holat ikonkasi (rang 15% fon).
  Widget _circle(IconData icon, Color c, {double size = 36}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .15)),
        child: Icon(icon, size: size * 0.5, color: c),
      );

  /// Ro'yxat kartasi ichidagi bo'sh holat matni.
  Widget _emptyRow(Pal p, String text) => SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Tx(text, size: 14, color: p.t4),
        ),
      );

  // ---- Hisoblar (davr) ----

  Widget _chargesBlock(Pal p, House h) {
    final list = ijaraRepo.chargesOf(h.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ij('chargesCap')),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          child: list.isEmpty
              ? _emptyRow(p, ij('noCharges'))
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++) _chargeRow(p, list[i], last: i == list.length - 1),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        GlassBtn(label: ij('addCharge'), onTap: () => _openNewCharge(h), h: 44),
      ],
    );
  }

  /// Hisob qatori (h64): holat doirasi · nom 15/600 + tur/muddat 13 t2 ·
  /// summa 15/600 num + holat/qoldiq 12/600.
  Widget _chargeRow(Pal p, Charge c, {required bool last}) {
    final state = ijChargeState(c);
    final due = c.dueDate;
    final sc = _stateColor(state, p);
    return Tap(
      onTap: () => _openEditCharge(c),
      scale: 0.99,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hairline))),
        child: Row(
          children: [
            _circle(_stateIcon(state), sc),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hisob nomi 2 qatorga o'raladi, undan uzuni "..." (F11)
                  Tx(c.title.isEmpty ? ijKind(c.kind) : c.title,
                      size: 15, w: FontWeight.w600, color: c.cancelled ? p.t3 : p.ink, maxLines: 2, ellipsis: true, lh: 20),
                  const SizedBox(height: 2),
                  Tx('${ijKind(c.kind)} · ${due == null ? ij('noDue') : ij('dueOn', {'date': ijDateShort(due)})}',
                      size: 13, color: p.t2, maxLines: 2, ellipsis: true, lh: 17),
                  // QISMAN to'lov ko'rinishi (mahsulot talabi)
                  if (!c.cancelled && c.paid > 0 && c.left > 0) ...[
                    const SizedBox(height: 2),
                    Tx(ij('paidOf', {'paid': ijFx(c.paid), 'total': ijFx(c.amount)}),
                        size: 12, color: p.t4, maxLines: 1, tab: true),
                  ],
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
                    child: Tx(ijMoneyCur(c.amount, ijaraRepo.currencyOf(c.houseId)),
                        size: 15, w: FontWeight.w600, color: c.cancelled ? p.t4 : p.ink, tab: true),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tx(
                      c.cancelled || c.left <= 0
                          ? ijState(state)
                          : ij('leftShort', {'left': ijFx(c.left)}),
                      size: 12, w: FontWeight.w600, color: sc, maxLines: 1, tab: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- To'lovlar (davr) ----

  Widget _paymentsBlock(Pal p, House h) {
    final list = ijaraRepo.paymentsOf(h.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(ij('paymentsCap')),
        const SizedBox(height: 12),
        GlassCard(
          r: Tb.rCard,
          child: list.isEmpty
              ? _emptyRow(p, ij('noPayments'))
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++) _paymentRow(p, list[i], last: i == list.length - 1),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        GlassBtn(label: ij('addPayment'), onTap: () => _openNewPayment(h), h: 44),
      ],
    );
  }

  Widget _paymentRow(Pal p, IjaraPayment pay, {required bool last}) {
    final d = pay.date;
    final linked = ijaraRepo.chargeById(pay.chargeId);
    final title = linked == null
        ? ij('payGeneral')
        : (linked.title.isEmpty ? ijKind(linked.kind) : linked.title);
    final sub = [
      if (d != null) ijDateShort(d),
      if (pay.note.isNotEmpty) pay.note,
    ].join(' · ');
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hairline))),
      child: Row(
        children: [
          _circle(Icons.payments_outlined, p.mint),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(title, size: 15, w: FontWeight.w600, color: p.ink, maxLines: 2, ellipsis: true, lh: 20),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Tx(sub, size: 13, color: p.t2, maxLines: 2, ellipsis: true, lh: 17),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Tx('+${ijMoneyCur(pay.amount, ijaraRepo.currencyOf(pay.houseId))}',
                  size: 15, w: FontWeight.w600, color: p.mint, tab: true),
            ),
          ),
          const SizedBox(width: 4),
          _xBtn(p, () => _askDeletePayment(pay)),
        ],
      ),
    );
  }

  /// O'chirish (×) tugmasi. F11: bosish maydoni 40×40 — barmoq bemalol tegadi.
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
  Widget _sheetTitle(Pal p, String title, VoidCallback close, {Widget? badge}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Tx(title, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 2, ellipsis: true),
        ),
        if (badge != null) ...[const SizedBox(width: 8), badge],
        const SizedBox(width: 8),
        GlassIconBtn(icon: Icons.close_rounded, onTap: _busy ? null : close),
      ],
    );
  }

  String get _cancelLabel => (store.L()['btnCancel'] as String?) ?? ij('no');

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
              Expanded(child: GlassBtn(label: ij('no'), h: 52, onTap: close)),
              const SizedBox(width: 12),
              Expanded(
                child: danger
                    ? SolidBtn.coral(ij('yes'), _busy ? null : () => _runConfirm(c), h: 52, loading: _busy)
                    : GradientBtn(label: ij('yes'), h: 52, loading: _busy, glow: false, onTap: () => _runConfirm(c)),
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

  /// 5 ta uy chegarasi — forma O'RNIGA shu xabar ko'rsatiladi (PO qarori).
  Widget _capModal(Pal p) {
    void close() => setState(() => _capOpen = false);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, ij('capTitle'), close),
          const SizedBox(height: 10),
          Tx(ij('capBody', {'n': '${ijaraRepo.maxHouses}'}), size: 14, color: p.t2, lh: 20),
          const SizedBox(height: 24),
          GradientBtn(label: ij('ok'), onTap: close),
        ],
      ),
    );
  }

  // ---- Oy generatori (U2) ----

  /// Tasdiqlash varag'i: qaysi uylarga qancha hisob yozilishi RO'YXAT bilan
  /// ko'rsatiladi, jami summa ostida. Yozish ketma-ket, jarayon "2/5..." ko'rinadi.
  Widget _genModal(Pal p) {
    final list = _gen!;
    // 023: ro'yxatda so'mli va dollarli uy aralash bo'lishi mumkin — yakun
    // VALYUTA BO'YICHA ajratiladi (qo'shib yuborish pul xatosi bo'lardi).
    final totals = <String, int>{};
    for (final h in list) {
      totals[h.currency] = (totals[h.currency] ?? 0) + h.rentAmount;
    }
    void close() {
      if (!_genBusy) setState(() => _gen = null);
    }

    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, ij('genSheetTitle'), close),
          const SizedBox(height: 8),
          Tx(ij('genSheetBody', {'month': '${ijMonth(_month.month)} ${_month.year}'}),
              size: 14, color: p.t2, lh: 20),
          const SizedBox(height: 16),
          GlassCard(
            r: Tb.rRow,
            pad: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                for (final h in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Tx(h.name, size: 14, w: FontWeight.w500, color: p.ink, maxLines: 1, ellipsis: true),
                        ),
                        const SizedBox(width: 12),
                        Tx(ijMoneyCur(h.rentAmount, h.currency),
                            size: 14, w: FontWeight.w600, color: p.ink, tab: true),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Container(height: 1, color: p.hairline),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tx(ij('genTotal'), size: 14, w: FontWeight.w600, color: p.t2),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final c in kIjaraCurrencies)
                            if ((totals[c] ?? 0) != 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Tx(ijMoneyCur(totals[c]!, c),
                                    size: 18, w: FontWeight.w600, color: p.ink, tab: true),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _genBusy
              ? GradientBtn(
                  label: ij('genProgress', {'done': '$_genDone', 'n': '${list.length}'}),
                  onTap: null,
                  glow: false,
                )
              : GradientBtn(label: ij('genChargesBtn'), icon: Icons.event_available_outlined, onTap: () => _runGen(list)),
        ],
      ),
    );
  }

  /// U2: hisoblarni KETMA-KET yozish. Qisman muvaffaqiyat — "X/N yozildi"
  /// (402 kvotada paywall allaqachon ochilgan bo'ladi, qolganlar yozilmaydi).
  Future<void> _runGen(List<House> targets) async {
    setState(() {
      _genBusy = true;
      _genDone = 0;
    });
    final ok = await ijaraRepo.generateRentCharges(targets, onProgress: (done, total) {
      if (mounted) setState(() => _genDone = done);
    });
    if (!mounted) return;
    setState(() {
      _genBusy = false;
      _gen = null;
    });
    ok >= targets.length
        ? _toastMsg(ij('genDoneAll', {'n': '$ok'}))
        : _toastMsg(ij('genDonePart', {'ok': '$ok', 'n': '${targets.length}'}));
  }

  // ---- Uy qo'shish / tahrirlash ----

  void _openNewHouse() {
    // QAT'IY chegara: 5 ta uydan keyin forma OCHILMAYDI — xabar ko'rsatiladi.
    if (!ijaraRepo.canAddHouse) {
      setState(() => _capOpen = true);
      return;
    }
    setState(() => _houseEdit = {'name': ''});
  }

  void _openEditHouse(House h) => setState(() => _houseEdit = {'id': h.id, 'name': h.name});

  // ---- Ijarachi qo'shish / tahrirlash (023) ----

  /// Uy kartochkasi ichidan ochiladi. Uy ALLAQACHON mavjud — shuning uchun
  /// 5-uy chegarasi bu yerda tekshirilmaydi (yangi uy yaratilmaydi).
  void _openTenant(House h) => setState(() => _tenantEdit = {
        'houseId': h.id,
        'name': h.tenantName,
        'phone': ijPhoneShow(h.tenantPhone),
        'rent': h.rentAmount > 0 ? ijFx(h.rentAmount) : '',
        'cur': h.currency,
        'dueDay': h.dueDay > 0 ? '${h.dueDay}' : '',
        // Forma sarlavhasi va "chiqarish" tugmasi uchun (serverga ketmaydi)
        'had': h.tenantName.isNotEmpty || h.tenantPhone.isNotEmpty,
      });

  /// UY formasi (023 dan keyin): FAQAT uy. Ijarachi, ijara summasi, pul birligi
  /// va to'lov kuni bu yerda EMAS — ular ijarachi formasida (uy ijarachisiz
  /// ham bo'ladi: bo'sh turgan kvartira ham ro'yxatda ko'rinishi kerak).
  Widget _houseModal(Pal p) {
    final e = _houseEdit!;
    final isNew = e['id'] == null;
    void close() => setState(() => _houseEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, isNew ? ij('newHouse') : ij('editHouse'), close),
          const SizedBox(height: 20),
          _field(p, ij('houseNameLabel'), '${e['name']}', (v) => setState(() => e['name'] = v),
              hint: ij('houseNamePh'), icon: Icons.apartment_rounded),
          if (isNew) ...[
            const SizedBox(height: 10),
            _note(p, ij('houseOnlyNote')),
          ],
          const SizedBox(height: 24),
          GradientBtn(label: ij('save'), loading: _busy, onTap: () => _saveHouse(e)),
          if (!isNew) ...[
            const SizedBox(height: 6),
            TextBtn(
              label: ij('archiveHouse'),
              color: p.coral,
              onTap: () => _askArchiveHouse('${e['id']}', '${e['name']}'),
            ),
          ],
        ],
      ),
    );
  }

  /// IJARACHI formasi (023): ism · telefon (+998 maskasi) · oylik ijara
  /// (oldida so'm/$ almashtirgichi) · to'lov kuni.
  Widget _tenantModal(Pal p) {
    final e = _tenantEdit!;
    final had = e['had'] == true;
    final cur = '${e['cur']}';
    void close() => setState(() => _tenantEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, had ? ij('editTenant') : ij('newTenant'), close),
          const SizedBox(height: 20),
          _field(p, ij('tenantNameLabel'), '${e['name']}', (v) => setState(() => e['name'] = v),
              hint: ij('tenantNamePh'), icon: Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _field(p, ij('tenantPhoneLabel'), '${e['phone']}', (v) => setState(() => e['phone'] = v),
              phone: true, hint: '+998 90 123 45 67', icon: Icons.smartphone_rounded),
          const SizedBox(height: 16),
          // Summa maydonining ICHIDA, oldida — pul birligi almashtirgichi.
          _moneyField(p, ij('rentAmountLabel'), '${e['rent']}',
              (v) => setState(() => e['rent'] = v),
              cur: cur, onCur: (c) => setState(() => e['cur'] = c)),
          const SizedBox(height: 16),
          _field(p, ij('dueDayLabel'), '${e['dueDay']}', (v) => setState(() => e['dueDay'] = v),
              hint: ij('dueDayPh'), day: true, icon: Icons.event_available_rounded),
          const SizedBox(height: 10),
          _note(p, ij('dueDayNote')),
          if (had) ...[
            const SizedBox(height: 10),
            _note(p, ij('tenantChangeNote')),
          ],
          const SizedBox(height: 24),
          GradientBtn(label: ij('save'), loading: _busy, onTap: () => _saveTenant(e)),
          if (had) ...[
            const SizedBox(height: 6),
            TextBtn(label: ij('removeTenant'), color: p.coral, onTap: () => _askRemoveTenant(e)),
          ],
        ],
      ),
    );
  }

  /// Ikonkali kichik izoh qatori (forma ostidagi tushuntirishlar).
  Widget _note(Pal p, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: p.t4),
        const SizedBox(width: 7),
        Expanded(child: Tx(text, size: 13, color: p.t4, lh: 18)),
      ],
    );
  }

  Future<void> _saveTenant(Map<String, dynamic> e) async {
    final name = '${e['name']}'.trim();
    if (name.isEmpty) {
      _toastMsg(ij('needTenantName'));
      return;
    }
    // Telefon IXTIYORIY, lekin kiritilgan bo'lsa TO'LIQ bo'lishi shart —
    // yarim raqam bilan qo'ng'iroq tugmasi ishlamas va ega buni faqat
    // ijarachiga zarur bo'lganda bilib qolardi.
    final phone = ijPhoneNorm('${e['phone']}');
    if (phone == null) {
      _toastMsg(ij('badPhone'));
      return;
    }
    // To'lov kuni ixtiyoriy (bo'sh = kelishilmagan), lekin 1..31 dan
    // tashqarisi yozilmaydi — server ham rad etadi.
    final dayTxt = '${e['dueDay']}'.trim();
    final day = dayTxt.isEmpty ? 0 : (int.tryParse(dayTxt) ?? -1);
    if (dayTxt.isNotEmpty && (day < 1 || day > 31)) {
      _toastMsg(ij('badDueDay'));
      return;
    }
    final body = <String, dynamic>{
      'tenant_name': name,
      'tenant_phone': phone,
      'rent_amount': _digits('${e['rent']}'),
      'currency': ijCurOf(e['cur']),
      'due_day': day > 0 ? day : '',
    };
    setState(() => _busy = true);
    final ok = await ijaraRepo.patchHouse('${e['houseId']}', body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _tenantEdit = null;
    });
    ok ? _toastMsg(ij('tenantSaved')) : _toastErr();
  }

  /// Ijarachini chiqarish: FAQAT ism/telefon/to'lov kuni tozalanadi. Ijara
  /// summasi va pul birligi UYDA QOLADI — ular obyektning narxi, keyingi
  /// ijarachi uchun ham o'sha (va oy generatori ularsiz ishlamaydi).
  void _askRemoveTenant(Map<String, dynamic> e) {
    final houseId = '${e['houseId']}';
    setState(() {
      _tenantEdit = null;
      _confirm = {
        'title': ij('removeTenant'),
        'body': ij('removeTenantBody'),
        'danger': true,
        'run': () async {
          final ok = await ijaraRepo.patchHouse(
              houseId, {'tenant_name': '', 'tenant_phone': '', 'due_day': ''});
          if (!mounted) return;
          ok ? _toastMsg(ij('tenantRemoved')) : _toastErr();
        },
      };
    });
  }

  Future<void> _saveHouse(Map<String, dynamic> e) async {
    final name = '${e['name']}'.trim();
    if (name.isEmpty) {
      _toastMsg(ij('needHouseName'));
      return;
    }
    // 023: uy formasida FAQAT nom bor — ijarachi/summa maydonlari yuborilmaydi
    // (yuborilsa PATCH ularni bo'shatib, mavjud ijarachini o'chirib yuborardi).
    final body = <String, dynamic>{'name': name};
    setState(() => _busy = true);
    final ok = e['id'] == null
        ? await ijaraRepo.createHouse(body)
        : await ijaraRepo.patchHouse('${e['id']}', body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _houseEdit = null;
    });
    // Server chegarani rad etsa (403 HOUSE_LIMIT / 402 SUB_EXPIRED) — _toastErr
    // uni modulning O'Z tilidagi modali yoki xabariga aylantiradi.
    ok ? _toastMsg(ij('houseSaved')) : _toastErr();
  }

  void _askArchiveHouse(String id, String name) {
    setState(() {
      _houseEdit = null;
      _confirm = {
        'title': ij('archiveHouse'),
        'body': name,
        'danger': true,
        'run': () async {
          final ok = await ijaraRepo.archiveHouse(id);
          if (!mounted) return;
          if (ok) {
            setState(() => _detailId = null);
            _toastMsg(ij('saved'));
          } else {
            _toastErr();
          }
        },
      };
    });
  }

  // ---- Hisob qo'shish / tahrirlash ----

  void _openNewCharge(House h) => setState(() => _chargeEdit = {
        'houseId': h.id,
        'kind': 'ijara',
        'title': ij('kindIjara'),
        // Oylik ijara belgilangan bo'lsa — summa avtomatik to'ladi
        'amount': h.rentAmount > 0 ? ijFx(h.rentAmount) : '',
        // 023: uyda to'lov kuni belgilangan bo'lsa muddat AVTOMATIK to'ladi
        // (qisqa oyda oxirgi kunga suriladi) — ega uni qo'lda tanlamasin.
        'due': _dueFromDay(h.dueDay),
      });

  /// Ko'rilayotgan oy + uyning to'lov kuni -> muddat sanasi. 0 yoki oy
  /// kunidan katta bo'lsa oyning OXIRGI kuni (31-fevral bo'lmasin).
  DateTime? _dueFromDay(int day) {
    if (day < 1 || day > 31) return null;
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    return DateTime(_month.year, _month.month, day > last ? last : day);
  }

  void _openEditCharge(Charge c) => setState(() => _chargeEdit = {
        'houseId': c.houseId,
        'id': c.id,
        'kind': c.kind,
        'title': c.title,
        'amount': ijFx(c.amount),
        'due': c.dueDate,
        'cancelled': c.cancelled,
      });

  Widget _chargeModal(Pal p) {
    final e = _chargeEdit!;
    // F8: bekor qilingan hisob TAHRIRLANMAYDI — faqat ko'rish oynasi.
    if (e['cancelled'] == true) return _chargeViewModal(p, e);
    final isNew = e['id'] == null;
    final due = e['due'] as DateTime?;
    void close() => setState(() => _chargeEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, isNew ? ij('newCharge') : ij('editCharge'), close),
          const SizedBox(height: 20),
          Cap(ij('kindLabel')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in kIjaraKinds)
                _chip(p, ijKind(k), e['kind'] == k, () => _pickKind(e, k)),
            ],
          ),
          const SizedBox(height: 16),
          _field(p, ij('chargeTitleLabel'), '${e['title']}', (v) => setState(() => e['title'] = v),
              hint: ij('chargeTitlePh'), icon: Icons.description_outlined),
          const SizedBox(height: 16),
          _field(
              p,
              '${ij('amountLabel')} · ${ijCurSym(ijaraRepo.currencyOf('${e['houseId']}'))}',
              '${e['amount']}',
              (v) => setState(() => e['amount'] = v),
              number: true,
              icon: Icons.payments_outlined),
          const SizedBox(height: 16),
          Cap(ij('dueDateLabel')),
          const SizedBox(height: 10),
          _dateField(p, due == null ? ij('noDue') : ijDateLong(due), due != null, () => _pickDue(e)),
          const SizedBox(height: 24),
          GradientBtn(label: ij('save'), loading: _busy, onTap: () => _saveCharge(e)),
          // Bekor qilinganlar bu formaga tushmaydi (yuqorida ko'rish oynasiga
          // buriladi) — shu sabab shart faqat isNew.
          if (!isNew) ...[
            const SizedBox(height: 6),
            TextBtn(
              label: ij('cancelCharge'),
              color: p.coral,
              onTap: () => _askCancelCharge('${e['id']}', '${e['title']}'),
            ),
          ],
        ],
      ),
    );
  }

  /// F8: bekor qilingan hisobning FAQAT KO'RISH oynasi — forma yo'q, saqlash
  /// yo'q; "Bekor" badge + summa + tur/muddat, yopish tugmasi.
  Widget _chargeViewModal(Pal p, Map<String, dynamic> e) {
    final due = e['due'] as DateTime?;
    final title = '${e['title']}'.trim();
    void close() => setState(() => _chargeEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, title.isEmpty ? ijKind('${e['kind']}') : title, close,
              badge: PillBadge.muted(ij('stBekor'))),
          const SizedBox(height: 6),
          Tx(ij('cancelledCharge'), size: 14, color: p.t4),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Tx('${e['amount']} ${ijCurSym(ijaraRepo.currencyOf('${e['houseId']}'))}',
                size: 32, w: FontWeight.w600, color: p.t3, tab: true),
          ),
          const SizedBox(height: 6),
          Tx('${ijKind('${e['kind']}')} · ${due == null ? ij('noDue') : ijDateLong(due)}',
              size: 14, color: p.t2, maxLines: 2, ellipsis: true),
          const SizedBox(height: 24),
          GlassBtn(label: ij('ok'), h: 52, onTap: close),
        ],
      ),
    );
  }

  /// Tur almashganda sarlavha ham yangilanadi — lekin FAQAT foydalanuvchi uni
  /// o'zi o'zgartirmagan bo'lsa (yozganini bosib ketmaymiz).
  void _pickKind(Map<String, dynamic> e, String k) {
    setState(() {
      final t = '${e['title']}'.trim();
      final auto = t.isEmpty || kIjaraKinds.any((x) => ijKind(x) == t);
      e['kind'] = k;
      if (auto) e['title'] = ijKind(k);
    });
  }

  /// F7: umumiy sana tanlagich — ilova palitrasidagi Theme va CLAMP: initialDate
  /// chegaradan tashqarida bo'lsa showDatePicker assert bilan YIQILARDI
  /// (masalan eski oyni ko'rib turib muddat tanlaganda).
  Future<DateTime?> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) {
    final p = curPal();
    final dark = ThemeData.estimateBrightnessForColor(p.bg) == Brightness.dark;
    var init = initial;
    if (init.isBefore(first)) init = first;
    if (init.isAfter(last)) init = last;
    return showDatePicker(
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
  }

  Future<void> _pickDue(Map<String, dynamic> e) async {
    final now = DateTime.now();
    final cur = e['due'] as DateTime?;
    final picked = await _pickDate(
      initial: cur ?? ijDay(DateTime(_month.year, _month.month, now.day.clamp(1, ijMonthEnd(_month).day))),
      first: DateTime(2020, 1, 1), // F7: eski davr hisoblari ham kiritilsin
      last: DateTime(now.year + 3, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => e['due'] = ijDay(picked));
  }

  Future<void> _saveCharge(Map<String, dynamic> e) async {
    final amount = _digits('${e['amount']}');
    if (amount <= 0) {
      _toastMsg(ij('needAmount'));
      return;
    }
    final title = '${e['title']}'.trim();
    final due = e['due'] as DateTime?;
    final isNew = e['id'] == null;
    final body = <String, dynamic>{
      if (isNew) 'house_id': e['houseId'],
      if (isNew) 'period': ijPeriod(_month),
      'kind': e['kind'],
      'title': title.isEmpty ? ijKind('${e['kind']}') : title,
      'amount': amount,
      if (due != null) 'due_date': ijYmd(due),
    };
    setState(() => _busy = true);
    final ok = isNew
        ? await ijaraRepo.createCharge(body)
        : await ijaraRepo.patchCharge('${e['id']}', body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _chargeEdit = null;
    });
    ok ? _toastMsg(isNew ? ij('created') : ij('saved')) : _toastErr();
  }

  void _askCancelCharge(String id, String title) {
    setState(() {
      _chargeEdit = null;
      _confirm = {
        'title': ij('confirmCancelChargeTitle'),
        'body': title,
        'danger': true,
        'run': () async {
          final ok = await ijaraRepo.cancelCharge(id);
          if (!mounted) return;
          ok ? _toastMsg(ij('cancelled')) : _toastErr();
        },
      };
    });
  }

  // ---- To'lov qo'shish ----

  void _openNewPayment(House h) => setState(() => _payEdit = {
        'houseId': h.id,
        // Bo'sh = umumiy to'lov (biror hisobga bog'lanmagan)
        'chargeId': '',
        'amount': '',
        'date': ijDay(DateTime.now()),
        'note': '',
      });

  /// To'lov sheet'i (§5.12): sarlavha ("To'lov keldi" — U1 tez to'lov /
  /// "Yangi to'lov"), "{uy} · {ijarachi}" 14 t2, summa 44/600 mint markazda
  /// (tahrirlanadi), qaysi hisobga chiplari, sana, izoh, mint "Qo'shish".
  Widget _payModal(Pal p) {
    final e = _payEdit!;
    final date = e['date'] as DateTime;
    final house = ijaraRepo.houseById('${e['houseId']}');
    // Faqat yopilmagan hisoblar tanlov uchun mantiqiy
    final open = ijaraRepo
        .chargesOf('${e['houseId']}')
        .where((c) => !c.cancelled && c.left > 0)
        .toList();
    final sub = house == null
        ? ''
        : [house.name, if (house.tenantName.isNotEmpty) house.tenantName].join(' · ');
    void close() => setState(() => _payEdit = null);
    return _sheet(
      close,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(p, e['quick'] == true ? ij('quickPay') : ij('newPayment'), close),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Tx(sub, size: 14, color: p.t2, maxLines: 2, ellipsis: true),
          ],
          const SizedBox(height: 20),
          // Summa — katta, markazda, mint (kiritiladi; guruhlangan raqam)
          StoreField(
            value: '${e['amount']}',
            onChanged: (v) => setState(() => e['amount'] = v),
            hint: '0',
            keyboardType: TextInputType.number,
            inputFormatters: [_GroupFmt()],
            textAlign: TextAlign.center,
            style: tbStyle(size: 44, w: FontWeight.w600, color: p.mint, tab: true),
            hintColor: p.t6,
          ),
          const SizedBox(height: 4),
          Center(child: Tx(
              '${ij('payAmountLabel')} · ${ijCurSym(ijaraRepo.currencyOf('${e['houseId']}'))}',
              size: 14, color: p.t2)),
          const SizedBox(height: 20),
          if (open.isNotEmpty) ...[
            Cap(ij('payTargetCap')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(p, ij('payGeneral'), '${e['chargeId']}'.isEmpty,
                    () => setState(() => e['chargeId'] = '')),
                for (final c in open)
                  _chip(
                    p,
                    c.title.isEmpty ? ijKind(c.kind) : c.title,
                    e['chargeId'] == c.id,
                    // Hisob tanlansa — qoldiq summasi avtomatik qo'yiladi
                    () => setState(() {
                      e['chargeId'] = c.id;
                      if (_digits('${e['amount']}') == 0) e['amount'] = ijFx(c.left);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Cap(ij('payDateLabel')),
          const SizedBox(height: 10),
          _dateField(p, ijDateLong(date), true, () => _pickPayDate(e)),
          const SizedBox(height: 16),
          _field(p, ij('payNoteLabel'), '${e['note']}', (v) => setState(() => e['note'] = v),
              icon: Icons.edit_outlined),
          const SizedBox(height: 24),
          SolidBtn.mint(ij('addBtn'), () => _savePayment(e),
              h: 56, fs: 16, icon: Icons.check_rounded, loading: _busy),
          const SizedBox(height: 4),
          TextBtn(label: _cancelLabel, onTap: _busy ? null : close),
        ],
      ),
    );
  }

  Future<void> _pickPayDate(Map<String, dynamic> e) async {
    final now = DateTime.now();
    final picked = await _pickDate(
      initial: e['date'] as DateTime,
      first: DateTime(2020, 1, 1), // F7: eski to'lovlarni kiritish ham mumkin
      last: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => e['date'] = ijDay(picked));
  }

  Future<void> _savePayment(Map<String, dynamic> e) async {
    final amount = _digits('${e['amount']}');
    if (amount <= 0) {
      _toastMsg(ij('needPayAmount'));
      return;
    }
    final chargeId = '${e['chargeId']}';
    final note = '${e['note']}'.trim();
    final body = <String, dynamic>{
      'house_id': e['houseId'],
      if (chargeId.isNotEmpty) 'charge_id': chargeId,
      'amount': amount,
      'paid_at': ijYmd(e['date'] as DateTime),
      if (note.isNotEmpty) 'note': note,
    };
    setState(() => _busy = true);
    final ok = await ijaraRepo.addPayment(body);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _payEdit = null;
    });
    ok ? _toastMsg(ij('created')) : _toastErr();
  }

  void _askDeletePayment(IjaraPayment pay) {
    setState(() => _confirm = {
          'title': ij('confirmDeleteTitle'),
          'body': '${ijMoneyCur(pay.amount, ijaraRepo.currencyOf(pay.houseId))}\n${ij('confirmDeleteBody')}',
          'danger': true,
          'run': () async {
            final ok = await ijaraRepo.deletePayment(pay.id);
            if (!mounted) return;
            ok ? _toastMsg(ij('deleted')) : _toastErr();
          },
        });
  }

  // ================= KICHIK ELEMENTLAR =================

  /// Tanlov chipi (h40): tanlangan — ink fon + bg matn; aks holda shisha.
  /// PillChip o'rniga o'zimizniki: uzun hisob nomi 220px'da "..." bilan
  /// tugaydi (F11) — PillChip ellipsis qilmaydi.
  Widget _chip(Pal p, String label, bool on, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: on ? p.ink : p.glass,
          border: Border.all(color: on ? p.ink : p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: Tx(label, size: 14, w: FontWeight.w600, color: on ? p.bg : p.t1, maxLines: 1, ellipsis: true, font: TbFont.body),
      ),
    );
  }

  /// Sana tanlash maydoni (GlassField ko'rinishida, bosilsa tanlagich).
  Widget _dateField(Pal p, String text, bool set, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: GlassField(
        h: 52,
        icon: Icons.calendar_today_rounded,
        iconColor: set ? p.amber : p.t2,
        trailing: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: p.t4),
        child: Tx(text, size: 15, w: FontWeight.w500, color: set ? p.ink : p.t5, maxLines: 1, ellipsis: true),
      ),
    );
  }

  /// 023 — pul maydoni: summa inputining OLDIDA pul birligi almashtirgichi
  /// (so'm / \$). Valyuta summa bilan BIR MAYDONDA turadi — alohida chiplar
  /// qatori bo'lsa ega summani terib, valyutani almashtirishni unutardi.
  Widget _moneyField(
    Pal p,
    String label,
    String value,
    ValueChanged<String> onChanged, {
    required String cur,
    required ValueChanged<String> onCur,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(label),
        const SizedBox(height: 10),
        GlassField(
          h: 52,
          focused: value.isNotEmpty,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              for (final c in kIjaraCurrencies) ...[
                _curSeg(p, c, c == cur, () => onCur(c)),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: StoreField(
                  value: value,
                  onChanged: onChanged,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_GroupFmt()],
                  style: tbStyle(size: 15, color: p.ink, w: FontWeight.w500, tab: true),
                  hintColor: p.t5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Pul birligi segmenti (maydon ichidagi ixcham tanlagich).
  Widget _curSeg(Pal p, String cur, bool on, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        constraints: const BoxConstraints(minWidth: 42),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: on ? p.ink : p.glass2,
          border: Border.all(color: on ? p.ink : p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: Tx(ijCurSym(cur),
            size: 13, w: FontWeight.w600, color: on ? p.bg : p.t2,
            maxLines: 1, ellipsis: true, font: TbFont.body),
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
    bool phone = false,
    bool day = false,
    int lines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Cap(label),
        const SizedBox(height: 10),
        GlassField(
          h: lines > 1 ? 52.0 + 22.0 * (lines - 1) : 52.0,
          icon: icon,
          focused: value.isNotEmpty,
          child: StoreField(
            value: value,
            onChanged: onChanged,
            hint: (hint == null || hint.isEmpty) ? null : hint,
            keyboardType: phone
                ? TextInputType.phone
                : (number || day ? TextInputType.number : TextInputType.text),
            // day: oyning kuni — guruhlash YO'Q ("5" "5" bo'lib qolsin),
            // ko'pi bilan 2 raqam (31 dan uzuni terilmasin).
            inputFormatters: phone
                ? [_PhoneFmt()]
                : (day
                    ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]
                    : (number ? [_GroupFmt()] : null)),
            maxLines: lines,
            minLines: lines > 1 ? lines : 1,
            style: tbStyle(size: 15, color: p.ink, w: FontWeight.w500, tab: number || phone || day),
            hintColor: p.t5,
          ),
        ),
      ],
    );
  }
}
