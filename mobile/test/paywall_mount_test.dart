// Modul paywall'ining MOUNT NUQTASI — 2026-08-04 review, FINDING 2 (HIGH).
//
// REGRESSIYA TARIXI: paywall faqat home_hub.dart ichida chizilardi, main.dart
// esa HomeHubScreen'ni faqat `isHub` bo'lganda quradi. Ammo store'ning global
// 402 ishlovchisi (Api.onPaymentRequired) paywall'ni ISTALGAN ekrandan ochadi —
// Xarajat, hamkor daftari, yangi operatsiya sheet'i. Natijada hub'dan tashqarida
// foydalanuvchi HECH NARSA ko'rmasdi (modulli 402'da global qizil banner ham
// ataylab o'chirilgan), S['paywall'] esa null bo'lmay qolar va sheet keyinroq
// hub'ga o'tilganda kutilmaganda "otilib chiqardi".
//
// Shuning uchun bu yerda AYNAN mount nuqtasi tekshiriladi: paywall global
// overlay (main.dart) bo'lishi va IKKI marta chizilmasligi shart.
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/main.dart';
import 'package:trust_mobile/screens/home_hub.dart';
import 'package:trust_mobile/screens/paywall_sheet.dart';
import 'package:trust_mobile/store.dart';

/// Store'ni ma'lum bir ekranda, paywall yopiq holatda boshlaydi.
void _atScreen(String screen) {
  store.S['stage'] = 'app';
  store.S['screen'] = screen;
  store.S['clientOpen'] = false;
  store.S['paywall'] = null;
}

void main() {
  testWidgets('hub BO\'LMAGAN ekranda 402 kelsa paywall chiziladi', (t) async {
    _atScreen('xarajat');
    await t.pumpWidget(const TrustApp());
    await t.pump();
    expect(find.byType(HomeHubScreen), findsNothing, reason: 'hub ochiq emas');
    expect(find.byType(PaywallSheet), findsNothing, reason: 'boshida paywall yo\'q');

    // Api.onPaymentRequired modulli 402'da AYNAN shuni chaqiradi
    store.openPaywall_('xarajat');
    await t.pump();
    expect(find.byType(PaywallSheet), findsOneWidget,
        reason: 'hub bo\'lmagan ekranda ham paywall ko\'rinishi SHART');

    // Yopilgach yo'qoladi — keyin hub'ga o'tganda "otilib chiqmaydi"
    store.paywallClose_();
    await t.pump();
    expect(find.byType(PaywallSheet), findsNothing);
  });

  testWidgets('hub ekranida BITTA paywall (ikki marta mount emas)', (t) async {
    _atScreen('hub');
    await t.pumpWidget(const TrustApp());
    await t.pump();
    expect(find.byType(HomeHubScreen), findsOneWidget);

    store.openPaywall_('qarz');
    await t.pump();
    // Global overlay + hub ichidagi eski mount birga qolsa 2 ta bo'lardi
    expect(find.byType(PaywallSheet), findsOneWidget);

    store.paywallClose_();
    await t.pump();
    expect(find.byType(PaywallSheet), findsNothing);
  });
}
