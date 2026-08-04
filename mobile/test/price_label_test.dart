// NARX YORLIG'I — do'kon tarmog'i (review 2026-08-04/05 topilmasi).
//
// Qulflanadigan qoida (PO qarori):
//   1) Do'konda mahsulot bor bo'lsa — AYNAN do'kon narxi ko'rsatiladi. U o'z
//      valyuta belgisini olib keladi ("24 000 so'm"), shuning uchun oldiga `$`
//      QO'YILMAYDI — aks holda UZS'da to'laydigan foydalanuvchiga
//      "$24 000 so'm/oy" chiqardi.
//   2) Do'konda yo'q bo'lsa — katalog narxi ("$13/oy") ko'rsatkich sifatida.
//      Korner hech qachon bo'sh qolmaydi.
//   3) XARID NUQTASI (paywall CTA) qat'iyroq: do'kon narxi bor bo'lsa DOIM o'sha —
//      tugma va'da qilgan summa bilan yechilgan summa farq qilmasligi shart.
//
// Bu tarmoq bugun ko'rinmaydi (mahsulotlar do'konda yaratilmagan), shuning uchun
// aynan shu test uni himoya qiladi: mahsulotlar paydo bo'lgan kuni xatolik
// to'g'ridan-to'g'ri pulga tegadi.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/iap.dart';
import 'package:trust_mobile/screens/paywall_sheet.dart';

void main() {
  // SOF test store'ga tegadi (l10n joriy tilni store'dan oladi), store esa
  // konstruktorida AudioPlayer yaratadi -> audioplayers plugin kanallari kerak.
  // Binding + mock handler'siz test "MissingPluginException" bilan yiqiladi.
  // Bu naqsh butun loyihada bir xil (ijara_data_test.dart dagi bilan).
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final ch in const ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
  }

  tearDown(() {
    for (final m in const ['xarajat', 'qarz', 'ijarachi', 'toyxona']) {
      IapService.setModulePriceForTests(m, null);
    }
  });

  test('do\'kon narxi bor — AYNAN o\'sha ko\'rsatiladi, oldiga \$ qo\'shilmaydi', () {
    IapService.setModulePriceForTests('ijarachi', '149 000 so\'m');
    final s = modPriceLabel('ijarachi', 13);
    expect(s.contains('149 000 so\'m'), isTrue, reason: 'do\'kon narxi ko\'rinmadi');
    expect(s.contains('\$'), isFalse,
        reason: 'do\'kon narxi oldiga \$ qo\'shilgan — "\$149 000 so\'m/oy" chiqadi');
    expect(s.contains('13'), isFalse, reason: 'katalog narxi do\'kon narxini bosib ketdi');
  });

  test('do\'kon narxi yo\'q — katalog narxi (korner bo\'sh qolmaydi)', () {
    final s = modPriceLabel('ijarachi', 13);
    expect(s.contains('13'), isTrue);
    expect(s.contains('\$'), isTrue, reason: 'katalog narxi USD — \$ bo\'lishi kerak');
    expect(s.trim(), isNotEmpty, reason: 'korner hech qachon bo\'sh qolmasligi kerak');
  });

  test('XARID TUGMASI — do\'kon narxi bor bo\'lsa doim o\'sha (pul aniqligi)', () {
    IapService.setModulePriceForTests('qarz', '99 000 so\'m');
    final cta = modCtaLabel('qarz', 8);
    expect(cta.contains('99 000 so\'m'), isTrue);
    expect(cta.contains('\$'), isFalse,
        reason: 'tugmada \$ va so\'m aralashib ketdi');
    expect(cta.contains('8'), isFalse,
        reason: 'tugma katalog narxini va\'da qilyapti — do\'kon boshqa summa yechadi');
  });

  test('XARID TUGMASI — do\'kon narxi yo\'q bo\'lsa katalogga tushadi', () {
    final cta = modCtaLabel('qarz', 8);
    expect(cta.contains('8'), isTrue);
    expect(cta.trim(), isNotEmpty);
  });

  test('har bir modul O\'Z narxini oladi (aralashib ketmaydi)', () {
    IapService.setModulePriceForTests('toyxona', '299 000 so\'m');
    expect(modPriceLabel('toyxona', 24).contains('299 000'), isTrue);
    // Boshqa modul do'kon narxini o'ziniki deb olmasligi kerak
    expect(modPriceLabel('ijarachi', 13).contains('299 000'), isFalse);
    expect(modPriceLabel('ijarachi', 13).contains('13'), isTrue);
  });
}
