// BOSH HUB — kartalar OILASI (PO 2026-08-04; redizayn 2026-09-07 §5.6).
//
// NEGA BU TEST:
//   1) «Ijaradagi uylar» va «To'yxona» kartalari ilgari ikkinchi navli edi.
//      PO talabi — to'rttasi ham AYNAN bir xil ko'rinsin: bitta qobiq (_card),
//      2×2 grid, bir xil o'lcham.
//   2) O'LCHAM ham bir xil: grid rejimida Expanded qatorlar, ixcham rejimda
//      kHubCardH — har ikkisida to'rttala karta teng bo'yda.
//   3) TARIF har kartaning sub qatori O'NG chetida va FAQAT ma'lumotdan
//      (server modSubs[].price, oflaynda kSubModuleDefaults) — widget ichida
//      qotirilgan narx satri bir marta tarif o'zgargach 6 tilda chiqib ketgan.
//   4) 404 HOLATI — bugungi production'da /api/ijara/summary va
//      /api/toyxona/summary YO'Q. O'shanda karta TINCH nol holatida chizilishi
//      shart: xato ham, spinner ham, crash ham bo'lmasin. PO qurilmada AYNAN
//      shu holatni ko'radi.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/l10n.dart';
import 'package:trust_mobile/main.dart';
import 'package:trust_mobile/screens/home_hub.dart';
import 'package:trust_mobile/screens/paywall_sheet.dart';
import 'package:trust_mobile/store.dart';

/// Bitta xarajat yozuvi — hub'ni "bo'sh holat"dan YUKLANGAN holatga o'tkazadi.
Map<String, dynamic> _xarEntry() {
  final now = DateTime.now();
  return {
    'id': 'x1', 'kind': 'x', 'cat': 'Transport', 'note': '',
    'a': 150000, 'days': 0, 't': '12:00',
    'ts': now.millisecondsSinceEpoch,
    'ym': '${now.year}-${now.month}', 'dom': now.day,
  };
}

/// Hub'ni ma'lum holat bilan boshlaydi.
/// `ijara`/`toy` — refreshHubMods_ yozadigan yakun xaritasi; null = server
/// javob bermadi (404) yoki hali kelmagan.
void _atHub({
  List<Map<String, dynamic>> mods = const [],
  bool empty = false,
  Map<String, int>? ijara,
  Map<String, int>? toy,
}) {
  store.S['stage'] = 'app';
  store.S['screen'] = 'hub';
  store.S['clientId'] = null;
  store.S['clientOpen'] = false;
  store.S['paywall'] = null;
  store.S['skelHome'] = false;
  store.S['modSubs'] = mods;
  store.S['modSubsLegacy'] = false;
  store.S['xarEntries'] = empty ? <Map<String, dynamic>>[] : [_xarEntry()];
  store.S['hubIjaraSum'] = ijara;
  store.S['hubToySum'] = toy;
}

/// Karta nomi = modul nomi (home_hub `_card`: modStr(kModNameKey[module])).
String _name(String nameKey) => lUz[nameKey] as String;

/// Kartalar tartibi (2×2 grid): Xarajatlar, Qarz daftar, Ijara, To'yxona.
const _modules = ['xarajat', 'qarz', 'ijarachi', 'toyxona'];

/// Hub kartalari — _card har biriga ValueKey('hubCard_<modul>') beradi.
Finder _card(String module) => find.byKey(ValueKey('hubCard_$module'));
Finder _cards() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('hubCard_');
    });

