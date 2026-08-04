// MODUL OBUNASI — paywall sheet'i.
//
// Ochilish: bosh hub kartasi qulflangan bo'lsa (bepul limit tugagan) yoki
// «Tez kunda» teaser qatori bosilsa — store: openPaywall(module).
// Ko'rinish tili: cc_sheet.dart / lang_sheet.dart (SheetShell + 24px yon padding).
//
// Store shartnomasi (hammasi HIMOYALI o'qiladi — kalit yo'q bo'lsa zaxira qiymat):
//   v['paywall']      -> {'module','price','soon','used','limit'} yoki null
//   v['paywallClose'] -> VoidCallback
//   v['paywallBuy']   -> VoidCallback
import 'package:flutter/material.dart';

import '../iap.dart';
import '../l10n.dart';
import '../store.dart';
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Sarlavha «...» bilan kesilmasin — uzun tarjima ikkinchi qatorga o'raladi
                child: Tx(title,
                    size: 18, w: FontWeight.w700, color: p.ink, lh: 24, maxLines: 2),
              ),
              const SizedBox(width: 12),
              // Narx — moliyaviy qiymat: hech qachon qisqarmaydi, sig'masa kichrayadi
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 11),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Tx(priceTxt,
                      size: 12.5, w: FontWeight.w700, color: p.t1, tab: true, maxLines: 1),
                ),
              ),
            ],
          ),
          // Modul nomi — tarjimasi bo'lmasa qator umuman chizilmaydi
          // (bo'sh matn o'rniga bo'shliq: xato ko'rinib tursin).
          if (name.isNotEmpty) ...[
            const SizedBox(height: 6),
            Tx(name, size: 12.5, color: p.t2, maxLines: 2),
          ],
          // Bepul limit qatori — faqat ochilgan (soon bo'lmagan) modullarda
          if (!soon && limit > 0) ...[
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Tx(
                modStrF('pwUsed', {'used': '$used', 'limit': '$limit'}),
                size: 12.5,
                color: locked ? p.red : p.t1,
                tab: true,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: p.barbg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: locked ? p.red : p.ink,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          for (final k in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.t4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Tx(modStr(k), size: 13.5, color: p.ink, lh: 19, maxLines: 3),
                  ),
                ],
              ),
            ),
          // Chegara siyosati — foydalar ostida, CTA'dan tepada: odam narxni
          // ko'rgach «nechta obyekt kiradi?» deb so'raydi, javob shu yerda.
          // Tarjimasi yo'q bo'lsa blok umuman chizilmaydi (bo'sh quti chiqmasin).
          if (capTxt.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Tx(capTxt, size: 12, color: p.t2, lh: 17.5, maxLines: 4),
            ),
          const SizedBox(height: 12),
          if (soon) ...[
            // «Tez kunda» — bosilmaydigan pill (CTA o'rniga)
            Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Tx(modStr('modSoon'), size: 15, w: FontWeight.w600, color: p.t2),
            ),
            const SizedBox(height: 10),
            Tx(modStrF('pwSoonNote', {'price': '$price'}),
                size: 11.5, color: p.t3, lh: 17, maxLines: 3),
          ] else
            InkBtn(
              label: modCtaLabel(module, price),
              // Xarid ketayotganda spinner + qayta bosish bloklanadi
              // (profil.dart bilan bir xil manba: store.S['iapBusy']).
              loading: store.S['iapBusy'] == true,
              onTap: () {
                final f = v['paywallBuy'];
                if (f is Function) f();
              },
            ),
        ],
      ),
    );
  }
}
