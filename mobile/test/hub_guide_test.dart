// BOSH HUB — NARX QO'LLANMASI («Narxni bilish» tugmasi, PO 2026-09-08).
//
// NEGA BU TEST:
//   1) Qo'llanma — SOF KO'RINISH qatlami. Tugma O'CHIQ bo'lganda hub AYNAN
//      avvalgidek ishlashi shart: markazda narx yo'q, karta bosilsa bo'lim
//      ochiladi. Bu shartnoma buzilsa foydalanuvchi bo'limlarga kira olmaydi.
//   2) Tugma YOQILGANDA karta BOSILMAYDI (hub tushuntirish rejimida) va har
//      kartaning MARKAZIDA tarif turadi: Xarajatlar «Bepul», Qarz $8/oy,
//      Ijara $13/oy (5 uygacha), To'yxona $21/oy (+ qo'shimcha to'yxona
//      uchun alohida to'lov). Kartaning O'ZIDA tarif YO'Q (PO 2026-09-08 kech) —
//      narx faqat qo'llanmada.
//   4) Yozuv KETMA-KET: Xarajatlar to'liq yozilmaguncha Qarz boshlanmaydi
//      (hammasi birdan chiqsa PO «ustma-ust» deb qaytardi).
//   3) Narx MA'LUMOTDAN keladi (server modSubs[].price, oflaynda
//      kSubModuleDefaults) — widget ichida qotirilgan narx satri BO'LMASIN.
//      Shu sabab test serverdan BOSHQA narx yuborib, ekranda o'shani kutadi.
import 'package:flutter/widgets.dart' show Color, Text, TextSpan, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/l10n.dart';
import 'package:trust_mobile/main.dart';
import 'package:trust_mobile/screens/toyxona.dart';
import 'package:trust_mobile/store.dart';

Map<String, dynamic> _xarEntry() {
  final now = DateTime.now();
  return {
    'id': 'x1', 'kind': 'x', 'cat': 'Transport', 'note': '',
    'a': 150000, 'days': 0, 't': '12:00',
    'ts': now.millisecondsSinceEpoch,
    'ym': '${now.year}-${now.month}', 'dom': now.day,
  };
}

void _atHub({List<Map<String, dynamic>> mods = const []}) {
  store.S['stage'] = 'app';
  store.S['screen'] = 'hub';
  store.S['clientId'] = null;
  store.S['clientOpen'] = false;
  store.S['paywall'] = null;
  store.S['skelHome'] = false;
  store.S['modSubs'] = mods;
  store.S['modSubsLegacy'] = false;
  store.S['xarEntries'] = [_xarEntry()];
}

String _l(String k) => lUz[k] as String;
String _price(int n) => _l('modPerMonth').replaceAll('{price}', '$n');

Finder _guideBtn() => find.byKey(const ValueKey('hubGuideBtn'));
Finder _gPrice(String m) => find.byKey(ValueKey('hubGuidePrice_$m'));
Finder _gNote(String m) => find.byKey(ValueKey('hubGuideNote_$m'));

/// Tugmani bosib, animatsiya tugagunicha kutadi.
Future<void> _toggle(WidgetTester t) async {
  await t.ensureVisible(_guideBtn());
  await t.pumpAndSettle();
  await t.tap(_guideBtn());
  await t.pumpAndSettle();
}

/// Qo'llanma matni Text.rich (yozilgan qism + shaffof qoldiq) — to'liq matn.
String _txt(WidgetTester t, Finder f) => t.widget<Text>(f).textSpan!.toPlainText();

