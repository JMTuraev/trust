// BOSH HUB — ilovaning ildiz ekrani (pastki navigatsiya o'rniga).
//
// Dizayn manbai: prototype/redesign/DESIGN_SPEC.md §5.6 «Bosh (Hub)» —
// "dark glass + gradient" (Claude Design, 2026-09-07):
//   header (RingAvatar · salom + sana · AI · qo'ng'iroq) ->
//   [pending bog'lanish banneri] ->
//   2×2 shisha kartalar (Xarajatlar | Qarz daftar / Ijaradagi uylar | To'yxona)
//   + o'ng-pastda gradient FAB (yordam chati).
//
// Navigatsiya: hub -> karta bosiladi -> bo'lim TO'LIQ EKRAN ochiladi ->
// header'dagi orqaga (<) hub'ga qaytaradi (store: goHub_ / hubBack).
// Barcha raqam va matnlar store.vals() / store.L() dan (real ma'lumot) — mock yo'q.
import 'package:flutter/material.dart';

import '../flags.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'paywall_sheet.dart';

/// «used/limit» hisoblagich chipi chiziladigan eng katta bepul limit.
///
/// NEGA KERAK: production'da render.yaml FREE_DEBT_ENTRIES/FREE_EXPENSE_ENTRIES
/// ATAYLAB 300 ga qo'yilgan — Play Billing ulanmaguncha hech kim to'siqqa
/// urilmasin. Server o'sha qiymatni `free_limit` sifatida qaytaradi, natijada
/// bosh ekranda har bir bepul foydalanuvchiga «7/300» ko'rinardi: dizayn
/// «3/5» ko'rsatadi, 300 esa ichki sinov qiymati — ekran buzuq bo'lib o'qiladi.
/// Shu sababli "cheksizga yaqin" limitlarda hisoblagich UMUMAN chizilmaydi.
/// QULF chipi (limit tugagan holat) bundan mustasno — u har qanday limitda
/// odatdagidek ishlaydi.
///
/// QIYMAT store.dart'dan OLINADI (nusxa emas, taqsimlangan `kSubLimitDisplayMax`):
/// ikkita mustaqil "shift" bo'lsa chip bir ekranda ko'rinib, boshqasida
/// yo'qolishi mumkin edi.
const int kModChipMaxLimit = kSubLimitDisplayMax;

/// Hub kartasining balandligi IXCHAM (skroll) rejimda.
///
/// Dizayn (§5.6): 2×2 grid ekran balandligini TENG bo'lib to'ldiradi (Expanded
/// qatorlar) — kartaning bo'yi ekranga qarab o'zgaradi. Tana balandligi
/// [kHubGridMinH] dan KICHIK bo'lsa (kichik/eski qurilma, klaviatura, split
/// screen) grid o'rniga skroll + QAT'IY karta balandligi ishlatiladi — aks
/// holda kartalar siqilib, illyustratsiya va matn toshib ketardi.
/// To'rttala karta har ikki rejimda ham AYNAN bir xil bo'yda (hub_cards_test).
const double kHubCardH = 200;

/// Shu balandlikdan boshlab grid ekranni to'ldiradi (aks holda skroll rejimi).
const double kHubGridMinH = 560;

/// Qo'llanma rejimida yuqori-chap burchakdagi ikonka o'lchami (pt).
/// PO 2026-09-08: 40 «juda kichik» — 52 ga oshirildi.
const double kHubGuideIcon = 52;

