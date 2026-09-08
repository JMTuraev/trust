// BOSH HUB — modul menyulari (PO 2026-08-04: To'yxona va Ijaradagi uylar
// QURILDI va endi Xarajatlar/Qarz daftar kabi ODDIY MENYU bo'lib ochiladi).
//
// NEGA BU TEST:
//   1) Ilgari bu ikki qator so'nik «Tez kunda» teaser edi va bosilganda
//      NAVIGATSIYA emas, paywall ochilardi. Bayroq (`soon`) yoki karta qaytib
//      teaserga aylansa — foydalanuvchi qurilgan bo'limga umuman kira olmaydi.
//   2) Qulflangan modul (bepul limit tugagan, obuna yo'q) — 2026-08-10 audit:
//      karta baribir BO'LIMNI ochadi (o'qish hech qachon bloklanmaydi, backend
//      402 ni faqat YOZISHDA beradi); paywall'ga qisqa yo'l — qulf CHIPI.
//   3) Apparat "orqaga" — modul ekranidan hub'ga qaytishi kerak, ILOVADAN
//      CHIQIB KETMASLIGI. Bu bugun ikki marta tishlagan xato sinfi
//      (main.dart Root PopScope + store.hubBackable()).
import 'package:flutter/widgets.dart' show Size, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/l10n.dart';
import 'package:trust_mobile/main.dart';
import 'package:trust_mobile/screens/ijara.dart';
import 'package:trust_mobile/screens/paywall_sheet.dart';
import 'package:trust_mobile/screens/toyxona.dart';
import 'package:trust_mobile/store.dart';

/// Bitta xarajat yozuvi — hub'ni "bo'sh holat"dan YUKLANGAN holatga o'tkazadi
/// (_hubVals: hasAny). Shakl store._mapExpense bilan bir xil.
Map<String, dynamic> _xarEntry() {
  final now = DateTime.now();
  return {
    'id': 'x1', 'kind': 'x', 'cat': 'Transport', 'note': '',
    'a': 150000, 'days': 0, 't': '12:00',
    'ts': now.millisecondsSinceEpoch,
    'ym': '${now.year}-${now.month}', 'dom': now.day,
  };
}

/// Hub'ni ma'lum obuna holati bilan boshlaydi (paywall yopiq, skelet yo'q).
void _atHub({List<Map<String, dynamic>> mods = const [], bool empty = false}) {
  store.S['stage'] = 'app';
  store.S['screen'] = 'hub';
  store.S['clientId'] = null;
  store.S['clientOpen'] = false;
  store.S['paywall'] = null;
  store.S['skelHome'] = false;
  store.S['modSubs'] = mods;
  store.S['modSubsLegacy'] = false;
  store.S['xarEntries'] = empty ? <Map<String, dynamic>>[] : [_xarEntry()];
}

/// Karta nomi = modul nomi (home_hub `_card`: modStr(kModNameKey[module])).
String _cap(String nameKey) => lUz[nameKey] as String;

