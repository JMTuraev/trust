// Ijara moduli — ma'lumot qatlamining SOF funksiyalari (ijara_data.dart):
//   ijParseHouses / ijParseCharges — server javobini ajratish
//   ijChargeState / ijSumCharges   — holat va davr yakunlari
//   ijFx / ijMoney / ijParseYmd    — format va sana
// Va ijara_l10n.dart lug'atlarining QAMROVI (6 til, bir xil kalitlar).
//
// ASOSIY TALAB (backend parallel qurilmoqda): javob yo'q/buzuq/maydonlari
// yetishmasa — BO'SH ro'yxat va nol hisoblagichlar, hech qanday exception.
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/ijara_data.dart';
import 'package:trust_mobile/ijara_l10n.dart';
import 'package:trust_mobile/store.dart';

/// Backend kontrakti bo'yicha to'liq /houses javobi.
List<Map<String, dynamic>> housesBody() => [
      {
        'id': 'h1',
        'name': 'Chilonzor 12-uy',
        'tenant_name': 'Alisher aka',
        'tenant_phone': '+998901234567',
        'rent_amount': 3000000,
        'sort': 0,
        'archived': false,
        'totals': {'charged': 3500000, 'paid': 2000000, 'left': 1500000},
        'overdue_count': 1,
      },
      {
        'id': 'h2',
        'name': 'Yunusobod 4-kv',
        'rent_amount': 2500000,
        'sort': 1,
        'archived': true,
      },
    ];

/// Backend kontrakti bo'yicha to'liq /charges javobi (to'lovlar ALOHIDA massivda).
Map<String, dynamic> chargesBody() => {
      'charges': [
        {
          'id': 'c1',
          'house_id': 'h1',
          'period': '2026-08',
          'kind': 'ijara',
          'title': 'Avgust ijarasi',
          'amount': 3000000,
          'status': 'kutish',
          'due_date': '2026-08-05',
        },
        {
          'id': 'c2',
          'house_id': 'h1',
          'period': '2026-08',
          'kind': 'kommunal',
          'title': 'Svet',
          'amount': 500000,
          'due_date': '2026-08-20',
        },
      ],
      'payments': [
        {'id': 'p1', 'house_id': 'h1', 'charge_id': 'c1', 'amount': 2000000, 'paid_at': '2026-08-03'},
        {'id': 'p2', 'house_id': 'h1', 'amount': 100000, 'paid_at': '2026-08-04', 'note': 'naqd'},
      ],
      'totals': {'count': 2, 'charged': 3500000, 'paid': 2100000, 'left': 1400000},
    };

Charge charge({
  int amount = 1000,
  String status = '',
  String due = '',
  List<Map<String, dynamic>> pays = const [],
  Map<String, dynamic>? totals,
}) =>
    Charge.fromJson({
      'id': 'x',
      'house_id': 'h1',
      'amount': amount,
      'status': status,
      'due_date': due,
      'payments': pays,
      if (totals != null) 'totals': totals,
    });

