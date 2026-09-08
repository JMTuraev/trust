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

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
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
  /// Sub matnlar — REAL ma'lumot (store.vals()):
  ///   Xarajatlar -> shu oy jami («−2 340 000 so'm»)
  ///   Qarz daftar -> «{d} faol qarz · {p} hamkor»
  ///   Ijara -> «{n} hisob-kitob · {w} kutilmoqda» (404/bo'sh: modul tavsifi)
  ///   To'yxona -> «Bu oyda {n} to'y» (404/bo'sh: modul tavsifi)
  /// Bo'sh hub (birinchi kirish): Xarajat va Qarz sub'lari o'rniga eski
  /// _emptyBody'ning sarlavha/CTA matni; Qarz kartasi bosilsa hubAddDebt.
  List<Widget> _cards(Map<String, dynamic> v, Pal p, bool empty) => [
        _card(
          v, p,
          module: 'xarajat',
          asset: 'assets/illustrations/xarajat.png',
          icon: Icons.account_balance_wallet_outlined,
          pro: false,
          sub: empty
              ? Tx(v['hubEmptyXarTitle'] as String, size: 13, color: p.t2, maxLines: 2, ellipsis: true)
              : _moneySub(p, '${v['hubXarTxt']} ${v['hubXarUnit']}'),
          onTap: () => v['hubOpenXar'](),
        ),
        _card(
          v, p,
          module: 'qarz',
          asset: 'assets/illustrations/daftar.png',
          icon: Icons.description_outlined,
          pro: true,
          sub: empty
              // Eski bo'sh-holat CTA («+ Qarz qo'shish») — karta bosilsa hubAddDebt
              ? Tx(v['hubEmptyDebtBtn'] as String, size: 13, w: FontWeight.w600, color: p.cyan, maxLines: 2, ellipsis: true)
              : _textSub(p, v['hubDebtSub'] as String),
          onTap: () => empty ? v['hubAddDebt']() : v['hubOpenDebt'](),
        ),
        _card(
          v, p,
          module: 'ijarachi',
          asset: 'assets/illustrations/ijara.png',
          icon: Icons.apartment_rounded,
          pro: true,
          sub: _textSub(p, v['hubIjaraSub'] as String),
          onTap: () => v['hubOpenIjara'](),
        ),
        _card(
          v, p,
          module: 'toyxona',
          asset: 'assets/illustrations/toyxona.png',
          icon: Icons.favorite_border_rounded,
          pro: true,
          sub: _textSub(p, v['hubToySub'] as String),
          onTap: () => v['hubOpenToy'](),
        ),
      ];

  /// Pul summasi sub'i: «...» bilan KESILMAYDI — sig'masa kichrayadi.
  Widget _moneySub(Pal p, String t) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Tx(t, size: 13, color: p.t2, tab: true, maxLines: 1),
      );

  /// Matnli sub (faktlar / modul tavsifi): 2 qatorgacha o'raladi.
  Widget _textSub(Pal p, String t) => Tx(t, size: 13, color: p.t2, tab: true, maxLines: 2, ellipsis: true);

  // ──────────────────── UMUMIY KARTA QOBIG'I ────────────────────
  // Hub'dagi BARCHA kartalar AYNAN shu qobiqdan chiqadi. Anatomiya (tepadan):
  //   [yuqori-o'ng: PRO badge yoki modul chipi «3/5» / qulf]  ->
  //   markazda illyustratsiya (asset yo'q bo'lsa gradient qutidagi ikonka)  ->
  //   nom 17/600 (Inter Tight)  ->  sub 13 t2 + o'ng chetda tarif 12 t4.
  //
  // 2026-08-10 audit: qulf KIRISHNI to'smaydi — karta bosilganda DOIM bo'lim
  // ochiladi. Backend o'qishni hech qachon bloklamaydi: limit tugagan
  // foydalanuvchi ham O'Z yozuvlarini ko'ra olishi kerak, karta esa paywall'ga
  // burab ma'lumotni «garovga» olardi. Paywall YOZISHDA (server 402 ->
  // Api.onPaymentRequired -> openPaywall_) o'zi ochiladi; qulf CHIPI ko'rinib
  // turadi va bosilsa paywall'ni ochadi (_modChip).
  Widget _card(
    Map<String, dynamic> v,
    Pal p, {
    required String module,
    required String asset,
    required IconData icon,
    required bool pro,
    required Widget sub,
    required VoidCallback onTap,
  }) {
    final name = modStr(kModNameKey[module] ?? '');
    // Modul chipi (hisoblagich/qulf) PRO badge'dan USTUN — bir joyda bittasi.
    final badge = _modChip(v, p, module) ?? (pro ? PillBadge.pro() : null);
    return Tap(
      onTap: onTap,
      child: GlassCard(
        key: ValueKey('hubCard_$module'),
        r: Tb.rCard,
        pad: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge qatori — badge bo'lmasa ham 24px: to'rttala karta bir xil tuzilma
            SizedBox(
              height: 24,
              child: Align(alignment: Alignment.topRight, child: badge ?? const SizedBox.shrink()),
            ),
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
                  return Center(child: Illustration(asset: asset, fallback: icon, size: s));
                },
              ),
            ),
            const SizedBox(height: 10),
            // Nom «...» bilan kesilmaydi — uzun tarjima (ru/fr) kichrayadi
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(name, size: 17, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 1),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 3, child: sub),
                const SizedBox(width: 6),
                // Tarif tor kartada (320pt, fr/ru) toshmasin — sig'masa kichrayadi
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(fit: BoxFit.scaleDown, child: _priceTx(v, p, module)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  /// Kartaning yuqori-o'ng chipi (PRO badge o'rnida):
  ///   bepul, limit tugamagan -> «3/5» hisoblagich (PillBadge.muted)
  ///   limit tugagan          -> FAQAT qulf ikonkasi (bosilsa paywall)
  ///   obuna faol / legacy / server qo'llamaydi -> chip yo'q (null)
  ///
  /// NARX BU YERDA YO'Q (PO 2026-08-04): tarif HAR kartaning sub qatori o'ng
  /// chetida doimiy turadi (_priceTx). Qulf chipida ham ko'rsatilsa,
  /// qulflangan modulda bitta karta ichida bir xil narx IKKI marta chiqardi.
  Widget? _modChip(Map<String, dynamic> v, Pal p, String module) {
    final e = _modOf(v, module);
    if (e == null || e['active'] == true) return null;
    final used = (e['used'] as int?) ?? 0;
    final limit = (e['limit'] as int?) ?? 0;
    final locked = limit > 0 && used >= limit;
    // Hisoblagich chizilmaydigan hollar (QULF chipi bularga bo'ysunmaydi):
    //   limit <= 0             — server limitni bilmaydi
    //   limit > kModChipMaxLimit — env "sinov rejimi" qiymati (render.yaml: 300),
    //                              «7/300» bosh ekranda ichki qiymatni oshkor qiladi
    if (!locked && (limit <= 0 || limit > kModChipMaxLimit)) return null;
    if (!locked) return PillBadge.muted('$used/$limit');
    // Qulf chipi BOSILADIGAN — paywall'ga qisqa yo'l (2026-08-10 audit: karta
    // o'zi endi paywall emas, BO'LIMNI ochadi — _card izohi).
    // Ichki Tap tashqi (karta) Tap'dan ustun: gesture arena'da ichki g'olib.
    return Tap(
      key: ValueKey('hubLock_$module'),
      onTap: () => _openPaywall(v, module),
      child: PillBadge.muted('', icon: Icons.lock_outline_rounded),
    );
  }

  /// Kartaning sub qatori O'NG chetidagi tarif («$5/oy», 12 t4).
  ///
  /// MANBA — SERVER: modSubs[].price (GET /api/subs/status). Lokal
  /// `kSubModuleDefaults` FAQAT oflayn zaxira (server javob bermadi / legacy
  /// premium / modul ro'yxatda yo'q). Widget ichida QOTIRILGAN narx satri
  /// bo'lishi MUMKIN EMAS — eskirgan «$9/oy» tarif o'zgarganidan keyin ham
  /// 6 tilda chiqib ketgan edi. Format ham qotirilmaydi: modPriceTxt
  /// «{price}/oy» kalitini joriy tildan oladi.
  ///
  /// OBUNA FAOL bo'lganda ham KO'RSATILADI: bu kartaning "tarifi", holat
  /// nishoni emas — PO uni barcha kartalarda STANDART tarzda so'ragan.
  ///
  /// VALYUTA (PO qarori 2026-08-04): `modPriceLabel` avval DO'KON narxini oladi
  /// (foydalanuvchi haqiqatan to'laydigan summa), u bo'lmasa katalog narxini.
  Widget _priceTx(Map<String, dynamic> v, Pal p, String module) {
    final price = (_modOf(v, module)?['price'] as int?) ?? modDefPrice(module);
    return Tx(modPriceLabel(module, price), size: 12, w: FontWeight.w500, color: p.t4, tab: true, maxLines: 1);
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
              const SizedBox(height: 6),
              const Skel(wf: .4, h: 12, r: 6),
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
