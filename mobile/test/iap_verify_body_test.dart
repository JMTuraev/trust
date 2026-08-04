// Apple chek tasdig'i so'rovining TANASI (POST /api/profile/me/subscription/verify).
//
// NEGA BU TEST BOR (2026-08-04 review, FINDING 1 — KRITIK):
// Server qaysi obunani yoqishni FAQAT `module` kaliti bo'yicha hal qiladi
// (src/routes/profile.js: `const pid = modKey ? MODULES[modKey].product_id
// : PREMIUM_PRODUCT_ID`). Klientning `product_id`si ATAYLAB e'tiborsiz
// qoldiriladi (anti-fraud) va serverda product_id -> module xaritasi YO'Q.
// Ilgari mobil faqat product_id yuborardi: modul SKU'lari do'konda paydo
// bo'lishi bilanoq server eski premium mahsuloti bo'yicha tekshirar, chekda mos
// yozuv topilmasdi -> 400 -> iap.dart 400'ni DOIMIY xato deb tranzaksiyani
// yopardi (pul olingan, modul ochilmagan, StoreKit qayta yubormaydi).
//
// SHART: modul xaridida tanada `module` BO'LADI; eski yagona premium xaridida
// tana AYNAN avvalgidek (`module` YO'Q) qoladi — baytma-bayt.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/api.dart';
import 'package:trust_mobile/iap.dart';
import 'package:trust_mobile/store.dart';

const String kReceipt = 'BASE64RECEIPT';

void main() {
  _retryTests();
  group('IapService.verifyBodyFor — modul xaridi', () {
    test('modul SKU -> tanada module kaliti bor', () {
      final b = IapService.verifyBodyFor('trust_xarajat_monthly', kReceipt);
      expect(b['module'], 'xarajat');
      expect(b['platform'], 'app_store');
      expect(b['receipt_data'], kReceipt);
      // product_id endi faqat eski moslik uchun ketadi (server o'qimaydi).
      expect(b['product_id'], 'trust_xarajat_monthly');
    });

    test('HAR BIR modul mahsuloti o\'z kalitini yuboradi', () {
      IapService.moduleProductIds.forEach((module, pid) {
        final b = IapService.verifyBodyFor(pid, kReceipt);
        expect(b['module'], module, reason: '$pid -> $module kutilgan');
        expect(b['product_id'], pid);
      });
    });

    test('module qiymati backend MODULES kalitlari bilan bir xil', () {
      // Bu ro'yxat backend katalogi (src/routes/profile.js MODULES) va
      // kSubModuleDefaults bilan sinxron bo'lishi SHART — aks holda server
      // "Noma'lum modul" (400) qaytaradi va xarid yo'qoladi.
      expect(IapService.moduleProductIds.keys.toSet(), kSubModuleDefaults.keys.toSet());
    });

    test('JSON tanasi kutilganidek (modul)', () {
      expect(jsonEncode(IapService.verifyBodyFor('trust_qarz_monthly', kReceipt)),
          '{"platform":"app_store","module":"qarz","product_id":"trust_qarz_monthly",'
          '"receipt_data":"$kReceipt"}');
    });
  });

  group('IapService.verifyBodyFor — eski premium (o\'zgarmasligi SHART)', () {
    test('premium SKU -> module kaliti YO\'Q', () {
      final b = IapService.verifyBodyFor(IapService.productId, kReceipt);
      expect(b.containsKey('module'), isFalse);
      expect(b['product_id'], 'trust_premium_monthly');
    });

    test('JSON tanasi o\'zgarishdan OLDINGI bilan baytma-bayt bir xil', () {
      expect(jsonEncode(IapService.verifyBodyFor(IapService.productId, kReceipt)),
          '{"platform":"app_store","product_id":"trust_premium_monthly",'
          '"receipt_data":"$kReceipt"}');
    });

    test('bo\'sh productID -> premium ID, module YO\'Q', () {
      final b = IapService.verifyBodyFor('', kReceipt);
      expect(b['product_id'], 'trust_premium_monthly');
      expect(b.containsKey('module'), isFalse);
    });

    test('notanish SKU -> module YO\'Q (eski oqim, server o\'zi hal qiladi)', () {
      final b = IapService.verifyBodyFor('trust_something_else', kReceipt);
      expect(b.containsKey('module'), isFalse);
      expect(b['product_id'], 'trust_something_else');
    });
  });

  group('IapService.moduleOf', () {
    test('mahsulot ID -> modul, premium/notanishda null', () {
      expect(IapService.moduleOf('trust_toyxona_monthly'), 'toyxona');
      expect(IapService.moduleOf(IapService.productId), isNull);
      expect(IapService.moduleOf(''), isNull);
      expect(IapService.moduleOf('trust_xarajat'), isNull);
    });
  });

  group('Api.verifyAppleBody', () {
    test('module berilmasa tanada yo\'q (standart premium mahsuloti)', () {
      final b = Api.verifyAppleBody(kReceipt);
      expect(b, {
        'platform': 'app_store',
        'product_id': kPremiumProductId,
        'receipt_data': kReceipt,
      });
    });

    test('module berilsa product_id dan OLDIN qo\'shiladi', () {
      final b = Api.verifyAppleBody(kReceipt, productId: 'trust_ijarachi_monthly', module: 'ijarachi');
      expect(b.keys.toList(), ['platform', 'module', 'product_id', 'receipt_data']);
      expect(b['module'], 'ijarachi');
    });

    test('kPremiumProductId backend PREMIUM_PRODUCT_ID bilan bir xil', () {
      expect(kPremiumProductId, 'trust_premium_monthly');
      expect(IapService.productId, kPremiumProductId);
    });
  });
}

// ---- Qaytariladigan tasdiq xatolari (review 2026-08-04 #2) ----
// Pul olingan, lekin server VAQTINCHA tasdiqlay olmagan holatda tranzaksiya OCHIQ
// qolishi shart: yopilsa StoreKit chekni boshqa qayta yubormaydi va foydalanuvchi
// pulidan ayriladi. Doimiy xatolar esa yopilishi kerak — aks holda chek abadiy qaytadi.
void _retryTests() {
  group('isRetryableVerify', () {
    test('tarmoq (0) va server xatolari (5xx) — QAYTA urinamiz', () {
      expect(IapService.isRetryableVerify(0, ''), isTrue);
      expect(IapService.isRetryableVerify(500, ''), isTrue);
      expect(IapService.isRetryableVerify(502, ''), isTrue);
      expect(IapService.isRetryableVerify(503, 'ANY'), isTrue);
    });

    test('409 + SUB_DB_NOT_READY (020 qo\'llanmagan) — QAYTA urinamiz', () {
      expect(IapService.isRetryableVerify(409, 'SUB_DB_NOT_READY'), isTrue);
    });

    test('boshqa 409 (chek boshqa akkauntniki) — DOIMIY, yopiladi', () {
      expect(IapService.isRetryableVerify(409, ''), isFalse);
      expect(IapService.isRetryableVerify(409, 'OTHER'), isFalse);
    });

    test('400/501 kabi doimiy xatolar — yopiladi', () {
      expect(IapService.isRetryableVerify(400, ''), isFalse);
      expect(IapService.isRetryableVerify(501, ''), isFalse);
      expect(IapService.isRetryableVerify(403, 'SUB_DB_NOT_READY'), isFalse);
    });
  });
}
