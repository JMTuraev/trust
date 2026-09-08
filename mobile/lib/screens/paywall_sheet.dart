// MODUL OBUNASI — paywall sheet'i. Dizayn: prototype/redesign/DESIGN_SPEC.md §5.17
// (gradient qutida crown · "{Modul} PRO" sarlavha · bepul limit kartasi ·
// 4 foyda · GradientBtn CTA · "Xaridni tiklash" · Apple 3.1.2 bloki).
//
// Ochilish: bosh hub kartasi qulflangan bo'lsa (bepul limit tugagan) yoki
// «Tez kunda» teaser qatori bosilsa — store: openPaywall(module).
//
// Store shartnomasi (hammasi HIMOYALI o'qiladi — kalit yo'q bo'lsa zaxira qiymat):
//   v['paywall']      -> {'module','price','soon','used','limit'} yoki null
//   v['paywallClose'] -> VoidCallback
//   v['paywallBuy']   -> VoidCallback
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart' show apiUrl;
import '../iap.dart';
import '../l10n.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

/// Modul narxi (oyiga, $) — server qiymat bermaganda ishlatiladigan zaxira.
/// YAGONA MANBA: store.dart'dagi kSubModuleDefaults (backend kontrakti bilan
/// bir joyda turadi) — bu yerda takrorlanmaydi.
int modDefPrice(String module) {
  final v = kSubModuleDefaults[module]?['price'];
  return v is int ? v : 0;
}

/// Modul hali sotuvda emasmi («tez kunda») — server aytmasa lokal standart.
bool modDefSoon(String module) => kSubModuleDefaults[module]?['soon'] == true;

/// Modul nomining l10n kaliti.
const Map<String, String> kModNameKey = {
  'xarajat': 'modXarajat',
  'qarz': 'modQarz',
  'ijarachi': 'modIjarachi',
  'toyxona': 'modToyxona',
};

/// Paywall sarlavhasining l10n kaliti.
const Map<String, String> kModTitleKey = {
  'xarajat': 'pwTitleXarajat',
  'qarz': 'pwTitleQarz',
  'ijarachi': 'pwTitleIjarachi',
  'toyxona': 'pwTitleToyxona',
};

/// Bitta obuna qamrab oladigan OBYEKT soni — backend YAGONA manbasi
/// src/lib/subscription.js: MODULES.<module>.max_units (ijarachi 5, toyxona 1).
/// Modul bu jadvalda bo'lmasa chegara umuman yo'q (xarajat/qarz — yozuv soni
/// bepul limit bilan boshqariladi, obyekt tushunchasi yo'q).
const Map<String, int> kModCapUnits = {'ijarachi': 5, 'toyxona': 1};

/// Chegara siyosati izohining l10n kaliti (faqat kModCapUnits'dagi modullarda).
///
/// NEGA KERAK (PO 2026-08-04): javob G'AYRIODDIY — chegaraga yetgan odam
/// «ko'proq» tarifiga o'tmaydi, BOSHQA telefon raqamiga alohida hisob ochadi.
/// Buni paywall'da AYTMASA, foydalanuvchi 6-uyni qo'sha olmay qolib "ilova
/// buzuq" deb o'ylaydi. Izohda NARX yozilmaydi — narx allaqachon yuqorida.
const Map<String, String> kModCapKey = {
  'ijarachi': 'pwCapIjara',
  'toyxona': 'pwCapToy',
};

/// Har modul uchun 4 ta foyda qatori (l10n kalitlari).
const Map<String, List<String>> kModBenefitKeys = {
  'xarajat': ['pwBenXar1', 'pwBenXar2', 'pwBenXar3', 'pwBenXar4'],
  'qarz': ['pwBenQarz1', 'pwBenQarz2', 'pwBenQarz3', 'pwBenQarz4'],
  'ijarachi': ['pwBenIjara1', 'pwBenIjara2', 'pwBenIjara3', 'pwBenIjara4'],
  'toyxona': ['pwBenToy1', 'pwBenToy2', 'pwBenToy3', 'pwBenToy4'],
};

/// Modul matni: joriy til -> zaxira o'zbekcha (UI'da qotirilgan satr yo'q).
String modStr(String key) =>
    (store.L()[key] as String?) ?? (lUz[key] as String? ?? '');

/// {token} almashtirishli variant (narx, limit va h.k.).
String modStrF(String key, Map<String, String> vars) {
  var s = modStr(key);
  vars.forEach((k, val) => s = s.replaceAll('{$k}', val));
  return s;
}

/// «$5/oy» ko'rinishidagi narx yorlig'i (katalog narxi — bizning USD ro'yxatimiz).
String modPriceTxt(int price) => modStrF('modPerMonth', {'price': '$price'});

