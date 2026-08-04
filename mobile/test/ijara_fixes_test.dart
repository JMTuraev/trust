// Ijara moduli — 2026-08-04 review tuzatishlari (FINDING 2 / 6 / 7 / 8 va
// backendning "bekor qilinganda to'lovlar uziladi" o'zgarishi).
//
// NEGA BU FAYL AJRATILGAN: ijara_data_test.dart shartnomaning O'ZGARMAS
// qismini (ajratgichlar, formatlar, lug'at qamrovi) qulflaydi. Bu yerda esa
// AYNAN qaytib kelishi mumkin bo'lgan xatolar turadi:
//   1) apparat "orqaga" ochiq formani emas, BUTUN modulni yopib yuborishi;
//   2) uy chegarasini javobning noto'g'ri joyidan o'qish (jimgina 5 da qolish);
//   3) bekor qilingan hisobning UZILGAN to'lovi yakunlardan yo'qolishi.
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/ijara_data.dart';
import 'package:trust_mobile/ijara_l10n.dart';
import 'package:trust_mobile/l10n.dart';
import 'package:trust_mobile/main.dart';
import 'package:trust_mobile/screens/ijara.dart';
import 'package:trust_mobile/store.dart';

/// GET /charges javobi: bitta BEKOR qilingan hisob + undan UZILGAN to'lov.
/// Backend (src/routes/ijara.js) bekor qilinganda charge_id -> null qiladi,
/// shuning uchun to'lov `unallocated` massivida keladi, hisob totals'i esa nol.
Map<String, dynamic> _cancelledBody() => {
      'success': true,
      'data': [
        {
          'id': 'c1',
          'house_id': 'h1',
          'period': '2026-08',
          'kind': 'ijara',
          'title': 'Avgust ijarasi',
          'amount': 3000000,
          'status': 'bekor',
          'payments': const [], // uzilgan — hisob ostida to'lov qolmaydi
          'totals': {'paid': 0, 'left': 0},
        },
        {
          'id': 'c2',
          'house_id': 'h1',
          'period': '2026-08',
          'kind': 'kommunal',
          'title': 'Svet',
          'amount': 500000,
          'status': 'kutilmoqda',
          'totals': {'paid': 0, 'left': 500000},
        },
      ],
      // Uzilgan to'lov — endi TAQSIMLANMAGAN tushum
      'unallocated': [
        {'id': 'p1', 'house_id': 'h1', 'charge_id': null, 'amount': 2000000, 'paid_at': '2026-08-03'},
      ],
      // Server yakuni: charged = faqat c2, paid = uzilgan to'lov
      'totals': {'count': 2, 'charged': 500000, 'paid': 2000000, 'left': -1500000},
    };

List<House> _houses() => ijParseHouses([
      {'id': 'h1', 'name': 'Chilonzor 12-uy', 'tenant_name': 'Alisher aka', 'rent_amount': 3000000},
    ]);

ChargesPage _page(Map<String, dynamic> body) =>
    ijParseCharges(ijChargesPayload(body['data'], body));

/// Repo'ni tarmoqsiz, YUKLANGAN holatga keltiradi (ekran skelet/xato emas,
/// ro'yxat chizadi). Yuklash yo'lining O'ZI ishlatiladi: applyHouses/applyPage.
void _seed({Map<String, dynamic>? body, Map<String, dynamic>? housesBody}) {
  ijaraRepo.month = ijMonthStart(DateTime.now());
  ijaraRepo.applyHouses(_houses(), housesBody);
  ijaraRepo.applyPage(_page(body ?? _cancelledBody()));
  ijaraRepo.loading = false;
  ijaraRepo.loaded = true;
}

void _atHub() {
  store.S['stage'] = 'app';
  store.S['screen'] = 'hub';
  store.S['clientId'] = null;
  store.S['clientOpen'] = false;
  store.S['paywall'] = null;
  store.S['skelHome'] = false;
  store.S['modSubs'] = const <Map<String, dynamic>>[];
  store.S['modSubsLegacy'] = false;
  store.S['lang'] = 'uz';
}

