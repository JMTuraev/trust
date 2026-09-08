// Backend manzili: asosiy api.trustbook.uz, ulanish xatosida zaxira (onrender).
// Faqat MANTIQ tekshiriladi — tarmoqqa chiqilmaydi (api.dart Api.base/useFallback).
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/api.dart';

void main() {
  setUp(Api.resetBase);
  tearDown(Api.resetBase);

  test('default: asosiy manzil o\'z domenimiz, zaxira Render', () {
    expect(kApiDefault, 'https://api.trustbook.uz');
    expect(kApiFallback, contains('onrender.com'));
    expect(Api.base, kApiPrimary);
    expect(apiUrl, Api.base);
  });

  test('useFallback: bir marta o\'tadi, ikkinchisida false (sticky)', () {
    expect(Api.onFallback, isFalse);
    // Testda API_URL berilmagan -> kApiPrimary == kApiDefault -> o'tish mumkin
    expect(Api.useFallback(), isTrue);
    expect(Api.onFallback, isTrue);
    expect(apiUrl, kApiFallback);
    expect(Api.useFallback(), isFalse, reason: 'zaxirada turib yana o\'tmaydi');
    expect(Api.base, kApiFallback);
  });

  test('resetBase asosiyga qaytaradi', () {
    Api.useFallback();
    Api.resetBase();
    expect(Api.base, kApiPrimary);
    expect(Api.onFallback, isFalse);
  });
}
