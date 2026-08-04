// BOSH HUB — ilovaning ildiz ekrani (pastki navigatsiya o'rniga).
//
// Dizayn manbai: prototype/bosh-ekran.dc.html «4-tur · Papkalar uslubi» —
//   4a «Asosiy — Light», 4b «Asosiy — Dark», 4c «Bo'sh holat».
// Skelet freymi 4-turda yo'q, shuning uchun «Yuklanish — skelet» (3d) freymidan
// olindi va 4-tur tuzilmasiga moslandi (radius 16 -> 18): yuklangach sakrash bo'lmasin.
//
// Navigatsiya: hub -> karta bosiladi -> bo'lim TO'LIQ EKRAN ochiladi ->
// header'dagi orqaga (<) hub'ga qaytaradi (store: goHub_ / hubBack).
// Barcha raqam store.vals() dan (real ma'lumot) — mock yo'q.
import 'package:flutter/material.dart';

import '../flags.dart';
import '../sparkline.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'paywall_sheet.dart';

// Kartalardagi ikonka turlari (prototipdagi inline SVG path'lari bilan 1:1).
// house/venue — «Ijaradagi uylar» va «To'yxona» menyulari uchun (PO 2026-08-04:
// modullar ochildi, qulf glifi ularning DOIMIY belgisi bo'lib qololmaydi).
enum _G { expense, swap, sparkle, lock, house, venue }

/// «used/limit» hisoblagich chipi chiziladigan eng katta bepul limit.
///
/// NEGA KERAK: production'da render.yaml FREE_DEBT_ENTRIES/FREE_EXPENSE_ENTRIES
/// ATAYLAB 300 ga qo'yilgan — Play Billing ulanmaguncha hech kim to'siqqa
/// urilmasin. Server o'sha qiymatni `free_limit` sifatida qaytaradi, natijada
/// bosh ekranda har bir bepul foydalanuvchiga «7/300» ko'rinardi: prototip
/// «3/5» ko'rsatadi, 300 esa ichki sinov qiymati — ekran buzuq bo'lib o'qiladi.
/// Shu sababli "cheksizga yaqin" limitlarda hisoblagich UMUMAN chizilmaydi.
/// QULF chipi (limit tugagan holat) bundan mustasno — u har qanday limitda
/// odatdagidek ishlaydi.
///
/// QIYMAT store.dart'dan OLINADI (nusxa emas, taqsimlangan `kSubLimitDisplayMax`):
/// ikkita mustaqil "shift" bo'lsa chip bir ekranda ko'rinib, boshqasida
/// yo'qolishi mumkin edi.
const int kModChipMaxLimit = kSubLimitDisplayMax;