void main() {
  testWidgets('qo\'llanma O\'CHIQ — hub avvalgidek: markazda narx yo\'q', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    expect(_guideBtn(), findsOneWidget, reason: '«Narxni bilish» tugmasi yo\'q');
    expect(find.text(_l('hubGuideBtn')), findsOneWidget);
    for (final m in ['xarajat', 'qarz', 'ijarachi', 'toyxona']) {
      expect(_gPrice(m), findsNothing, reason: '$m: qo\'llanma o\'chiq bo\'lsa markaz bo\'sh');
      expect(_gNote(m), findsNothing);
    }
  });

  testWidgets('tugma bosilsa — har karta markazida TARIF chiqadi', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _toggle(t);

    // Xarajatlar HAMMA uchun bepul (kSubModuleDefaults free:true) -> «Bepul»
    expect(_txt(t, _gPrice('xarajat')), _l('subFree'));
    expect(_txt(t, _gNote('xarajat')), _l('hubGuideXar'));
    // Qarz daftar — $8/oy, «Cheksiz yozuv»
    expect(_txt(t, _gPrice('qarz')), _price(8));
    expect(_txt(t, _gNote('qarz')), _l('hubGuideQarz'));
    // Ijara — $13/oy, «5 tagacha ijaradagi uy»
    expect(_txt(t, _gPrice('ijarachi')), _price(13));
    expect(_txt(t, _gNote('ijarachi')), _l('hubGuideIjara').replaceAll('{n}', '5'));
    // To'yxona — $21/oy va qo'shimcha to'yxona uchun ALOHIDA to'lov aytiladi
    expect(_txt(t, _gPrice('toyxona')), _price(21));
    expect(_txt(t, _gNote('toyxona')), _l('hubGuideToy').replaceAll('{price}', _price(21)));
  });

  testWidgets('qo\'llanma yoqilgan — kartalar BOSILMAYDI', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _toggle(t);

    final card = find.byKey(const ValueKey('hubCard_toyxona'));
    await t.ensureVisible(card);
    await t.pumpAndSettle();
    await t.tap(card);
    await t.pumpAndSettle();
    expect(store.S['screen'], 'hub', reason: 'qo\'llanmada karta navigatsiya qilmaydi');
    expect(find.byType(ToyxonaScreen), findsNothing);
  });

  testWidgets('tugma O\'CHIRILSA — qo\'llanma yo\'qoladi, karta yana ochadi', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _toggle(t); // yoq
    await _toggle(t); // o'chir

    for (final m in ['xarajat', 'qarz', 'ijarachi', 'toyxona']) {
      expect(_gPrice(m), findsNothing);
    }
    final card = find.byKey(const ValueKey('hubCard_toyxona'));
    await t.ensureVisible(card);
    await t.pumpAndSettle();
    await t.tap(card);
    await t.pumpAndSettle();
    expect(store.S['screen'], 'toyxona', reason: 'qo\'llanma o\'chgach hub avvalgidek');
    expect(find.byType(ToyxonaScreen), findsOneWidget);
  });

  testWidgets('narx MA\'LUMOTDAN — server boshqa narx bersa o\'sha chiqadi', (t) async {
    _atHub(
      mods: mapSubsModules({
        'modules': [
          {'module': 'qarz', 'active': false, 'soon': false, 'used': 0, 'free_limit': 5, 'price_usd': 9},
        ],
      }),
    );
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _toggle(t);

    expect(_txt(t, _gPrice('qarz')), _price(9), reason: 'qotirilgan \$8 emas, server narxi');
  });

  testWidgets('yozuv KETMA-KET: Xarajatlar tugamaguncha Qarz boshlanmaydi', (t) async {
    _atHub();
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await t.ensureVisible(_guideBtn());
    await t.pumpAndSettle();
    await t.tap(_guideBtn());
    // Birinchi kadr — ticker shu yerda "0" ni oladi (elapsed birinchi tikdan
    // hisoblanadi); undan keyingina vaqt o'tadi.
    await t.pump();
    // Ikonkalar ko'chib bo'lgach (450ms) yozuv boshlanadi; Xarajatlar matni
    // ~18 belgi × 20ms = ~360ms. 450+150ms da: Xarajatlar yozilyapti,
    // Qarz hali BO'SH (shaffof) bo'lishi kerak.
    await t.pump(const Duration(milliseconds: 600));
    String vis(Finder f) {
      // Ko'rinadigan (shaffof bo'lmagan) qism — birinchi span
      final span = t.widget<Text>(f).textSpan!;
      final buf = StringBuffer();
      span.visitChildren((c) {
        if (c is TextSpan && c.style?.color != const Color(0x00000000)) buf.write(c.text ?? '');
        return true;
      });
      return buf.toString();
    }
    final xar = vis(_gPrice('xarajat'));
    final qarz = vis(_gPrice('qarz'));
    expect(xar, isNotEmpty, reason: 'Xarajatlar yozila boshlagan bo\'lishi kerak');
    expect(qarz, isEmpty, reason: 'Qarz Xarajatlardan OLDIN yozila boshladi: "$qarz"');
    await t.pumpAndSettle();
    expect(vis(_gPrice('qarz')), _price(8));
  });
}