void main() {
  // ─────────────────── 1. Bir xil ANATOMIYA ───────────────────
  group('to\'rttala karta bitta oila', () {
    testWidgets('4 ta karta, hammasi bir xil qobiqdan (ValueKey hubCard_*)', (t) async {
      _atHub();
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Xarajat, Qarz daftar, Ijaradagi uylar, To'yxona
      expect(_cards(), findsNWidgets(4));
      for (final m in _modules) {
        expect(_card(m), findsOneWidget, reason: '$m kartasi yo\'q');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('IXCHAM rejim (tana < kHubGridMinH): BALANDLIK aynan kHubCardH', (t) async {
      // Test yuzasi 800×600 — tana balandligi kHubGridMinH dan kichik,
      // shuning uchun skroll rejimi va qat'iy karta bo'yi.
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      final hs = t.renderObjectList<RenderBox>(_cards()).map((r) => r.size.height).toList();
      expect(hs.length, 4);
      for (final h in hs) {
        expect(h, kHubCardH, reason: 'karta bo\'yi farq qilyapti: $hs');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('GRID rejim (844pt): kartalar ekranni to\'ldiradi, to\'rttasi teng', (t) async {
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(390, 844);
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(t.takeException(), isNull, reason: 'grid rejimida overflow');
      final rects = t
          .renderObjectList<RenderBox>(_cards())
          .map((r) => r.localToGlobal(Offset.zero) & r.size)
          .toList();
      expect(rects.length, 4);
      // Grid: kartalar kHubCardH dan baland (ekranni to'ldiradi) va teng
      for (final r in rects) {
        expect(r.height, greaterThan(kHubCardH), reason: 'grid rejimi emas: $rects');
        expect(r.height, closeTo(rects.first.height, 0.5), reason: 'kartalar teng emas: $rects');
        expect(r.width, closeTo(rects.first.width, 0.5));
      }
      // Ikki ustun: 0 va 2 chapda, 1 va 3 o'ngda; ikki qator
      expect(rects[0].left, closeTo(rects[2].left, 0.5));
      expect(rects[1].left, closeTo(rects[3].left, 0.5));
      expect(rects[0].top, closeTo(rects[1].top, 0.5));
      expect(rects[2].top, closeTo(rects[3].top, 0.5));
      expect(rects[1].left, greaterThan(rects[0].right));
      expect(rects[2].top, greaterThan(rects[0].bottom));
    });

    testWidgets('har kartada: NOM + sub + tarif', (t) async {
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Nomlar (17/600) — to'rttasi ham
      for (final key in ['modXarajat', 'modQarz', 'modIjarachi', 'modToyxona']) {
        expect(find.text(_name(key)), findsOneWidget, reason: '${_name(key)} kartasi yo\'q');
      }
      // Sub qatorlar — real ma'lumot
      expect(find.text('3 hisob-kitob · 2 kutilmoqda'), findsOneWidget);
      expect(find.text('Bu oyda 4 to\'y'), findsOneWidget);
      // Xarajat: shu oy jami («−150 000 so'm») — store qiymati bilan aynan
      final hv = store.vals();
      expect(find.text('${hv['hubXarTxt']} ${hv['hubXarUnit']}'), findsOneWidget);
      // Tarif — har kartaning sub qatori o'ng chetida (oflayn zaxira narxlari)
      for (final price in [5, 8, 13, 24]) {
        expect(find.text('\$$price/oy'), findsOneWidget, reason: '\$$price/oy yo\'q');
      }
    });

    // PO talabi so'zma-so'z: tarif PASTKI-O'NG burchakda, hamma kartada bir xil
    // joyda. Matn mavjudligini tekshirish yetarli emas edi — u kartaning
    // o'rtasida turib ham testdan o'tib ketardi.
    testWidgets('tarif AYNAN pastki-o\'ng burchakda (4 kartada ham)', (t) async {
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      final cardRects = t
          .renderObjectList<RenderBox>(_cards())
          .map((r) => r.localToGlobal(Offset.zero) & r.size)
          .toList();
      expect(cardRects.length, 4);

      for (final price in [5, 8, 13, 24]) {
        final pr = t.getRect(find.text('\$$price/oy'));
        // Qaysi kartaga tegishli
        final card = cardRects.firstWhere((c) => c.contains(pr.center),
            orElse: () => Rect.zero);
        expect(card, isNot(Rect.zero), reason: '\$$price/oy hech bir kartada emas');
        // O'ng chetga taqalgan (pad 16) va pastda (pad 16)
        expect(card.right - pr.right, closeTo(16, 1.5),
            reason: '\$$price/oy o\'ng chetda emas');
        expect(card.bottom - pr.bottom, lessThan(24),
            reason: '\$$price/oy pastki burchakda emas');
      }
    });

    testWidgets('PRO badge — Qarz/Ijara/To\'yxona da bor, Xarajatda YO\'Q', (t) async {
      _atHub(); // modSubs bo'sh -> chip yo'q, PRO badge ko'rinadi
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('PRO'), findsNWidgets(3));
      final xar = t.getRect(_card('xarajat'));
      for (final pro in t.widgetList(find.text('PRO'))) {
        final r = t.getRect(find.byWidget(pro));
        expect(xar.contains(r.center), isFalse, reason: 'Xarajat kartasida PRO chiqdi');
      }
    });
  });

  // ─────────────────── 2. YANGI KARTALARDAGI SUB ───────────────────
  group('ma\'lumot bor — karta faktlarni ko\'rsatadi', () {
    testWidgets('Ijara: hisob-kitob/kutilmoqda', (t) async {
      _atHub(ijara: const {'left': 4200000, 'count': 3, 'pending': 2});
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('3 hisob-kitob · 2 kutilmoqda'), findsOneWidget);
      // Faktlar bor ekan, tavsif sub-qatordan chiqib ketadi
      expect(find.text(lUz['modIjarachiDesc'] as String), findsNothing);
    });

    testWidgets('To\'yxona: bandlar soni', (t) async {
      _atHub(toy: const {'left': 18500000, 'count': 4, 'pending': 1});
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('Bu oyda 4 to\'y'), findsOneWidget);
      expect(find.text(lUz['modToyxonaDesc'] as String), findsNothing);
    });

    testWidgets('MANFIY qoldiq (avans olingan) — crash yo\'q', (t) async {
      _atHub(ijara: const {'left': -350000, 'count': 1, 'pending': 0});
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // hubLeftTxt bilan bir xil qoida store'da saqlanadi (ekran endi summani
      // ko'rsatmaydi — bo'lim ekrani ko'rsatadi)
      expect(store.vals()['hubIjaraTxt'], '−350 000');
      expect(store.vals()['hubIjaraPos'], isFalse);
      expect(find.text('1 hisob-kitob · 0 kutilmoqda'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  // ─────────────────── 3. 404 / BO'SH — TINCH NOL HOLATI ───────────────────
  // Bugungi production'da endpointlar YO'Q. Bu — PO qurilmada ko'radigan holat.
  group('404 / ma\'lumot yo\'q — karta tinch nol holatida', () {
    testWidgets('sub-qatorda modul TAVSIFI, xato/spinner YO\'Q', (t) async {
      _atHub(); // ijara/toy null — aynan 404 dan keyingi holat
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Karta o'z joyida, to'liq oila bilan
      expect(_cards(), findsNWidgets(4));
      expect(find.text(_name('modIjarachi')), findsOneWidget);
      expect(find.text(_name('modToyxona')), findsOneWidget);
      // Faktlar yo'q ekan, sub-qatorda modul tavsifi turadi
      expect(find.text(lUz['modIjarachiDesc'] as String), findsOneWidget);
      expect(find.text(lUz['modToyxonaDesc'] as String), findsOneWidget);
      // Hech qanday xato nishoni yo'q. Skelet ham yo'q — kartalar CHIZILGAN
      // (hub 404 tufayli "abadiy yuklanmoqda" holatida qolib ketmasin).
      expect(t.takeException(), isNull);
      expect(store.vals()['hubSkel'], isFalse);
      expect(find.textContaining('rror'), findsNothing);
      expect(find.textContaining('404'), findsNothing);
    });

    testWidgets('BO\'SH hub\'da ham (birinchi kirish) to\'rttala karta bir xil', (t) async {
      _atHub(empty: true);
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(_cards(), findsNWidgets(4));
      final hs = t.renderObjectList<RenderBox>(_cards()).map((r) => r.size.height).toList();
      for (final h in hs) {
        expect(h, kHubCardH, reason: 'bo\'sh holatda stack tirqishli: $hs');
      }
      // Bo'sh holat matni/CTA saqlangan (eski _emptyBody)
      expect(find.text(lUz['hubEmptyExpTitle'] as String), findsOneWidget);
      expect(find.text(lUz['hubEmptyDebtBtn'] as String), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('BO\'SH hub: Qarz kartasi «Qarz qo\'shish» oqimini ochadi', (t) async {
      _atHub(empty: true);
      await t.pumpWidget(const TrustApp());
      await t.pump();

      final f = find.text(_name('modQarz'));
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
      // hubAddDebt: home + yangi hamkor sheet'i
      expect(store.S['screen'], 'home');
      expect(store.S['npOpen'], isTrue);
      store.S['npOpen'] = false;
      store.goHub_();
      await t.pumpAndSettle();
    });

    testWidgets('SKELET: 4 ta shisha blok, crash yo\'q', (t) async {
      _atHub();
      store.S['skelHome'] = true;
      addTearDown(() => store.S['skelHome'] = false);
      await t.pumpWidget(const TrustApp());
      await t.pump();

      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('hubSkel_$i')), findsOneWidget);
      }
      expect(_cards(), findsNothing);
      expect(t.takeException(), isNull);
    });

    test('mapper: axlat javob ham NOL xarita beradi (crash yo\'q)', () {
      for (final junk in <dynamic>[null, '', 0, <String>[], '<html>404</html>']) {
        expect(mapIjaraHubSum(junk), kHubModZero, reason: 'ijara: $junk');
        expect(mapToyHubSum(junk), kHubModZero, reason: 'toyxona: $junk');
      }
      // Maydonlar yetishmasa ham — bor qismi olinadi, qolgani 0
      expect(mapIjaraHubSum({'left': 500}), {'left': 500, 'count': 0, 'pending': 0});
    });

    test('mapper: server shakli -> karta qiymatlari', () {
      // src/routes/ijara.js foldCharges
      expect(
        mapIjaraHubSum({
          'count': 4, 'countActive': 3, 'charged': 5000000, 'paid': 800000,
          'left': 4200000, 'byStatus': {'kutilmoqda': 2, 'tolangan': 1, 'bekor': 1},
        }),
        {'left': 4200000, 'count': 3, 'pending': 2},
      );
      // src/routes/toyxona.js foldSummary
      expect(
        mapToyHubSum({
          'count': 5, 'countActive': 4, 'total': 30000000, 'paid': 11500000,
          'left': 18500000, 'cancelledPaid': 200000,
          'byStatus': {'band': 1, 'tasdiq': 2, 'yakun': 1, 'bekor': 1},
        }),
        {'left': 18500000, 'count': 4, 'pending': 3},
      );
    });
  });

  // ─────────────────── 4. TARIF (sub qatori o'ng cheti) ───────────────────
  group('narx — faqat ma\'lumotdan', () {
    testWidgets('SERVER narxi lokal zaxirani almashtiradi', (t) async {
      _atHub(
        mods: mapSubsModules({
          'modules': [
            // Server tarifi lokal kSubModuleDefaults (5) dan BOSHQA
            {'module': 'xarajat', 'active': false, 'soon': false,
              'used': 1, 'free_limit': 5, 'price_usd': 7},
          ],
        }),
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('\$7/oy'), findsOneWidget, reason: 'server narxi ishlatilmadi');
      expect(find.text('\$5/oy'), findsNothing, reason: 'eskirgan lokal narx chiqdi');
    });

    testWidgets('QULF chipida narx YO\'Q — bir kartada ikki marta chiqmasin',
        (t) async {
      _atHub(
        mods: mapSubsModules({
          'modules': [
            {'module': 'toyxona', 'active': false, 'soon': false,
              'used': 5, 'free_limit': 5, 'price_usd': 24},
          ],
        }),
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Tarif faqat BITTA joyda — sub qatori o'ng chetida
      expect(find.text('\$24/oy'), findsOneWidget);
      // Qulf chipi PRO badge O'RNIDA: To'yxona kartasida PRO yo'q, boshqa ikkisida bor
      expect(find.byKey(const ValueKey('hubLock_toyxona')), findsOneWidget);
      expect(find.text('PRO'), findsNWidgets(2));
    });

    testWidgets('«3/5» hisoblagich — PRO badge o\'rnida', (t) async {
      _atHub(
        mods: mapSubsModules({
          'modules': [
            {'module': 'ijarachi', 'active': false, 'soon': false,
              'used': 3, 'free_limit': 5, 'price_usd': 13},
          ],
        }),
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('PRO'), findsNWidgets(2));
      // «7/300» — sinov limiti hisoblagichda KO'RINMAYDI (kModChipMaxLimit)
      _atHub(
        mods: mapSubsModules({
          'modules': [
            {'module': 'ijarachi', 'active': false, 'soon': false,
              'used': 7, 'free_limit': 300, 'price_usd': 13},
          ],
        }),
      );
      store.set({});
      await t.pump();
      expect(find.text('7/300'), findsNothing);
      expect(find.text('PRO'), findsNWidgets(3));
    });

    testWidgets('OBUNA FAOL bo\'lsa ham tarif ko\'rinadi (bir xillik)', (t) async {
      _atHub(
        mods: mapSubsModules({
          'modules': [
            {'module': 'ijarachi', 'active': true, 'soon': false,
              'used': 2, 'free_limit': 5, 'price_usd': 13},
          ],
        }),
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('\$13/oy'), findsOneWidget);
    });
  });

  // ─────────────────── 5. Qulf va navigatsiya buzilmagan ───────────────────
  // 2026-08-10 audit: qulf endi KIRISHNI to'smaydi (o'qish bloklanmaydi, 402
  // faqat yozishda) — karta bo'limni ochadi, paywall'ga yo'l esa QULF CHIPI.
  testWidgets('qulflangan modul — chip paywall, karta esa bo\'lim (raqam bilan ham)',
      (t) async {
    _atHub(
      ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
      mods: mapSubsModules({
        'modules': [
          {'module': 'ijarachi', 'active': false, 'soon': false,
            'used': 5, 'free_limit': 5, 'price_usd': 13},
        ],
      }),
    );
    await t.pumpWidget(const TrustApp());
    await t.pump();

    // Qulf CHIPI (_modChip, ValueKey hubLock_<modul>) -> paywall, screen hub'da qoladi
    final chip = find.byKey(const ValueKey('hubLock_ijarachi'));
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(find.byType(PaywallSheet), findsOneWidget);
    expect(store.S['screen'], 'hub');
    store.paywallClose_();
    await t.pump();

    // KARTA bosilsa — bo'lim ochiladi, paywall YO'Q
    final f = find.text(_name('modIjarachi'));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
    expect(find.byType(PaywallSheet), findsNothing);
    expect(store.S['screen'], 'ijara');
    store.goHub_();
    await t.pumpAndSettle();
  });

  // ─────────────────── 6. Header: profil / AI / bildirishnomalar ───────────
  testWidgets('header: avatar -> profil, qo\'ng\'iroq -> bildirishnomalar', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    await t.tap(find.byKey(const ValueKey('hubBellBtn')));
    await t.pump();
    expect(store.S['notifOpen'], isTrue);
    store.S['notifOpen'] = false;
    store.set({});
    await t.pump();

    // Yordam FAB'i o'ng-pastda (bosilsa store.openSupport_ — tarmoq + polling,
    // shu sabab bu yerda faqat mavjudligi va joyi tekshiriladi)
    final fab = find.byKey(const ValueKey('hubSupportFab'));
    expect(fab, findsOneWidget);
    final fr = t.getRect(fab);
    final screen = t.getRect(find.byType(HomeHubScreen));
    expect(screen.right - fr.right, closeTo(20, 1));
    expect(screen.bottom - fr.bottom, closeTo(24, 1));
    expect(fr.width, 60);
  });

  // ─────────────────── 7. Tor ekran × 6 til — toshib ketmasin ───────────────
  // ru/fr eng uzun tarjimalar; 320pt eng tor qurilma. Karta QAT'IY balandlikda
  // (ixcham rejim), shuning uchun mazmun ichkarida sig'ishi kerak — karta
  // o'smasligi va overflow bo'lmasligi SHART.
  for (final lang in kLangs.keys) {
    testWidgets('$lang — 320pt: 4 karta, bir xil bo\'y, toshish yo\'q', (t) async {
      addTearDown(() {
        store.S['lang'] = 'uz';
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(320, 640);
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
        mods: mapSubsModules({
          'modules': [
            {'module': 'ijarachi', 'active': false, 'soon': false,
              'used': 4, 'free_limit': 5, 'price_usd': 13},
            {'module': 'toyxona', 'active': false, 'soon': false,
              'used': 1, 'free_limit': 1, 'price_usd': 24}, // qulf chipi
          ],
        }),
      );
      store.S['lang'] = lang;
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(t.takeException(), isNull, reason: '$lang: overflow/xato');
      final hs = t.renderObjectList<RenderBox>(_cards()).map((r) => r.size.height).toList();
      expect(hs.length, 4, reason: '$lang: 4 ta karta emas');
      // Tana balandligi kHubGridMinH dan katta bo'lsa grid rejimi (kartalar
      // teng bo'lib to'ldiradi), aks holda ixcham (kHubCardH). Ikkalasida ham:
      // to'rttala karta BIR XIL bo'yda va ixcham qiymatdan kichik emas.
      for (final h in hs) {
        expect(h, hs.first, reason: '$lang: kartalar bo\'yi har xil ($hs)');
        expect(h >= kHubCardH, isTrue, reason: '$lang: karta juda past ($hs)');
      }
    });
  }
}
