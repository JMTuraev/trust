// Home kuchli qidiruv matcher'i (store.searchNorm / digitsOf / partnerMatch):
// apostrof variantlari, kirill↔lotin, telefon (>=3 raqam), summa (raqamli so'rov).
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/store.dart';

void main() {
  group('searchNorm', () {
    test('kichik harf + apostrof variantlari birxillashadi', () {
      expect(searchNorm('G’ani'), "g'ani"); // ’
      expect(searchNorm('Gʻani'), "g'ani"); // ʻ
      expect(searchNorm('Gʼani'), "g'ani"); // ʼ
      expect(searchNorm('G`ani'), "g'ani"); // `
      expect(searchNorm("G'ani"), "g'ani"); // to'g'ri apostrof o'zgarmaydi
    });

    test('kirill -> lotin (o\'zbek harflari bilan)', () {
      expect(searchNorm('Азиз'), 'aziz');
      expect(searchNorm('Шерзод'), 'sherzod');
      expect(searchNorm('Чоршанба'), 'chorshanba');
      expect(searchNorm('Ғани'), "g'ani");
      expect(searchNorm('Ўктам'), "o'ktam");
      expect(searchNorm('Қудрат'), 'qudrat');
      expect(searchNorm('Ҳасан'), 'hasan');
      expect(searchNorm('Хуршид'), 'xurshid');
      expect(searchNorm('Юлдуз'), 'yulduz');
      expect(searchNorm('Ёқуб'), "yoqub");
    });

    test('lotin matn o\'zgarishsiz qoladi', () {
      expect(searchNorm('Aziz Karimov'), 'aziz karimov');
    });
  });

  group('digitsOf', () {
    test('faqat raqamlar qoladi', () {
      expect(digitsOf('+998 90 703-44-44'), '998907034444');
      expect(digitsOf('abc'), '');
    });
  });

  group('partnerMatch — ism', () {
    test('kirill so\'rov lotin ismni topadi va aksincha', () {
      expect(partnerMatch('азиз', name: 'Aziz Karimov'), isTrue);
      expect(partnerMatch('aziz', name: 'Азиз Каримов'), isTrue);
      expect(partnerMatch('ғани', name: "G'anisher"), isTrue);
      expect(partnerMatch("g'ani", name: 'Ғанишер'), isTrue);
    });

    test('apostrof varianti farq qilmaydi', () {
      expect(partnerMatch("g'ani", name: 'Gʻani aka'), isTrue);
      expect(partnerMatch('G’ani', name: "G'ani aka"), isTrue);
    });

    test('mos kelmasa false', () {
      expect(partnerMatch('aziz', name: 'Baxtiyor'), isFalse);
    });

    test('bo\'sh so\'rov hammani o\'tkazadi', () {
      expect(partnerMatch('', name: 'Har kim'), isTrue);
      expect(partnerMatch('   ', name: 'Har kim'), isTrue);
    });
  });

  group('partnerMatch — telefon', () {
    const phone = '+998 90 703 44 44';

    test('>=3 raqamli so\'rov telefon ichidan topiladi', () {
      expect(partnerMatch('90 703', name: 'Aziz', phone: phone), isTrue);
      expect(partnerMatch('7034444', name: 'Aziz', phone: phone), isTrue);
      expect(partnerMatch('998', name: 'Aziz', phone: phone), isTrue);
    });

    test('<3 raqam telefon qidiruvini ishga tushirmaydi', () {
      // '90' — 2 raqam: telefon bo'yicha emas; summa bo'yicha ham yo'q (amounts bo'sh)
      expect(partnerMatch('90', name: 'Aziz', phone: phone), isFalse);
    });

    test('mos kelmagan raqamlar false', () {
      expect(partnerMatch('555123', name: 'Aziz', phone: phone), isFalse);
    });
  });

  group('partnerMatch — summa', () {
    test('raqamli so\'rov balans raqamlariga qism-satr mos', () {
      expect(partnerMatch('500', name: 'Aziz', amounts: const [1500000]), isTrue);
      expect(partnerMatch('1500000', name: 'Aziz', amounts: const [1500000]), isTrue);
      expect(partnerMatch('700', name: 'Aziz', amounts: const [1500000]), isFalse);
    });

    test('ajratkichli raqamli so\'rov ham ishlaydi ("1 500")', () {
      expect(partnerMatch('1 500', name: 'Aziz', amounts: const [1500000]), isTrue);
    });

    test('manfiy balans (qarzingiz) abs bilan solishtiriladi', () {
      expect(partnerMatch('250', name: 'Aziz', amounts: const [-250000]), isTrue);
    });

    test('harf aralash so\'rov summa qidiruvini ishga tushirmaydi', () {
      expect(partnerMatch('a500', name: 'Aziz', amounts: const [1500000]), isFalse);
    });

    test('bir nechta valyuta balanslari tekshiriladi', () {
      expect(partnerMatch('120', name: 'Aziz', amounts: const [999, 1200]), isTrue);
    });
  });
}