/// Matnni ko'rinadigan joyga surib bosadi (kartalar/tugmalar ekran ostida qoladi).
Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Hub kartasini bosib modulga kiradi. Karta sarlavhasi JORIY tilda.
Future<void> _openIjara(WidgetTester t) async {
  final lang = store.S['lang'] as String? ?? 'uz';
  final name = (kLangs[lang] ?? lUz)['modIjarachi'] as String;
  await _tapText(t, name.toUpperCase());
}

void main() {
  // ij() lug'at tilini store'dan o'qiydi, store esa audio pleyerni yaratadi —
  // sof testda kanal soxta ishlovchi bilan yopiladi (ijara_data_test bilan bir xil).
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ch in const ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }

  setUp(() => store.S['lang'] = 'uz');

  // ===================== FINDING 6 =====================
  // Route javobi: {data:[...], limit:{max_houses, used}} — `max_houses` ILDIZDA
  // EMAS. Ilgari r.body['max_houses'] o'qilardi va chegara abadiy lokal 5 bo'lib
  // qolardi (ya'ni "tarifni ilova yangilanmasdan o'zgartirish" ishlamasdi).
  group('ijMaxHouses — chegara javobning QAYSI joyidan o\'qiladi', () {
    test('haqiqiy shakl: limit.max_houses', () {
      expect(ijMaxHouses({'success': true, 'data': [], 'limit': {'max_houses': 8, 'used': 2}}), 8);
    });

    test('403 HOUSE_LIMIT: limit RAQAM bo\'lib keladi', () {
      expect(ijMaxHouses({'code': 'HOUSE_LIMIT', 'limit': 5, 'used': 5}), 5);
      expect(ijMaxHouses({'code': 'HOUSE_LIMIT', 'limit': '7', 'used': 7}), 7);
    });

    test('eski tekis shakl ham qabul qilinadi', () {
      expect(ijMaxHouses({'max_houses': 9}), 9);
    });

    test('yo\'q / buzuq / nol -> zaxira', () {
      expect(ijMaxHouses(<String, dynamic>{}), kIjaraMaxHouses);
      expect(ijMaxHouses({'limit': 'nope'}), kIjaraMaxHouses);
      expect(ijMaxHouses({'limit': {'used': 3}}), kIjaraMaxHouses);
      expect(ijMaxHouses({'limit': 0}), kIjaraMaxHouses);
      // Berilgan zaxira ustun (repo joriy qiymatini yo'qotmasin)
      expect(ijMaxHouses(<String, dynamic>{}, 8), 8);
    });

    test('repo javobni qo\'llaganda maxHouses YANGILANADI', () {
      ijaraRepo.maxHouses = kIjaraMaxHouses;
      ijaraRepo.applyHouses(_houses(), {'limit': {'max_houses': 12, 'used': 1}});
      expect(ijaraRepo.maxHouses, 12);
      expect(ijaraRepo.canAddHouse, isTrue);
      ijaraRepo.maxHouses = kIjaraMaxHouses; // keyingi testlarga toza holat
    });
  });

  // ===================== BEKOR + UZILGAN TO'LOV =====================
  // Backend bekor qilinganda charge_id -> null qiladi: pul yo'qolmaydi,
  // TAQSIMLANMAGAN tushumga aylanadi. Mijoz ham AYNAN shu qoidada sanashi
  // kerak, aks holda ekrandagi son server soni bilan farq qilardi.
  group('bekor qilingan hisob — uzilgan to\'lov', () {
    test('ijSumPeriod: bekor summa tushadi, uzilgan to\'lov QOLADI', () {
      final page = _page(_cancelledBody());
      final t = ijSumPeriod(page.charges, page.payments);
      expect(t.charged, 500000, reason: 'bekor qilingan 3 000 000 sanalmaydi');
      expect(t.paid, 2000000, reason: 'uzilgan to\'lov tushum bo\'lib qoladi');
      expect(t.left, -1500000, reason: 'ortiqcha to\'lov -> manfiy (clamp yo\'q)');
    });

    test('server yakuni bilan AYNAN mos (foldCharges qoidasi)', () {
      final body = _cancelledBody();
      final page = _page(body);
      final srv = page.totals!;
      final own = ijSumPeriod(page.charges, page.payments);
      expect([own.charged, own.paid, own.left], [srv.charged, srv.paid, srv.left]);
    });

    test('repo: davr va uy yakunlari ham shu qoidada', () {
      _seed();
      // Server xulosasi bor -> o'sha ishlatiladi
      expect(ijaraRepo.periodTotals.paid, 2000000);
      // Xulosasiz (eski/qisqa javob) -> mahalliy hisob AYNAN o'sha sonni beradi
      ijaraRepo.summary = const IjaraSummary();
      expect(ijaraRepo.periodTotals.charged, 500000);
      expect(ijaraRepo.periodTotals.paid, 2000000);
      final h = ijaraRepo.totalsOf('h1');
      expect(h.charged, 500000);
      expect(h.paid, 2000000);
    });

    test('bekor qilingan hisob ro\'yxatdan YO\'QOLMAYDI, holati "bekor"', () {
      final page = _page(_cancelledBody());
      final c = page.charges.firstWhere((c) => c.id == 'c1');
      expect(c.amount, 3000000, reason: 'xom summa ko\'rinadi');
      expect(c.paid, 0);
      expect(ijChargeState(c), 'bekor', reason: 'left 0 -> "tolangan" DEB ko\'rsatilmasin');
      // Uzilgan to'lov endi hech qaysi hisobga yopishmaydi (umumiy)
      final p = page.payments.single;
      expect(p.chargeId, isEmpty);
      expect(p.houseId, 'h1');
    });
  });

  // ===================== FINDING 8 =====================
  group('modul nomi bitta', () {
    test('ij(\'title\') == l10n.dart modIjarachi (6 tilda)', () {
      for (final e in kLangs.entries) {
        expect(kIjaraLangs[e.key]!['title'], e.value['modIjarachi'],
            reason: '${e.key}: hub kartasi va ekran sarlavhasi FARQ qiladi');
      }
    });

    test('yangi errSubExpired kaliti 6 tilda ham bor', () {
      for (final e in kIjaraLangs.entries) {
        expect('${e.value['errSubExpired']}'.trim(), isNotEmpty, reason: e.key);
      }
    });
  });

  // ===================== FINDING 2 =====================
  // Apparat "orqaga": modul QATLAMLARI State ichida yashaydi, store ularni
  // ko'rmaydi. Root PopScope (main.dart) endi store.setModuleBack_ hook'ini
  // hub'ga qaytishdan OLDIN chaqiradi.
  group('apparat "orqaga" — modul qatlami avval yopiladi', () {
    testWidgets('ochiq forma yopiladi, modul JOYIDA qoladi', (t) async {
      _atHub();
      _seed();
      await t.pumpWidget(const TrustApp());
      await t.pump();
      await _openIjara(t);
      expect(find.byType(IjaraScreen), findsOneWidget);

      // Ekran mount bo'lganda hook ro'yxatdan o'tadi
      expect(store.moduleBack, isNotNull, reason: 'modul hook\'i qo\'yilmagan');

      // Uy tafsiloti -> "+ To'lov" formasi (eng chuqur qatlam)
      await _tapText(t, 'Chilonzor 12-uy');
      await _tapText(t, ij('addPayment'));
      expect(find.text(ij('newPayment')), findsOneWidget);

      // 1-orqaga: FAQAT forma yopiladi (kiritilgan ma'lumot yo'qolmasin)
      expect(store.tryModuleBack_(), isTrue);
      await t.pumpAndSettle();
      expect(find.text(ij('newPayment')), findsNothing);
      expect(find.byType(IjaraScreen), findsOneWidget);
      expect(store.S['screen'], 'ijara');

      // 2-orqaga: uy tafsilotidan UYLAR RO'YXATIGA (hub'ga EMAS)
      expect(store.tryModuleBack_(), isTrue);
      await t.pumpAndSettle();
      expect(find.text(ij('addHouse')), findsOneWidget, reason: 'ro\'yxat qaytmadi');
      expect(store.S['screen'], 'ijara');

      // 3-orqaga: yopiladigan qatlam yo'q -> Root hub'ga qaytaradi
      expect(store.tryModuleBack_(), isFalse);
      final v = store.vals();
      expect(v['hubBackable'], isTrue);
      (v['hubBack'] as void Function())();
      await t.pumpAndSettle();
      expect(store.S['screen'], 'hub');
      expect(find.byType(IjaraScreen), findsNothing);
      // Ekran yechilgach hook ham tozalanadi (hub'da "orqaga" o'zgarmaydi)
      expect(store.moduleBack, isNull);
      expect(store.tryModuleBack_(), isFalse);
    });

    testWidgets('HAQIQIY tizim "orqaga" — bir bosishda modul yopilmaydi', (t) async {
      _atHub();
      _seed();
      await t.pumpWidget(const TrustApp());
      await t.pump();
      await _openIjara(t);
      await _tapText(t, 'Chilonzor 12-uy');
      expect(find.text(ij('balanceCap')), findsOneWidget);

      // Root PopScope'ni platformadagidek chaqiramiz (main.dart simlari bilan)
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(store.S['screen'], 'ijara', reason: 'bitta bosish MODULDAN CHIQARDI');
      expect(find.text(ij('addHouse')), findsOneWidget, reason: 'uylar ro\'yxatiga qaytmadi');

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(store.S['screen'], 'hub');
    });
  });

  // ===================== KO'RINISH =====================
  testWidgets('bekor qilingan hisob va uzilgan to\'lov EKRANDA', (t) async {
    _atHub();
    _seed();
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _openIjara(t);
    await _tapText(t, 'Chilonzor 12-uy');

    // Hisob ro'yxatida turadi va "Bekor" deb belgilanadi
    expect(find.text('Avgust ijarasi'), findsOneWidget);
    expect(find.text(ij('stBekor')), findsOneWidget);
    // Pul YO'QOLMAYDI: to'lov "Umumiy" bo'lib TO'LOVLAR ro'yxatida qoladi
    expect(find.text(ij('payGeneral')), findsOneWidget);
    expect(find.text(ijMoney(2000000)), findsWidgets);
    // Balans bloki: hisoblandi faqat bekor QILINMAGAN hisobdan
    expect(find.text(ijMoney(500000)), findsWidgets);
    expect(t.takeException(), isNull);
  });

  // ===================== FINDING 7 =====================
  testWidgets('server chegara/obuna xatosi — modul O\'Z tilida gapiradi', (t) async {
    _atHub();
    _seed();
    store.S['lang'] = 'ru';
    addTearDown(() {
      store.S['lang'] = 'uz';
      ijaraRepo.lastCode = '';
      ijaraRepo.error = null;
      ijaraRepo.maxHouses = kIjaraMaxHouses;
    });
    await t.pumpWidget(const TrustApp());
    await t.pump();
    await _openIjara(t);

    // Serverning O'ZBEKCHA 403 matni (ruscha ega uni tushunmaydi)
    const uzOnly = "Bitta hisobda ko'pi bilan 5 ta uy bo'lishi mumkin";
    ijaraRepo.error = uzOnly;
    ijaraRepo.lastCode = 'HOUSE_LIMIT';

    // Chegaraga yetgan holatda "+ Uy qo'shish" cap modalini ochadi — AYNAN
    // shu modal 403 javobida ham ko'rsatiladi (server matni EMAS).
    ijaraRepo.maxHouses = 1;
    await _tapText(t, ij('addHouse'));
    expect(find.text(ij('capTitle')), findsOneWidget);
    expect(find.textContaining(uzOnly), findsNothing, reason: 'o\'zbekcha server matni chiqdi');
  });
}
