// Modul obunalari (per-module subscriptions) — sof funksiyalar (store.dart):
//   mapSubsModules    — GET /api/subs/status tanasi -> 'modSubs' qatorlari
//   subsLegacyActive  — legacy_premium.active
//   subsPaywallEntry  — bitta modul uchun paywall holati (serverda yo'q bo'lsa — lokal standart)
//
// ASOSIY TALAB: javob yo'q/buzuq/maydonlari yetishmasa — BO'SH ro'yxat va nol
// hisoblagichlar, ya'ni ilova modul obunalarisiz (bugungidek) ishlaydi.
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/l10n.dart';
// Ekran qatlamidagi modul xaritalarining QAMROVINI tekshirish uchun (testda
// ekranni import qilish normal): kalit yetishmasa paywall boshqa modulning
// sarlavhasi/foydalari bilan ochilardi.
import 'package:trust_mobile/screens/home_hub.dart' show kModChipMaxLimit;
import 'package:trust_mobile/screens/paywall_sheet.dart';
import 'package:trust_mobile/store.dart';

// Backend kontrakti (2026-08-04, migration 020) bo'yicha to'liq javob.
Map<String, dynamic> fullBody() => {
      'success': true,
      'legacy_premium': {'active': false, 'until': null},
      'modules': [
        {
          'module': 'xarajat', 'active': false, 'active_until': null, 'soon': false,
          'price_usd': 5, 'product_id': 'trust_xarajat_monthly', 'used': 3, 'free_limit': 5,
        },
        {
          'module': 'qarz', 'active': true, 'active_until': '2026-09-04T00:00:00Z', 'soon': false,
          'price_usd': 8, 'product_id': 'trust_qarz_monthly', 'used': 12, 'free_limit': 5,
        },
        {
          'module': 'ijarachi', 'active': false, 'active_until': null, 'soon': true,
          'price_usd': 13, 'product_id': 'trust_ijarachi_monthly', 'used': 0, 'free_limit': 0,
        },
        {
          'module': 'toyxona', 'active': false, 'active_until': null, 'soon': true,
          'price_usd': 24, 'product_id': 'trust_toyxona_monthly', 'used': 0, 'free_limit': 0,
        },
      ],
    };

