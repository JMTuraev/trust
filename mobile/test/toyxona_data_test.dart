// To'yxona moduli — ma'lumot qatlamining SOF funksiyalari (toyxona_data.dart):
//   Booking.tryParse / toyParseBookings — server javobini HIMOYALI ajratish
//   toyLocalSummary                     — oy yakuni (backend foldSummary qoidasi)
//   ToySeq                              — so'rov-nomer (eskirgan javob tashlanadi)
//   toyMatches / toyMergeSearch         — qidiruv mosligi va birlashtirish
//   toySlotTakenBy                      — formadagi slot bandligi
//   toyFx / toyMoney / toyParseYmd      — format va sana
// Va toyxona_l10n.dart lug'atlarining QAMROVI (6 til, bir xil kalitlar) +
// 'title' == l10n.dart 'modToyxona' qulfi (ijara FINDING 8 bilan bir qoida).
//
// ASOSIY TALAB (2026-08-10 yangilanishi): javob buzuq/maydonlari yetishmasa —
// qator TASHLAB KETILADI yoki nol, hech qachon exception ham, DateTime.now()
// bilan soxta "bugungi bron" ham YO'Q (eski xato: buzuq sana bugunga tushardi,
// buzuq bola element esa butun oyni abadiy skeletda qoldirardi).
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/l10n.dart';
import 'package:trust_mobile/store.dart';
import 'package:trust_mobile/toyxona_data.dart';
import 'package:trust_mobile/toyxona_l10n.dart';

/// Backend kontrakti bo'yicha TO'LIQ bitta band javobi (GET /bookings elementi).
Map<String, dynamic> bookingBody() => {
      'id': 'b1',
      'hall_id': 'h1',
      'hall_name': "Navro'z",
      'menu_id': 'm1',
      'menu_title': 'Lyuks',
      'event_date': '2026-09-12',
      'slot': 'kechki',
      'client_name': 'Alisher aka',
      'client_phone': '+998 90 123 45 67',
      'guests': 300,
      'price_per_guest': 200000,
      'note': 'gul bezagi kerak',
      'status': 'tasdiq',
      'items': [
        {'id': 'i1', 'title': 'Musiqa', 'amount': 3000000, 'qty': 1},
        {'id': 'i2', 'title': 'Salyut', 'amount': 500000, 'qty': 3},
      ],
      'payments': [
        {'id': 'p1', 'amount': 20000000, 'kind': 'avans', 'paid_at': '2026-08-01'},
      ],
      'totals': {
        'food': 60000000,
        'extras': 4500000,
        'total': 64500000,
        'paid': 20000000,
        'left': 44500000,
      },
    };

/// Qisqa band quruvchi (yakun/qidiruv/slot testlari uchun).
Booking bk({
  String id = 'x',
  String? hallId,
  String hallName = '',
  String date = '2026-09-12',
  String slot = 'kechki',
  String name = 'Mijoz',
  String phone = '',
  String note = '',
  String status = 'band',
  int guests = 100,
  int price = 100000,
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> pays = const [],
}) =>
    Booking.tryParse({
      'id': id,
      if (hallId != null) 'hall_id': hallId,
      'hall_name': hallName,
      'event_date': date,
      'slot': slot,
      'client_name': name,
      'client_phone': phone,
      'note': note,
      'status': status,
      'guests': guests,
      'price_per_guest': price,
      'items': items,
      'payments': pays,
    })!;