/// KO'RSATILADIGAN narx — YAGONA qoida (PO 2026-08-04 qarori):
///   1) do'kon narxi bor bo'lsa AYNAN o'sha (foydalanuvchi haqiqatan to'laydigan
///      summa, o'z valyutasida: «24 000 so'm/oy»);
///   2) bo'lmasa — katalog narxi («$13/oy»), ya'ni ro'yxat narxi ko'rsatkich sifatida.
///
/// NEGA IKKALASI: faqat do'kon narxi qoidasi bugun barcha narxlarni YO'Q qilardi —
/// mahsulotlar Play/App Store'da hali yaratilmagan, ya'ni `modulePrice` hamma uchun
/// bo'sh. Faqat katalog qoidasi esa UZS'da to'laydigan foydalanuvchiga u hech qachon
/// to'lamaydigan «$13» ni ko'rsatardi (aynan shu sabab eski `$9/oy` matni tashlangan).
/// Hozir katalog ko'rinadi, mahsulotlar yaratilgan kuni AVTOMATIK haqiqiy narxga o'tadi.
String modPriceLabel(String module, int catalogPrice) {
  final store = IapService.modulePrice(module);
  if (store.isNotEmpty) return modStrF('modPerMonthCur', {'price': store});
  return modPriceTxt(catalogPrice);
}

/// Sotib olish tugmasi yorlig'i — XARID NUQTASI, shuning uchun narx aniqligi
/// eng muhim joy: do'kon narxi bo'lsa doim o'sha ishlatiladi.
String modCtaLabel(String module, int catalogPrice) {
  final store = IapService.modulePrice(module);
  if (store.isNotEmpty) return modStrF('pwCtaCur', {'price': store});
  return modStrF('pwCta', {'price': '$catalogPrice'});
}

/// Tashqi havolani ochish (profil.dart bilan bir xil naqsh) — ochilmasa jim o'tadi.
Future<void> _openUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {/* havola ochilmadi — jim o'tamiz */}
}

/// Apple standart EULA — o'z shartnomamiz yo'q, ASC'da ham AYNAN shu havola turadi.
const String _kEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Paywall ostidagi Apple 3.1.2 bloki: avtoyangilanish sharti, «Xaridni tiklash»
/// va ikki havola (EULA + Maxfiylik).
///
/// NEGA PAYWALL'DA: bu ma'lumotlar profil kartasida bor edi, XARID NUQTASIDA esa
/// yo'q. Apple aynan shu sabab (3.1.2(c) — «obuna uchun nima berilishi va sharti
/// aniq emas») AllClubs'ni 2026-07-17 da rad etgan.
///
/// `price` — CTA tugmasidagi summa bilan BIR XIL manbadan keladi: ikki xil summa
/// oshkorlikning o'zini buzadi.
class _ApplePaywallTerms extends StatelessWidget {
  final String price;
  const _ApplePaywallTerms({required this.price});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final busy = store.S['iapBusy'] == true;
    final linkStyle = tbStyle(size: 12, w: FontWeight.w600, color: p.t2).copyWith(decoration: TextDecoration.underline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // «Xaridni tiklash» — Apple talabi (qurilma almashsa obuna qaytadi).
        // Xarid ketayotganda bosilmaydi: ikki oqim bir vaqtda ishlamasin.
        Center(
          child: TextBtn(
            label: modStr('subRestore'),
            h: 44, fs: 15, color: p.t1,
            onTap: busy ? () {} : () => store.restorePremium(),
          ),
        ),
        const SizedBox(height: 4),
        Tx(modStrF('pwAutoRenew', {'price': price}),
            size: 12, color: p.t4, lh: 16, maxLines: 5),
        const SizedBox(height: 8),
        Row(
          children: [
            Tap(
              onTap: () => _openUrl(_kEulaUrl),
              child: Text(modStr('subTerms'), style: linkStyle, textScaler: TextScaler.noScaling),
            ),
            Tx('   ·   ', size: 12, color: p.t6),
            Tap(
              onTap: () => _openUrl('$apiUrl/privacy'),
              child: Text(modStr('subPrivacy'), style: linkStyle, textScaler: TextScaler.noScaling),
            ),
          ],
        ),
      ],
    );
  }
}

