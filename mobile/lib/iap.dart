// Trust — Apple App Store (StoreKit) ichki xarid: $9/oy premium obuna.
//
// NEGA: App Store Guideline 3.1.1 — ilova ichidagi raqamli obuna FAQAT Apple IAP orqali
// sotilishi shart (tashqi to'lov havolasi = rad). Shu servis StoreKit obunasini
// (mahsulot: trust_premium_monthly) sotib oladi, chekni backendga tekshirtiradi
// (POST /api/profile/me/subscription/verify, platform: app_store) va premium'ni yoqadi.
//
// PLATFORMA: hozircha FAQAT iOS. Android Play Billing keyin ulanadi — u yergacha
// Android kvota modelida ishlaydi (server 402 beradi), bu servis Android'da "off".
//
// 2026-08-04 — MODUL OBUNALARI (per-module subscriptions): eski yagona premium
// yonida har bo'lim uchun alohida mahsulot bor (moduleProductIds). Bu mahsulotlar
// do'konlarda HALI YARATILMAGAN, shuning uchun buyModule() ularni topa olmasa
// `false` qaytaradi (xato toasti YO'Q) — paywall mavjud "to'lov tez orada"
// xabarini ko'rsatadi. Eski premium oqimi (profil kartasi) tegilmagan.
import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api.dart';

class IapService {
  /// App Store Connect'dagi obuna mahsuloti IDsi bilan AYNAN bir xil bo'lishi SHART.
  /// Backend ham shu ID'ni kutadi (lib/subscription.js PREMIUM_PRODUCT_ID).
  static const String productId = kPremiumProductId;

  /// Modul obunalari (per-module subscriptions, 2026-08-04): modul -> mahsulot ID.
  /// Do'konda xaridni shu ID bilan boshlaymiz, chekni tasdiqlashda esa serverga
  /// MODUL KALITI ketadi (`verifyBodyFor`) — backend product_id'ga ISHONMAYDI va
  /// mahsulot ID'sini o'z katalogidan (MODULES) oladi.
  ///
  /// MUHIM: bu mahsulotlar App Store Connect / Play Console'da HALI YARATILMAGAN.
  /// Shu sabab so'rov `notFoundIDs`ga tushadi — buyModule() `false` qaytaradi va
  /// paywall mavjud "to'lov tez orada" xabarini ko'rsatadi (crash/hang YO'Q).
  static const Map<String, String> moduleProductIds = {
    'xarajat': 'trust_xarajat_monthly',
    'qarz': 'trust_qarz_monthly',
    'ijarachi': 'trust_ijarachi_monthly',
    'toyxona': 'trust_toyxona_monthly',
  };

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static bool _storeReady = false;
  static ProductDetails? _product;
  /// Do'kondan yuklangan modul mahsulotlari: mahsulot ID -> tafsilot.
  static final Map<String, ProductDetails> _modProducts = {};
  static Timer? _busyTimer;

  // ---- Store -> UI ko'priklari (store.dart ulaydi) ----
  /// Xato yuz berdi — foydalanuvchiga toast (o'zbekcha xabar).
  static void Function(String message)? onError;

  /// Premium yoqildi (backend tasdiqladi) — store profilni qayta yuklaydi.
  static void Function()? onPremiumGranted;

  /// Modul obunasi yoqildi (backend tasdiqladi) — store modul holatini qayta oladi.
  /// Eski premium mahsuloti bu callback'ni CHAQIRMAYDI (u onPremiumGranted'da qoladi).
  static void Function(String module)? onModuleGranted;

  /// Xarid jarayoni ketmoqda/tugadi — paywall CTA spinnerini boshqarish.
  static void Function(bool busy)? onBusy;

  /// iOS'da StoreKit tayyor VA mahsulot yuklangan — paywall "sotib olish" tugmasini ko'rsatadi.
  static bool get canBuy => Platform.isIOS && _storeReady && _product != null;

  /// Mahsulotning lokalizatsiyalangan narxi ("$9.99", "9,99 €", ...). Bo'sh = noma'lum.
  static String get priceLabel => _product?.price ?? '';

  /// Modul mahsulotining do'kondagi lokalizatsiyalangan narxi. Bo'sh = do'konda
  /// yo'q (bugungi holat) — paywall serverdan kelgan `price_usd` ni ko'rsatadi.
  static String modulePrice(String module) =>
      _modProducts[moduleProductIds[module]]?.price ?? '';