/// Hub kartalarining UMUMIY balandligi (logik piksel).
///
/// NEGA QAT'IY: kartalar — MENYULAR ro'yxati va ro'yxat o'sib boradi. Har biri
/// o'z mazmuniga qarab bo'y olsa stack tirqishli ko'rinadi (Xarajat sparkline
/// bilan baland, Qarz esa fx/muzlash qatorlariga qarab har safar boshqa) va
/// yangi menyu qo'shilganda yana qo'lda moslash kerak bo'lardi. Endi hammasi
/// bitta qobiqdan (_hubShell) chiqadi va AVTOMATIK bir xil o'lchamda.
///
/// QIYMAT eng BOY karta bo'yicha olingan (Xarajat: sarlavha + summa + chegara
/// qatori + 46px sparkline + tarif) — hech qanday mavjud mazmun olib
/// tashlanmagan. Boshqa kartalarda pastda bo'sh joy qoladi; aynan o'sha yerda
/// tarif (pastki-o'ng burchak) turadi.
///
/// SIG'MAGAN HOLAT KARTANI O'STIRMAYDI: mazmun bloki FittedBox(scaleDown)
/// ichida — uzun tarjima (ru/fr) yoki tor ekranda (320pt) ichkarida kichrayadi.
///
/// SHU SABAB QIYMAT KO'ZDAN EMAS, O'LCHOVDAN: kichik qiymatda karta buzilmaydi,
/// balki Xarajat kartasi JIMGINA kichrayib qoladi (258 da sparkline 46 -> 42.8
/// px bo'lgan edi — ko'z bilan payqash qiyin). Shuning uchun test bor:
/// hub_cards_test.dart «eng boy karta SIQILMAYDI» — sparkline'ning ekrandagi
/// bo'yi aynan 46 px ekanini tekshiradi. Kartaga qator qo'shsangiz o'sha test
/// yiqiladi; yechim — mazmunni qisqartirish emas, shu qiymatni oshirish.
const double kHubCardH = 272;

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
    final dark = store.S['dark'] == true;
    final skel = v['hubSkel'] == true;
    final empty = !skel && v['hubEmpty'] == true;

    // Prototip: skroller padding 6px 20px 28px
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      child: Column(
        // stretch — CSS blok oqimi kabi: kartalar doim to'liq kenglikda
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(v, p, empty),
          // Menga kelgan pending bog'lanish so'rovlari — salomlashuvdan keyin,
          // kartalardan tepada (ikki-tomonlama qabul, item 7).
          if (!skel && (v['hubPendingReq'] as int) > 0) ...[
            const SizedBox(height: 14),
            _pendingBanner(v, p),
          ],
          const SizedBox(height: 18), // grid margin-top:18
          // DIQQAT: `const` EMAS — const instance kanonik bo'lgani uchun qayta
          // qurishda Element rebuild'ni o'tkazib yuborardi (main.dart'dagi izoh).
          if (skel)
            _HubSkelBody()
          else if (empty)
            ..._emptyBody(v, p, dark)
          else
            ..._body(v, p, dark),
        ],
      ),
    );

    // Modul obunasi paywall'i BU YERDA chizilmaydi — u GLOBAL overlay
    // (main.dart, z:64). Sabab: 402 javobi istalgan ekranda kelishi mumkin,
    // hub esa ularning faqat bittasi. Hub kartasi qulfi ham o'sha yagona
    // store holatini (S['paywall']) yoqadi — ko'rinishi main.dart'da.
    return body;
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

  /// Bepul limit tugagan va obuna yo'q — karta bosilsa paywall ochiladi.
  bool _modLocked(Map<String, dynamic> v, String module) {
    final e = _modOf(v, module);
    if (e == null || e['active'] == true) return false;
    final used = (e['used'] as int?) ?? 0;
    final limit = (e['limit'] as int?) ?? 0;
    return limit > 0 && used >= limit;
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

  /// Karta sarlavha qatorining o'ng chipi:
  ///   bepul, limit tugamagan -> «3/5» hisoblagich
  ///   limit tugagan          -> FAQAT qulf glifi
  ///   obuna faol / legacy / server qo'llamaydi -> chip yo'q (null)
  ///
  /// NARX BU YERDA YO'Q (PO 2026-08-04): tarif endi HAR kartaning pastki-o'ng
  /// burchagida doimiy turadi (_priceRow). Qulf chipida ham ko'rsatilsa,
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 3, horizontal: locked ? 7 : 9),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: locked
          // Qulf — YOLG'IZ glif (narx pastki-o'ngda, _priceRow)
          ? SizedBox(
              width: 11,
              height: 11,
              child: CustomPaint(painter: _Glyph(_G.lock, p.t1, 1.5)),
            )
          // Hisoblagich — son: «...» bilan kesilmaydi
          : Tx('$used/$limit',
              size: 11, w: FontWeight.w600, color: p.t1, tab: true, maxLines: 1),
    );
  }

  /// Kartaning PASTKI-O'NG burchagidagi tarif («$5/oy»).
  ///
  /// MANBA — SERVER: modSubs[].price (GET /api/subs/status). Lokal
  /// `kSubModuleDefaults` FAQAT oflayn zaxira (server javob bermadi / legacy
  /// premium / modul ro'yxatda yo'q). Widget ichida QOTIRILGAN narx satri
  /// bo'lishi MUMKIN EMAS — eskirgan «$9/oy» tarif o'zgarganidan keyin ham
  /// 6 tilda chiqib ketgan edi. Format ham qotirilmaydi: modPriceTxt
  /// «{price}/oy» kalitini joriy tildan oladi.
  ///
  /// OBUNA FAOL bo'lganda ham KO'RSATILADI: bu kartaning "tarifi", holat
  /// nishoni emas — PO uni barcha kartalarda STANDART tarzda so'ragan, faol
  /// modulda yashirilsa aynan o'sha bir xillik buzilardi.
  ///
  /// VALYUTA (PO qarori 2026-08-04): `modPriceLabel` avval DO'KON narxini oladi
  /// (foydalanuvchi haqiqatan to'laydigan summa, o'z valyutasida), u bo'lmasa
  /// katalog narxini ko'rsatadi. Bugun mahsulotlar do'konda yaratilmagani uchun
  /// katalog ko'rinadi; yaratilgan kuni burchak AVTOMATIK haqiqiy narxga o'tadi.
  Widget _priceRow(Map<String, dynamic> v, Pal p, String module) {
    final price = (_modOf(v, module)?['price'] as int?) ?? modDefPrice(module);
    return Row(
      children: [
        Expanded(
          // Narx — summa: «...» bilan kesilmaydi, sig'masa kichrayadi
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Tx(modPriceLabel(module, price),
                size: 11, w: FontWeight.w500, color: p.t3, tab: true, maxLines: 1),
          ),
        ),
      ],
    );
  }

  // ──────────────────── UMUMIY KARTA QOBIG'I ────────────────────
  // Hub'dagi BARCHA kartalar (Xarajat, Qarz daftar, Ijaradagi uylar, To'yxona
  // va ularning bo'sh-holat variantlari) AYNAN shu qobiqdan chiqadi. Yangi
  // menyu qo'shish = shu funksiyaga yana bitta chaqiruv; o'lchami, bezaklari,
  // chipi va tarifi avtomatik bir xil bo'ladi.
  //
  // Anatomiya (tepadan pastga):
  //   _cardDeco (urg'u gradienti + halo)  ->  watermark glif  ->
  //   _capRow (BO'LIM NOMI + chip)  ->  34x34 tint kvadrat  ->
  //   mazmun (body: sarlavha, KATTA summa, sub-qatorlar, sparkline)  ->
  //   [bo'sh joy]  ->  tarif (pastki-o'ng).
  Widget _hubShell(
    Map<String, dynamic> v,
    Pal p,
    bool dark, {
    required String module,
    required Color accent, // deco + watermark + ikonka rangi
    required Color tint, // 34x34 kvadrat foni
    required Color iconColor, // kvadrat ichidagi glif
    required _G glyph,
    required String sec, // BO'LIM NOMI (caption)
    required List<Widget> body,
    required VoidCallback onTap,
  }) {
    // Bepul limit tugagan va obuna yo'q -> bo'lim emas, paywall ochiladi.
    final locked = _modLocked(v, module);
    return Tap(
      onTap: () {
        if (locked && _openPaywall(v, module)) return;
        onTap();
      },
      child: Container(
        height: kHubCardH, // QAT'IY — izoh kHubCardH ustida
        clipBehavior: Clip.antiAlias, // prototip: overflow:hidden (watermark)
        decoration: _cardDeco(p, p.hov2, accent, dark),
        child: Stack(
          children: [
            // Watermark: light 0.06, dark 0.07 (qora fonda bir xil sezilishi uchun)
            Positioned(
              right: -24,
              top: -16,
              child: Opacity(
                opacity: dark ? .07 : .06,
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: CustomPaint(painter: _Glyph(glyph, accent, 1.1)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _capRow(sec, p, _modChip(v, p, module)),
                  const SizedBox(height: 10),
                  _tintBox(tint, 16, glyph, iconColor, 1.4),
                  const SizedBox(height: 10),
                  // Mazmun qolgan bo'sh joyni egallaydi. Sig'masa KARTA
                  // O'SMAYDI — blok butunligicha kichrayadi (FittedBox):
                  // uzun tarjima (ru/fr) yoki 320pt ekran tirqish ochmasin.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: c.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: body,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _priceRow(v, p, module),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Summa ustidagi sarlavha qatori — barcha kartalarda AYNAN bir xil.
  Widget _cardCap(Pal p, String t) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        // Moliyaviy ilova qoidasi: sarlavha «...» bilan kesilmaydi
        child: Tx(t, size: 13.5, color: p.t1, maxLines: 1),
      );

  /// Kartaning KATTA summasi + birlik — barcha kartalarda AYNAN bir xil.
  /// Summa hech qachon «...» bilan kesilmaydi: sig'masa FittedBox butun raqamni
  /// kichraytirib to'liq ko'rsatadi.
  Widget _cardAmount(Pal p, String amount, Color c, String unit) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(amount,
                  size: 27, w: FontWeight.w600, color: c, ls: -0.5, tab: true, maxLines: 1),
            ),
          ),
          const SizedBox(width: 4),
          Tx(unit, size: 14, color: p.t2),
        ],
      );

  /// Bo'lim nomi + (bo'lsa) modul chipi — kartaning eng tepa qatori.
  /// Chip yo'q bo'lsa AYNAN eski ko'rinish qaytadi (yolg'iz caption matni).
  Widget _capRow(String cap, Pal p, Widget? chip) {
    final title =
        Tx(cap, size: 11, w: FontWeight.w800, color: p.t1, ls: 1.4, maxLines: 1);
    if (chip == null) return title;
    return Row(
      children: [
        // Uzun tarjimada ham «...» yo'q — sig'masa kichrayadi
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: title,
          ),
        ),
        const SizedBox(width: 10),
        chip,
      ],
    );
  }

  // ─────────── MODUL KARTALARI (Ijaradagi uylar / To'yxona) ───────────
  // PO 2026-08-04: ikkala modul QURILDI (backend + ekranlar) va endi Xarajatlar
  // hamda Qarz daftar bilan AYNAN BIR XIL karta — «Tez kunda» so'nik teaser'i
  // ham, undan keyingi "tavsif + chevron" menyu qatori ham olib tashlandi.
  // Ikkinchisi kartani ikkinchi navli qilib ko'rsatardi: yuqoridagi ikkitasida
  // katta summa, bularda esa raqam umuman yo'q edi.
  //
  // ANATOMIYA _hubShell'dan keladi — Xarajat va Qarz daftar bilan AYNAN bir xil
  // (o'lchami ham: kHubCardH).
  //
  // RANG — YASHIL, yangi tus emas: qizil = pul chiqmoqda, yashil = pul kirmoqda.
  // Ikkala modulning bosh raqami ham EGAGA kelishi kerak bo'lgan pul (yig'ilmagan
  // ijara / to'lanmagan bron qoldig'i) = kirim. Summaning O'ZI manfiy bo'lsa
  // (avans olingan) qizilga o'tadi — hubLeftTxt bilan bir xil qoida.
  //
  // MA'LUMOT: store.refreshHubMods_ -> GET /api/<modul>/summary. Endpoint
  // bugungi serverda YO'Q (404): o'shanda summa 0 bo'ladi va sub-qatorda modul
  // TAVSIFI turadi — karta tinch va to'liq o'qiladi, xato/spinner ko'rinmaydi.
  //
  // Sarlavha qatori = MODUL NOMI bosh harflarda (l10n'dagi nomdan olinadi —
  // alohida "SECTION" kaliti yaratilmaydi, aks holda nom ikki joyda ajralib
  // ketishi mumkin edi). Chip — _modChip: «3/5» yoki qulf glifi, aynan
  // Xarajat/Qarz kartalaridagidek.
  Widget _menuCard(
    Map<String, dynamic> v,
    Pal p,
    bool dark, {
    required String module,
    required _G glyph,
    required String cap,
    required String amount,
    required bool pos,
    required String unit,
    required String sub,
    required VoidCallback open,
  }) {
    final name = modStr(kModNameKey[module] ?? '');
    return _hubShell(
      v, p, dark,
      module: module,
      accent: p.green, // kirim — Qarz daftar bilan bir xil urg'u
      tint: _tint(p.green, dark),
      iconColor: p.green,
      glyph: glyph,
      sec: name.toUpperCase(),
      onTap: open,
      body: [
        _cardCap(p, cap),
        const SizedBox(height: 3),
        // Manfiy = avans olingan (egada turgan begona pul) -> qizil
        _cardAmount(p, amount, pos ? p.green : p.red, unit),
        const SizedBox(height: 2),
        // Sub-qator: ma'lumot bo'lsa faktlar («3 hisob-kitob · 2 kutilmoqda»),
        // bo'lmasa modul tavsifi. Tavsif uzun bo'lgani uchun ikki qatorga
        // o'raladi — «...» bilan KESILMAYDI.
        Tx(sub, size: 11, color: p.t2, lh: 15, maxLines: 2),
      ],
    );
  }

  /// Hub'dagi ikkita modul kartasi + oralaridagi 10px (grid gap).
  /// Asosiy va BO'SH holatda bir xil ro'yxat chiziladi — bo'limlar birinchi
  /// kirishda ham ko'rinsin.
  ///
  /// NEGA BO'SH HOLATDA HAM RANGLI (4c dagi "rang faqat ma'lumot bilan" qoidasi
  /// bu kartalarga TEGISHLI EMAS): hub'ning bo'sh holati `hasAny` — xarajat va
  /// hamkorlar bo'yicha hisoblanadi. Faqat ijara yurituvchi foydalanuvchida u
  /// true bo'ladi-yu, uyning puli baribir bor — kartani so'ndirish o'sha
  /// raqamni yashirardi. Qarz daftar ham `toMe == 0` da yashil qolgani kabi.
  ///
  /// DIQQAT: bu kartalar `kModuleSubsUi` bayrog'iga BOG'LANMAGAN (teaser paytida
  /// bog'langan edi). O'sha bayroq — OBUNA UI'sining avariya tugmasi (hisoblagich,
  /// qulf, paywall), modulning MAVJUDLIGI emas. Uni o'chirish qurilgan bo'limni
  /// butunlay yetib bo'lmas qilib qo'yardi. Bayroq false bo'lganda karta o'zi
  /// to'g'ri "so'nadi": modSubs bo'sh -> chip yo'q, _modLocked false -> tap
  /// odatdagi navigatsiya.
  List<Widget> _moduleMenus(Map<String, dynamic> v, Pal p, bool dark) => [
        const SizedBox(height: 10),
        _menuCard(v, p, dark,
            module: 'ijarachi',
            glyph: _G.house,
            cap: v['hubIjaraCap'] as String,
            amount: v['hubIjaraTxt'] as String,
            pos: v['hubIjaraPos'] == true,
            unit: v['hubIjaraUnit'] as String,
            sub: v['hubIjaraSub'] as String,
            open: () => v['hubOpenIjara']()),
        const SizedBox(height: 10),
        _menuCard(v, p, dark,
            module: 'toyxona',
            glyph: _G.venue,
            cap: v['hubToyCap'] as String,
            amount: v['hubToyTxt'] as String,
            pos: v['hubToyPos'] == true,
            unit: v['hubToyUnit'] as String,
            sub: v['hubToySub'] as String,
            open: () => v['hubOpenToy']()),
      ];

  // Menga kelgan pending bog'lanish so'rovlari banneri (item 7) — brend uslubi:
  // p.field fon, r14, ink matn; bosilganda hubOpenReq (1 ta bo'lsa to'g'ridan
  // ochadi, ko'p bo'lsa Qarz Daftar ro'yxatiga o'tadi).
  Widget _pendingBanner(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['hubOpenReq'](),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            _tintBox(p.card2, 15, _G.swap, p.ink, 1.4),
            const SizedBox(width: 11),
            Expanded(
              // Moliyaviy ilova qoidasi: so'rov matni (soni bilan) «...» bilan
              // kesilmasin — sig'masa FittedBox to'liq matnni kichraytiradi
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Tx(v['hubPendingReqTxt'] as String,
                    size: 13, w: FontWeight.w600, color: p.ink, maxLines: 1),
              ),
            ),
            const SizedBox(width: 10),
            ChevRight(color: p.t3, size: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── SARLAVHA ───────────────────────────
  // Prototip: margin-top:10; padding:0 4px; align-items:flex-start.
  // PO 2026-07-17: eng tepada brend qatori (TrustMark chapda, qo'ng'iroq+avatar
  // o'ngda), salomlashuv to'liq kenglikdagi alohida qatorda (ism qisqarmasin),
  // obuna mikro-nishoni sana qatoriga ko'chdi («juma»dan keyin).
  Widget _header(Map<String, dynamic> v, Pal p, bool empty) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // home.dart headeri bilan bir uslub: logo + «Trust» yozuvi (PO 2026-07-17)
              const TrustMark(size: 27, boxed: true),
              const SizedBox(width: 9),
              // Flexible+FittedBox: 3 ta ikonka (AI+qo'ng'iroq+sozlamalar) qatorni
              // to'ldirgach tor ekranda (≤320pt) brend yozuvi toshib ketmasin — kesilmaydi,
              // faqat kichrayadi (moliyaviy "..." qoidasi bilan bir mantiq).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Tx('Trustbook', size: 21, w: FontWeight.w700, color: p.ink, ls: -0.3),
                ),
              ),
              const Spacer(),
              // AI kirish nuqtasi — menyu kartasi o'rniga header ikonkasi (PO 2026-08-04)
              if (kAiEnabled) ...[
                _aiBtn(v, p),
                const SizedBox(width: 10),
              ],
              _bellBtn(v, p),
              const SizedBox(width: 10),
              _avatarBtn(v, p), // Profil kirish nuqtasi
            ],
          ),
          const SizedBox(height: 14),
          Tx(
            (empty ? v['hubGreetEmpty'] : v['hubGreet']) as String,
            size: 20, w: FontWeight.w600, color: p.ink, ls: -0.4,
            // Moliyaviy ilova qoidasi: salomlashuv «...» bilan kesilmasin —
            // uzun ism keyingi qatorga o'raladi
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          // Sana + obuna mikro-nishoni: sinov chipi (4a/4c) yoki «Premium» matni (3a).
          // Wrap — tor ekranda nishon keyingi qatorga tushadi, Row overflow bo'lmaydi.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Sana «...» bilan kesilmaydi — Wrap ichida tabiiy o'raladi
              Tx(v['hubDate'] as String, size: 13, color: p.t2),
              if (v['hubTrial'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Tx(v['hubTrialTxt'] as String,
                      size: 11, w: FontWeight.w600, color: p.t1, maxLines: 1),
                )
              else if (v['hubPrem'] == true)
                Tx(v['hubPremTxt'] as String, size: 11, color: p.t4, maxLines: 1),
            ],
          ),
        ],
      ),
    );
  }

  // Bildirishnomalar tugmasi — 38x38 dumaloq, ichida qo'ng'iroq (prototip: div'lar).
  // Nuqta (o'qilmagan) prototipda yo'q — home.dart bilan bir xil uslubda qo'shildi
  // (ildiz ekranda o'qilmagan bildirishnoma ko'rinmay qolmasligi uchun).
  Widget _bellBtn(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['hubOpenNotifs'](),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.hair),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 9,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: p.ink, width: 1.5),
                          top: BorderSide(color: p.ink, width: 1.5),
                          right: BorderSide(color: p.ink, width: 1.5),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 1.5,
                      decoration:
                          BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(1)),
                    ),
                    Container(
                      width: 4,
                      height: 3,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: p.ink,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(3),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (v['hubBellDot'] == true)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: p.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Trust AI tugmasi — 38x38 dumaloq, bell/avatar bilan bir uslub (PO 2026-08-04:
  // AI menyu kartasi olib tashlandi — kirish nuqtasi endi shu header ikonkasi).
  // Ichida sparkle motivi (PO 2026-08-04: romb o'rniga uch yulduzli AI belgisi).
  Widget _aiBtn(Map<String, dynamic> v, Pal p) {
    return Tap(
      // goAi — vals()dagi mavjud o'tish (aiFrom='hub' saqlanadi, orqaga hub'ga qaytadi)
      onTap: () => v['goAi'](),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.hair),
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _Glyph(_G.sparkle, p.ink, 1.15)),
        ),
      ),
    );
  }

  // Avatar — 38x38, kontur phair, ichida bosh harflar yoki tanlangan rasm.
  // PO 2026-07-28 (#10): avatar/ism harflari o'rniga SOZLAMALAR ikonkasi —
  // profil (sozlamalar) kirish nuqtasi endi aniq "settings" bo'lib ko'rinadi.
  Widget _avatarBtn(Map<String, dynamic> v, Pal p) {
    return Tap(
      onTap: () => v['hubOpenProfil'](),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: p.hair),
        ),
        child: Icon(Icons.settings_outlined, size: 20, color: p.ink),
      ),
    );
  }

  // ─────────────────────────── ASOSIY HOLAT ───────────────────────────
  // PO 2026-08-04: menyular ko'payadi (Ijarachi, To'yxona rejada) — har bir
  // menyu kartasi TO'LIQ QATORDA. Yangi menyu qo'shish: ro'yxatga karta +
  // 10px oraliq (grid gap) qo'shiladi. AI kartasi olib tashlandi — header
  // ikonkasi (_aiBtn) uning kirish nuqtasi.
  List<Widget> _body(Map<String, dynamic> v, Pal p, bool dark) => [
        _heroCard(v, p, dark),
        const SizedBox(height: 10), // grid gap
        _debtCard(v, p, dark),
        // Ijaradagi uylar + To'yxona menyulari (modSubs bo'sh bo'lsa ham
        // ko'rinadi — chip yo'q, tap odatdagi navigatsiya).
        ..._moduleMenus(v, p, dark),
        // Action tugmalar qatori olib tashlandi (PO 2026-07-17): kartalarning
        // o'zi kirish nuqtasi. «SO'NGGI» tepasidagi 18px margin saqlanadi.
        const SizedBox(height: 18),
        _recent(v, p),
      ];

  // XARAJAT kartasi — hub'dagi ENG BOY karta (chegara qatori + sparkline).
  // kHubCardH aynan shu karta sig'adigan qilib tanlangan.
  Widget _heroCard(Map<String, dynamic> v, Pal p, bool dark) {
    final hasLimit = v['hubHasLimit'] == true;
    final trend = v['hubTrendTxt'] as String;
    return _hubShell(
      v, p, dark,
      module: 'xarajat',
      accent: p.red, // #20: Xarajat — qizil urg'u (pul CHIQMOQDA)
      tint: _tint(p.red, dark),
      iconColor: p.red,
      glyph: _G.expense,
      // Bo'lim nomi — «TRUST AI» caption uslubida (PO: birinchi kirishda
      // karta qaysi bo'limga olib borishi tushunarli bo'lsin).
      sec: v['hubXarSec'] as String,
      onTap: () => v['hubOpenXar'](),
      body: [
        _cardCap(p, v['hubXarCap'] as String),
        const SizedBox(height: 3),
        _cardAmount(p, v['hubXarTxt'] as String, p.red, v['hubXarUnit'] as String),
        if (hasLimit || trend.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              // Streak-glif (ikki burilgan tomchi) olib tashlandi
              // (PO 2026-07-17: ma'ni ajratmayapti) — raqamdan keyin bo'sh.
              if (hasLimit) ...[
                Tx(v['hubLeftCap'] as String, size: 12, color: p.t1),
                Tx(v['hubLeftTxt'] as String,
                    size: 12,
                    w: FontWeight.w600,
                    color: v['hubLeftPos'] == true ? p.green : p.red,
                    tab: true),
              ],
              if (trend.isNotEmpty)
                // Trend summasi (moliyaviy) «...» bilan kesilmasin —
                // Expanded+FittedBox o'ng chetga taqaydi, sig'masa kichraytiradi
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Tx(trend,
                        size: 11,
                        // Prototipda faqat o'sish holati bor (prd). Kamayish —
                        // yaxshi xabar, shuning uchun brend yashilida (§hisobot).
                        color: v['hubTrendUp'] == true ? p.red : p.green,
                        tab: true,
                        maxLines: 1),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: Sparkline(
            values: (v['hubXarSpark'] as List).cast<double>(),
            color: p.red,
            stroke: 2.2,
            dot: 3.5,
          ),
        ),
      ],
    );
  }

  // OLDI-BERDI kartasi
  Widget _debtCard(Map<String, dynamic> v, Pal p, bool dark) {
    final spark = (v['hubDebtSpark'] as List).cast<double>();
    // Chet valyuta netlari (PO 2026-07-17): [{'cur':'USD','txt':'−2 000','pos':false}]
    final fx = (v['hubDebtFx'] as List).cast<Map<String, dynamic>>();
    return _hubShell(
      v, p, dark,
      module: 'qarz',
      accent: p.green, // #20: Qarz — yashil urg'u (pul KIRMOQDA)
      tint: _tint(p.green, dark),
      iconColor: p.green,
      glyph: _G.swap,
      // Bo'lim nomi — XARAJATLAR kabi ikonkadan TEPADA (PO sinov 2026-07-17).
      sec: v['hubDebtSec'] as String,
      onTap: () => v['hubOpenDebt'](),
      body: [
        _cardCap(p, v['hubDebtCap'] as String),
        const SizedBox(height: 3),
        _cardAmount(p, v['hubDebtTxt'] as String, p.green, v['hubDebtUnit'] as String),
        const SizedBox(height: 2),
        // Sublabel bo'lsa-da ichida sonlar bor («3 faol qarz · 12 hamkor»)
        // — to'liq ko'rinadi, sig'masa kichrayadi
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Tx(v['hubDebtSub'] as String, size: 11, color: p.t2, maxLines: 1),
        ),
        // Chet valyuta bo'yicha net qatorlari (PO 2026-07-17): «USD: −2 000».
        // Manfiy = sizning qarzingiz (p.red), musbat = sizga (p.green).
        for (final f in fx) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Tx('${f['cur']}:', size: 12, color: p.t1),
              const SizedBox(width: 4),
              Flexible(
                // Valyuta neti ham to'liq ko'rinadi (── «...» yo'q)
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Tx(f['txt'] as String,
                      size: 12,
                      w: FontWeight.w600,
                      color: f['pos'] == true ? p.green : p.red,
                      tab: true,
                      maxLines: 1),
                ),
              ),
            ],
          ),
        ],
        if (v['hubFrozen'] == true) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.red),
              ),
              const SizedBox(width: 6),
              Expanded(
                // «N kun javobsiz» raqami kesilmasin — sig'masa kichrayadi
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Tx(v['hubFrozenTxt'] as String,
                      size: 11, color: p.red, maxLines: 1),
                ),
              ),
            ],
          ),
        ],
        // Tekis tarix (variatsiya yo'q) «yolg'iz nuqta» bo'lib chizilardi —
        // store bunday holda [] beradi, blok butunlay yashirinadi va
        // kartada ortiqcha bo'shliq qolmaydi (PO 2026-07-17).
        if (spark.length >= 2) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: Sparkline(values: spark, color: p.green, stroke: 2, dot: 3),
          ),
        ],
      ],
    );
  }

  // TRUST AI kartasi olib tashlandi (PO 2026-08-04) — kirish nuqtasi _aiBtn.

  // «SO'NGGI» tasmasi
  Widget _recent(Map<String, dynamic> v, Pal p) {
    final rows = (v['hubRecentRows'] as List).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DIQQAT (2026-08-04): bu qator ilgari ikkita erkin kenglikdagi
          // boladan iborat edi va uzun tarjimalarda (ru «ПОСЛЕДНИЕ · Сегодня»,
          // fr «Aujourd'hui») 320pt ekranda RenderFlex TOSHIB ketardi —
          // «Bugun» summasi ekrandan chiqib qolardi. Endi kartalardagi bilan
          // bir xil naqsh: chapda qat'iy caption, o'ngda Expanded+FittedBox
          // (summa «...» bilan kesilmaydi, sig'masa butun guruh kichrayadi).
          Row(
            children: [
              Cap(v['hubRecentCap'] as String),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tx(v['hubTodayCap'] as String,
                          size: 11, w: FontWeight.w500, color: p.t1, tab: true),
                      Tx(v['hubTodayTxt'] as String,
                          size: 11, w: FontWeight.w500, color: p.red, tab: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Tx(v['hubEmptyRecent'] as String, size: 12.5, color: p.t4),
            ),
          for (var i = 0; i < rows.length; i++)
            _recentRow(rows[i], p, last: i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _recentRow(Map<String, dynamic> r, Pal p, {required bool last}) {
    return Tap(
      onTap: r['tap'] as VoidCallback,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: last
            ? null
            : BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.card2),
              child: Tx(r['ini'] as String, size: 10, w: FontWeight.w600, color: p.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hamkor ismi kesilmasin — uzun ism ikkinchi qatorga o'raladi
                  Tx(r['name'] as String,
                      size: 13, w: FontWeight.w500, color: p.ink, maxLines: 2),
                  const SizedBox(height: 1),
                  // Balans/izoh qatori sonli — to'liq ko'rinadi, sig'masa kichrayadi
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Tx(r['sub'] as String, size: 11, color: p.t3, maxLines: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Tx(r['amt'] as String,
                size: 13,
                w: FontWeight.w500,
                color: r['inc'] == true ? p.green : p.red,
                tab: true,
                maxLines: 1),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── BO'SH HOLAT (4c) ───────────────────────────
  // «Rang faqat ma'lumot bilan keladi»: tintlar neytralga (card2/t1) tushadi,
  // sparkline o'rniga nuqtali «kutish» chizig'i — struktura tanish qoladi.
  // DIQQAT: bo'sh holatda ham BARCHA menyular ko'rinadi (Ijaradagi uylar,
  // To'yxona) — birinchi kirishda ilova nimalar qila olishi ko'rinib tursin.
  //
  // O'LCHAM: bu ikkisi ham _hubShell'dan chiqadi — bo'sh hub'da ham stack tekis
  // (hammasi kHubCardH) va tarif burchagi hamma kartada bir xil joyda turadi.
  List<Widget> _emptyBody(Map<String, dynamic> v, Pal p, bool dark) => [
        _hubShell(
          v, p, dark,
          module: 'xarajat',
          accent: p.ink, // bo'sh holat — neytral urg'u (rang ma'lumot bilan keladi)
          tint: p.card2,
          iconColor: p.t1,
          glyph: _G.expense,
          sec: v['hubXarSec'] as String,
          onTap: () => v['hubOpenXar'](),
          body: [
            Tx(v['hubEmptyXarCap'] as String, size: 13.5, color: p.t1),
            const SizedBox(height: 3),
            Tx(v['hubEmptyXarTitle'] as String,
                size: 17, w: FontWeight.w600, color: p.ink),
            const SizedBox(height: 9),
            Tx(v['hubEmptyXarHint'] as String, size: 12, color: p.t3),
            const SizedBox(height: 10),
            SizedBox(height: 30, child: SparkDots(color: p.t6)),
          ],
        ),
        const SizedBox(height: 10),
        // Oldi-berdi CTA — to'liq qator (PO 2026-08-04: har menyu alohida qatorda,
        // AI teaser kartasi olib tashlandi — kirish nuqtasi header'dagi _aiBtn)
        _hubShell(
          v, p, dark,
          module: 'qarz',
          accent: p.ink,
          tint: p.card2,
          iconColor: p.t1,
          glyph: _G.swap,
          // Bo'lim nomi — loaded karta bilan bir xil, ikonkadan TEPADA (PO sinov)
          sec: v['hubDebtSec'] as String,
          onTap: () => v['hubAddDebt'](),
          body: [
            Tx(v['hubEmptyDebtTitle'] as String,
                size: 14, w: FontWeight.w600, color: p.ink, lh: 19.6),
            const SizedBox(height: 5),
            Tx(v['hubEmptyDebtHint'] as String, size: 11.5, color: p.t3, lh: 17.25),
            const SizedBox(height: 13),
            Tx(v['hubEmptyDebtBtn'] as String,
                size: 12, w: FontWeight.w600, color: p.ink),
          ],
        ),
        // Bo'sh holatda ham modul menyulari ko'rinadi
        ..._moduleMenus(v, p, dark),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cap(v['hubRecentCap'] as String),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Tx(v['hubEmptyRecent'] as String, size: 12.5, color: p.t4),
              ),
            ],
          ),
        ),
      ];

  // Tint kvadrat: 34x34, radius 11 (prototipdagi ikonka fon-kvadrati)
  Widget _tintBox(Color tint, double icon, _G g, Color c, double sw) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)),
        child: SizedBox(
          width: icon,
          height: icon,
          child: CustomPaint(painter: _Glyph(g, c, sw)),
        ),
      );

  // --pgrT / --prdT: light rgba(...,0.09), dark rgba(...,0.14)
  Color _tint(Color c, bool dark) => c.withValues(alpha: dark ? .14 : .09);

  // #20: Bosh ekran kartasi bezaklari — CHUQURLIK (yumshoq soya) + RANG GRADIENT.
  // base = karta foni (hov2/field), accent = bo'lim rangi (qizil/yashil/binafsha).
  // Gradient juda nozik (matn o'qilishi buzilmasin); soya accent tusida "ko'tarilish" beradi.
  BoxDecoration _cardDeco(Pal p, Color base, Color accent, bool dark) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base,
          Color.alphaBlend(accent.withValues(alpha: dark ? .11 : .075), base),
        ],
      ),
      border: Border.all(color: p.hair),
      boxShadow: [
        // Accent tusidagi yumshoq "halo" — kartani fondan ko'taradi
        BoxShadow(
          color: accent.withValues(alpha: dark ? .16 : .13),
          blurRadius: 18,
          spreadRadius: -3,
          offset: const Offset(0, 7),
        ),
        // Neytral yerga bosuvchi soya (chuqurlikni aniqlaydi)
        BoxShadow(
          color: dark ? const Color(0x33000000) : const Color(0x0F000000),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
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
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 12),
              BackBtn(onTap: () => store.vals()['goHub']()),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Ikonkalar — prototipdagi inline SVG path'lari (viewBox birligida) 1:1.
class _Glyph extends CustomPainter {
  final _G kind;
  final Color color;
  final double sw; // viewBox birligidagi stroke-width
  const _Glyph(this.kind, this.color, this.sw);

  @override
  void paint(Canvas canvas, Size size) {
    final vb = kind == _G.swap ? 16.0 : 14.0;
    final k = size.shortestSide / vb;
    if (k <= 0) return;
    final path = Path();
    if (kind == _G.expense) {
      // M3.5 10.5 L10.5 3.5 M5.5 3.5 H10.5 V8.5
      path
        ..moveTo(3.5 * k, 10.5 * k)
        ..lineTo(10.5 * k, 3.5 * k)
        ..moveTo(5.5 * k, 3.5 * k)
        ..lineTo(10.5 * k, 3.5 * k)
        ..lineTo(10.5 * k, 8.5 * k);
    } else if (kind == _G.swap) {
      // M2.5 5 H13 M10.5 2.5 L13 5 L10.5 7.5 M13.5 11 H3 M5.5 8.5 L3 11 L5.5 13.5
      path
        ..moveTo(2.5 * k, 5 * k)
        ..lineTo(13 * k, 5 * k)
        ..moveTo(10.5 * k, 2.5 * k)
        ..lineTo(13 * k, 5 * k)
        ..lineTo(10.5 * k, 7.5 * k)
        ..moveTo(13.5 * k, 11 * k)
        ..lineTo(3 * k, 11 * k)
        ..moveTo(5.5 * k, 8.5 * k)
        ..lineTo(3 * k, 11 * k)
        ..lineTo(5.5 * k, 13.5 * k);
    } else if (kind == _G.lock) {
      // Qulf (hali ochilmagan modul): tepada yoy — «shackle», pastda tana.
      // Material Icons emas — prototip bilan bitta qo'l uslubi (chiziqli glif).
      path
        ..moveTo(4.9 * k, 6.6 * k)
        ..lineTo(4.9 * k, 5.1 * k)
        ..arcToPoint(Offset(9.1 * k, 5.1 * k),
            radius: Radius.circular(2.2 * k), clockwise: true)
        ..lineTo(9.1 * k, 6.6 * k)
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(3.3 * k, 6.6 * k, 10.7 * k, 11.9 * k),
          Radius.circular(1.6 * k),
        ));
    } else if (kind == _G.house) {
      // «Ijaradagi uylar» — tom + devorlar + eshik. Chiziqli glif, prototipdagi
      // qo'l uslubi (Material ikonka EMAS): devorlar aynan tom qirrasidan
      // boshlanadi (x=3.7 va x=10.3 da tom chizig'i y=5.4 ga tushadi).
      path
        ..moveTo(2.2 * k, 6.6 * k)
        ..lineTo(7 * k, 2.7 * k)
        ..lineTo(11.8 * k, 6.6 * k)
        ..moveTo(3.7 * k, 5.4 * k)
        ..lineTo(3.7 * k, 11.5 * k)
        ..lineTo(10.3 * k, 11.5 * k)
        ..lineTo(10.3 * k, 5.4 * k)
        ..moveTo(5.9 * k, 11.5 * k)
        ..lineTo(5.9 * k, 8.6 * k)
        ..lineTo(8.1 * k, 8.6 * k)
        ..lineTo(8.1 * k, 11.5 * k);
    } else if (kind == _G.venue) {
      // «To'yxona» — ravoqli zal: keng poydevor + yarim doira ravoq.
      // Vatar 7.6, radius 3.8 -> aniq yarim doira (yassilanib qolmaydi).
      path
        ..moveTo(1.7 * k, 11.8 * k)
        ..lineTo(12.3 * k, 11.8 * k)
        ..moveTo(3.2 * k, 11.8 * k)
        ..lineTo(3.2 * k, 7.4 * k)
        ..arcToPoint(Offset(10.8 * k, 7.4 * k),
            radius: Radius.circular(3.8 * k), clockwise: true)
        ..lineTo(10.8 * k, 11.8 * k);
    } else {
      // Trust AI — uchta 4 nurli yulduz (sparkle): katta + o'rta + kichik.
      // Har nur markazga BOTIQ: kvadratik egri nazorat nuqtasi markazga yaqin
      // (b = r*0.22) — nurlar ingichka va o'tkir chiqadi.
      void star(double cx, double cy, double r) {
        final b = r * 0.22;
        path
          ..moveTo(cx * k, (cy - r) * k)
          ..quadraticBezierTo((cx + b) * k, (cy - b) * k, (cx + r) * k, cy * k)
          ..quadraticBezierTo((cx + b) * k, (cy + b) * k, cx * k, (cy + r) * k)
          ..quadraticBezierTo((cx - b) * k, (cy + b) * k, (cx - r) * k, cy * k)
          ..quadraticBezierTo((cx - b) * k, (cy - b) * k, cx * k, (cy - r) * k)
          ..close();
      }

      star(8.9, 8.7, 4.7); // katta — pastki o'ng
      star(4.2, 3.9, 2.9); // o'rta — yuqori chap
      star(2.8, 11.0, 1.9); // kichik — pastki chap
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Glyph old) =>
      old.kind != kind || old.color != color || old.sw != sw;
}