class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    // Sheet ko'rinishini store boshqaradi — bu yerda Navigator ishlatilmaydi.
    final pw = (v['paywall'] as Map?)?.cast<String, dynamic>() ?? const {};
    final module = (pw['module'] as String?) ?? 'xarajat';
    final soon = pw['soon'] == true || (pw['soon'] == null && modDefSoon(module));
    final price = (pw['price'] as int?) ?? modDefPrice(module);
    final used = (pw['used'] as int?) ?? 0;
    final limit = (pw['limit'] as int?) ?? 0;
    final locked = limit > 0 && used >= limit;
    final priceTxt = modPriceLabel(module, price);
    // Avtoyangilanish matnidagi summa — «/oy» qo'shimchasisiz xom narx:
    // «hisobingizdan $9.99/oy yechiladi» ikki marta davr aytgan bo'lardi.
    final storePrice = IapService.modulePrice(module);
    final rawPrice = storePrice.isNotEmpty ? storePrice : '\$$price';
    final benefits = kModBenefitKeys[module] ?? const <String>[];

    // NOTANISH MODUL (jadvallardan birida yo'q yoki tarjimasi qo'shilmagan):
    // XARAJAT satrlari ZAXIRA QILINMAYDI. Ilgari `?? 'modXarajat'` sabab yangi
    // modul boshqa modulning narxi yonida «Xarajatlar» deb ochilardi — jim va
    // NOTO'G'RI, ustiga pul haqidagi ekranda. Endi modul KODI chiqadi
    // (sarlavha) va nomi bo'sh qoladi — bo'shliq darhol ko'zga tashlanadi.
    final titleKey = kModTitleKey[module];
    final titleTr = titleKey == null ? '' : modStr(titleKey);
    final title = titleTr.isNotEmpty ? titleTr : module;
    final nameKey = kModNameKey[module];
    final name = nameKey == null ? '' : modStr(nameKey);
    // Obyekt chegarasi bo'lgan modullarda («5 uygacha», «1 to'yxona») siyosat
    // izohi chiziladi: chegaradan oshsa — boshqa raqamga alohida hisob.
    final capKey = kModCapKey[module];
    final capTxt = capKey == null
        ? ''
        : modStrF(capKey, {'n': '${kModCapUnits[module] ?? 0}'});

    return SheetShell(
      onClose: () {
        // Himoyali chaqiruv: kalit hali qo'shilmagan bo'lsa sheet shunchaki turadi
        final f = v['paywallClose'];
        if (f is Function) f();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 64px r22 gradient qutida crown (soya Tb.glow)
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: Tb.brandDiag,
                borderRadius: BorderRadius.circular(22),
                boxShadow: Tb.glow,
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 30, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          // Modul nomi + PRO (tarjimasi bo'lmasa modul kodi — bo'shliq ko'rinib tursin)
          Tx('${name.isNotEmpty ? name : module} PRO',
              size: 24, w: FontWeight.w600, color: p.ink, font: TbFont.head, align: TextAlign.center, maxLines: 2),
          const SizedBox(height: 6),
          // Sarlavha (l10n «Xarajatlar — cheksiz yozuv») — tavsif sifatida
          Tx(title, size: 15, color: p.t2, align: TextAlign.center, lh: 21, maxLines: 3),
          const SizedBox(height: 6),
          // Narx yorlig'i — moliyaviy qiymat: hech qachon qisqarmaydi, sig'masa kichrayadi
          Center(child: PillBadge.cyan(priceTxt, h: 28)),
          // Bepul limit kartasi — faqat ochilgan (soon bo'lmagan) modullarda
          if (!soon && limit > 0) ...[
            const SizedBox(height: 16),
            GlassCard(
              r: 20,
              pad: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Tx(
                          modStrF('pwUsed', {'used': '$used', 'limit': '$limit'}),
                          size: 14, color: locked ? p.coral : p.t1, maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Tx('$used/$limit', size: 15, w: FontWeight.w600, color: locked ? p.coral : p.ink, tab: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.ink.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: Tb.amberCoral,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // 4 foyda: 32px mint15 doira check + 15 matn
          for (final k in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.mint.withValues(alpha: .15)),
                    child: Icon(Icons.check_rounded, size: 18, color: p.mint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Tx(modStr(k), size: 15, color: p.ink, lh: 21, maxLines: 3),
                    ),
                  ),
                ],
              ),
            ),
          // Chegara siyosati — foydalar ostida, CTA'dan tepada: odam narxni
          // ko'rgach «nechta obyekt kiradi?» deb so'raydi, javob shu yerda.
          // Tarjimasi yo'q bo'lsa blok umuman chizilmaydi (bo'sh quti chiqmasin).
          if (capTxt.isNotEmpty)
            GlassCard(
              r: 16,
              pad: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Tx(capTxt, size: 13, color: p.t2, lh: 18, maxLines: 4),
            ),
          const SizedBox(height: 16),
          if (soon) ...[
            // «Tez kunda» — bosilmaydigan pill (CTA o'rniga)
            GradientBtn(label: modStr('modSoon'), onTap: null, enabled: false),
            const SizedBox(height: 10),
            Tx(modStrF('pwSoonNote', {'price': '$price'}),
                size: 12, color: p.t3, lh: 17, maxLines: 3, align: TextAlign.center),
          ] else
            GradientBtn(
              label: modCtaLabel(module, price),
              // Xarid ketayotganda spinner + qayta bosish bloklanadi
              // (profil.dart bilan bir xil manba: store.S['iapBusy']).
              loading: store.S['iapBusy'] == true,
              onTap: () {
                final f = v['paywallBuy'];
                if (f is Function) f();
              },
            ),
          // Apple 3.1.2 majburiy oshkorligi — FAQAT iOS'da va faqat sotuvdagi
          // modullarda ("tez kunda" holatida xarid tugmasining o'zi yo'q).
          if (Platform.isIOS && !soon) ...[
            const SizedBox(height: 8),
            _ApplePaywallTerms(price: rawPrice),
          ],
        ],
      ),
    );
  }
}