void main() {
  // ij() lug'at tilini store'dan o'qiydi, store esa (TrustStore ctor) audio
  // pleyerni yaratadi va platforma kanaliga murojaat qiladi. Sof (widget emas)
  // testda binding qo'lda ko'tariladi va kanal soxta ishlovchi bilan yopiladi —
  // aks holda MissingPluginException setUp ichida otiladi.
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ch in const ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }

  // Lug'at tili testlar davomida barqaror bo'lsin (ijMoney 'so'm' qo'shadi).
  setUp(() => store.S['lang'] = 'uz');

  group('ijParseHouses', () {
    test("to'liq javob — maydonlar to'g'ri ko'chadi", () {
      final list = ijParseHouses(housesBody());
      expect(list.length, 2);
      final h = list.first;
      expect(h.id, 'h1');
      expect(h.name, 'Chilonzor 12-uy');
      expect(h.tenantName, 'Alisher aka');
      expect(h.tenantPhone, '+998901234567');
      expect(h.rentAmount, 3000000);
      expect(h.archived, isFalse);
      expect(h.overdueCount, 1);
      expect(h.hasServerTotals, isTrue);
      expect(h.serverTotals.left, 1500000);
    });

    test("{houses:[...]} o'ramasi ham qabul qilinadi", () {
      final list = ijParseHouses({'houses': housesBody()});
      expect(list.map((h) => h.id).toList(), ['h1', 'h2']);
    });

    test('arxivlangan uy ham ajratiladi (filtrlash repo ishi)', () {
      expect(ijParseHouses(housesBody()).last.archived, isTrue);
    });

    test("maydonlar yo'q -> bo'sh satr / nol, crash yo'q", () {
      final h = ijParseHouses([
        {'id': 'h9'}
      ]).first;
      expect(h.name, '');
      expect(h.tenantName, '');
      expect(h.rentAmount, 0);
      expect(h.overdueCount, 0);
      expect(h.hasServerTotals, isFalse);
      expect(h.serverTotals.left, 0);
    });

    test('overdue bool sifatida kelsa ham ishlaydi', () {
      expect(ijParseHouses([
        {'id': 'a', 'overdue': true}
      ]).first.overdueCount, 1);
      expect(ijParseHouses([
        {'id': 'a', 'overdue': false}
      ]).first.overdueCount, 0);
    });

    test("endpoint yo'q / buzuq javob -> bo'sh ro'yxat", () {
      expect(ijParseHouses(null), isEmpty);
      expect(ijParseHouses('404 not found'), isEmpty);
      expect(ijParseHouses(<String, dynamic>{}), isEmpty);
      expect(ijParseHouses({'houses': 'nope'}), isEmpty);
      expect(ijParseHouses([]), isEmpty);
      // id'siz va Map bo'lmagan qatorlar tashlab ketiladi
      expect(ijParseHouses([null, 42, 'uy', {'name': 'id yoq'}]), isEmpty);
    });

    test('raqamlar satr/double bo\'lsa ham int', () {
      final h = ijParseHouses([
        {'id': 'a', 'rent_amount': '2500000', 'sort': 3.0}
      ]).first;
      expect(h.rentAmount, 2500000);
      expect(h.sort, 3);
    });
  });

  group('ijParseCharges', () {
    test("to'liq javob — hisoblar, to'lovlar, yakunlar", () {
      final page = ijParseCharges(chargesBody());
      expect(page.charges.length, 2);
      expect(page.payments.length, 2);
      expect(page.totals!.charged, 3500000);
      expect(page.totals!.left, 1400000);
      expect(page.totals!.count, 2);
    });

    test("alohida massivdagi to'lovlar hisobga charge_id bo'yicha biriktiriladi", () {
      final page = ijParseCharges(chargesBody());
      final c1 = page.charges.firstWhere((c) => c.id == 'c1');
      final c2 = page.charges.firstWhere((c) => c.id == 'c2');
      expect(c1.paid, 2000000);
      expect(c1.left, 1000000); // QISMAN to'lov ko'rinadi
      // Umumiy to'lov (charge_id yo'q) hech qaysi hisobga yopishmaydi
      expect(c2.paid, 0);
      expect(c2.left, 500000);
    });

    test('faqat ro\'yxat kelsa ham ishlaydi', () {
      final page = ijParseCharges(chargesBody()['charges']);
      expect(page.charges.length, 2);
      expect(page.payments, isEmpty);
      expect(page.totals, isNull);
    });

    test("hisob ichidagi to'lovlar IKKI MARTA sanalmaydi", () {
      final page = ijParseCharges({
        'charges': [
          {
            'id': 'c1',
            'house_id': 'h1',
            'amount': 1000,
            'payments': [
              {'id': 'p1', 'charge_id': 'c1', 'amount': 400}
            ],
          }
        ],
        'payments': [
          {'id': 'p1', 'house_id': 'h1', 'charge_id': 'c1', 'amount': 400}
        ],
      });
      expect(page.charges.first.paid, 400);
      expect(page.payments.length, 1);
    });

    test("hisob ichidagi to'lov uyni hisobdan meros oladi", () {
      final page = ijParseCharges({
        'charges': [
          {
            'id': 'c1',
            'house_id': 'h7',
            'amount': 1000,
            'payments': [
              {'id': 'p9', 'amount': 250}
            ],
          }
        ],
      });
      expect(page.payments.single.houseId, 'h7');
    });

    test('notanish kind -> boshqa (chip baribir chiziladi)', () {
      final c = ijParseCharges([
        {'id': 'c', 'kind': 'garaj', 'amount': 1}
      ]).charges.first;
      expect(c.kind, 'boshqa');
    });

    test("endpoint yo'q / buzuq javob -> bo'sh sahifa", () {
      for (final bad in [null, '404 not found', <String, dynamic>{}, {'charges': 'nope'}, []]) {
        final page = ijParseCharges(bad);
        expect(page.charges, isEmpty);
        expect(page.payments, isEmpty);
        expect(page.totals, isNull);
      }
    });
  });

  // src/routes/ijara.js HAQIQIY javobi: to'lovlar `unallocated`, yakunlar
  // `totals` — ikkalasi ham `data` NING YONIDA. _req faqat `data`ni beradi.
  group('ijChargesPayload (haqiqiy backend shakli)', () {
    test("data + unallocated + totals bitta sahifaga yig'iladi", () {
      final body = {
        'success': true,
        'data': [
          {'id': 'c1', 'house_id': 'h1', 'amount': 1000, 'payments': [
            {'id': 'p1', 'charge_id': 'c1', 'amount': 400}
          ]}
        ],
        'unallocated': [
          {'id': 'p2', 'house_id': 'h1', 'amount': 250, 'paid_at': '2026-08-04'}
        ],
        'totals': {'count': 1, 'charged': 1000, 'paid': 650, 'left': 350},
      };
      final page = ijParseCharges(ijChargesPayload(body['data'], body));
      expect(page.charges.length, 1);
      expect(page.charges.first.paid, 400); // faqat BOG'LANGAN to'lov
      expect(page.charges.first.left, 600);
      // Bog'lanmagan to'lov ham ro'yxatda (uy balansiga kiradi)
      expect(page.payments.map((p) => p.id).toSet(), {'p1', 'p2'});
      expect(page.totals!.paid, 650);
      expect(page.totals!.left, 350);
    });

    test('qo\'shimcha maydonlarsiz javob — data o\'zgarishsiz o\'tadi', () {
      final data = [
        {'id': 'c1', 'amount': 5}
      ];
      expect(ijChargesPayload(data, {'success': true}), same(data));
      expect(ijParseCharges(ijChargesPayload(data, {'success': true})).charges.length, 1);
    });

    test("bekor qilingan hisob: server totals NOL, amount xom bo'lib qoladi", () {
      // ijara.js chargeTotals(): status 'bekor' -> {charged:0, paid:0, left:0}
      final c = ijParseCharges([
        {'id': 'c', 'amount': 900000, 'status': 'bekor', 'totals': {'paid': 0, 'left': 0}}
      ]).charges.first;
      expect(c.amount, 900000); // ro'yxatda ko'rinadi
      expect(c.left, 0);
      expect(ijChargeState(c), 'bekor'); // "tolangan" DEB ko'rsatilmaydi
      expect(ijSumCharges([c]).charged, 0); // yakunga kirmaydi
    });

    test("server statuslari ('kutilmoqda'/'tolangan') UI holatiga tushadi", () {
      final today = DateTime(2026, 8, 10);
      final open = ijParseCharges([
        {'id': 'a', 'amount': 1000, 'status': 'kutilmoqda', 'due_date': '2026-08-20', 'totals': {'paid': 0, 'left': 1000}}
      ]).charges.first;
      final done = ijParseCharges([
        {'id': 'b', 'amount': 1000, 'status': 'tolangan', 'totals': {'paid': 1000, 'left': 0}}
      ]).charges.first;
      expect(ijChargeState(open, today: today), 'kutish');
      expect(ijChargeState(done, today: today), 'tolangan');
    });
  });

  group('Charge — qisman/ortiqcha to\'lov', () {
    test("server totals USTUVOR (to'lovlar ro'yxatidan emas)", () {
      final c = charge(amount: 1000, totals: {'paid': 700, 'left': 300}, pays: [
        {'id': 'p', 'amount': 999999}
      ]);
      expect(c.paid, 700);
      expect(c.left, 300);
    });

    test("totals yo'q -> bog'langan to'lovlardan hisoblanadi", () {
      final c = charge(amount: 1000, pays: [
        {'id': 'p1', 'amount': 300},
        {'id': 'p2', 'amount': 200},
      ]);
      expect(c.paid, 500);
      expect(c.left, 500);
    });

    test('ortiqcha to\'lov -> left MANFIY (clamp yo\'q)', () {
      final c = charge(amount: 1000, pays: [
        {'id': 'p', 'amount': 1200}
      ]);
      expect(c.left, -200);
      expect(ijMoney(c.left), startsWith('−'));
    });

    test('bekor qilingan hisob', () {
      expect(charge(status: 'bekor').cancelled, isTrue);
      expect(charge(status: 'kutish').cancelled, isFalse);
    });
  });

  group('ijChargeState (tartib qoidalari)', () {
    final today = DateTime(2026, 8, 10);

    test("bekor — muddati o'tgan bo'lsa ham 'bekor'", () {
      expect(ijChargeState(charge(status: 'bekor', due: '2026-08-01'), today: today), 'bekor');
    });

    test("to'liq to'langan -> tolangan (muddat o'tgan bo'lsa ham)", () {
      final c = charge(amount: 1000, due: '2026-08-01', pays: [
        {'id': 'p', 'amount': 1000}
      ]);
      expect(ijChargeState(c, today: today), 'tolangan');
    });

    test("muddati o'tgan qisman to'lov -> kechikkan (qismandan USTUN)", () {
      final c = charge(amount: 1000, due: '2026-08-01', pays: [
        {'id': 'p', 'amount': 400}
      ]);
      expect(ijChargeState(c, today: today), 'kechikkan');
    });

    test("muddati kelmagan qisman to'lov -> qisman", () {
      final c = charge(amount: 1000, due: '2026-08-20', pays: [
        {'id': 'p', 'amount': 400}
      ]);
      expect(ijChargeState(c, today: today), 'qisman');
    });

    test("to'lovsiz, muddati bor -> kutish", () {
      expect(ijChargeState(charge(amount: 1000, due: '2026-08-20'), today: today), 'kutish');
    });

    test("muddat yo'q -> hech qachon kechikkan emas", () {
      expect(ijChargeState(charge(amount: 1000), today: today), 'kutish');
    });

    test("muddat AYNAN bugun -> hali kechikkan emas", () {
      expect(ijChargeState(charge(amount: 1000, due: '2026-08-10'), today: today), 'kutish');
    });

    test('barcha holatlar kIjaraStates ichida va yorlig\'i bor', () {
      for (final s in kIjaraStates) {
        expect(ijState(s), isNotEmpty);
        expect(ijState(s), isNot(startsWith('st')));
      }
    });
  });

  group('ijSumCharges', () {
    test('bekor qilinganlar SANALMAYDI', () {
      final t = ijSumCharges([
        charge(amount: 1000, pays: [
          {'id': 'a', 'amount': 400}
        ]),
        charge(amount: 5000, status: 'bekor'),
      ]);
      expect(t.charged, 1000);
      expect(t.paid, 400);
      expect(t.left, 600);
    });

    test("bo'sh ro'yxat -> nollar", () {
      final t = ijSumCharges(const []);
      expect(t.charged, 0);
      expect(t.paid, 0);
      expect(t.left, 0);
    });
  });

  group('IjaraSummary', () {
    test('left yuborilmasa hisoblab olinadi', () {
      final s = IjaraSummary.fromJson({'count': 3, 'charged': 1000, 'paid': 250});
      expect(s.left, 750);
    });

    test('byStatus ajratiladi, buzuq javob nol beradi', () {
      final s = IjaraSummary.fromJson({
        'byStatus': {'kutish': 2, 'bekor': '1'}
      });
      expect(s.byStatus['kutish'], 2);
      expect(s.byStatus['bekor'], 1);
      expect(s.charged, 0);
      expect(IjaraSummary.fromJson(<String, dynamic>{}).left, 0);
    });
  });

  group('format va sana', () {
    test('ijFx — minglik ajratgich', () {
      expect(ijFx(0), '0');
      expect(ijFx(999), '999');
      expect(ijFx(1234567), '1 234 567');
      expect(ijFx(-1500), '1 500'); // ishora ijMoney'da
    });

    test("ijMoney — valyuta yorlig'i va manfiy ishora", () {
      expect(ijMoney(1500), "1 500 so'm");
      expect(ijMoney(-1500), "−1 500 so'm");
    });

    test('ijParseYmd — timezone siljishi YO\'Q', () {
      final d = ijParseYmd('2026-08-04');
      expect(d, isNotNull);
      expect([d!.year, d.month, d.day], [2026, 8, 4]);
      // To'liq ISO (Z bilan) ham AYNAN o'sha kun bo'lib qoladi
      final iso = ijParseYmd('2026-08-04T00:00:00.000Z');
      expect([iso!.year, iso.month, iso.day], [2026, 8, 4]);
    });

    test("ijParseYmd — buzuq sana null (crash emas)", () {
      expect(ijParseYmd(''), isNull);
      expect(ijParseYmd('2026-08'), isNull);
      expect(ijParseYmd('kecha'), isNull);
      expect(ijParseYmd('yyyy-mm-dd'), isNull);
    });

    test('ijYmd / ijPeriod', () {
      expect(ijYmd(DateTime(2026, 8, 4)), '2026-08-04');
      expect(ijPeriod(DateTime(2026, 8, 4)), '2026-08');
      expect(ijPeriod(DateTime(2026, 12, 31)), '2026-12');
    });

    test('oy chegaralari (kabisa yili ham)', () {
      expect(ijMonthStart(DateTime(2026, 8, 15)), DateTime(2026, 8, 1));
      expect(ijMonthEnd(DateTime(2026, 8, 15)).day, 31);
      expect(ijMonthEnd(DateTime(2026, 2, 3)).day, 28);
      expect(ijMonthEnd(DateTime(2028, 2, 3)).day, 29);
    });
  });

  group('ijara_l10n — 6 til qamrovi', () {
    final en = kIjaraLangs['en']!;
    final tokenRe = RegExp(r'\{(\w+)\}');

    test('6 til bor', () {
      expect(kIjaraLangs.keys.toSet(), {'uz', 'ru', 'en', 'es', 'fr', 'zh'});
    });

    test('har tilda AYNAN bir xil kalitlar (bo\'sh matn chiqmasin)', () {
      for (final e in kIjaraLangs.entries) {
        expect(e.value.keys.toSet(), en.keys.toSet(), reason: '${e.key}: kalitlar farq qiladi');
        for (final k in en.keys) {
          expect('${e.value[k]}'.trim(), isNotEmpty, reason: '${e.key}: $k bo\'sh');
        }
      }
    });

    test('{token}\'lar har tilda saqlangan', () {
      for (final e in kIjaraLangs.entries) {
        for (final k in en.keys) {
          final want = tokenRe.allMatches(en[k]!).map((m) => m[1]).toSet();
          final got = tokenRe.allMatches(e.value[k]!).map((m) => m[1]).toSet();
          expect(got, want, reason: '${e.key}: $k tokenlari mos emas');
        }
      }
    });

    test('ij() joriy tilda ishlaydi va {token} to\'ladi', () {
      store.S['lang'] = 'uz';
      expect(ij('title'), 'Ijaradagi uylar');
      final s = ij('capBody', {'n': '$kIjaraMaxHouses'});
      expect(s, contains('5'));
      expect(s, isNot(contains('{n}')));
      store.S['lang'] = 'ru';
      expect(ij('title'), isNot('Ijaradagi uylar'));
    });

    test('notanish til -> en zaxira, notanish kalit -> kalitning o\'zi', () {
      store.S['lang'] = 'de';
      expect(ij('title'), kIjaraLangs['en']!['title']);
      expect(ij('yoqKalit'), 'yoqKalit');
    });

    test('ijKind / ijMonth — barcha qiymatlar yorliqli', () {
      store.S['lang'] = 'uz';
      for (final k in kIjaraKinds) {
        expect(ijKind(k), isNotEmpty);
      }
      expect(ijKind('garaj'), ij('kindBoshqa')); // notanish -> boshqa
      for (var m = 1; m <= 12; m++) {
        expect(ijMonth(m), isNotEmpty);
        expect(ijMonth(m), isNot(startsWith('mon')));
      }
      // clamp: chegaradan tashqari oy raqami yiqitmaydi
      expect(ijMonth(0), ijMonth(1));
      expect(ijMonth(13), ijMonth(12));
    });
  });

  group('kontrakt konstantalari', () {
    test('uylar chegarasi 5 (PO qarori)', () {
      expect(kIjaraMaxHouses, 5);
    });

    test('hisob turlari backend bilan bir xil', () {
      expect(kIjaraKinds, ['ijara', 'kommunal', 'boshqa']);
    });
  });
}
