// BOSH HUB — kartalar OILASI (PO 2026-08-04).
//
// NEGA BU TEST:
//   1) «Ijaradagi uylar» va «To'yxona» kartalari ilgari ikkinchi navli edi:
//      urg'u rangi yo'q, watermark yo'q va eng muhimi RAQAM yo'q edi (yuqoridagi
//      ikkita kartada katta summa, bularda faqat tavsif + chevron). PO talabi —
//      to'rttasi ham AYNAN bir xil ko'rinsin.
//   2) O'LCHAM ham bir xil: kartalar menyular ro'yxati va ro'yxat o'sib boradi.
//      Har biri o'z mazmuniga qarab bo'y olsa stack tirqishli bo'lardi.
//   3) TARIF har kartaning pastki-o'ng burchagida va FAQAT ma'lumotdan
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
import 'package:trust_mobile/sparkline.dart';
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

/// Karta sarlavhasi = modul nomi BOSH HARFLARDA (_menuCard).
String _cap(String nameKey) => (lUz[nameKey] as String).toUpperCase();

/// Hub kartalari — _hubShell qat'iy balandlik beradi, shu bo'yicha topamiz.
Finder _cards() => find.byWidgetPredicate((w) =>
    w is Container && w.constraints == BoxConstraints.tightFor(height: kHubCardH));