void main() {
  // ty() lug'at tilini store'dan o'qiydi, store esa (TrustStore ctor) audio
  // pleyerni yaratadi va platforma kanaliga murojaat qiladi. Sof (widget emas)
  // testda binding qo'lda ko'tariladi va kanal soxta ishlovchi bilan yopiladi —
  // aks holda MissingPluginException setUp ichida otiladi.
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ch in const ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }

  // Lug'at tili testlar davomida barqaror bo'lsin (toyMoney "so'm" qo'shadi).
  setUp(() => store.S['lang'] = 'uz');

  group('format va sana', () {
    test('toyFx — minglik ajratgich', () {
      expect(toyFx(0), '0');
      expect(toyFx(999), '999');
      expect(toyFx(1234567), '1 234 567');
      expect(toyFx(-1500), '1 500'); // ishora toyMoney'da
    });

    test("toyMoney — valyuta yorlig'i va manfiy ishora", () {
      expect(toyMoney(1500), "1 500 so'm");
      expect(toyMoney(-1500), "−1 500 so'm");
    });

    test("toyParseYmd — timezone siljishi YO'Q", () {
      final d = toyParseYmd('2026-08-04');
      expect(d, isNotNull);
      expect([d!.year, d.month, d.day], [2026, 8, 4]);
      // To'liq ISO (Z bilan) ham AYNAN o'sha kun bo'lib qoladi
      final iso = toyParseYmd('2026-08-04T00:00:00.000Z');
      expect([iso!.year, iso.month, iso.day], [2026, 8, 4]);
    });

    test('toyParseYmd — buzuq sana NULL (DateTime.now() zaxirasi EMAS)', () {
      expect(toyParseYmd(''), isNull);
      expect(toyParseYmd('2026-08'), isNull);
      expect(toyParseYmd('kecha'), isNull);
      expect(toyParseYmd('yyyy-mm-dd'), isNull);
    });

    test('toyYmd / oy chegaralari (kabisa yili ham)', () {
      expect(toyYmd(DateTime(2026, 8, 4)), '2026-08-04');
      expect(toyMonthStart(DateTime(2026, 8, 15)), DateTime(2026, 8, 1));
      expect(toyMonthEnd(DateTime(2026, 8, 15)).day, 31);
      expect(toyMonthEnd(DateTime(2026, 2, 3)).day, 28);
      expect(toyMonthEnd(DateTime(2028, 2, 3)).day, 29);
    });
  });

  group('Booking.tryParse — himoyali ajratish', () {
    test("to'liq javob — maydonlar to'g'ri ko'chadi", () {
      final b = Booking.tryParse(bookingBody())!;
      expect(b.id, 'b1');
      expect(b.hallId, 'h1');
      expect(b.hallName, "Navro'z");
      expect(b.menuTitle, 'Lyuks');
      expect([b.eventDate.year, b.eventDate.month, b.eventDate.day], [2026, 9, 12]);
      expect(b.slot, 'kechki');
      expect(b.clientName, 'Alisher aka');
      expect(b.guests, 300);
      expect(b.pricePerGuest, 200000);
      expect(b.status, 'tasdiq');
      expect(b.items.length, 2);
      expect(b.payments.length, 1);
      expect(b.cancelled, isFalse);
      expect(b.priceMissing, isFalse);
    });

    test('server totals USTUVOR (bolalardan qayta hisoblanmaydi)', () {
      final b = Booking.tryParse(bookingBody())!;
      expect(b.food, 60000000);
      expect(b.extras, 4500000);
      expect(b.total, 64500000);
      expect(b.paid, 20000000);
      expect(b.left, 44500000);
    });

    test("totals yo'q -> snapshot va bolalardan hisob; xizmat = amount × qty", () {
      final j = bookingBody()..remove('totals');
      final b = Booking.tryParse(j)!;
      expect(b.food, 300 * 200000);
      // i1: 3 000 000 × 1, i2: 500 000 × 3 (qator jami amount × qty, U3)
      expect(b.items[1].total, 1500000);
      expect(b.extras, 3000000 + 1500000);
      expect(b.total, b.food + b.extras);
      expect(b.paid, 20000000);
      expect(b.left, b.total - b.paid);
    });

    test("ortiqcha to'lov -> left MANFIY (clamp yo'q)", () {
      final b = bk(guests: 1, price: 1000, pays: [
        {'id': 'p', 'amount': 5000}
      ]);
      expect(b.left, -4000);
      expect(toyMoney(b.left), startsWith('−'));
    });

    test('buzuq sana / id yo‘q / Map emas -> NULL (qator tashlab ketiladi)', () {
      expect(Booking.tryParse({...bookingBody(), 'event_date': 'buzuq'}), isNull);
      expect(Booking.tryParse({...bookingBody(), 'event_date': null}), isNull);
      expect(Booking.tryParse(bookingBody()..remove('id')), isNull);
      expect(Booking.tryParse(null), isNull);
      expect(Booking.tryParse('qator emas'), isNull);
      expect(Booking.tryParse(42), isNull);
    });

    test('buzuq BOLA element faqat O‘ZI tushib qoladi (band saqlanadi)', () {
      final j = bookingBody();
      j['items'] = [
        {'id': 'i1', 'title': 'Musiqa', 'amount': 3000000, 'qty': 1},
        null, // Map emas
        'salyut', // Map emas
        {'title': 'idsiz', 'amount': 5}, // id yo'q
      ];
      j['payments'] = [
        42,
        {'id': 'p1', 'amount': 1000000, 'kind': 'avans'},
      ];
      final b = Booking.tryParse(j)!;
      expect(b.items.length, 1);
      expect(b.items.single.title, 'Musiqa');
      expect(b.payments.length, 1);
      expect(b.payments.single.amount, 1000000);
    });

    test("raqamlar satr bo'lsa ham int, notanish maydonlar bo'sh", () {
      final b = Booking.tryParse({
        'id': 7, // satrga aylanadi
        'event_date': '2026-01-05',
        'guests': '250',
        'price_per_guest': '150000',
      })!;
      expect(b.id, '7');
      expect(b.guests, 250);
      expect(b.pricePerGuest, 150000);
      expect(b.clientName, '');
      expect(b.slot, 'kechki'); // zaxira slot
      expect(b.status, 'band');
    });

    test("priceMissing (U5): narx 0 VA xizmat yo'q — avansli bo'lsa ham", () {
      final noPrice = bk(price: 0, pays: [
        {'id': 'p', 'amount': 2000000}
      ]);
      expect(noPrice.priceMissing, isTrue);
      expect(bk(price: 0, items: [
        {'id': 'i', 'title': 'Tort', 'amount': 500000, 'qty': 1}
      ]).priceMissing, isFalse);
      expect(bk(price: 150000).priceMissing, isFalse);
    });
  });

  group('toyParseBookings', () {
    test('buzuq qatorlar tashlab ketiladi, tartib saqlanadi', () {
      final list = toyParseBookings([
        bookingBody(),
        {'id': 'b2', 'event_date': 'buzuq-sana', 'client_name': 'X'}, // tushadi
        null,
        'qator emas',
        {...bookingBody(), 'id': 'b3', 'event_date': '2026-09-13'},
      ]);
      expect(list.map((b) => b.id).toList(), ['b1', 'b3']);
    });

    test("massiv bo'lmagan javob -> bo'sh ro'yxat (crash yo'q)", () {
      expect(toyParseBookings(null), isEmpty);
      expect(toyParseBookings('404 not found'), isEmpty);
      expect(toyParseBookings(<String, dynamic>{}), isEmpty);
      expect(toyParseBookings([]), isEmpty);
    });
  });

  group('toyLocalSummary — backend foldSummary qoidalari (F3 zaxirasi)', () {
    test("bekor puli 'paid'ga KIRMAYDI, cancelledPaid'da ALOHIDA", () {
      final rows = [
        bk(id: 'a', guests: 100, price: 100000, pays: [
          {'id': 'p1', 'amount': 4000000}
        ]),
        bk(id: 'b', status: 'bekor', guests: 200, price: 150000, pays: [
          {'id': 'p2', 'amount': 5000000}
        ]),
      ];
      final s = toyLocalSummary(rows);
      expect(s.count, 2);
      expect(s.countActive, 1);
      expect(s.total, 10000000, reason: "bekor bandning 30 mln'i daromad emas");
      expect(s.paid, 4000000);
      expect(s.left, 6000000);
      expect(s.cancelledPaid, 5000000, reason: 'egada qolgan avans ko‘rinishi shart');
      expect(s.byStatus['band'], 1);
      expect(s.byStatus['bekor'], 1);
    });

    test("bo'sh ro'yxat -> nollar", () {
      final s = toyLocalSummary(const []);
      expect([s.count, s.countActive, s.total, s.paid, s.left, s.cancelledPaid],
          [0, 0, 0, 0, 0, 0]);
    });
  });

  group('ToySummary.fromJson', () {
    test('countActive yubormaydigan eski backend — bekor ayirib hisoblanadi', () {
      final s = ToySummary.fromJson({
        'count': 5,
        'total': 100,
        'byStatus': {'band': 2, 'bekor': 2, 'tasdiq': 1},
      });
      expect(s.countActive, 3);
      expect(ToySummary.fromJson(<String, dynamic>{}).cancelledPaid, 0);
    });
  });

  group("ToySeq — eskirgan javob tashlanadi (F2)", () {
    test('faqat OXIRGI so‘rov joriy', () {
      final seq = ToySeq();
      final t1 = seq.begin();
      expect(seq.isCurrent(t1), isTrue);
      final t2 = seq.begin(); // foydalanuvchi tez boshqa oyga o'tdi
      expect(seq.isCurrent(t1), isFalse, reason: 'sekin kelgan eski javob yozilmasin');
      expect(seq.isCurrent(t2), isTrue);
      expect(seq.current, t2);
      final t3 = seq.begin();
      expect([seq.isCurrent(t1), seq.isCurrent(t2), seq.isCurrent(t3)],
          [false, false, true]);
    });
  });

  group('toyMatches / toyMergeSearch (U7)', () {
    test('ism/izoh/to‘yxona bo‘yicha registrsiz moslik', () {
      final b = bk(name: 'Alisher aka', note: 'Gul bezagi', hallName: "Navro'z");
      expect(toyMatches(b, 'alis'), isTrue);
      expect(toyMatches(b, 'GUL'), isTrue);
      expect(toyMatches(b, "navro"), isTrue);
      expect(toyMatches(b, 'botir'), isFalse);
      expect(toyMatches(b, '  '), isFalse);
    });

    test('telefon — faqat raqamlar solishtiriladi', () {
      final b = bk(phone: '+998 90 123 45 67');
      expect(toyMatches(b, '90 123'), isTrue);
      expect(toyMatches(b, '998901234567'), isTrue);
      expect(toyMatches(b, '9999'), isFalse);
    });

    test('birlashtirish: server avval, id dedup, klient qo‘shimchalari keyin', () {
      final s1 = bk(id: 'a', date: '2026-12-01');
      final s2 = bk(id: 'b', date: '2026-10-01');
      final l1 = bk(id: 'b', date: '2026-10-01'); // serverda ham bor — tushadi
      final l2 = bk(id: 'c', date: '2026-09-01');
      final merged = toyMergeSearch([s1, s2], [l1, l2]);
      expect(merged.map((b) => b.id).toList(), ['a', 'b', 'c']);
    });
  });

  group('toySlotTakenBy (U1)', () {
    final day = [
      bk(id: 'k1', hallId: 'h1', slot: 'kechki', name: 'Alisher'),
      bk(id: 'n1', hallId: 'h2', slot: 'nahor', name: 'Botir'),
      bk(id: 'c1', hallId: 'h1', slot: 'nahor', status: 'bekor', name: 'Bekor qilingan'),
      bk(id: 'z1', slot: 'tushlik', name: "To'yxonasiz"), // hall_id NULL guruhi
    ];

    test('aynan shu to‘yxona + slot bandi topiladi', () {
      expect(toySlotTakenBy(day, hallId: 'h1', slot: 'kechki')?.clientName, 'Alisher');
      // h1'da kechki band, h2'da esa bo'sh (zallar alohida guruh)
      expect(toySlotTakenBy(day, hallId: 'h2', slot: 'kechki'), isNull);
    });

    test("bekor qilingan band slotni USHLAMAYDI", () {
      expect(toySlotTakenBy(day, hallId: 'h1', slot: 'nahor'), isNull);
    });

    test("hall_id NULL — ALOHIDA guruh (backend qoidasi)", () {
      expect(toySlotTakenBy(day, hallId: null, slot: 'tushlik')?.id, 'z1');
      expect(toySlotTakenBy(day, hallId: 'h1', slot: 'tushlik'), isNull);
    });

    test('tahrirda bandning O‘ZI band hisoblanmaydi (exceptId)', () {
      expect(toySlotTakenBy(day, hallId: 'h1', slot: 'kechki', exceptId: 'k1'), isNull);
      expect(toySlotTakenBy(day, hallId: 'h1', slot: 'kechki', exceptId: 'boshqa'), isNotNull);
    });
  });

  group('Hall.fromJson', () {
    test('menus elementma-element — buzuq toifa zallarni yiqitmaydi', () {
      final h = Hall.fromJson({
        'id': 'h1',
        'name': "Navro'z",
        'capacity': '500',
        'menus': [
          {'id': 'm2', 'title': 'Lyuks', 'price_per_guest': 200000, 'sort': 1},
          null,
          'buzuq',
          {'title': 'idsiz'},
          {'id': 'm1', 'title': 'Oddiy', 'price_per_guest': 150000, 'sort': 0},
          {'id': 'm3', 'title': 'Arxiv', 'price_per_guest': 1, 'archived': true},
        ],
      });
      expect(h.capacity, 500);
      expect(h.menus.length, 3);
      // tiers: arxivsiz, sort bo'yicha
      expect(h.tiers.map((m) => m.title).toList(), ['Oddiy', 'Lyuks']);
    });
  });

  group('toyxona_l10n — 6 til qamrovi', () {
    final en = kToyLangs['en']!;
    final tokenRe = RegExp(r'\{(\w+)\}');

    test('6 til bor', () {
      expect(kToyLangs.keys.toSet(), {'uz', 'ru', 'en', 'es', 'fr', 'zh'});
    });

    test("har tilda AYNAN bir xil kalitlar (bo'sh matn chiqmasin)", () {
      for (final e in kToyLangs.entries) {
        expect(e.value.keys.toSet(), en.keys.toSet(), reason: '${e.key}: kalitlar farq qiladi');
        for (final k in en.keys) {
          expect('${e.value[k]}'.trim(), isNotEmpty, reason: '${e.key}: $k bo\'sh');
        }
      }
    });

    test("{token}'lar har tilda saqlangan", () {
      for (final e in kToyLangs.entries) {
        for (final k in en.keys) {
          final want = tokenRe.allMatches(en[k]!).map((m) => m[1]).toSet();
          final got = tokenRe.allMatches(e.value[k]!).map((m) => m[1]).toSet();
          expect(got, want, reason: '${e.key}: $k tokenlari mos emas');
        }
      }
    });

    test('2026-08-10 yangilanishining kalitlari 6 tilda ham bor', () {
      const fresh = [
        'errSubExpired', 'delHasPayments', 'cancelledKept', 'overCapacity',
        'noPriceChip', 'showAll', 'showLess', 'searchPh', 'searchEmpty',
        'searchOffline', 'emptyMonth', 'emptyOnboard', 'needSvcTitle',
        'loadingHint', 'archivedN', 'unarchive', 'payDateLabel',
      ];
      for (final e in kToyLangs.entries) {
        for (final k in fresh) {
          expect('${e.value[k]}'.trim(), isNotEmpty, reason: '${e.key}: $k yo\'q');
        }
      }
    });

    test("ty() joriy tilda ishlaydi va {token} to'ladi", () {
      store.S['lang'] = 'uz';
      expect(ty('title'), "To'yxona");
      final s = ty('guestsN', {'n': '300'});
      expect(s, contains('300'));
      expect(s, isNot(contains('{n}')));
      store.S['lang'] = 'ru';
      expect(ty('title'), isNot("To'yxona"));
    });

    test("notanish til -> en zaxira, notanish kalit -> kalitning o'zi", () {
      store.S['lang'] = 'de';
      expect(ty('title'), kToyLangs['en']!['title']);
      expect(ty('yoqKalit'), 'yoqKalit');
    });

    test('tyMonth / tyWeekday / tySlot / tyStatus / tyPayKind — yorliqli', () {
      store.S['lang'] = 'uz';
      for (var m = 1; m <= 12; m++) {
        expect(tyMonth(m), isNot(startsWith('mon')));
      }
      // clamp: chegaradan tashqari raqam yiqitmaydi
      expect(tyMonth(0), tyMonth(1));
      expect(tyMonth(13), tyMonth(12));
      for (var w = 1; w <= 7; w++) {
        expect(tyWeekday(w), isNot(startsWith('wd')));
      }
      for (final s in kToySlots) {
        expect(tySlot(s), isNotEmpty);
      }
      for (final s in kToyStatuses) {
        expect(tyStatus(s), isNot(startsWith('st')));
      }
      for (final k in kToyPayKinds) {
        expect(tyPayKind(k), isNotEmpty);
      }
    });
  });

  // Hub kartasi, profil qatori va paywall l10n.dart'dagi 'modToyxona'ni o'qiydi;
  // modul ekrani esa o'z 'title'ini — FARQ bo'lsa bo'lim kirishda o'z nomini
  // o'zgartirib yuboradi (F15; ijara FINDING 8 bilan bir xil qulf).
  group('modul nomi bitta', () {
    test("ty('title') == l10n.dart modToyxona (6 tilda)", () {
      for (final e in kLangs.entries) {
        expect(kToyLangs[e.key]!['title'], e.value['modToyxona'],
            reason: '${e.key}: hub kartasi va ekran sarlavhasi FARQ qiladi');
      }
    });
  });

  group('kontrakt konstantalari', () {
    test('slotlar kalendar tartibida, backend bilan bir xil', () {
      expect(kToySlots, ['nahor', 'tushlik', 'kechki']);
    });

    test('holatlar va to‘lov turlari backend bilan bir xil', () {
      expect(kToyStatuses, ['band', 'tasdiq', 'yakun', 'bekor']);
      expect(kToyPayKinds, ['avans', 'yakuniy', 'qaytarim']);   // 024: qaytarim
    });

    test('xizmat soni chegarasi (U3 stepper)', () {
      expect(kToyMaxSvcQty, 20);
    });
  });

  // 025 — SERVIS KATEGORIYALARI. Ro'yxat IKKI joyda yashaydi: shu yerda va
  // backend'dagi src/lib/toyxonaCategories.js. Slug'lar farq qilsa server
  // "Kategoriya noto'g'ri" (400) qaytarardi va ega sababini bilmasdi.
  group('servis kategoriyalari (025)', () {
    // Backend TOY_SERVICE_CATEGORIES bilan AYNAN bir xil tartib va slug'lar.
    const backend = [
      'taomnoma', 'tort', 'ichimlik', 'musiqa', 'boshlovchi', 'shou', 'foto',
      'bezak', 'yoruglik', 'salyut', 'gozallik', 'transport', 'taklifnoma',
      'sovga', 'xizmat', 'bolalar', 'zal', 'boshqa',
    ];

    test('slug va TARTIB backend ro\'yxati bilan bir xil', () {
      expect(kToyServiceCats.map((c) => c.slug).toList(), backend);
      expect(kToyDefaultCat, 'boshqa');
      expect(kToyServiceCats.last.slug, kToyDefaultCat, reason: "'boshqa' oxirgi bo'lishi shart");
    });

    test('catOf — noma\'lum/bo\'sh slug YIQILMAYDI, "boshqa" qaytadi', () {
      // Server kelajakda yangi kategoriya qo'shsa, ESKI ilova uni ko'rsata
      // olmaydi — lekin item ekrandan YO'QOLMASLIGI kerak.
      expect(catOf('yangi_kategoriya').slug, 'boshqa');
      expect(catOf('').slug, 'boshqa');
      expect(catOf(null).slug, 'boshqa');
      expect(catOf('musiqa').slug, 'musiqa');
    });

    test('har kategoriyaning nomi 6 TILDA ham bor', () {
      for (final c in kToyServiceCats) {
        for (final e in kToyLangs.entries) {
          expect(e.value[c.key], isNotNull,
              reason: "${e.key}: '${c.key}' kaliti yo'q (${c.slug})");
          expect(e.value[c.key]!.trim(), isNotEmpty, reason: '${e.key}: ${c.key} bo\'sh');
        }
      }
    });

    test('HallService.fromJson — kategoriya/rasm/tavsif, eski javob ham ishlaydi', () {
      final full = HallService.fromJson({
        'id': 's1',
        'category': 'musiqa',
        'title': "Ansambl Navro'z",
        'price': 4000000,
        'description': 'Repertuar: milliy va zamonaviy',
        'images': ['https://x/1.jpg', 'https://x/2.jpg', 42, ''],
        'sort': 3,
      });
      expect(full.category, 'musiqa');
      expect(full.cat.slug, 'musiqa');
      expect(full.description, 'Repertuar: milliy va zamonaviy');
      // Raqam va bo'sh satr TASHLANADI (buzuq javob ekranni yiqitmasin)
      expect(full.images, ['https://x/1.jpg', 'https://x/2.jpg']);
      expect(full.cover, 'https://x/1.jpg');

      // 024 davridagi javob (category/images YO'Q) — 'boshqa', rasmsiz
      final old = HallService.fromJson({'id': 's2', 'title': 'Video', 'price': 0});
      expect(old.category, 'boshqa');
      expect(old.images, isEmpty);
      expect(old.cover, isNull);
    });

    test('BookingItem — SNAPSHOT kategoriya va rasm', () {
      final it = BookingItem.fromJson({
        'id': 'i1', 'title': 'Salyut', 'amount': 500000, 'qty': 2,
        'category': 'salyut', 'image': 'https://x/s.jpg',
      });
      expect(it.category, 'salyut');
      expect(it.image, 'https://x/s.jpg');
      // Eski qator: rasm yo'q -> null (bo'sh satr EMAS, aks holda Image.network
      // bo'sh manzil bilan chaqirilardi)
      final old = BookingItem.fromJson({'id': 'i2', 'title': 'Tort', 'amount': 300000, 'image': ''});
      expect(old.image, isNull);
      expect(old.category, 'boshqa');
    });
  });

  main027();
}