/// Yuklanish skeleti — «Yuklanish — skelet» (3d) freymi, 4-tur tuzilmasiga
/// moslangan (radius 18): yuklangach bloklar sakramaydi.
///
/// DIQQAT: ui.dart'dagi `Skel` bu yerda ishlatilmadi — u rangni p.card2 ga
/// qotirgan va pulsatsiya qilmaydi, prototip esa --pskel (Pal.skelDot) +
/// trSkel pulsini talab qiladi (hisobot §NEW-PATCHES: Skel'ga `color` qo'shish).
class _HubSkelBody extends StatefulWidget {
  const _HubSkelBody();

  @override
  State<_HubSkelBody> createState() => _HubSkelBodyState();
}

class _HubSkelBodyState extends State<_HubSkelBody> with SingleTickerProviderStateMixin {
  // Prototip: animation trSkel 1.4s ease infinite (0%,100% opacity .45; 50% opacity 1)
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Bitta skelet bloki. delay — prototipdagi animation-delay (soniyada).
  Widget _b({double? w, required double h, double r = 5, double delay = 0}) {
    final p = curPal();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = (_c.value - delay / 1.4) % 1.0; // Dart: manfiy qoldiq musbatga keladi
        final k = Curves.easeInOut.transform(t < .5 ? t * 2 : (1 - t) * 2);
        return Opacity(
          opacity: .45 + .55 * k,
          child: Container(
            width: w ?? double.infinity,
            height: h,
            decoration:
                BoxDecoration(color: p.skelDot, borderRadius: BorderRadius.circular(r)),
          ),
        );
      },
    );
  }

  Widget _row(double w1, double w2, double d, {required bool last, required Pal p}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration:
          last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
      child: Row(
        children: [
          _b(w: 32, h: 32, r: 16, delay: d),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: w1,
                  alignment: Alignment.centerLeft,
                  child: _b(h: 9, delay: d + .1),
                ),
                const SizedBox(height: 7),
                FractionallySizedBox(
                  widthFactor: w2,
                  alignment: Alignment.centerLeft,
                  child: _b(h: 8, r: 4, delay: d + .15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _b(w: 52, h: 10, delay: d + .2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Pal p = curPal();
    return Column(
      // stretch — asosiy holat bilan bir xil: bloklar to'liq kenglikda,
      // yuklangach karta o'lchami sakramaydi
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Xarajat kartasi (span 2)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border.all(color: p.hair),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _b(w: 120, h: 9),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _b(w: 140, h: 26, r: 8),
                      const SizedBox(height: 10),
                      _b(w: 95, h: 9, delay: .1),
                    ],
                  ),
                  _b(w: 110, h: 40, r: 10, delay: .15),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: p.hair),
              const SizedBox(height: 13),
              Row(
                children: [
                  _b(w: 62, h: 9, delay: .2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: p.barbg, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _b(w: 30, h: 9, delay: .25),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Oldi-berdi kartasi — to'liq qator (PO 2026-08-04: yuklangan holat bilan
        // mos, sakrash bo'lmasin; AI kartasi skeleti olib tashlandi)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border.all(color: p.hair),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _b(w: 72, h: 9),
              const SizedBox(height: 14),
              _b(w: 88, h: 18, r: 6, delay: .1),
              const SizedBox(height: 9),
              _b(w: 110, h: 9, delay: .15),
              const SizedBox(height: 14),
              Row(
                children: [
                  _b(w: 26, h: 26, r: 13),
                  const SizedBox(width: 4),
                  _b(w: 26, h: 26, r: 13, delay: .1),
                  const SizedBox(width: 4),
                  _b(w: 26, h: 26, r: 13, delay: .2),
                ],
              ),
              const SizedBox(height: 14),
              _b(w: 80, h: 9, delay: .25),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _b(h: 50, r: 14, delay: .3),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              _row(.45, .60, 0, last: false, p: p),
              _row(.55, .40, .1, last: true, p: p),
            ],
          ),
        ),
      ],
    );
  }
}
