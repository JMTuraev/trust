// Profil > Obuna bo'limi — HAR BO'LIM uchun alohida qator (PO 2026-08-04).
//
// NEGA BU TEST: tarif bitta $9 premiumdan per-modul obunaga o'tdi, profil esa
// bitta umumiy karta ko'rsatardi va hech qachon obuna bo'lmagan odamga
// «Obunani yangilash» CTAsini chiqarardi. Bu yerda uchala ko'rinish
// (modul ro'yxati / legacy premium / modSubs BO'SH) va ikkita qattiq qoida
// tekshiriladi:
//   1) HECH QAYERDA qotirilgan summa chizilmaydi (eski «$9/oy» qaytmasin),
//   2) hisoblagich faqat MA'NOLI limitda (production'da free_limit=300 —
//      profilda «7/300» ko'rinmasligi SHART, home_hub `_modChip` qoidasi).
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/l10n.dart';
import 'package:trust_mobile/main.dart';
import 'package:trust_mobile/store.dart';

/// Profil ekranini kerakli obuna holati bilan boshlaydi.
void _atProfil({
  List<Map<String, dynamic>> mods = const [],
  bool legacy = false,
  String subStatus = 'free',
  String? premUntil,
}) {
  store.S['stage'] = 'app';
  store.S['screen'] = 'profil';
  store.S['clientOpen'] = false;
  store.S['paywall'] = null;
  store.S['modSubs'] = mods;
  store.S['modSubsLegacy'] = legacy;
  store.S['subStatus'] = subStatus;
  store.S['premUntil'] = premUntil;
}

/// Server javobi -> 'modSubs' qatorlari (store'dagi sof funksiya bilan).
List<Map<String, dynamic>> _mods({int xarUsed = 3, int xarLimit = 5}) =>
    mapSubsModules({
      'modules': [
        {
          'module': 'xarajat', 'active': false, 'soon': false,
          'used': xarUsed, 'free_limit': xarLimit, 'price_usd': 5,
        },
        {
          'module': 'qarz', 'active': true, 'soon': false,
          'active_until': _kQarzUntil, 'price_usd': 8,
        },
        {'module': 'ijarachi', 'active': false, 'soon': false, 'price_usd': 13},
        {'module': 'toyxona', 'active': false, 'soon': false, 'price_usd': 24},
      ],
    });

String _uz(String k) => lUz[k] as String;

/// ISO -> «04.09.2026» LOKAL vaqtda. Test boshqa timezone'da ham o'tsin:
/// UTC yarim tunidagi sana zonaga qarab ±1 kun siljiydi.
String _localDate(String iso) {
  final d = DateTime.parse(iso).toLocal();
  String d2(int x) => x.toString().padLeft(2, '0');
  return '${d2(d.day)}.${d2(d.month)}.${d.year}';
}

const _kQarzUntil = '2026-09-04T00:00:00Z';
const _kPremUntil = '2026-12-01T00:00:00Z';