/// Kartani ko'rinadigan joyga surib, bosadi (kartalar ekran ostida qoladi).
Future<void> _tapCard(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('hub — 4 ta menyu kartasi, «Tez kunda» qolmagan', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    for (final cap in [
      _cap('modXarajat'), // Xarajatlar
      _cap('modQarz'), // Qarz daftar
      _cap('modIjarachi'), // Ijaradagi uylar
      _cap('modToyxona'), // To'yxona
    ]) {
      expect(find.text(cap), findsOneWidget, reason: '$cap kartasi yo\'q');
    }
    // Modullar ochildi — yo'l xaritasi nishoni bosh ekranda qolmasin
    expect(find.text(lUz['modSoon'] as String), findsNothing);
  });

  testWidgets('BO\'SH holatda ham ikkala modul menyusi ko\'rinadi', (t) async {
    _atHub(empty: true);
    await t.pumpWidget(const TrustApp());
    await t.pump();

    expect(find.text(_cap('modIjarachi')), findsOneWidget);
    expect(find.text(_cap('modToyxona')), findsOneWidget);
    expect(find.text(lUz['modSoon'] as String), findsNothing);
  });

  testWidgets('To\'yxona kartasi — obuna holati yo\'q: EKRAN ochiladi', (t) async {
    _atHub(); // modSubs bo'sh = server qo'llamaydi / hali kelmagan
    await t.pumpWidget(const TrustApp());
    await t.pump();

    await _tapCard(t, _cap('modToyxona'));
    expect(find.byType(ToyxonaScreen), findsOneWidget);
    expect(find.byType(PaywallSheet), findsNothing, reason: 'paywall EMAS — bo\'lim ochiq');
    expect(store.S['screen'], 'toyxona');
  });

  testWidgets('Ijaradagi uylar kartasi — EKRAN ochiladi', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    await _tapCard(t, _cap('modIjarachi'));
    expect(find.byType(IjaraScreen), findsOneWidget);
    expect(find.byType(PaywallSheet), findsNothing);
    expect(store.S['screen'], 'ijara');
  });

  // 2026-08-10 audit: qulf endi KIRISHNI to'smaydi — ma'lumot «garovda» edi
  // (backend o'qishni hech qachon bloklamaydi, 402 faqat yozishda). Karta doim
  // bo'limni ochadi; paywall'ga qisqa yo'l — kartadagi QULF CHIPI.
  testWidgets('QULFLANGAN modul — chip paywall ochadi, karta esa EKRANNI', (t) async {
    _atHub(
      mods: mapSubsModules({
        'modules': [
          {
            'module': 'toyxona', 'active': false, 'soon': false,
            'used': 5, 'free_limit': 5, 'price_usd': 21,
          },
        ],
      }),
    );
    await t.pumpWidget(const TrustApp());
    await t.pump();

    // 1) Qulf CHIPI (_modChip, ValueKey hubLock_<modul>) -> paywall, navigatsiya YO'Q
    final chip = find.byKey(const ValueKey('hubLock_toyxona'));
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(find.byType(PaywallSheet), findsOneWidget);
    expect(find.byType(ToyxonaScreen), findsNothing, reason: 'chip — faqat paywall');
    expect(store.S['screen'], 'hub');

    // Chegara siyosati AYNAN shu yerda aytiladi: «bitta obuna — bitta to'yxona,
    // ko'proq kerak bo'lsa boshqa raqamga alohida hisob» (PO 2026-08-04).
    expect(find.text(lUz['pwCapToy'] as String), findsOneWidget);
    // Modul ochiq (soon:false) -> «Tez kunda» pill emas, haqiqiy CTA turadi
    expect(find.text(lUz['modSoon'] as String), findsNothing);

    store.paywallClose_();
    await t.pump();
    expect(find.byType(PaywallSheet), findsNothing);

    // 2) KARTA bosilsa — bo'lim OCHILADI (o'qish qulflanmaydi; yozishda server
    //    402 beradi va paywall o'sha yerda o'zi chiqadi)
    await _tapCard(t, _cap('modToyxona'));
    expect(find.byType(ToyxonaScreen), findsOneWidget,
        reason: 'qulflangan modul ham O\'QISH uchun ochiq');
    expect(find.byType(PaywallSheet), findsNothing);
    expect(store.S['screen'], 'toyxona');
  });

  testWidgets('Ijara paywall\'i — chegara izohida uy soni to\'ldirilgan', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    store.openPaywall_('ijarachi');
    await t.pump();
    expect(find.byType(PaywallSheet), findsOneWidget);
    final want = (lUz['pwCapIjara'] as String)
        .replaceAll('{n}', '${kModCapUnits['ijarachi']}');
    expect(find.text(want), findsOneWidget);
    expect(find.textContaining('{n}'), findsNothing);

    store.paywallClose_();
    await t.pump();
  });

  // Qarz — obyekt tushunchasi yo'q modul (xarajat 2026-09-08 dan BEPUL,
  // uning paywall'i umuman ochilmaydi — pastdagi test).
  testWidgets('Qarz paywall\'ida chegara izohi YO\'Q (obyekt tushunchasi yo\'q)',
      (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    store.openPaywall_('qarz');
    await t.pump();
    expect(find.byType(PaywallSheet), findsOneWidget);
    expect(find.text(lUz['pwCapIjara'] as String), findsNothing);
    expect(find.text(lUz['pwCapToy'] as String), findsNothing);

    store.paywallClose_();
    await t.pump();
  });

  testWidgets('Xarajat BEPUL (PO 2026-09-08) — paywall OCHILMAYDI', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    store.openPaywall_('xarajat');
    await t.pump();
    expect(find.byType(PaywallSheet), findsNothing);
    expect(store.S['paywall'], isNull);
  });

  // Tor ekran (320pt) + eng uzun tarjimalar: karta ichidagi hech narsa toshib
  // ketmasin. Nom sig'masa FittedBox bilan kichrayadi, tavsif 2 qatorga
  // o'raladi (Text widgeti mavjud — find.text topadi).
  // HAR TIL ALOHIDA test: `const TrustApp()` kanonik instance, shu sabab bitta
  // test ichida qayta pumpWidget qilinsa Element rebuild'ni O'TKAZIB YUBORADI
  // (main.dart'dagi «const EMAS» izohi bilan bir xil tuzoq) — til almashmasdi.
  for (final lang in kLangs.keys) {
    testWidgets('$lang — tor ekranda (320pt) karta toshib ketmaydi', (t) async {
      addTearDown(() {
        store.S['lang'] = 'uz';
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(320, 640);
      _atHub(
        mods: mapSubsModules({
          'modules': [
            {
              'module': 'ijarachi', 'active': false, 'soon': false,
              'used': 4, 'free_limit': 5, 'price_usd': 13, // «4/5» hisoblagich
            },
            {
              'module': 'toyxona', 'active': false, 'soon': false,
              'used': 1, 'free_limit': 1, 'price_usd': 21, // qulf + «$21/oy»
            },
          ],
        }),
      );
      store.S['lang'] = lang;
      await t.pumpWidget(const TrustApp());
      await t.pump();

      expect(t.takeException(), isNull, reason: '$lang: overflow/xato');
      final name = kLangs[lang]!['modToyxona'] as String;
      expect(find.text(name), findsOneWidget, reason: '$lang: To\'yxona kartasi yo\'q');
      // Nom ostida sub matn (tavsif) YO'Q — PO 2026-09-08
      expect(find.text(kLangs[lang]!['modToyxonaDesc'] as String), findsNothing,
          reason: '$lang: tavsif hali chiqyapti');
    });
  }

  testWidgets('apparat "orqaga" — modul ekranidan hub\'ga qaytadi (chiqmaydi)',
      (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _tapCard(t, _cap('modIjarachi'));

    // Root PopScope shu uchta qiymatga qarab qaror qiladi (main.dart)
    var v = store.vals();
    expect(v['layerOpen'], isFalse, reason: 'modul ekrani — qatlam emas, EKRAN');
    expect(v['hubBackable'], isTrue, reason: 'orqaga hub\'ga qaytarishi SHART');
    expect(v['hubAtRoot'], isFalse, reason: 'aks holda "yana bosing — chiqadi"ga tushardi');

    // PopScope AYNAN shuni chaqiradi
    (v['hubBack'] as void Function())();
    await t.pumpAndSettle();
    expect(store.S['screen'], 'hub');
    expect(find.byType(IjaraScreen), findsNothing);

    // To'yxona uchun ham bir xil
    await _tapCard(t, _cap('modToyxona'));
    v = store.vals();
    expect(v['hubBackable'], isTrue);
    (v['hubBack'] as void Function())();
    await t.pumpAndSettle();
    expect(store.S['screen'], 'hub');
    expect(find.byType(ToyxonaScreen), findsNothing);
  });
}
