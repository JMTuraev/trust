// Trust — Apple App Store (StoreKit) ichki xarid: $9/oy premium obuna.
//
// NEGA: App Store Guideline 3.1.1 — ilova ichidagi raqamli obuna FAQAT Apple IAP orqali
// sotilishi shart (tashqi to'lov havolasi = rad). Shu servis StoreKit obunasini
// (mahsulot: trust_premium_monthly) sotib oladi, chekni backendga tekshirtiradi
// (POST /api/profile/me/subscription/verify, platform: app_store) va premium'ni yoqadi.
//
// PLATFORMA: hozircha FAQAT iOS. Android Play Billing keyin ulanadi — u yergacha
// Android kvota modelida ishlaydi (server 402 beradi), bu servis Android'da "off".
import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api.dart';

class IapService {
  /// App Store Connect'dagi obuna mahsuloti IDsi bilan AYNAN bir xil bo'lishi SHART.
  /// Backend ham shu ID'ni kutadi (lib/subscription.js PREMIUM_PRODUCT_ID).
  static const String productId = 'trust_premium_monthly';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static bool _storeReady = false;
  static ProductDetails? _product;
  static Timer? _busyTimer;

  // ---- Store -> UI ko'priklari (store.dart ulaydi) ----
  /// Xato yuz berdi — foydalanuvchiga toast (o'zbekcha xabar).
  static void Function(String message)? onError;

  /// Premium yoqildi (backend tasdiqladi) — store profilni qayta yuklaydi.
  static void Function()? onPremiumGranted;

  /// Xarid jarayoni ketmoqda/tugadi — paywall CTA spinnerini boshqarish.
  static void Function(bool busy)? onBusy;

  /// iOS'da StoreKit tayyor VA mahsulot yuklangan — paywall "sotib olish" tugmasini ko'rsatadi.
  static bool get canBuy => Platform.isIOS && _storeReady && _product != null;

  /// Mahsulotning lokalizatsiyalangan narxi ("$9.99", "9,99 €", ...). Bo'sh = noma'lum.
  static String get priceLabel => _product?.price ?? '';

  /// main/store startapda bir marta chaqiradi. Android'da darhol qaytadi (no-op).
  static Future<void> init() async {
    if (!Platform.isIOS) return; // Android: kvota modeli (Play Billing keyin)
    try {
      _storeReady = await _iap.isAvailable();
      if (!_storeReady) return;
      // Xaridlar oqimini kuzatamiz — buy() natijasi shu yerga keladi; startapda
      // tugallanmagan/tiklangan xaridlar ham shu orqali qayta ishlanadi.
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onDone: () => _sub?.cancel(),
        onError: (_) {},
      );
      await _loadProduct();
    } catch (_) {
      _storeReady = false;
    }
  }

  static Future<void> _loadProduct() async {
    try {
      final resp = await _iap.queryProductDetails(<String>{productId});
      if (resp.productDetails.isNotEmpty) _product = resp.productDetails.first;
    } catch (_) {/* narx keyin qayta yuklanadi */}
  }

  /// Paywall "Obunani yangilash / sotib olish" — StoreKit to'lov oynasini ochadi.
  static Future<void> buy() async {
    if (!Platform.isIOS) return;
    if (!_storeReady) {
      onError?.call("App Store hozir mavjud emas — keyinroq urinib ko'ring");
      return;
    }
    if (_product == null) {
      await _loadProduct();
      if (_product == null) {
        onError?.call("Obuna mahsuloti topilmadi — keyinroq urinib ko'ring");
        return;
      }
    }
    onBusy?.call(true);
    try {
      final ok = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      // ok=false — StoreKit oynani ocha olmadi (kamdan-kam). Natija baribir stream'da keladi.
      if (ok == false) {
        onBusy?.call(false);
        onError?.call("Xaridni boshlab bo'lmadi");
      }
    } catch (_) {
      onBusy?.call(false);
      onError?.call("Xaridni boshlab bo'lmadi — keyinroq urinib ko'ring");
    }
  }

  /// "Xaridni tiklash" — qurilma almashtirilganda oldingi obunani qaytaradi (Apple talabi).
  static Future<void> restore() async {
    if (!Platform.isIOS || !_storeReady) return;
    onBusy?.call(true);
    _armBusyTimeout(); // tiklashda hech nima kelmasa spinner osilib qolmasin
    try {
      await _iap.restorePurchases();
    } catch (_) {
      _busyTimer?.cancel();
      onBusy?.call(false);
      onError?.call("Tiklab bo'lmadi — keyinroq urinib ko'ring");
    }
  }

  static void _armBusyTimeout() {
    _busyTimer?.cancel();
    _busyTimer = Timer(const Duration(seconds: 20), () => onBusy?.call(false));
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    _busyTimer?.cancel();
    for (final p in purchases) {
      // Tranzaksiyani YOPish (finishTransaction) — pending bo'lsa yopmaymiz; tasdiq
      // MUVAFFAQIYATSIZ bo'lsa ham yopmaymiz (keyingi ochilishda StoreKit qayta yuboradi,
      // shunda backend qayta tekshiradi — pul ketib premium yoqilmay qolmasin).
      var finish = p.pendingCompletePurchase;
      switch (p.status) {
        case PurchaseStatus.pending:
          onBusy?.call(true);
          finish = false;
          break;
        case PurchaseStatus.canceled:
          onBusy?.call(false);
          break;
        case PurchaseStatus.error:
          onBusy?.call(false);
          final m = p.error?.message ?? '';
          onError?.call(m.isNotEmpty ? m : "To'lovda xatolik — qayta urinib ko'ring");
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _verify(p);
          onBusy?.call(false);
          if (ok) {
            onPremiumGranted?.call();
          } else {
            onError?.call("Chekni tasdiqlab bo'lmadi — qayta urinib ko'ring");
            finish = false; // tasdiqlanmadi — qayta urinish uchun ochiq qoldiramiz
          }
          break;
      }
      if (finish) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  static Future<bool> _verify(PurchaseDetails p) async {
    // StoreKit 1: serverVerificationData = base64 app receipt. Backend Apple'da tekshiradi.
    final receipt = p.verificationData.serverVerificationData;
    if (receipt.isEmpty) return false;
    final res = await Api.verifyApple(receipt);
    return res.ok;
  }

  static void dispose() {
    _busyTimer?.cancel();
    _sub?.cancel();
  }
}