void main() {
  testWidgets('modul ro\'yxati: 4 bo\'lim, nomlari joriy tilda', (t) async {
    _atProfil(mods: _mods());
    await t.pumpWidget(const TrustApp());
    await t.pump();

    for (final k in ['modXarajat', 'modQarz', 'modIjarachi', 'modToyxona']) {
      expect(find.text(_uz(k)), findsOneWidget, reason: '$k qatori yo\'q');
    }
    // PO: «Ijarachi» (tenant) emas — obunani UY EGASI oladi
    expect(_uz('modIjarachi'), 'Ijaradagi uylar');
  });

  testWidgets('holatlar: faol (sana bilan) / hisoblagich / CTA', (t) async {
    _atProfil(mods: _mods());
    await t.pumpWidget(const TrustApp());
    await t.pump();

    // qarz — faol, tugash sanasi bilan
    expect(find.text('Faol · ${_localDate(_kQarzUntil)} gacha'), findsOneWidget);
    // xarajat — bepul, ma'noli limit (3/5) -> hisoblagich ko'rinadi
    expect(find.text('3/5 bepul yozuv ishlatildi'), findsOneWidget);
    // Faol bo'lmagan 3 ta bo'limda CTA (faol qarzda YO'Q)
    expect(find.text(_uz('subModSubscribe')), findsNWidgets(3));
    // Hech qachon obuna bo'lmagan odamga «Obunani yangilash» chiqmaydi
    expect(find.text(_uz('subRenew')), findsNothing);
  });

  testWidgets('limit tugagan bo\'lim — «Bepul limit tugagan»', (t) async {
    _atProfil(mods: _mods(xarUsed: 5, xarLimit: 5));
    await t.pumpWidget(const TrustApp());
    await t.pump();

    expect(find.text(_uz('subModLimitOut')), findsOneWidget);
    expect(find.text('5/5 bepul yozuv ishlatildi'), findsNothing);
  });

  testWidgets('production limiti (300) — hisoblagich CHIZILMAYDI', (t) async {
    _atProfil(mods: _mods(xarUsed: 7, xarLimit: 300));
    await t.pumpWidget(const TrustApp());
    await t.pump();

    expect(find.text('7/300 bepul yozuv ishlatildi'), findsNothing,
        reason: 'render.yaml sinov qiymati oshkor bo\'lmasin');
    expect(find.textContaining('/300'), findsNothing);
    // O'rniga oddiy «Bepul reja»
    expect(find.text(_uz('subFreeTitle')), findsWidgets);
  });

  testWidgets('LEGACY premium: eski ko\'rinish saqlanadi + hamma modul qamrab olingan',
      (t) async {
    _atProfil(
      mods: _mods(),
      legacy: true,
      subStatus: 'premium',
      premUntil: _kPremUntil,
    );
    await t.pumpWidget(const TrustApp());
    await t.pump();

    // Eski sarlavha AYNAN avvalgidek
    expect(find.text('Premium · ${_localDate(_kPremUntil)} gacha'), findsOneWidget);
    expect(find.text(_uz('subPremiumBody')), findsOneWidget);
    // Har bir modul — premiumga kiritilgan, sotib olish CTAsi YO'Q
    expect(find.text(_uz('subModLegacy')), findsNWidgets(4));
    expect(find.text(_uz('subModSubscribe')), findsNothing);
    // Boshqarish tugmasi joyida
    expect(find.text(_uz('subManage')), findsOneWidget);
  });

  testWidgets('modSubs BO\'SH (server qo\'llamaydi) — zaxira karta, narxsiz',
      (t) async {
    _atProfil();
    await t.pumpWidget(const TrustApp());
    await t.pump();

    // Modul qatorlari yo'q
    expect(find.text(_uz('subModLegacy')), findsNothing);
    expect(find.textContaining('Faol ·'), findsNothing);
    // Eski umumiy karta: bepul reja + narxsiz izoh
    expect(find.text(_uz('subFreeTitle')), findsWidgets);
    expect(find.text(_uz('subInfo')), findsWidgets);
    // Bepul rejada CTA «yangilash» emas, «obuna bo'lish»
    expect(find.text(_uz('subModSubscribe')), findsOneWidget);
    expect(find.text(_uz('subRenew')), findsNothing);
  });

  testWidgets('HECH QAYERDA qotirilgan summa yo\'q', (t) async {
    _atProfil(mods: _mods());
    await t.pumpWidget(const TrustApp());
    await t.pump();

    // StoreKit narxi yo'q (test hostida do'kon yo'q) -> hech qanday $ summa
    expect(find.textContaining('\$'), findsNothing);
    expect(find.textContaining('9/oy'), findsNothing);
  });

  group('l10n — yangi kalitlar 6 tilda', () {
    const keys = [
      'subModActive',
      'subModActiveUntil',
      'subModLimitOut',
      'subModLegacy',
      'subModSubscribe',
      'subAutoRenewNoteMod',
    ];

    test('kalit har tilda bor va bo\'sh emas', () {
      for (final e in kLangs.entries) {
        for (final k in keys) {
          expect(e.value[k], isA<String>(), reason: '${e.key}: $k yo\'q');
          expect('${e.value[k]}'.trim(), isNotEmpty, reason: '${e.key}: $k bo\'sh');
        }
      }
    });

    test('{d} o\'rin egasi har tilda saqlangan', () {
      for (final e in kLangs.entries) {
        expect('${e.value['subModActiveUntil']}', contains('{d}'), reason: e.key);
      }
    });

    test('modul qatorlari matnida NARX yo\'q', () {
      for (final e in kLangs.entries) {
        for (final k in keys) {
          expect('${e.value[k]}', isNot(contains('\$')), reason: '${e.key}: $k');
        }
      }
    });
  });
}