void main() {
  group('mapSubsModules (to\'liq javob)', () {
    test('4 modul, kelishilgan tartibda', () {
      final m = mapSubsModules(fullBody());
      expect(m.map((e) => e['module']).toList(), ['xarajat', 'qarz', 'ijarachi', 'toyxona']);
    });

    test('maydonlar UI kontraktiga mos ko\'chadi (limit=free_limit, price=price_usd)', () {
      final x = mapSubsModules(fullBody()).first;
      expect(x['module'], 'xarajat');
      expect(x['active'], isFalse);
      expect(x['soon'], isFalse);
      expect(x['used'], 3);
      expect(x['limit'], 5);
      expect(x['price'], 5);
      expect(x['product'], 'trust_xarajat_monthly');
    });

    test('faol modul: active + active_until', () {
      final q = mapSubsModules(fullBody())[1];
      expect(q['active'], isTrue);
      expect(q['until'], '2026-09-04T00:00:00Z');
      expect(q['used'], 12);
    });

    test('"tez orada" modullarda hisoblagich YO\'Q (0/0)', () {
      final m = mapSubsModules(fullBody());
      for (final e in m.where((e) => e['soon'] == true)) {
        expect(e['used'], 0);
        expect(e['limit'], 0);
      }
      expect(m[2]['price'], 13); // ijarachi
      expect(m[3]['price'], 24); // toyxona
    });

    test('server tartibi teskari bo\'lsa ham UI tartibi barqaror', () {
      final body = fullBody();
      body['modules'] = (body['modules'] as List).reversed.toList();
      expect(mapSubsModules(body).map((e) => e['module']).toList(),
          ['xarajat', 'qarz', 'ijarachi', 'toyxona']);
    });

    test('notanish modul yiqitmaydi — oxiriga tushadi', () {
      final body = fullBody();
      (body['modules'] as List).insert(0, {'module': 'yangi', 'active': false});
      final m = mapSubsModules(body);
      expect(m.length, 5);
      expect(m.last['module'], 'yangi');
    });
  });

  group('mapSubsModules (himoya: buzuq/kam javob)', () {
    test('endpoint yo\'q / boshqa shakl -> bo\'sh ro\'yxat', () {
      expect(mapSubsModules(null), isEmpty);
      expect(mapSubsModules(<String, dynamic>{}), isEmpty);
      expect(mapSubsModules('404 not found'), isEmpty);
      expect(mapSubsModules({'success': true}), isEmpty);
      expect(mapSubsModules({'modules': 'nope'}), isEmpty);
      expect(mapSubsModules({'modules': []}), isEmpty);
    });

    test('qator Map emas yoki modulsiz -> tashlab ketiladi', () {
      final m = mapSubsModules({
        'modules': ['xarajat', null, 42, {'active': true}, {'module': '  '}, {'module': 'qarz'}],
      });
      expect(m.length, 1);
      expect(m.first['module'], 'qarz');
    });

    test('maydonlar yo\'q -> nol/false, narx lokal standartdan', () {
      final m = mapSubsModules({
        'modules': [{'module': 'xarajat'}],
      }).first;
      expect(m['active'], isFalse);
      expect(m['soon'], isFalse);
      expect(m['used'], 0);
      expect(m['limit'], 0);
      expect(m['price'], 5); // kSubModuleDefaults
      expect(m['product'], 'trust_xarajat_monthly'); // ID yo'q -> yasaladi
      expect(m['until'], isNull);
    });

    // PO 2026-08-04: ijarachi/toyxona OCHILDI — lokal standart endi soon:false,
    // ya'ni server bayroqni yubormasa ham hisoblagich TO'LIQ o'tadi.
    test('soon maydoni yo\'q -> lokal standart (barcha modullar ochiq)', () {
      final m = mapSubsModules({
        'modules': [
          {'module': 'ijarachi', 'used': 7, 'free_limit': 3},
          {'module': 'toyxona'},
        ],
      });
      expect(m[0]['soon'], isFalse);
      expect(m[0]['used'], 7); // soon emas -> hisoblagich ko'chadi
      expect(m[0]['limit'], 3);
      expect(m[1]['soon'], isFalse);
      expect(m[1]['price'], 24);
    });

    // Mantiq O'ZI joyida qoladi: kelgusida yangi modul "tez orada" bo'lishi
    // mumkin — server bayroq yuborsa UI unga bo'ysunadi.
    test('server soon:true yuborsa — hisoblagich yopiladi', () {
      final m = mapSubsModules({
        'modules': [
          {'module': 'toyxona', 'soon': true, 'used': 4, 'free_limit': 5},
        ],
      }).first;
      expect(m['soon'], isTrue);
      expect(m['used'], 0);
      expect(m['limit'], 0);
    });

    test('raqamlar satr/double/null bo\'lsa ham int', () {
      final m = mapSubsModules({
        'modules': [
          {'module': 'qarz', 'used': '4', 'free_limit': 5.0, 'price_usd': '8'},
        ],
      }).first;
      expect(m['used'], 4);
      expect(m['limit'], 5);
      expect(m['price'], 8);
    });

    test('axlat raqam -> 0 (crash emas)', () {
      final m = mapSubsModules({
        'modules': [{'module': 'qarz', 'used': 'ko\'p', 'free_limit': null}],
      }).first;
      expect(m['used'], 0);
      expect(m['limit'], 0);
    });
  });

  group('subsLegacyActive', () {
    test('faol premium', () {
      expect(subsLegacyActive({'legacy_premium': {'active': true, 'until': '2026-12-01'}}), isTrue);
    });
    test('faol emas / yo\'q / buzuq -> false', () {
      expect(subsLegacyActive({'legacy_premium': {'active': false}}), isFalse);
      expect(subsLegacyActive({'legacy_premium': null}), isFalse);
      expect(subsLegacyActive({'legacy_premium': 'yes'}), isFalse);
      expect(subsLegacyActive(<String, dynamic>{}), isFalse);
      expect(subsLegacyActive(null), isFalse);
    });
  });

  group('subsPaywallEntry', () {
    test('server qatoridan olinadi', () {
      final mods = mapSubsModules(fullBody());
      final pw = subsPaywallEntry('xarajat', mods);
      expect(pw['module'], 'xarajat');
      expect(pw['price'], 5);
      expect(pw['soon'], isFalse);
      expect(pw['used'], 3);
      expect(pw['limit'], 5);
      expect(pw['product'], 'trust_xarajat_monthly');
    });

    test('server ro\'yxatida yo\'q -> lokal standartdan yasaladi', () {
      final pw = subsPaywallEntry('toyxona', const []);
      expect(pw['price'], 24);
      expect(pw['soon'], isFalse); // modul ochiq — paywall'da haqiqiy CTA
      expect(pw['used'], 0);
      expect(pw['limit'], 0);
      expect(pw['product'], 'trust_toyxona_monthly');
    });

    test('butunlay notanish modul -> nol narx, crash yo\'q', () {
      final pw = subsPaywallEntry('yangi', const []);
      expect(pw['module'], 'yangi');
      expect(pw['price'], 0);
      expect(pw['soon'], isFalse);
    });
  });

  group('subModuleThanksText (xarid tasdig\'i toasti)', () {
    test('modul nomi joriy tilda qo\'yiladi', () {
      final txt = subModuleThanksText(lUz, 'xarajat');
      expect(txt, contains('Xarajatlar')); // uz: 'modXarajat'
      expect(txt, isNot(contains('{module}'))); // placeholder to'ldirilgan
      expect(subModuleThanksText(lUz, 'toyxona'), contains('To\'yxona'));
    });

    test('barcha tillarda kalitlar bor va placeholder to\'ladi', () {
      for (final entry in kLangs.entries) {
        final l = entry.value;
        for (final m in kSubModuleOrder) {
          final txt = subModuleThanksText(l, m);
          expect(txt, isNot(contains('{module}')), reason: '${entry.key}/$m');
          expect(txt, isNot('subModuleThanks'), reason: '${entry.key}: kalit yo\'q');
        }
        expect(l['pwPayComingSoon'], isA<String>(), reason: '${entry.key}: pwPayComingSoon yo\'q');
      }
    });

    test('notanish modul — crash yo\'q, kod nomi bilan chiqadi', () {
      final txt = subModuleThanksText(lUz, 'yangi');
      expect(txt, contains('yangi'));
      expect(txt, isNot(contains('{module}')));
    });

    test('kalitlar yo\'q bo\'lsa ham yiqilmaydi', () {
      expect(subModuleThanksText(const {}, 'xarajat'), 'subModuleThanks');
    });

    test('kSubModuleNameKey qamrovi kSubModuleDefaults bilan bir xil', () {
      expect(kSubModuleNameKey.keys.toSet(), kSubModuleDefaults.keys.toSet());
    });
  });

  // 2026-08-04 review, FINDING 13: paywall_sheet.dart'da YANA UCHTA modul
  // xaritasi bor. Modul birortasidan tushib qolsa sheet zaxira kalitga tushib,
  // BOSHQA modulning sarlavhasi/foydalarini ko'rsatadi (narx esa to'g'ri) —
  // foydalanuvchi "Xarajatlar" sarlavhasi ostida qarz obunasini sotib oladi.
  group('paywall_sheet modul xaritalari (qamrov)', () {
    final want = kSubModuleDefaults.keys.toSet();

    test('kModNameKey — barcha modullar', () {
      expect(kModNameKey.keys.toSet(), want);
    });

    test('kModTitleKey — barcha modullar', () {
      expect(kModTitleKey.keys.toSet(), want);
    });

    test('kModBenefitKeys — barcha modullar, har birida 4 qator', () {
      expect(kModBenefitKeys.keys.toSet(), want);
      kModBenefitKeys.forEach((m, keys) {
        expect(keys.length, 4, reason: '$m: foyda qatorlari 4 ta bo\'lishi kerak');
      });
    });

    test('barcha kalitlar HAR TILDA mavjud (bo\'sh matn chiqmasin)', () {
      for (final entry in kLangs.entries) {
        final l = entry.value;
        for (final m in want) {
          for (final k in [kModNameKey[m]!, kModTitleKey[m]!, ...kModBenefitKeys[m]!]) {
            expect(l[k], isA<String>(), reason: '${entry.key}: $k yo\'q ($m)');
            expect('${l[k]}'.trim(), isNotEmpty, reason: '${entry.key}: $k bo\'sh ($m)');
          }
        }
      }
    });
  });

  // 2026-08-04 review, FINDING 5: hisoblagich serverning HAQIQIY qaroriga mos
  // bo'lishi shart — mapping limitni O'YLAB TOPMAYDI va KESMAYDI. Prod'da
  // free_limit=300 (render.yaml, ataylab) — u ham o'zgarishsiz o'tadi, chipni
  // ko'rsatmaslik qarori UI qatlamida (kSubLimitDisplayMax).
  group('free_limit — o\'zgarishsiz o\'tadi (klamp yo\'q)', () {
    test('300 (prod qiymati) aynan 300 bo\'lib qoladi', () {
      final m = mapSubsModules({
        'modules': [
          {'module': 'xarajat', 'used': 7, 'free_limit': 300},
          {'module': 'qarz', 'used': 0, 'free_limit': 300},
        ],
      });
      expect(m[0]['limit'], 300);
      expect(m[0]['used'], 7);
      expect(m[1]['limit'], 300);
    });

    test('paywall yozuvi ham o\'sha qiymatni ko\'chiradi', () {
      final mods = mapSubsModules({
        'modules': [{'module': 'xarajat', 'used': 7, 'free_limit': 300}],
      });
      final pw = subsPaywallEntry('xarajat', mods);
      expect(pw['limit'], 300);
      expect(pw['used'], 7);
    });

    test('kSubLimitDisplayMax — UI shifti prod qiymatidan past, real tarifdan yuqori', () {
      expect(kSubLimitDisplayMax, lessThan(300)); // "7/300" chizilmaydi
      expect(kSubLimitDisplayMax, greaterThan(5)); // haqiqiy bepul limit ko'rinadi
    });

    test('hub chip shifti store shifti bilan BIR XIL (ikkita mustaqil qiymat bo\'lmasin)', () {
      expect(kModChipMaxLimit, kSubLimitDisplayMax);
    });

    test('yangi server javobi paywall raqamlarini yangilaydi (snapshot emas)', () {
      // refreshSubs_ ochiq paywall'ni AYNAN shu funksiya bilan qayta hisoblaydi.
      final before = subsPaywallEntry('xarajat', mapSubsModules({
        'modules': [{'module': 'xarajat', 'used': 0, 'free_limit': 5}],
      }));
      final after = subsPaywallEntry('xarajat', mapSubsModules({
        'modules': [{'module': 'xarajat', 'used': 5, 'free_limit': 5}],
      }));
      expect(before['used'], 0);
      expect(after['used'], 5);
      expect(after['limit'], 5);
    });
  });

  group('kSubModuleDefaults (kontrakt narxlari)', () {
    test('xarajat 5, qarz 8, ijarachi 13, toyxona 24', () {
      expect(kSubModuleDefaults['xarajat']!['price'], 5);
      expect(kSubModuleDefaults['qarz']!['price'], 8);
      expect(kSubModuleDefaults['ijarachi']!['price'], 13);
      expect(kSubModuleDefaults['toyxona']!['price'], 24);
    });

    // PO 2026-08-04: To'yxona va Ijaradagi uylar QURILDI — hub'da oddiy menyu,
    // paywall'da haqiqiy CTA. Backend katalogi (src/lib/subscription.js MODULES)
    // ham `soon` bayrog'ini tashladi; bu ikki manba sinxron qolishi SHART.
    test('HECH BIR modul "tez orada" emas — hammasi ochiq', () {
      for (final e in kSubModuleDefaults.entries) {
        expect(e.value['soon'], isFalse, reason: '${e.key}: soon:true qolib ketgan');
      }
    });
  });

  // Obyekt chegarasi siyosati (PO 2026-08-04): «bitta obuna — 5 uy / 1 to'yxona,
  // ko'proq kerak bo'lsa boshqa raqamga alohida hisob». Bu javob g'ayrioddiy,
  // shuning uchun paywall'da AYTILISHI shart va HAR TILDA bo'lishi kerak.
  group('modul obyekt chegarasi (paywall izohi)', () {
    test('chegara faqat obyektli modullarda (xarajat/qarz — yo\'q)', () {
      expect(kModCapUnits.keys.toSet(), {'ijarachi', 'toyxona'});
      expect(kModCapKey.keys.toSet(), kModCapUnits.keys.toSet());
      // Backend: MODULES.ijarachi.max_units=5, MODULES.toyxona.max_units=1
      expect(kModCapUnits['ijarachi'], 5);
      expect(kModCapUnits['toyxona'], 1);
    });

    test('izoh har tilda bor, bo\'sh emas va NARX ko\'rsatmaydi', () {
      for (final entry in kLangs.entries) {
        for (final k in kModCapKey.values) {
          final s = entry.value[k];
          expect(s, isA<String>(), reason: '${entry.key}: $k yo\'q');
          expect('$s'.trim(), isNotEmpty, reason: '${entry.key}: $k bo\'sh');
          expect('$s', isNot(contains('\$')), reason: '${entry.key}: $k narx yozgan');
        }
      }
    });

    test('{n} o\'rin egasi to\'ladi (uy soni qotirilmagan)', () {
      for (final entry in kLangs.entries) {
        expect('${entry.value['pwCapIjara']}', contains('{n}'), reason: entry.key);
      }
      // To'yxona chegarasi 1 — matnda son emas, SO'Z bilan («bitta to'yxona»),
      // shuning uchun {n} talab qilinmaydi.
      //
      // DIQQAT: bu yerda modStrF() CHAQIRILMAYDI — u store.L() ga tegadi,
      // store esa AudioPlayer yaratadi va sof (widget bo'lmagan) testda
      // MissingPluginException beradi. Almashtirish mantiqi bir xil.
      final s = '${lUz['pwCapIjara']}'.replaceAll('{n}', '${kModCapUnits['ijarachi']}');
      expect(s, isNot(contains('{n}')));
      expect(s, contains('5'));
    });
  });
}