/// Qo'llanma izohining l10n kaliti (narx ostidagi bir jumla). Modul bu
/// jadvalda BO'LMASA izoh chizilmaydi — faqat tarif turadi.
const Map<String, String> kHubGuideNoteKey = {
  'xarajat': 'hubGuideXar',
  'qarz': 'hubGuideQarz',
  'ijarachi': 'hubGuideIjara',
  'toyxona': 'hubGuideToy',
};

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> with SingleTickerProviderStateMixin {
  /// NARX QO'LLANMASI yoqilganmi («Narxni bilish» tugmasi, PO 2026-09-08).
  ///
  /// Yoqilganda hub «tushuntirish» rejimiga o'tadi: kartalar BOSILMAYDI,
  /// avval TO'RT ikonka yuqori-chap burchakka kichrayib ko'chadi, so'ng
  /// tariflar KETMA-KET «yozilgandek» chiqadi: Xarajatlar yozilib bo'lgach
  /// Qarz daftar, keyin Ijara, keyin To'yxona (hammasi birdan EMAS — PO).
  /// O'chirilsa — hub AYNAN avvalgidek ishlaydi (qo'llanma faqat ko'rinish
  /// qatlami: hech qanday holat, navigatsiya yoki server so'rovi o'zgarmaydi).
  bool _guide = false;

  /// Qo'llanma animatsiyasi (0 = odatdagi karta, 1 = hammasi yozib bo'lingan).
  /// Davomiyligi MATN UZUNLIGIGA qarab _toggleGuide'da hisoblanadi (til va
  /// tarifga bog'liq) — teskarisi (o'chirish) doim qisqa.
  late final AnimationController _gc = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
    // O'chirish tezroq: foydalanuvchi "avvalgi holat"ni kutyapti, tomosha emas.
    reverseDuration: const Duration(milliseconds: 450),
  );

  /// Ikonka ko'chish bosqichi tugaydigan nuqta (0..1) — undan keyin yozuv.
  double _moveEnd = 0.15;

  /// Har karta uchun yozuv oynasi [start, end] (0..1), kSubModuleOrder
  /// tartibida, KETMA-KET (bir-birini kutadi). Standart — teng bo'lingan.
  List<List<double>> _win = const [[.15, .36], [.36, .57], [.57, .78], [.78, 1]];

  static const int _kMoveMs = 450; // ikonkalar ko'chishi
  static const int _kCharMs = 20; // bir belgi «yozilishi»

  /// Ikonka ko'chishi (0..1) — to'rttala kartada BIR VAQTDA, yozuvdan OLDIN:
  /// ikonka hali ko'chayotganda matn chiqsa ustma-ust tushardi (PO 2026-09-08).
  double _iconT() {
    final x = (_gc.value / _moveEnd).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(x);
  }

  /// `i`-karta matnining yozilish ulushi (0..1) — o'z oynasida chiziqli
  /// (belgi tezligi bir tekis), oynasi kelmagan bo'lsa 0, o'tgan bo'lsa 1.
  double _typeT(int i) {
    if (i >= _win.length) return _gc.value >= _moveEnd ? 1 : 0;
    final a = _win[i][0], b = _win[i][1];
    if (b <= a) return _gc.value >= a ? 1 : 0;
    return ((_gc.value - a) / (b - a)).clamp(0.0, 1.0);
  }

  void _toggleGuide() {
    if (!_guide) {
      // Oynalar matn uzunligidan: har belgi _kCharMs, kartalar ketma-ket.
      final v = store.vals();
      final lens = kSubModuleOrder
          .map((m) => _guidePrice(v, m).length + _guideNote(v, m).length)
          .toList();
      var typeMs = lens.fold<int>(0, (a, b) => a + b) * _kCharMs;
      if (typeMs < 400) typeMs = 400;
      final total = _kMoveMs + typeMs;
      _gc.duration = Duration(milliseconds: total);
      _moveEnd = _kMoveMs / total;
      var cur = _moveEnd;
      final win = <List<double>>[];
      for (final n in lens) {
        final wdt = n * _kCharMs / total;
        win.add([cur, cur + wdt]);
        cur += wdt;
      }
      if (win.isNotEmpty) win.last[1] = 1.0; // yaxlitlash qoldig'i oxirgi kartaga
      _win = win;
    }
    setState(() => _guide = !_guide);
    if (_guide) {
      _gc.forward(from: 0);
    } else {
      _gc.reverse();
    }
  }

  @override
  void dispose() {
    _gc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // AI suhbat tarixini oldindan yuklash — header'dagi AI tugmasi bosilganda
    // ekran tarix bilan tayyor ochilsin (PO 2026-08-04: AI kartasi olib
    // tashlandi, kirish nuqtasi endi header ikonkasi). loadAiMsgs() 'aiLoaded'
    // bilan himoyalangan — bir marta yuklanadi. build/vals() ichida EMAS:
    // hosilaviy qiymatlar nojo'ya effektsiz qolishi kerak.
    if (kAiEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => store.loadAiMsgs());
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();
    final skel = v['hubSkel'] == true;
    final empty = !skel && v['hubEmpty'] == true;

    // Qo'llanma animatsiyasi kadrma-kadr qayta chizadi — TANA shu sababli
    // AnimatedBuilder ichida quriladi (qo'llanma o'chiq bo'lsa _gc jim turadi
    // va bu yerda hech narsa qimirlamaydi).
    return AnimatedBuilder(animation: _gc, builder: (_, __) => _body(v, p, skel, empty));
  }

  Widget _body(Map<String, dynamic> v, Pal p, bool skel, bool empty) {
    // 4 ta karta: [Xarajatlar | Qarz daftar] / [Ijaradagi uylar | To'yxona].
    // Skeletda — shisha bloklar, bo'sh holatda — sub o'rniga kirish matni/CTA.
    final cards = skel ? _skelCards() : _cards(v, p, empty);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(v, p, empty),
        // Menga kelgan pending bog'lanish so'rovlari — salomlashuvdan keyin,
        // kartalardan tepada (ikki-tomonlama qabul, item 7).
        if (!skel && (v['hubPendingReq'] as int) > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 14, Tb.padX, 0),
            child: _pendingBanner(v, p),
          ),
        // Tana: balandlik yetarli bo'lsa grid ekranni to'ldiradi, aks holda
        // skroll + qat'iy karta balandligi (kichik ekranda overflow bo'lmasin).
        Expanded(
          child: LayoutBuilder(
            builder: (_, c) => c.maxHeight < kHubGridMinH ? _compactGrid(cards) : _fillGrid(cards),
          ),
        ),
      ],
    );

    // Modul obunasi paywall'i BU YERDA chizilmaydi — u GLOBAL overlay
    // (main.dart, z:64). Sabab: 402 javobi istalgan ekranda kelishi mumkin,
    // hub esa ularning faqat bittasi. Hub kartasi qulfi ham o'sha yagona
    // store holatini (S['paywall']) yoqadi — ko'rinishi main.dart'da.
    // Yordam chati ham global qatlam (main.dart z:13, S['supportOpen']) —
    // FAB faqat store.openSupport_() ni chaqiradi.
    return Stack(
      children: [
        Positioned.fill(child: body),
        // Pastki-CHAP: narx qo'llanmasi tugmasi (chat FAB'ining qarshisida,
        // grid pastidagi bo'sh joyda — grid pb:96 shu ikkisiga joy qoldiradi).
        if (!skel)
          Positioned(left: Tb.padX, bottom: 24, child: _guideBtn(p)),
        Positioned(
          right: Tb.padX,
          bottom: 24,
          child: GlassIconBtn(
            key: const ValueKey('hubSupportFab'),
            icon: Icons.headset_mic_rounded,
            gradient: true,
            size: 60,
            iconSize: 28,
            onTap: () => store.openSupport_(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── TANA (2×2 grid) ───────────────────────────

  /// Grid ekranni to'ldiradi: ikki Expanded qator, har birida ikki Expanded karta.
  /// px 20, pt 20, pb 96 (FAB uchun joy), gap 12.
  Widget _fillGrid(List<Widget> cards) {
    Widget row(Widget a, Widget b) => Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 20, Tb.padX, 96),
      child: Column(
        children: [row(cards[0], cards[1]), const SizedBox(height: 12), row(cards[2], cards[3])],
      ),
    );
  }

  /// Ixcham rejim (tana < kHubGridMinH): skroll + qat'iy karta balandligi.
  Widget _compactGrid(List<Widget> cards) {
    Widget row(Widget a, Widget b) => SizedBox(
          height: kHubCardH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 20, Tb.padX, 96),
      child: Column(
        children: [row(cards[0], cards[1]), const SizedBox(height: 12), row(cards[2], cards[3])],
      ),
    );
  }

  /// To'rtta karta (tartib: Xarajatlar, Qarz daftar, Ijaradagi uylar, To'yxona).
  ///
  /// NOM OSTIDA SUB MATN YO'Q (PO 2026-09-08): faktlar/tavsif/CTA kartadan
  /// olib tashlandi — faqat nom va tarif (bepul modulda tarif o'rniga
  /// yuqori-o'ngda «Bepul» badge). Bo'sh hub (birinchi kirish): Qarz kartasi
  /// bosilsa hubAddDebt (yangi hamkor oqimi), aks holda bo'lim ochiladi.
  List<Widget> _cards(Map<String, dynamic> v, Pal p, bool empty) => [
        _card(
          v, p,
          t: _iconT(),
          k: _typeT(0),
          module: 'xarajat',
          asset: 'assets/illustrations/xarajat.png',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => v['hubOpenXar'](),
        ),
        _card(
          v, p,
          t: _iconT(),
          k: _typeT(1),
          module: 'qarz',
          asset: 'assets/illustrations/daftar.png',
          icon: Icons.description_outlined,
          onTap: () => empty ? v['hubAddDebt']() : v['hubOpenDebt'](),
        ),
        _card(
          v, p,
          t: _iconT(),
          k: _typeT(2),
          module: 'ijarachi',
          asset: 'assets/illustrations/ijara.png',
          icon: Icons.apartment_rounded,
          onTap: () => v['hubOpenIjara'](),
        ),
        _card(
          v, p,
          t: _iconT(),
          k: _typeT(3),
          module: 'toyxona',
          asset: 'assets/illustrations/toyxona.png',
          icon: Icons.favorite_border_rounded,
          onTap: () => v['hubOpenToy'](),
        ),
      ];

  // ──────────────────── UMUMIY KARTA QOBIG'I ────────────────────
  // Hub'dagi BARCHA kartalar AYNAN shu qobiqdan chiqadi. Anatomiya (tepadan):
  //   markazda illyustratsiya (asset yo'q bo'lsa gradient qutidagi ikonka)  ->
  //   [chapda: «N ta yozuv bepul» mint badge / «Bepul limit tugadi» coral,
  //    bosilsa paywall — _freeChip]  ->
  //   nom 17/600 (Inter Tight) — ENG PASTDA.
  // PO 2026-09-08 (kech): kartada TARIF («$8/oy») va «Bepul» badge YO'Q —
  // narxlar faqat «Narxni bilish» qo'llanmasida; badge NOM USTIGA ko'chdi
  // (ilgari nom ostida edi). Sub matn YO'Q.
  //
  // 2026-08-10 audit: qulf KIRISHNI to'smaydi — karta bosilganda DOIM bo'lim
  // ochiladi. Backend o'qishni hech qachon bloklamaydi: limit tugagan
  // foydalanuvchi ham O'Z yozuvlarini ko'ra olishi kerak, karta esa paywall'ga
  // burab ma'lumotni «garovga» olardi. Paywall YOZISHDA (server 402 ->
  // Api.onPaymentRequired -> openPaywall_) o'zi ochiladi; qulf CHIPI ko'rinib
  // turadi va bosilsa paywall'ni ochadi (_freeChip).
  //
  // QO'LLANMA (t — ikonka ko'chishi 0..1, k — matn yozilishi 0..1):
  //   t: ikonka markazdan YUQORI-CHAP burchakka kichrayib ko'chadi (kHubGuideIcon),
  //      badge qatori so'nib YIG'ILADI (joy matnga qoladi);
  //   k: bo'shagan markazda tarif + izoh «yozilgandek» belgima-belgi chiqadi.
  Widget _card(
    Map<String, dynamic> v,
    Pal p, {
    required String module,
    required String asset,
    required IconData icon,
    required VoidCallback onTap,
    double t = 0,
    double k = 0,
  }) {
    final name = modStr(kModNameKey[module] ?? '');
    final freeTx = _freeChip(v, p, module); // null = badge chizilmaydi
    return Tap(
      // QO'LLANMA rejimida karta BOSILMAYDI (PO 2026-09-08): hub shu paytda
      // navigatsiya emas, tushuntirish qatlami. Qo'llanma o'chirilishi bilan
      // onTap aynan avvalgi ko'rinishiga qaytadi.
      onTap: _guide ? null : onTap,
      child: GlassCard(
        key: ValueKey('hubCard_$module'),
        r: Tb.rCard,
        pad: const EdgeInsets.all(16),
        // Qo'llanmada chegara brend rangiga o'tadi — karta "gapirayotgani" ko'rinsin.
        border: t > 0 ? Color.lerp(p.glassBd, p.cyan.withValues(alpha: .45), t) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illyustratsiya — qolgan bo'sh joyni egallaydi, kvadrat (max 140).
            // O'lcham LayoutBuilder'dan: FittedBox EMAS — yuklanmagan Image
            // 0×0 bo'lib, FittedBox aspekt assert'iga uriladi.
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = c.hasBoundedWidth ? c.maxWidth : 140.0;
                  final h = c.hasBoundedHeight ? c.maxHeight : 140.0;
                  var s = w < h ? w : h;
                  if (s > 140) s = 140;
                  if (s < 0) s = 0;
                  if (t <= 0) {
                    return Center(child: Illustration(asset: asset, fallback: icon, size: s));
                  }
                  final small = s < kHubGuideIcon ? s : kHubGuideIcon;
                  final size = s + (small - s) * t;
                  final align = Alignment.lerp(Alignment.center, Alignment.topLeft, t) ?? Alignment.center;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: align,
                          child: Illustration(asset: asset, fallback: icon, size: size),
                        ),
                      ),
                      // Matn ikonka qatori OSTIDA (ustma-ust tushmaydi); yozilishi
                      // (k) ikonka ko'chib BO'LGACH boshlanadi — _toggleGuide.
                      Positioned(
                        top: kHubGuideIcon + 4, left: 0, right: 0, bottom: 0,
                        child: _guideBody(v, p, module, w, k),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // BADGE qatori — «N ta yozuv bepul» / «Bepul limit tugadi» (22) + 8
            // oraliq. Badge bo'lmasa ham 30px: to'rttala karta bir xil tuzilma.
            // QO'LLANMADA so'nadi va YIG'ILADI (heightFactor) — joy matnga
            // qoladi; ko'rinmas qulf chipi bosilmasin (IgnorePointer).
            ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: (1 - t).clamp(0.0, 1.0),
                child: IgnorePointer(
                  ignoring: t > 0,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: SizedBox(
                      height: 30,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          height: 22,
                          child: freeTx == null
                              ? const SizedBox.shrink()
                              : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: freeTx),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Nom «...» bilan kesilmaydi — uzun tarjima (ru/fr) kichrayadi
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(name, size: 17, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────── NARX QO'LLANMASI («Narxni bilish») ────────────
  // Butun qo'llanma — SOF KO'RINISH qatlami: server so'rovi, holat yozuvi va
  // navigatsiya YO'Q. Tugma o'chirilsa hub avvalgi holiga qaytadi.

  /// Pastki-chapdagi toggle tugma. Bosilmagan holat — KO'TARILGAN (soya),
  /// bosilgan holat — botgan (soya yo'q, 3pt pastga siljigan, brend rangi):
  /// foydalanuvchi tugmaning YOQILGANINI bir qarashda ko'radi.
  Widget _guideBtn(Pal p) {
    final on = _guide;
    return Tap(
      key: const ValueKey('hubGuideBtn'),
      onTap: _toggleGuide,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        transform: Matrix4.translationValues(0, on ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: on ? p.cyan.withValues(alpha: .18) : p.glass2,
          borderRadius: BorderRadius.circular(Tb.rPill),
          border: Border.all(color: on ? p.cyan.withValues(alpha: .55) : p.glassBd),
          boxShadow: on
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: p.isDark ? .45 : .14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.local_offer_rounded : Icons.local_offer_outlined,
              size: 18,
              color: on ? p.cyan : p.t2,
            ),
            const SizedBox(width: 8),
            Tx(modStr('hubGuideBtn'), size: 14, w: FontWeight.w600, color: on ? p.cyan : p.ink, maxLines: 1),
          ],
        ),
      ),
    );
  }

  /// Karta MARKAZIDAGI qo'llanma bloki: tarif + izoh, «yozilgandek» (k 0..1).
  ///
  /// YOZUV MEXANIKASI: matn TO'LIQ joylashtiriladi, hali yozilmagan qismi
  /// SHAFFOF — shunda belgilar chiqqan sari satrlar sakramaydi (o'rama va
  /// markazlash yakuniy holat bilan bir xil). Avval narx, keyin izoh.
  /// FittedBox — kichik kartada (kHubCardH=200) blok o'zi kichrayadi, toshmaydi.
  Widget _guideBody(Map<String, dynamic> v, Pal p, String module, double w, double k) {
    final price = _guidePrice(v, module);
    final note = _guideNote(v, module);
    final shown = (k * (price.length + note.length)).round();
    final sp = shown.clamp(0, price.length);
    final sn = (shown - price.length).clamp(0, note.length);
    final priceSt = tbStyle(size: 20, w: FontWeight.w700, color: p.ink, font: TbFont.head, tab: true);
    final noteSt = tbStyle(size: 11, color: p.t2, lh: 14);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _typed(price, sp, priceSt, key: ValueKey('hubGuidePrice_$module'), maxLines: 1),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 4),
                _typed(note, sn, noteSt, key: ValueKey('hubGuideNote_$module'), maxLines: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// `s` matnining birinchi `n` belgisi ko'rinadi, qolgani SHAFFOF (joy egallaydi).
  Widget _typed(String s, int n, TextStyle st, {Key? key, int? maxLines}) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: s.substring(0, n), style: st),
        TextSpan(text: s.substring(n), style: st.copyWith(color: Colors.transparent)),
      ]),
      key: key,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      textScaler: TextScaler.noScaling,
    );
  }

  /// Qo'llanmadagi NARX satri. Bepul modulda (Xarajatlar) — «Bepul».
  /// MANBA: server modSubs[].price, oflaynda kSubModuleDefaults; do'kon narxi
  /// bo'lsa modPriceLabel o'sha summani beradi. Qotirilgan narx satri YO'Q.
  String _guidePrice(Map<String, dynamic> v, String module) {
    if (subsModuleFree(module, v['modSubs'])) return modStr('subFree');
    final price = (_modOf(v, module)?['price'] as int?) ?? modDefPrice(module);
    return modPriceLabel(module, price);
  }

  /// Narx ostidagi izoh: xarajat/qarz — «cheksiz yozuv» (bepul / pullik
  /// rejaning mohiyati), ijara — {n} ta uy, to'yxona — bitta to'yxona +
  /// qo'shimchasi uchun alohida {price}. Har jumla ORTIDA ishlaydigan tarif
  /// bor (pwTitle* bilan bir ma'no) — bu yerda yangi va'da berilmaydi.
  String _guideNote(Map<String, dynamic> v, String module) {
    final k = kHubGuideNoteKey[module];
    if (k == null) return '';
    final price = (_modOf(v, module)?['price'] as int?) ?? modDefPrice(module);
    return modStrF(k, {
      'n': '${kModCapUnits[module] ?? 0}',
      'price': modPriceLabel(module, price),
    });
  }

  // ─────────────────── MODUL OBUNALARI (per-module subs) ───────────────────
  // Store shartnomasi HIMOYALI o'qiladi — kalitlar hali yo'q bo'lsa hub aynan
  // bugungidek ko'rinadi (chip yo'q, tap — odatdagi navigatsiya):
  //   v['modSubs']       -> [{'module','active','soon','used','limit','price'}]
  //   v['modSubsLegacy'] -> bool (eski umumiy premium: hamma modul ochiq)
  //   v['openPaywall']   -> void Function(String module)

  /// Modul yozuvi. null = chip/qulf mantiqi umuman qo'llanmaydi
  /// (eski premium, server qo'llamaydi yoki modul ro'yxatda yo'q).
  Map<String, dynamic>? _modOf(Map<String, dynamic> v, String module) {
    if (v['modSubsLegacy'] == true) return null;
    final raw = v['modSubs'];
    if (raw is! List) return null;
    for (final e in raw) {
      if (e is Map && e['module'] == module) return e.cast<String, dynamic>();
    }
    return null;
  }

  /// Paywall'ni ochadi. Store hali qo'llamasa false qaytaradi — chaqiruvchi
  /// odatdagi navigatsiyaga tushadi (hub hech qachon "o'lik" bo'lib qolmaydi).
  bool _openPaywall(Map<String, dynamic> v, String module) {
    final f = v['openPaywall'];
    if (f is Function) {
      f(module);
      return true;
    }
    return false;
  }

  /// Kartaning PASTKI-CHAP badge'i — «N ta yozuv bepul» (PO 2026-09-08).
  ///
  /// DINAMIK: `n` = qolgan bepul yozuvlar (limit − used), manba
  /// store.subsFreeEntries (server `used`ini o'qiydi) — yozuv qo'shilganda
  /// o'zi kamayadi. Limit tugaganda coral «Bepul limit tugadi» + qulf
  /// ikonkasi, BOSILSA paywall (karta o'zi baribir bo'limni ochadi —
  /// 2026-08-10 audit: qulf KIRISHNI to'smaydi).
  /// null (badge yo'q): bepul modul, obuna faol, «tez orada», legacy premium.
  Widget? _freeChip(Map<String, dynamic> v, Pal p, String module) {
    final e = subsFreeEntries(module, v['modSubs'], legacy: v['modSubsLegacy'] == true);
    if (e == null) return null;
    final left = e['left'] ?? 0;
    if (left > 0) {
      return KeyedSubtree(
        key: ValueKey('hubFreeLeft_$module'),
        child: PillBadge.mint(modStrF('subFreeLeft', {'n': '$left'}), h: 22),
      );
    }
    // Ichki Tap tashqi (karta) Tap'dan ustun: gesture arena'da ichki g'olib.
    return Tap(
      key: ValueKey('hubLock_$module'),
      onTap: () => _openPaywall(v, module),
      child: PillBadge.coral(modStr('subFreeOver'), h: 22, icon: Icons.lock_outline_rounded),
    );
  }

  // ─────────────────────────── SARLAVHA ───────────────────────────
  // [RingAvatar 44 -> Profil] [Salom, {ism} 20/600 · sana 13 t2 (+ sinov chipi)]
  // [AI (cyan) -> Trust AI] [qo'ng'iroq + badge -> Bildirishnomalar]
  Widget _header(Map<String, dynamic> v, Pal p, bool empty) {
    final unread = (v['notifUnread'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
      child: Row(
        children: [
          // Profil kirish nuqtasi (hubOpenProfil)
          Tap(
            onTap: () => v['hubOpenProfil'](),
            child: RingAvatar(initials: (v['hubIni'] as String?) ?? '', size: 44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Salomlashuv «...» bilan kesilmasin — uzun ism kichrayadi
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Tx(
                    (empty ? v['hubGreetEmpty'] : v['hubGreet']) as String,
                    size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                // Sana + obuna mikro-nishoni: sinov chipi yoki «Premium» matni
                Row(
                  children: [
                    Flexible(child: Tx(v['hubDate'] as String, size: 13, color: p.t2, maxLines: 1, ellipsis: true)),
                    if (v['hubTrial'] == true) ...[
                      const SizedBox(width: 6),
                      PillBadge.amber(v['hubTrialTxt'] as String, h: 20),
                    ] else if (v['hubPrem'] == true) ...[
                      const SizedBox(width: 6),
                      Tx(v['hubPremTxt'] as String, size: 11, w: FontWeight.w600, color: p.t4, maxLines: 1),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // AI kirish nuqtasi — header ikonkasi (PO 2026-08-04). goAi — vals()dagi
          // mavjud o'tish (aiFrom='hub' saqlanadi, orqaga hub'ga qaytadi).
          if (kAiEnabled) ...[
            const SizedBox(width: 8),
            GlassIconBtn(
              key: const ValueKey('hubAiBtn'),
              icon: Icons.auto_awesome_rounded,
              color: p.cyan,
              onTap: () => v['goAi'](),
            ),
          ],
          const SizedBox(width: 8),
          GlassIconBtn(
            key: const ValueKey('hubBellBtn'),
            icon: Icons.notifications_none_rounded,
            badge: unread,
            onTap: () => v['hubOpenNotifs'](),
          ),
        ],
      ),
    );
  }

  // Menga kelgan pending bog'lanish so'rovlari banneri (item 7) — amber urg'u.
  // Bosilganda hubOpenReq (1 ta bo'lsa qaror sheet'ini to'g'ridan ochadi, ko'p
  // bo'lsa BILDIRISHNOMALAR panelini — so'rovlar o'sha yerda alohida qator
  // bo'lib turadi, 2026-08-10 audit).
  Widget _pendingBanner(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['hubOpenReq'](),
      child: GlassCard(
        key: const ValueKey('hubPendingBanner'),
        r: Tb.rRow,
        pad: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        color: p.amber.withValues(alpha: .10),
        border: p.amber.withValues(alpha: .30),
        child: Row(
          children: [
            Icon(Icons.people_outline_rounded, size: 20, color: p.amber),
            const SizedBox(width: 10),
            // So'rov matni (soni bilan) «...» bilan kesilmasin — ikki qatorga o'raladi
            Expanded(
              child: Tx(v['hubPendingReqTxt'] as String, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2),
            ),
            const SizedBox(width: 10),
            // "Tugma" — amber doira ichida chevron
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.amber),
              child: Icon(Icons.chevron_right_rounded, size: 22, color: p.isDark ? p.bg : Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── SKELET ───────────────────────────
  // 2×2 shisha kartalar (r24) — yuklangan holat bilan bir xil tuzilma,
  // yuklangach sakrash bo'lmaydi. DIQQAT: `const` EMAS — const instance kanonik
  // bo'lgani uchun qayta qurishda Element rebuild'ni o'tkazib yuborardi.
  List<Widget> _skelCards() => List.generate(
        4,
        (i) => GlassCard(
          key: ValueKey('hubSkel_$i'),
          r: Tb.rCard,
          pad: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                height: 24,
                child: Align(alignment: Alignment.topRight, child: Skel(w: 44, h: 22, r: 999)),
              ),
              const Expanded(child: Center(child: Skel(w: 72, h: 72, r: 20))),
              const SizedBox(height: 10),
              const Skel(wf: .6, h: 16, r: 6),
              const SizedBox(height: 8),
              const Skel(wf: .55, h: 22, r: 999),
            ],
          ),
        ),
      );
}

/// Hub'dan ochilgan bo'lim uchun yengil qobiq: header'da faqat orqaga (<).
/// Hozir faqat profil.dart shu bilan o'raladi (main.dart). Hamkorlar (home.dart)
/// esa orqaga tugmasini O'Z header qatorida ko'rsatadi (PO 2026-07-17: bitta
/// ekranda ikkita header qatori bo'lmasin).
class HubSection extends StatelessWidget {
  final Widget child;
  const HubSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
          child: Row(
            children: [BackBtn(onTap: () => store.vals()['goHub']())],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
