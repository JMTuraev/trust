// Home davr filtri chegaralari (store.homePeriodRange) — QURILMA-LOKAL kunlar.
// Loyihaviy saboq: kun chegarasi serverda emas, shu sof funksiyada hisoblanadi
// (timezone ±1 kun xatosiga qarshi). [fromMs, toMs): from INKLYUZIV, to
// EKSKLYUZIV (keyingi kun 00:00) — server .lt(to) bilan solishtiradi, shu
// sabab kunning oxirgi millisekundi ham yo'qolmaydi (2026-08-04 review fix).
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/store.dart';

void main() {
  int ms(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

  // 2026-08-04 — seshanba (haftaning 2-kuni), kun o'rtasi
  final now = DateTime(2026, 8, 4, 15, 30, 42);

  test('today: kun boshidan keyingi kun 00:00 gacha (eksklyuziv)', () {
    expect(homePeriodRange('today', now), [ms(2026, 8, 4), ms(2026, 8, 5)]);
  });

  test('yesterday: kechagi kun to\'liq', () {
    expect(homePeriodRange('yesterday', now), [ms(2026, 8, 3), ms(2026, 8, 4)]);
  });

  test('week: dushanbadan bugun oxirigacha', () {
    // 2026-08-03 — dushanba
    expect(homePeriodRange('week', now), [ms(2026, 8, 3), ms(2026, 8, 5)]);
  });

  test('week: oy chegarasidan o\'tadi', () {
    // 2026-09-01 — seshanba; dushanba = 2026-08-31
    final tue = DateTime(2026, 9, 1, 9);
    expect(homePeriodRange('week', tue), [ms(2026, 8, 31), ms(2026, 9, 2)]);
  });

  test('week: yil chegarasidan o\'tadi', () {
    // 2026-01-01 — payshanba; dushanba = 2025-12-29
    final thu = DateTime(2026, 1, 1, 12);
    expect(homePeriodRange('week', thu), [ms(2025, 12, 29), ms(2026, 1, 2)]);
  });

  test('week: dushanbaning o\'zida — bir kunlik oraliq', () {
    final mon = DateTime(2026, 8, 3, 8);
    expect(homePeriodRange('week', mon), [ms(2026, 8, 3), ms(2026, 8, 4)]);
  });

  test('month: oy boshidan bugun oxirigacha', () {
    expect(homePeriodRange('month', now), [ms(2026, 8, 1), ms(2026, 8, 5)]);
  });

  test('month: oyning 1-kunida', () {
    final first = DateTime(2026, 8, 1, 0, 5);
    expect(homePeriodRange('month', first), [ms(2026, 8, 1), ms(2026, 8, 2)]);
  });

  test('custom: kun ichidagi vaqtlar kun chegaralariga yoyiladi', () {
    final from = DateTime(2026, 7, 10, 13, 45).millisecondsSinceEpoch;
    final to = DateTime(2026, 7, 12, 5, 10).millisecondsSinceEpoch;
    expect(homePeriodRange('custom', now, customFrom: from, customTo: to),
        [ms(2026, 7, 10), ms(2026, 7, 13)]);
  });

  test('custom: from > to bo\'lsa almashtiriladi', () {
    final from = DateTime(2026, 7, 12).millisecondsSinceEpoch;
    final to = DateTime(2026, 7, 10).millisecondsSinceEpoch;
    expect(homePeriodRange('custom', now, customFrom: from, customTo: to),
        [ms(2026, 7, 10), ms(2026, 7, 13)]);
  });

  test('custom: bir kunlik oraliq', () {
    final d = DateTime(2026, 7, 10, 10).millisecondsSinceEpoch;
    expect(homePeriodRange('custom', now, customFrom: d, customTo: d),
        [ms(2026, 7, 10), ms(2026, 7, 11)]);
  });

  test('all (va noma\'lum): [0, 0] — filtr yo\'q', () {
    expect(homePeriodRange('all', now), [0, 0]);
    expect(homePeriodRange('???', now), [0, 0]);
  });

  test('chegaralar tutashadi: yesterday.to == today.from (yarim-ochiq oraliq)', () {
    final y = homePeriodRange('yesterday', now);
    final t = homePeriodRange('today', now);
    // [from, to) konvensiyasi: kechaning eksklyuziv oxiri = bugunning boshi,
    // hech bir millisekund ikki davrga tushmaydi va yo'qolmaydi ham.
    expect(y[1], t[0]);
  });
}