void main() {
  // ─────────────────── 1. Bir xil ANATOMIYA ───────────────────
  group('to\'rttala karta bitta oila', () {
    testWidgets('4 ta karta, hammasi bir xil qobiqdan (kHubCardH)', (t) async {
      _atHub();
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Xarajat, Qarz daftar, Ijaradagi uylar, To'yxona
      expect(_cards(), findsNWidgets(4));
      expect(t.takeException(), isNull);
    });

    testWidgets('BALANDLIK aynan bir xil — stack tirqishsiz', (t) async {
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      final hs = t.renderObjectList<RenderBox>(_cards()).map((r) => r.size.height).toList();
      expect(hs.length, 4);
      // Xarajat kartasi (sparkline bilan) ham, eng kambag'ali ham bir xil
      for (final h in hs) {
        expect(h, kHubCardH, reason: 'karta bo\'yi farq qilyapti: $hs');
      }
    });

    // kHubCardH «eng boy karta sig'adigan» qilib tanlangan. Agar u kichrayib
    // ketsa, _hubShell ichidagi FittedBox mazmunni JIMGINA kichraytiradi —
    // Xarajat kartasi dizayndan mayda bo'lib qolardi va buni ko'z bilan
    // payqash qiyin. Shu sabab: sparkline'ning EKRANDAGI (transform bilan)
    // bo'yi tuzilishdagi 46px ga TENG bo'lishi shart — ya'ni siqilish yo'q.
    testWidgets('eng boy karta SIQILMAYDI (kHubCardH yetarli)', (t) async {
      // Xarajat kartasining ENG TO'LIQ ko'rinishi: sarlavha + summa + CHEGARA
      // qatori + sparkline. Chegarasiz fikstura bu qatorni chizmaydi va test
      // eng og'ir holatni umuman sinamay qolardi.
      _atHub();
      store.S['xarLimit'] = 3000000; // -> hubHasLimit: «Qoldi: +2 850 000»
      // 0 ga qaytariladi, null EMAS: _xarVals uni `as int` bilan o'qiydi.
      addTearDown(() => store.S['xarLimit'] = 0);
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(store.vals()['hubHasLimit'], isTrue, reason: 'chegara qatori chizilmadi');
      expect(find.text(lUz['hubLeft'] as String), findsOneWidget);

      // FittedBox siqsa, EKRANDAGI (transform bilan) bo'y 46 dan kichik bo'lardi
      final spark = find.byType(Sparkline).first;
      expect(t.getRect(spark).height, closeTo(46, 0.01),
          reason: 'Xarajat sparkline\'i siqilgan — kHubCardH kichik');
    });

    testWidgets('har kartada: bo\'lim nomi + sarlavha + SUMMA + tarif', (t) async {
      _atHub(
        ijara: const {'left': 4200000, 'count': 3, 'pending': 2},
        toy: const {'left': 18500000, 'count': 4, 'pending': 1},
      );
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Bo'lim nomlari
      for (final cap in [
        lUz['hubXarSec'] as String,
        lUz['hubDebtSec'] as String,
        _cap('modIjarachi'),
        _cap('modToyxona'),
      ]) {
        expect(find.text(cap), findsOneWidget, reason: '$cap kartasi yo\'q');
      }
      // Sarlavha qatorlari (summa ustidagi) — to'rttasida ham bor
      expect(find.text(lUz['hubToMe'] as String), findsOneWidget);
      expect(find.text(lUz['hubIjaraCap'] as String), findsOneWidget);
      expect(find.text(lUz['hubToyCap'] as String), findsOneWidget);
      // Birlik («so'm») — endi to'rttala kartada ham summadan keyin turadi
      expect(find.text(lUz['som'] as String), findsNWidgets(4));
      // Tarif — har kartaning pastki-o'ng burchagida (oflayn zaxira narxlari)
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
        // O'ng chetga taqalgan (padding 14) va pastda (padding 12)
        expect(card.right - pr.right, closeTo(14, 1.5),
            reason: '\$$price/oy o\'ng chetda emas');
        expect(card.bottom - pr.bottom, lessThan(20),
            reason: '\$$price/oy pastki burchakda emas');
      }
    });
  });

  // ─────────────────── 2. YANGI KARTALARDAGI RAQAM ───────────────────
  group('ma\'lumot bor — karta summani ko\'rsatadi', () {
    testWidgets('Ijara: yig\'ilishi kerak + hisob-kitob/kutilmoqda', (t) async {
      _atHub(ijara: const {'left': 4200000, 'count': 3, 'pending': 2});
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('+4 200 000'), findsOneWidget);
      expect(find.text(lUz['hubIjaraCap'] as String), findsOneWidget);
      expect(find.text('3 hisob-kitob · 2 kutilmoqda'), findsOneWidget);
      // Faktlar bor ekan, tavsif sub-qatordan chiqib ketadi
      expect(find.text(lUz['modIjarachiDesc'] as String), findsNothing);
    });

    testWidgets('To\'yxona: to\'lanmagan qoldiq + bandlar soni', (t) async {
      _atHub(toy: const {'left': 18500000, 'count': 4, 'pending': 1});
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(find.text('+18 500 000'), findsOneWidget);
      expect(find.text(lUz['hubToyCap'] as String), findsOneWidget);
      expect(find.text('Bu oyda 4 to\'y'), findsOneWidget);
      expect(find.text(lUz['modToyxonaDesc'] as String), findsNothing);
    });

    testWidgets('MANFIY qoldiq (avans olingan) — qizil ishora bilan', (t) async {
      _atHub(ijara: const {'left': -350000, 'count': 1, 'pending': 0});
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // hubLeftTxt bilan bir xil qoida: ishora + mutlaq qiymat
      expect(find.text('−350 000'), findsOneWidget);
      expect(store.vals()['hubIjaraPos'], isFalse);
      expect(t.takeException(), isNull);
    });
  });

  // ─────────────────── 3. 404 / BO'SH — TINCH NOL HOLATI ───────────────────
  // Bugungi production'da endpointlar YO'Q. Bu — PO qurilmada ko'radigan holat.
  group('404 / ma\'lumot yo\'q — karta tinch nol holatida', () {
    testWidgets('summa 0, sub-qatorda modul TAVSIFI, xato/spinner YO\'Q', (t) async {
      _atHub(); // ijara/toy null — aynan 404 dan keyingi holat
      await t.pumpWidget(const TrustApp());
      await t.pump();

      // Karta o'z joyida, to'liq oila bilan
      expect(_cards(), findsNWidgets(4));
      expect(find.text(_cap('modIjarachi')), findsOneWidget);
      expect(find.text(_cap('modToyxona')), findsOneWidget);
      // Nol summa — «0 so'm», ishorasi musbat (hubDebtTxt bilan bir xil idioma).
      // Uchta: Ijara + To'yxona (404) va Qarz daftar (bu fikstura'da qarz yo'q).
      expect(find.text('+0'), findsNWidgets(3));
      // Sarlavha qatori qoladi — karta "yarim qurilgan" bo'lib ko'rinmasin
      expect(find.text(lUz['hubIjaraCap'] as String), findsOneWidget);
      expect(find.text(lUz['hubToyCap'] as String), findsOneWidget);
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

  // ─────────────────── 4. TARIF (pastki-o'ng burchak) ───────────────────
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

      // Tarif faqat BITTA joyda — pastki-o'ng burchakda
      expect(find.text('\$24/oy'), findsOneWidget);
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
  testWidgets('qulflangan modul — hamon paywall (raqam qo\'shilgach ham)',
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

    final f = find.text(_cap('modIjarachi'));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();

    expect(find.byType(PaywallSheet), findsOneWidget);
    expect(store.S['screen'], 'hub');
    store.paywallClose_();
    await t.pump();
  });

  // ─────────────────── 6. Tor ekran × 6 til — toshib ketmasin ───────────────
  // ru/fr eng uzun tarjimalar; 320pt eng tor qurilma. Karta QAT'IY balandlikda,
  // shuning uchun mazmun ichkarida kichrayishi kerak — karta o'smasligi SHART.
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
      for (final h in hs) {
        expect(h, kHubCardH, reason: '$lang: karta bo\'yi o\'zgardi ($hs)');
      }
    });
  }
}
