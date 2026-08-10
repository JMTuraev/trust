// Ijaradagi uylar — ijaraga berilgan uylar, oylik hisoblar (ijara/kommunal/boshqa),
// to'lovlar va qoldiq. Vizual til: toyxona.dart bilan AYNAN bir xil primitivlar
// (Tx/Tap/curPal, karta radiusi 18, hairline chegaralar, header + oy dropdown
// naqshi). Yangi komponent uslubi YO'Q.
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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, TextInputFormatter, TextEditingValue, TextSelection;
import 'package:google_fonts/google_fonts.dart';
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

int _digits(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return 0;
  return int.tryParse(d.length > 15 ? d.substring(0, 15) : d) ?? 0;
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
  Map<String, dynamic>? _houseEdit; // {id?, name, tenant, phone, rent}
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

  Color _stateColor(String state, Pal p) => switch (state) {
        'tolangan' => p.green,
        'kechikkan' => p.red,
        'bekor' => p.t4,
        _ => p.t1,
      };

  /// Qoldiq rangi: to'lanmagan qism qizil, yopilgan (yoki ortiqcha) yashil.
  Color _leftColor(int left, Pal p) => left > 0 ? p.red : p.green;

  bool get _anyLayer => _detailId != null;

  bool get _anyModal =>
      _confirm != null ||
      _houseEdit != null ||
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
            if (_detailId != null) Positioned.fill(child: Container(color: p.bg, child: _detail(p))),
            if (_monthMenu) _monthMenuCard(p),
            if (_capOpen) _capModal(p),
            if (_gen != null) _genModal(p),
            if (_confirm != null) _confirmModal(p),
            if (_houseEdit != null) _houseModal(p),
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

  Widget _header(Pal p) {
    final n = ijaraRepo.houses.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            Tap(
              onTap: widget.onBack,
              child: SizedBox(width: 34, height: 34, child: Center(child: BackChevron(color: p.ink))),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(ij('title'), size: 17, w: FontWeight.w700, color: p.ink, ls: -0.2, maxLines: 2),
                const SizedBox(height: 1),
                // Uylar soni / chegara — "3 / 5" (faqat raqam, tarjima talab qilmaydi)
                Tx('$n / ${ijaraRepo.maxHouses}', size: 11.5, color: p.t3, maxLines: 1),
              ],
            ),
          ),
          // Oy filtri — toyxona/xarajat davr dropdown'i bilan bir uslub
          Tap(
            onTap: () => setState(() => _monthMenu = true),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: p.bd),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Tx('${ijMonth(_month.month)} ${_month.year}',
                          size: 11.5, w: FontWeight.w600, color: p.ink, maxLines: 1),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Tx('▾', size: 9, color: p.t3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Oy tanlash — header trigger ostidagi anchored karta (toyxona bilan 1:1).
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
            top: 54,
            right: 20,
            child: Container(
              constraints: const BoxConstraints(minWidth: 186, maxHeight: 330),
              decoration: BoxDecoration(
                color: p.bg,
                border: Border.all(color: p.bd2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(offset: Offset(0, 10), blurRadius: 28, color: Color(0x29000000))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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

  /// Menyu qatori — tanlanganida w600 + o'ngda 6px nuqta (home._fltItem uslubi).
  /// `current` (joriy oy, tanlanmagan bo'lsa) — to'ldirilmagan halqa belgisi.
  Widget _menuRow(Pal p, String label, bool on, bool first, VoidCallback onTap,
      {bool current = false}) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 13.5, w: on || current ? FontWeight.w600 : FontWeight.w500, color: p.ink),
            if (on) ...[
              const SizedBox(width: 12),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle)),
            ] else if (current) ...[
              const SizedBox(width: 12),
              Container(
                width: 6,
                height: 6,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(p),
          // F1: davr yuklanmadi — eski oy sonlari o'rniga banner + qayta urinish
          if (ijaraRepo.loaded && ijaraRepo.loadError != null) ...[
            const SizedBox(height: 16),
            _periodErrorBanner(p),
          ] else if (missing.isNotEmpty && !refreshing) ...[
            const SizedBox(height: 16),
            _genBanner(p, missing),
          ],
          const SizedBox(height: 20),
          if (all.isEmpty)
            _noHousesCard(p)
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Tx(ij('housesCap'), size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4),
            ),
            const SizedBox(height: 10),
            // Filtr faol-u mos uy yo'q — ro'yxat o'rniga qisqa izoh
            if (houses.isEmpty && _pillFilter != null)
              Tx(ij('pillEmpty'), size: 12, color: p.t4)
            else
              for (var i = 0; i < houses.length; i++) ...[
                _houseRow(p, houses[i]),
                if (i < houses.length - 1) const SizedBox(height: 8),
              ],
            if (!ijaraRepo.canAddHouse) ...[
              const SizedBox(height: 12),
              Tx(ij('capNote', {'n': '${ijaraRepo.maxHouses}'}), size: 11.5, color: p.t4, lh: 17),
            ],
          ],
          // U7: arxivlangan uylar — ro'yxat oxirida yig'ma bo'lim
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 26),
            Tap(
              onTap: () => setState(() => _archOpen = !_archOpen),
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Tx(ij('archivedSection', {'n': '${archived.length}'}),
                          size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4, maxLines: 1, ellipsis: true),
                    ),
                    Tx(_archOpen ? '▴' : '▾', size: 9, color: p.t3),
                  ],
                ),
              ),
            ),
            if (_archOpen) ...[
              const SizedBox(height: 10),
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
              valueColor: AlwaysStoppedAnimation<Color>(p.t3),
            ),
          ),
      ],
    );
  }

  /// F1: oy hisoblari yuklanmadi — sarlavha ishlayveradi, ro'yxat tanasida
  /// sabab + qayta urinish (eski oy qatorlari allaqachon tozalangan).
  Widget _periodErrorBanner(Pal p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: p.red),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(ij('periodLoadFailed'), size: 12.5, w: FontWeight.w600, color: p.t1, maxLines: 2, lh: 17),
                if ('${ijaraRepo.loadError}'.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Tx('${ijaraRepo.loadError}', size: 11, color: p.t4, maxLines: 2, ellipsis: true, lh: 15),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tap(
            onTap: () => ijaraRepo.load(_month),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: p.bd),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Tx(ij('retry'), size: 11.5, w: FontWeight.w600, color: p.ink),
            ),
          ),
        ],
      ),
    );
  }

  /// U2: "bu oyda N ta uyga hisob yozilmagan" banneri — tasdiqlash varag'ini ochadi.
  Widget _genBanner(Pal p, List<House> missing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tx(ij('genChargesBanner', {'n': '${missing.length}'}),
                size: 12, color: p.t1, lh: 17, maxLines: 3, ellipsis: true),
          ),
          const SizedBox(width: 10),
          Tap(
            onTap: () => setState(() {
              _gen = missing;
              _genDone = 0;
            }),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(999)),
              child: Tx(ij('genChargesBtn'), size: 11.5, w: FontWeight.w600, color: p.bg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton(Pal p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skel(wf: .45, h: 11),
          const SizedBox(height: 12),
          const Skel(wf: .62, h: 30),
          const SizedBox(height: 10),
          const Skel(wf: .8, h: 12),
          const SizedBox(height: 26),
          for (var i = 0; i < 4; i++) ...[
            const Skel(h: 68, r: 18),
            const SizedBox(height: 8),
          ],
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
            Tx(ij('loadFailed'), size: 14, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
            const SizedBox(height: 6),
            Tx(ijaraRepo.error ?? '', size: 12, color: p.t4, align: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: 170,
              child: GhostBtn(label: ij('retry'), onTap: () => ijaraRepo.load(_month), h: 44),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(Pal p) {
    final t = ijaraRepo.periodTotals;
    final n = ijaraRepo.houses.length;
    // F3: manfiy qoldiq = ORTIQCHA to'lov. Yalang'och absolyut son chiqmaydi:
    // '+' belgisi + yashil + "Oldindan to'langan" izohi (qarz bilan adashmasin).
    final over = t.left < 0;
    final pills = ijPillSums(ijaraRepo.charges, ijaraRepo.payments);
    final anyPill =
        (pills['pending'] ?? 0) != 0 || (pills['overdue'] ?? 0) != 0 || (pills['paid'] ?? 0) != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tx(
          ij('summaryCap', {'month': '${ijMonth(_month.month)} ${_month.year}', 'n': '$n'}),
          size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4,
        ),
        const SizedBox(height: 7),
        // Sarlavha raqami — QOLDIQ (ega uchun eng muhim son: yig'ilmagan pul).
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Tx(over ? '+${ijFx(t.left)}' : ijFx(t.left),
                    size: 30, w: FontWeight.w700, color: _leftColor(t.left, p), ls: -0.6, tab: true),
              ),
            ),
            const SizedBox(width: 7),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tx(ij('som'), size: 13, color: p.t3),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Tx(ij('leftLabel'), size: 11.5, w: FontWeight.w600, color: p.t3),
            if (over) ...[
              const SizedBox(width: 7),
              Flexible(
                child: Tx(ij('overpaidNote'),
                    size: 11.5, w: FontWeight.w600, color: p.green, maxLines: 1, ellipsis: true),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Tx(
          ij('summaryLine', {'charged': ijMoney(t.charged), 'paid': ijMoney(t.paid)}),
          size: 12, color: p.t2, lh: 17,
        ),
        // U4: oy holat pill'lari — bosilsa ro'yxat shu holat bo'yicha filtrlanadi
        if (anyPill) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _pill(p, 'pending', ij('pillPending'), pills['pending'] ?? 0, p.t1),
              _pill(p, 'overdue', ij('pillOverdue'), pills['overdue'] ?? 0, p.red),
              _pill(p, 'paid', ij('pillPaid'), pills['paid'] ?? 0, p.green),
            ],
          ),
        ],
      ],
    );
  }

  /// U4: bitta holat pill'i. Tanlangani to'liq bo'yaladi (chip uslubi),
  /// rang nuqtasi holatni bildiradi (kechikkan — qizil, to'langan — yashil).
  Widget _pill(Pal p, String key, String label, int sum, Color accent) {
    final on = _pillFilter == key;
    return Tap(
      onTap: () => setState(() => _pillFilter = on ? null : key),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: on ? p.ink : const Color(0x00000000),
          border: Border.all(color: on ? p.ink : p.bd),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: on ? p.bg : accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Tx('$label · ${ijFx(sum)}',
                size: 11.5, w: FontWeight.w600, color: on ? p.bg : p.t1, maxLines: 1, tab: true),
          ],
        ),
      ),
    );
  }

  Widget _noHousesCard(Pal p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 26),
      decoration: BoxDecoration(
        color: p.hov2,
        border: Border.all(color: p.hair2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Tx(ij('noHousesTitle'), size: 14, w: FontWeight.w600, color: p.t1, align: TextAlign.center),
          const SizedBox(height: 6),
          Tx(ij('noHousesSub'), size: 12, color: p.t4, align: TextAlign.center, lh: 17),
        ],
      ),
    );
  }

  Widget _houseRow(Pal p, House h) {
    final t = ijaraRepo.totalsOf(h.id);
    final overdue = ijaraRepo.overdueOf(h.id);
    final hasCharges = ijaraRepo.chargesOf(h.id).isNotEmpty;
    final barColor = overdue > 0 ? p.red : (t.charged == 0 ? p.t4 : _leftColor(t.left, p));
    return Tap(
      onTap: () => setState(() => _detailId = h.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: p.hov2,
          border: Border.all(color: p.hair2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, height: 38, color: barColor),
            const SizedBox(width: 11),
            // Nom va ijarachi — 2 qatorga o'raladi, undan uzuni "..." (F11)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(h.name, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2, ellipsis: true, lh: 19),
                  const SizedBox(height: 3),
                  Tx(h.tenantName.isEmpty ? ij('noTenant') : h.tenantName,
                      size: 11.5, color: p.t3, maxLines: 2, ellipsis: true, lh: 16),
                  // U5: kechikkan hisob — qizil nuqta + yorliq (bir qarashda ko'rinsin)
                  if (overdue > 0) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: p.red, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Tx(overdue == 1 ? ij('overdue') : ij('overdueN', {'n': '$overdue'}),
                              size: 11, w: FontWeight.w600, color: p.red, maxLines: 1, ellipsis: true),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Pul — FittedBox: hech qachon "..." bo'lmaydi
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tx(ijMoney(t.left), size: 13.5, w: FontWeight.w600, color: _leftColor(t.left, p), tab: true),
                  ),
                  const SizedBox(height: 3),
                  // U6: "Bu oyda hisob yo'q" qatori BOSILADI — hisob formasi
                  // shu uy va shu oy uchun tayyor holda ochiladi.
                  !hasCharges
                      ? Tap(
                          onTap: () => _openNewCharge(h),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Tx(ij('noChargeMonth'), size: 11, color: p.t3, maxLines: 1),
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Tx(
                            t.left <= 0
                                ? ij('allPaid')
                                : ij('paidOf', {'paid': ijFx(t.paid), 'total': ijFx(t.charged)}),
                            size: 11,
                            color: p.t3,
                            maxLines: 1,
                          ),
                        ),
                  // U1: bir bosishda "pul keldi" — to'lov formasi to'ldirilgan
                  // holda ochiladi. U6: hisob yo'q oyda — "+ Hisob" yorlig'i.
                  if (hasCharges && t.left > 0) ...[
                    const SizedBox(height: 8),
                    _rowPillBtn(p, '✓ ${ij('quickPay')}', filled: true, onTap: () => _openQuickPay(h)),
                  ] else if (!hasCharges) ...[
                    const SizedBox(height: 8),
                    _rowPillBtn(p, ij('addCharge'), filled: false, onTap: () => _openNewCharge(h)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Uy qatoridagi ixcham harakat pill'i (U1/U6).
  Widget _rowPillBtn(Pal p, String label, {required bool filled, required VoidCallback onTap}) {
    return Tap(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? p.ink : const Color(0x00000000),
          border: Border.all(color: filled ? p.ink : p.bd),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Tx(label, size: 11.5, w: FontWeight.w600, color: filled ? p.bg : p.ink, maxLines: 1),
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
        });
  }

  /// U7: arxivlangan uy qatori — xira ko'rinish + "Arxivdan chiqarish".
  Widget _archivedRow(Pal p, House h) {
    final busy = _unarchBusy == h.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: p.hair2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(h.name, size: 13.5, w: FontWeight.w600, color: p.t3, maxLines: 1, ellipsis: true),
                  if (h.tenantName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Tx(h.tenantName, size: 11, color: p.t4, maxLines: 1, ellipsis: true),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tap(
              onTap: busy || _unarchBusy.isNotEmpty ? null : () => _unarchive(h),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: p.bd),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: busy
                    ? SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(p.ink)),
                      )
                    : Tx(ij('unarchive'), size: 11.5, w: FontWeight.w600, color: p.ink),
              ),
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

  Widget _bottomBar(Pal p) {
    if (_anyLayer) return const SizedBox.shrink();
    return Container(
      // Gradient YO'Q (gradient qatlami tap'larni yutib yuborardi) — qattiq fon
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: p.hair2, margin: const EdgeInsets.only(bottom: 12)),
          InkBtn(label: ij('addHouse'), onTap: _openNewHouse),
        ],
      ),
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
    return Column(
      children: [
        _layerHeader(
          p,
          h.name,
          '${ijMonth(_month.month)} ${_month.year}',
          () => setState(() => _detailId = null),
          action: Tap(
            onTap: () => _openEditHouse(h),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                border: Border.all(color: p.bd),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(child: Tx(ij('edit'), size: 12, w: FontWeight.w600, color: p.ink)),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tenantBlock(p, h),
                const SizedBox(height: 20),
                _balanceBlock(p, h),
                const SizedBox(height: 20),
                _chargesBlock(p, h),
                const SizedBox(height: 20),
                _paymentsBlock(p, h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _layerHeader(Pal p, String title, String sub, VoidCallback onClose, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
      child: Row(
        children: [
          Tap(
            onTap: onClose,
            child: SizedBox(width: 34, height: 34, child: Center(child: BackChevron(color: p.ink))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uy nomi 2 qatorga o'raladi, undan uzuni "..." (F11)
                Tx(title, size: 17, w: FontWeight.w700, color: p.ink, ls: -0.2, maxLines: 2, ellipsis: true, lh: 22),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Tx(sub, size: 11.5, color: p.t3, maxLines: 1),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action],
        ],
      ),
    );
  }

  Widget _cap(Pal p, String t) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Tx(t, size: 11, w: FontWeight.w600, color: p.t2, ls: 1.4),
      );

  Widget _tenantBlock(Pal p, House h) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cap(p, ij('tenantCap')),
        const SizedBox(height: 8),
        Tx(h.tenantName.isEmpty ? ij('noTenant') : h.tenantName,
            size: 19,
            w: FontWeight.w700,
            color: h.tenantName.isEmpty ? p.t3 : p.ink,
            ls: -0.3,
            maxLines: 2,
            ellipsis: true,
            lh: 25),
        const SizedBox(height: 5),
        if (h.tenantPhone.isEmpty)
          Tx(ij('noPhone'), size: 12.5, color: p.t4)
        else
          Row(
            children: [
              // Raqamga bosish — nusxalash (eski xatti-harakat saqlanadi)
              Expanded(
                child: Tap(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: h.tenantPhone));
                    _toastMsg(ij('phoneCopied'));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Tx(h.tenantPhone,
                            size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true),
                      ),
                      const SizedBox(width: 7),
                      Icon(Icons.copy_rounded, size: 13, color: p.t3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // U3: egan har kuni qiladigan ish — ijarachiga QO'NG'IROQ
              Tap(
                onTap: () => _callTenant(h.tenantPhone),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call_rounded, size: 13, color: p.bg),
                      const SizedBox(width: 6),
                      Tx(ij('call'), size: 12, w: FontWeight.w600, color: p.bg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Tx(h.rentAmount > 0 ? ij('rentLine', {'amount': ijMoney(h.rentAmount)}) : ij('noRent'),
            size: 12.5, color: p.t2),
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
        _cap(p, ij('balanceCap')),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: p.hov2,
            border: Border.all(color: p.hair2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _totalRow(p, ij('chargedLabel'), ijMoney(t.charged), p.ink),
              const SizedBox(height: 7),
              _totalRow(p, ij('paidLabel'), ijMoney(t.paid), p.green),
              const SizedBox(height: 10),
              Container(height: 1, color: p.hair2),
              const SizedBox(height: 10),
              _totalRow(p, ij('leftLabel'), ijMoney(t.left), _leftColor(t.left, p), big: true),
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
        Tx(label, size: big ? 12 : 11.5, w: big ? FontWeight.w600 : FontWeight.w400, color: p.t2, ls: big ? 0.6 : null),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Tx(value, size: big ? 16 : 13, w: big ? FontWeight.w700 : FontWeight.w600, color: c, tab: true),
          ),
        ),
      ],
    );
  }

  // ---- Hisoblar (davr) ----

  Widget _chargesBlock(Pal p, House h) {
    final list = ijaraRepo.chargesOf(h.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cap(p, ij('chargesCap')),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tx(ij('noCharges'), size: 12.5, color: p.t4),
          )
        else
          for (final c in list) _chargeRow(p, c),
        const SizedBox(height: 4),
        _addBtnRow(p, ij('addCharge'), () => _openNewCharge(h)),
      ],
    );
  }

  Widget _chargeRow(Pal p, Charge c) {
    final state = ijChargeState(c);
    final due = c.dueDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tap(
        onTap: () => _openEditCharge(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: p.hov2,
            border: Border.all(color: p.hair2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3, height: 34, color: _stateColor(state, p)),
              const SizedBox(width: 11),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hisob nomi 2 qatorga o'raladi, undan uzuni "..." (F11)
                    Tx(c.title.isEmpty ? ijKind(c.kind) : c.title,
                        size: 13.5, w: FontWeight.w600, color: p.ink, maxLines: 2, ellipsis: true, lh: 18),
                    const SizedBox(height: 3),
                    Tx('${ijKind(c.kind)} · ${due == null ? ij('noDue') : ij('dueOn', {'date': ijDateShort(due)})}',
                        size: 11, color: p.t3, maxLines: 2, ellipsis: true, lh: 15),
                    // QISMAN to'lov ko'rinishi (mahsulot talabi)
                    if (!c.cancelled && c.paid > 0 && c.left > 0) ...[
                      const SizedBox(height: 3),
                      Tx(ij('paidOf', {'paid': ijFx(c.paid), 'total': ijFx(c.amount)}),
                          size: 11, color: p.t3, maxLines: 1),
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
                      child: Tx(ijMoney(c.amount),
                          size: 13.5, w: FontWeight.w600, color: c.cancelled ? p.t4 : p.ink, tab: true),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Tx(
                        c.cancelled || c.left <= 0
                            ? ijState(state)
                            : ij('leftShort', {'left': ijFx(c.left)}),
                        size: 11, w: FontWeight.w600, color: _stateColor(state, p), maxLines: 1,
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

  // ---- To'lovlar (davr) ----

  Widget _paymentsBlock(Pal p, House h) {
    final list = ijaraRepo.paymentsOf(h.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cap(p, ij('paymentsCap')),
        const SizedBox(height: 10),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tx(ij('noPayments'), size: 12.5, color: p.t4),
          )
        else
          for (final pay in list) _paymentRow(p, pay),
        const SizedBox(height: 4),
        _addBtnRow(p, ij('addPayment'), () => _openNewPayment(h)),
      ],
    );
  }

  Widget _paymentRow(Pal p, IjaraPayment pay) {
    final d = pay.date;
    final linked = ijaraRepo.chargeById(pay.chargeId);
    final title = linked == null
        ? ij('payGeneral')
        : (linked.title.isEmpty ? ijKind(linked.kind) : linked.title);
    final sub = [
      if (d != null) ijDateShort(d),
      if (pay.note.isNotEmpty) pay.note,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.hov2,
          border: Border.all(color: p.hair2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(title, size: 13, w: FontWeight.w500, color: p.ink, maxLines: 2, ellipsis: true, lh: 17),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Tx(sub, size: 11, color: p.t4, maxLines: 2, ellipsis: true, lh: 15),
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
                child: Tx(ijMoney(pay.amount), size: 13, w: FontWeight.w600, color: p.green, tab: true),
              ),
            ),
            _xBtn(p, () => _askDeletePayment(pay)),
          ],
        ),
      ),
    );
  }

  /// O'chirish (×) tugmasi. F11: bosish maydoni 40×40 (padding hisobiga) —
  /// ikonkaning KO'RINISHI o'zgarmaydi, barmoq esa bemalol tegadi.
  Widget _xBtn(Pal p, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: Icon(Icons.close_rounded, size: 14, color: p.t3)),
      ),
    );
  }

  Widget _addBtnRow(Pal p, String label, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: p.bd),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Tx(label, size: 12.5, w: FontWeight.w600, color: p.ink),
      ),
    );
  }

  // ================= MODALLAR =================

  Widget _scrimCard(Pal p, VoidCallback close, Widget card) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : close,
        child: Container(
          color: p.dim,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: GestureDetector(
            onTap: () {},
            child: SingleChildScrollView(child: card),
          ),
        ),
      ),
    );
  }

  BoxDecoration _modalDeco(Pal p) => BoxDecoration(
        color: p.bg,
        border: Border.all(color: p.bd2),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 40, offset: const Offset(0, 16))
        ],
      );

  Widget _confirmModal(Pal p) {
    final c = _confirm!;
    return _scrimCard(
      p,
      () => setState(() => _confirm = null),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx('${c['title']}', size: 15, w: FontWeight.w700, color: p.ink, maxLines: 2, lh: 20),
            const SizedBox(height: 7),
            Tx('${c['body']}', size: 12.5, color: p.t2, lh: 18),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GhostBtn(
                    label: ij('no'),
                    h: 44,
                    fs: 13.5,
                    onTap: () => setState(() => _confirm = null),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Tap(
                    onTap: _busy ? null : () => _runConfirm(c),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c['danger'] == true ? p.red : p.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(p.bg)),
                            )
                          : Tx(ij('yes'), size: 13.5, w: FontWeight.w600, color: p.bg),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return _scrimCard(
      p,
      () => setState(() => _capOpen = false),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(ij('capTitle'), size: 15, w: FontWeight.w700, color: p.ink, maxLines: 2, lh: 20),
            const SizedBox(height: 7),
            Tx(ij('capBody', {'n': '${ijaraRepo.maxHouses}'}), size: 12.5, color: p.t2, lh: 18),
            const SizedBox(height: 18),
            InkBtn(label: ij('ok'), h: 44, fs: 13.5, onTap: () => setState(() => _capOpen = false)),
          ],
        ),
      ),
    );
  }

  // ---- Oy generatori (U2) ----

  /// Tasdiqlash varag'i: qaysi uylarga qancha hisob yozilishi RO'YXAT bilan
  /// ko'rsatiladi, jami summa ostida. Yozish ketma-ket, jarayon "2/5..." ko'rinadi.
  Widget _genModal(Pal p) {
    final list = _gen!;
    final total = list.fold<int>(0, (s, h) => s + h.rentAmount);
    return _scrimCard(
      p,
      () {
        if (!_genBusy) setState(() => _gen = null);
      },
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(ij('genSheetTitle'), size: 15, w: FontWeight.w700, color: p.ink, maxLines: 2, lh: 20),
            const SizedBox(height: 7),
            Tx(ij('genSheetBody', {'month': '${ijMonth(_month.month)} ${_month.year}'}),
                size: 12.5, color: p.t2, lh: 18),
            const SizedBox(height: 12),
            for (final h in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Tx(h.name, size: 12.5, w: FontWeight.w500, color: p.ink, maxLines: 1, ellipsis: true),
                    ),
                    const SizedBox(width: 12),
                    Tx(ijMoney(h.rentAmount), size: 12.5, w: FontWeight.w600, color: p.ink, tab: true),
                  ],
                ),
              ),
            const SizedBox(height: 3),
            Container(height: 1, color: p.hair2),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Tx(ij('genTotal'), size: 11.5, w: FontWeight.w600, color: p.t2, ls: 0.6),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tx(ijMoney(total), size: 13.5, w: FontWeight.w700, color: p.ink, tab: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _genBusy
                ? Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(12)),
                    child: Tx(ij('genProgress', {'done': '$_genDone', 'n': '${list.length}'}),
                        size: 13.5, w: FontWeight.w600, color: p.bg, tab: true),
                  )
                : InkBtn(label: ij('genChargesBtn'), h: 46, fs: 13.5, onTap: () => _runGen(list)),
          ],
        ),
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
    setState(() => _houseEdit = {'name': '', 'tenant': '', 'phone': '', 'rent': ''});
  }

  void _openEditHouse(House h) => setState(() => _houseEdit = {
        'id': h.id,
        'name': h.name,
        'tenant': h.tenantName,
        'phone': h.tenantPhone,
        'rent': h.rentAmount > 0 ? ijFx(h.rentAmount) : '',
      });

  Widget _houseModal(Pal p) {
    final e = _houseEdit!;
    final isNew = e['id'] == null;
    return _scrimCard(
      p,
      () => setState(() => _houseEdit = null),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(isNew ? ij('newHouse') : ij('editHouse'), size: 15, w: FontWeight.w700, color: p.ink),
            const SizedBox(height: 14),
            _field(p, ij('houseNameLabel'), '${e['name']}', (v) => setState(() => e['name'] = v),
                hint: ij('houseNamePh')),
            const SizedBox(height: 10),
            _field(p, ij('tenantNameLabel'), '${e['tenant']}', (v) => setState(() => e['tenant'] = v),
                hint: ij('tenantNamePh')),
            const SizedBox(height: 10),
            _field(p, ij('tenantPhoneLabel'), '${e['phone']}', (v) => setState(() => e['phone'] = v),
                phone: true),
            // U8: ijarachi almashganda uy o'chirilmasin — shu formada yangilanadi,
            // o'tgan oylar tarixi uyda qoladi. Yumshoq eslatma (faqat tahrirda).
            if (!isNew) ...[
              const SizedBox(height: 6),
              Tx(ij('tenantChangeNote'), size: 11, color: p.t4, lh: 15),
            ],
            const SizedBox(height: 10),
            _field(p, ij('rentAmountLabel'), '${e['rent']}', (v) => setState(() => e['rent'] = v),
                number: true),
            const SizedBox(height: 16),
            InkBtn(label: ij('save'), h: 46, loading: _busy, onTap: () => _saveHouse(e)),
            if (!isNew) ...[
              const SizedBox(height: 6),
              Tap(
                onTap: () => _askArchiveHouse('${e['id']}', '${e['name']}'),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  child: Tx(ij('archiveHouse'), size: 13, w: FontWeight.w600, color: p.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveHouse(Map<String, dynamic> e) async {
    final name = '${e['name']}'.trim();
    if (name.isEmpty) {
      _toastMsg(ij('needHouseName'));
      return;
    }
    final body = <String, dynamic>{
      'name': name,
      'tenant_name': '${e['tenant']}'.trim(),
      'tenant_phone': '${e['phone']}'.trim(),
      'rent_amount': _digits('${e['rent']}'),
    };
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
        'due': null,
      });

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
    return _scrimCard(
      p,
      () => setState(() => _chargeEdit = null),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(isNew ? ij('newCharge') : ij('editCharge'), size: 15, w: FontWeight.w700, color: p.ink),
            const SizedBox(height: 14),
            _cap(p, ij('kindLabel')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final k in kIjaraKinds)
                  _chip(p, ijKind(k), e['kind'] == k, () => _pickKind(e, k)),
              ],
            ),
            const SizedBox(height: 12),
            _field(p, ij('chargeTitleLabel'), '${e['title']}', (v) => setState(() => e['title'] = v),
                hint: ij('chargeTitlePh')),
            const SizedBox(height: 10),
            _field(p, ij('amountLabel'), '${e['amount']}', (v) => setState(() => e['amount'] = v),
                number: true),
            const SizedBox(height: 10),
            _cap(p, ij('dueDateLabel')),
            const SizedBox(height: 7),
            Tap(
              onTap: () => _pickDue(e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Tx(due == null ? ij('noDue') : ijDateLong(due),
                          size: 14, w: FontWeight.w500, color: due == null ? p.t5 : p.ink, maxLines: 1),
                    ),
                    Icon(Icons.calendar_today_rounded, size: 15, color: p.t3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkBtn(label: ij('save'), h: 46, loading: _busy, onTap: () => _saveCharge(e)),
            // Bekor qilinganlar bu formaga tushmaydi (yuqorida ko'rish oynasiga
            // buriladi) — shu sabab shart faqat isNew.
            if (!isNew) ...[
              const SizedBox(height: 6),
              Tap(
                onTap: () => _askCancelCharge('${e['id']}', '${e['title']}'),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  child: Tx(ij('cancelCharge'), size: 13, w: FontWeight.w600, color: p.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// F8: bekor qilingan hisobning FAQAT KO'RISH oynasi — forma yo'q, saqlash
  /// yo'q; kichik "Bekor" belgisi + summa + tur/muddat, yopish tugmasi.
  Widget _chargeViewModal(Pal p, Map<String, dynamic> e) {
    final due = e['due'] as DateTime?;
    final title = '${e['title']}'.trim();
    return _scrimCard(
      p,
      () => setState(() => _chargeEdit = null),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Tx(title.isEmpty ? ijKind('${e['kind']}') : title,
                      size: 15, w: FontWeight.w700, color: p.ink, maxLines: 2, ellipsis: true, lh: 20),
                ),
                const SizedBox(width: 10),
                // "Bekor" belgisi
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.bd),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Tx(ij('stBekor'), size: 10.5, w: FontWeight.w600, color: p.t3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Tx(ij('cancelledCharge'), size: 12, color: p.t4),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx('${e['amount']} ${ij('som')}',
                  size: 20, w: FontWeight.w700, color: p.t3, tab: true),
            ),
            const SizedBox(height: 5),
            Tx('${ijKind('${e['kind']}')} · ${due == null ? ij('noDue') : ijDateLong(due)}',
                size: 12, color: p.t2, maxLines: 2, ellipsis: true),
            const SizedBox(height: 16),
            GhostBtn(label: ij('ok'), h: 44, fs: 13.5, onTap: () => setState(() => _chargeEdit = null)),
          ],
        ),
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

  /// F7: umumiy sana tanlagich — ilova palitrasidagi monoxrom Theme
  /// (home.dart _pickCustomRange bilan AYNAN bir xil) va CLAMP: initialDate
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
            primary: p.ink,
            onPrimary: p.bg,
            surface: p.bg,
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

  Widget _payModal(Pal p) {
    final e = _payEdit!;
    final date = e['date'] as DateTime;
    // Faqat yopilmagan hisoblar tanlov uchun mantiqiy
    final open = ijaraRepo
        .chargesOf('${e['houseId']}')
        .where((c) => !c.cancelled && c.left > 0)
        .toList();
    return _scrimCard(
      p,
      () => setState(() => _payEdit = null),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: _modalDeco(p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(ij('newPayment'), size: 15, w: FontWeight.w700, color: p.ink),
            const SizedBox(height: 14),
            if (open.isNotEmpty) ...[
              _cap(p, ij('payTargetCap')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
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
              const SizedBox(height: 12),
            ],
            _field(p, ij('payAmountLabel'), '${e['amount']}', (v) => setState(() => e['amount'] = v),
                number: true),
            const SizedBox(height: 10),
            _cap(p, ij('payDateLabel')),
            const SizedBox(height: 7),
            Tap(
              onTap: () => _pickPayDate(e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: Tx(ijDateLong(date), size: 14, w: FontWeight.w500, color: p.ink, maxLines: 1)),
                    Icon(Icons.calendar_today_rounded, size: 15, color: p.t3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _field(p, ij('payNoteLabel'), '${e['note']}', (v) => setState(() => e['note'] = v)),
            const SizedBox(height: 16),
            InkBtn(label: ij('addBtn'), h: 46, loading: _busy, onTap: () => _savePayment(e)),
          ],
        ),
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
          'body': '${ijMoney(pay.amount)}\n${ij('confirmDeleteBody')}',
          'danger': true,
          'run': () async {
            final ok = await ijaraRepo.deletePayment(pay.id);
            if (!mounted) return;
            ok ? _toastMsg(ij('deleted')) : _toastErr();
          },
        });
  }

  // ================= KICHIK ELEMENTLAR =================

  Widget _chip(Pal p, String label, bool on, VoidCallback onTap) {
    return Tap(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: on ? p.ink : const Color(0x00000000),
          border: Border.all(color: on ? p.ink : p.bd),
          borderRadius: BorderRadius.circular(999),
        ),
        // F11: uzun hisob nomi qattiq KESILMAYDI — "..." bilan tugaydi
        child: Tx(label, size: 12.5, w: FontWeight.w600, color: on ? p.bg : p.ink, maxLines: 1, ellipsis: true),
      ),
    );
  }

  /// Yorliqli maydon (Cap + input qutisi).
  Widget _field(
    Pal p,
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? hint,
    bool number = false,
    bool phone = false,
    int lines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cap(p, label),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
          child: StoreField(
            value: value,
            onChanged: onChanged,
            hint: (hint == null || hint.isEmpty) ? null : hint,
            keyboardType: phone
                ? TextInputType.phone
                : (number ? TextInputType.number : TextInputType.text),
            inputFormatters: number ? [_GroupFmt()] : null,
            maxLines: lines,
            minLines: lines > 1 ? lines : 1,
            style: GoogleFonts.inter(fontSize: 14, color: p.ink, fontWeight: FontWeight.w500),
            hintColor: p.t5,
          ),
        ),
      ],
    );
  }
}