// ---------------- 027: STOL KO'RINISHI — mahsulot hisobi (backend bilan bir xil) ----------------
void main027() {
  test('027 toyLineTotal / toyPerGuest — miqdor × narx; 1 kishiga YUQORIGA yaxlitlab', () {
    expect(toyLineTotal(2, 120000), 240000);
    expect(toyLineTotal(1.5, 95000), 142500);
    expect(toyLineTotal(null, 100), 0);
    expect(toyLineTotal(2, 0), 0);
    expect(toyPerGuest(411000, 12), 34250);
    expect(toyPerGuest(411000, 7), 58715);
    expect(toyPerGuest(411000, null), 0);
    expect(toyPerGuest(0, 12), 0);
  });

  test('027 Menu.fromJson — mahsulot qatorlari, tableTotal/perGuestCalc; eski qty qatori buzilmaydi', () {
    final m = Menu.fromJson({
      'id': 'm1', 'title': 'Oddiy', 'price_per_guest': 34250, 'seats': 12,
      'items': [
        {'id': 'a', 'title': 'Osh', 'amount': 2, 'unit': 'kg', 'unit_price': 120000},
        {'id': 'b', 'title': 'Non', 'amount': '12', 'unit': 'dona', 'unit_price': 8000},
        {'id': 'c', 'title': 'Salat', 'amount': 3, 'unit': 'porsiya', 'unit_price': 25000},
        {'id': 'd', 'title': 'Eski', 'qty': '2 ta'},
      ],
    });
    expect(m.items.length, 4);
    expect(m.items[0].lineTotal, 240000);
    expect(m.items[0].qtyText, '2 kg');
    expect(m.items[3].amount, isNull);
    expect(m.items[3].qtyText, '2 ta');
    expect(m.items[3].label, 'Eski · 2 ta');
    expect(m.tableTotal, 411000);
    expect(m.perGuestCalc, 34250);
    expect(toyAmountStr(2.5), '2.5');
    expect(toyAmountStr(2), '2');
    expect(toyAmountStr(0.25), '0.25');
  });

  test('027 l10n — yangi kalitlar 6 tilda', () {
    for (final e in kToyLangs.entries) {
      for (final k in ['tablesTitle', 'tablesBtn', 'productsCap', 'perGuestCap', 'pickTable', 'unitKg', 'unitPaket']) {
        expect(e.value[k], isNotNull, reason: '${e.key}: $k');
      }
    }
    expect(tyUnit('kg'), isNotEmpty);
    expect(tyUnit('x'), '');
  });
}