  /// Mahsulot ID'sidan modul nomi (teskari xarita). Premium mahsulotida null.
  static String? moduleOf(String pid) {
    for (final e in moduleProductIds.entries) {
      if (e.value == pid) return e.key;
    }
    return null;
  }

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
        // Oqim xatosi ilgari JIMGINA yutilardi — spinner esa faqat 20s taymer bilan
        // o'chardi va foydalanuvchi sababini bilmasdi (2026-08-02 audit).
        onError: (_) {
          _busyTimer?.cancel();
          onBusy?.call(false);
          onError?.call("To'lov servisi bilan aloqa uzildi — qayta urinib ko'ring");
        },
      );
      await _loadProduct();
      await _loadModuleProducts(); // topilmasa jim o'tadi (mahsulotlar hali yo'q)
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

  /// Modul mahsulotlarini bitta so'rovda oladi. Do'konda hali yaratilmaganlari
  /// `notFoundIDs`ga tushadi — bu XATO EMAS, shunchaki narx ko'rsatilmaydi.
  /// Timeout: do'kon javob bermasa startap osilib qolmasin.
  static Future<void> _loadModuleProducts() async {
    try {
      final resp = await _iap
          .queryProductDetails(moduleProductIds.values.toSet())
          .timeout(const Duration(seconds: 10));
      for (final p in resp.productDetails) {
        _modProducts[p.id] = p;
      }
    } catch (_) {/* keyin buyModule() qayta urinadi */}
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

  /// Modul obunasini sotib olish (paywall CTA). Eski premium oqimiga TEGMAYDI.
  ///
  /// Qaytadi:
  ///   false — do'kon yoki mahsulot MAVJUD EMAS (Android, StoreKit o'chiq, yoki
  ///           mahsulot hali yaratilmagan). Chaqiruvchi (store.paywallBuy_) mavjud
  ///           toast mexanizmi bilan "to'lov tez orada" xabarini ko'rsatadi —
  ///           bu yerda onError CHAQIRILMAYDI (ikkita xabar chiqmasin).
  ///   true  — to'lov oynasi ochildi; natija purchaseStream orqali keladi.
  static Future<bool> buyModule(String module) async {
    final id = moduleProductIds[module];
    if (id == null) return false; // noma'lum modul ("tez orada" bo'lishi mumkin)
    if (!Platform.isIOS) return false; // Android: Play Billing hali ulanmagan
    if (!_storeReady) return false; // StoreKit tayyor emas
    var pd = _modProducts[id];
    if (pd == null) {
      await _loadModuleProducts(); // bir marta qayta so'raymiz (do'kon yangilangan bo'lishi mumkin)
      pd = _modProducts[id];
      if (pd == null) return false; // mahsulot do'konda yo'q — jim, xatosiz
    }
    onBusy?.call(true);
    _armBusyTimeout(); // oyna ochilmay qolsa spinner osilib qolmasin
    try {
      final ok = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: pd));
      if (ok == false) {
        _busyTimer?.cancel();
        onBusy?.call(false);
        return false;
      }
      return true;
    } catch (_) {
      _busyTimer?.cancel();
      onBusy?.call(false);
      return false;
    }
  }

  /// "Xaridni tiklash" — qurilma almashtirilganda oldingi obunani qaytaradi (Apple talabi).
  /// MUHIM (2026-08-02 audit): hech qachon xarid qilmagan foydalanuvchida
  /// restorePurchases() HECH NARSA emitmaydi — ilgari spinner 20 soniya aylanib,
  /// so'ng JIMGINA to'xtardi va foydalanuvchi ilovani buzuq deb o'ylardi.
  static bool _sawResult = false;
  static Future<void> restore() async {
    if (!Platform.isIOS || !_storeReady) return;
    _sawResult = false;
    onBusy?.call(true);
    _armBusyTimeout(); // tiklashda hech nima kelmasa spinner osilib qolmasin
    try {
      await _iap.restorePurchases();
      // Natijalar purchaseStream orqali keladi — qisqa muhlat beramiz.
      await Future.delayed(const Duration(seconds: 3));
      if (!_sawResult) {
        _busyTimer?.cancel();
        onBusy?.call(false);
        onError?.call('Tiklanadigan xarid topilmadi');
      }
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
          _sawResult = true;
          final res = await _verify(p);
          onBusy?.call(false);
          if (res.ok) {
            // Modul mahsulotimi yoki eski premiummi — ID bo'yicha ajratamiz.
            final mod = moduleOf(p.productID);
            if (mod != null) {
              onModuleGranted?.call(mod);
            } else {
              onPremiumGranted?.call();
            }
          } else if (isRetryableVerify(res.status, res.code)) {
            // QAYTARILADIGAN xato — tranzaksiya OCHIQ qoladi, StoreKit uni qayta yuboradi.
            // status 0 — tarmoq/timeout; 5xx — server vaqtincha ishlamayapti;
            // 409 SUB_DB_NOT_READY — 020 migratsiya hali qo'llanmagan (deploy oynasi).
            // Bularda yopib yuborilsa: pul olingan, obuna yo'q, chek qaytarilmaydi.
            onError?.call("Chekni tasdiqlab bo'lmadi — biroz o'tib avtomatik qayta urinamiz");
            finish = false;
          } else {
            // MUHIM (2026-08-02 audit): 400/501 kabi DOIMIY xatolarda tranzaksiya
            // YOPILADI. Ilgari u ochiq qolar va StoreKit uni HAR bir ochilishda qayta
            // yuborardi: foydalanuvchidan pul olingan, premium yo'q, har startda qizil
            // xato, va o'sha SKU'ni qayta sotib ham bo'lmasdi.
            onError?.call("Xarid tasdiqlanmadi (${res.status}). Iltimos, Yordam chatiga yozing — "
                'biz qo\'lda tekshiramiz.');
            finish = true;
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

  /// Tasdiq so'rovining tanasi mahsulot ID'sidan (sof funksiya — testlanadi).
  ///
  /// MUHIM (2026-08-04 review, FINDING 1): server qaysi obunani yoqishni FAQAT
  /// `module` kaliti bo'yicha hal qiladi; klient `product_id`si ATAYLAB
  /// e'tiborsiz qoldiriladi (anti-fraud) va serverda product_id -> module
  /// xaritasi YO'Q. Ilgari bu yerdan faqat product_id ketardi: modul SKU'si
  /// do'konda yaratilishi bilanoq server eski premium mahsuloti bo'yicha
  /// tekshirar, chekda mos yozuv topilmasdi -> 400 -> _onPurchases 400'ni DOIMIY
  /// xato deb tranzaksiyani yopardi. Ya'ni pul olinib, modul ochilmasdi va
  /// StoreKit chekni boshqa qayta yubormasdi.
  ///
  /// Eski yagona premium mahsulotida `moduleOf` null qaytaradi — tana AYNAN
  /// avvalgidek (`module` kaliti YO'Q), ya'ni eski oqim o'zgarmaydi.
  static Map<String, dynamic> verifyBodyFor(String purchasedId, String receipt) {
    final pid = purchasedId.isNotEmpty ? purchasedId : productId;
    return Api.verifyAppleBody(receipt, productId: pid, module: moduleOf(purchasedId));
  }

  /// Tasdiq xatosida tranzaksiyani OCHIQ qoldirish kerakmi (sof funksiya — testlanadi).
  ///
  /// MUHIM (2026-08-04 review, FINDING 2): pul olingan, lekin server vaqtincha
  /// tasdiqlay olmagan holatda tranzaksiya YOPILSA, StoreKit chekni boshqa qayta
  /// yubormaydi — foydalanuvchi pulidan ayriladi va faqat "Xaridni tiklash" bilan
  /// qutqariladi. Shuning uchun VAQTINCHA xatolarda `false` (yopmaymiz):
  ///   status 0    — tarmoq/timeout
  ///   status >=500 — server xatosi
  ///   409 + SUB_DB_NOT_READY — 020 migratsiya hali qo'llanmagan (deploy oynasi)
  /// DIQQAT: boshqa 409'lar ("bu xarid boshqa akkauntniki", "boshqa obuna uchun
  /// ishlatilgan") DOIMIY — ular yopiladi, aks holda chek abadiy qaytaverardi.
  static bool isRetryableVerify(int status, String code) {
    if (status == 0) return true; // tarmoq/timeout
    // 501 ISTISNO: "To'lov hali ulanmagan" — serverning DOIMIY holati (imkoniyat yo'q),
    // vaqtinchalik nosozlik emas. Qayta urinish uni hech qachon tuzatmaydi, chek esa
    // har ochilishda qaytib, foydalanuvchiga har safar qizil xato ko'rsatardi.
    if (status >= 500 && status != 501) return true;
    return status == 409 && code == 'SUB_DB_NOT_READY';
  }

  static Future<ApiRes> _verify(PurchaseDetails p) async {
    // StoreKit 1: serverVerificationData = base64 app receipt. Backend Apple'da tekshiradi.
    final receipt = p.verificationData.serverVerificationData;
    if (receipt.isEmpty) return ApiRes(false, null, 'Chek bo\'sh', 400);
    return Api.verifyAppleRaw(verifyBodyFor(p.productID, receipt));
  }

  static void dispose() {
    _busyTimer?.cancel();
    _sub?.cancel();
  }
}
