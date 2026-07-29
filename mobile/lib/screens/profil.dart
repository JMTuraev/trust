// Profil ekrani — prototype/template.html 654–681 bilan 1:1
// Qo'shimcha (prototipdan keyingi mahsulot qarori): obuna holati kartasi —
// sinov kunlari / premium sanasi / tugagan holat + $9/oy narxi (SubInfo: tab_bar.dart).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../store.dart';
import '../ui.dart';
import '../iap.dart';
import '../api.dart' show apiUrl;
import 'tab_bar.dart' show SubInfo, subTr, subWarnInk;

/// Tashqi havolani ochish (Apple 3.1.2 — Shartlar / Maxfiylik). Ochib bo'lmasa jim o'tadi.
Future<void> _openUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {/* havola ochilmadi — jim o'tamiz */}
}

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final rows = (v['profRows'] as List).cast<Map<String, dynamic>>();
    // Avatar picker keshida saqlanadi — OS keshni tozalasa fayl yo'qoladi;
    // yo'q faylni FileImage'ga bersak render xatosi bo'ladi, shuning uchun tekshiramiz.
    final avatarPath = v['meAvatar'] as String?;
    final File? avatarFile =
        (avatarPath != null && File(avatarPath).existsSync()) ? File(avatarPath) : null;

    return Stack(
      children: [
        ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar — bosilsa galereyadan rasm tanlanadi (edit photo)
              Tap(
                onTap: () => v['pickAvatar'](),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: p.card2,
                        shape: BoxShape.circle,
                        image: avatarFile != null
                            ? DecorationImage(image: FileImage(avatarFile), fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarFile == null
                          ? Tx(v['meInitials'], size: 22, w: FontWeight.w600, color: p.ink)
                          : null,
                    ),
                    Positioned(
                      right: -2, bottom: -2,
                      child: Container(
                        width: 24, height: 24, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.ink, shape: BoxShape.circle,
                          border: Border.all(color: p.bg, width: 2),
                        ),
                        child: Icon(Icons.photo_camera_outlined, size: 12, color: p.bg),
                      ),
                    ),
                  ],
                ),
              ),
              if (v['meEditing'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border.all(color: p.bd),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: StoreField(
                            value: v['meEditVal'],
                            onChanged: (t) => v['onMeName'](t),
                            hint: L0['yourNameHint'] as String,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
                            onSubmit: () => v['meNameSave'](),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tap(
                        onTap: () => v['meNameSave'](),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(18)),
                          child: Tx(L0['btnOk'] as String, size: 12.5, w: FontWeight.w600, color: p.bg),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  // Ism — mijozlarga shu ko'rinadi; bosib tahrirlash mumkin
                  child: Tap(
                    onTap: () => v['meEditToggle'](),
                    child: Tx(v['meName'], size: 18, w: FontWeight.w700, color: p.ink),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tx(v['mePhoneFmt'], size: 13, color: p.t2),
              ),
              // 8 xonali unikal ID (PO 2026-07-28) — kengayish uchun; nusxalash oson format
              if ('${v['meNoFmt'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Tx('${v['meNoFmt']}', size: 12, w: FontWeight.w600, color: p.t4, tab: true),
                ),
            ],
          ),
        ),
        // Obuna bo'limi — holat kartasi (sinov/premium/tugagan) + $9/oy + CTA.
        // DIQQAT: const EMAS — store o'zgarganda qayta qurilishi kerak.
        _SubCard(),
        for (final pr in rows)
          Tap(
            onTap: pr['tap'],
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(
                children: [
                  // danger (profil o'chirish) — qizil rangda
                  Expanded(child: Tx(pr['label'], size: 14.5, color: pr['danger'] == true ? p.red : p.ink)),
                  const SizedBox(width: 12),
                  if (pr['isSwitch'] == true)
                    Container(
                      width: 44,
                      height: 26,
                      decoration: BoxDecoration(
                        color: pr['trk'],
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            top: 3,
                            left: pr['knobLeft'],
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: pr['knob'],
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (pr['isPlain'] == true) ...[
                    Tx(pr['value'], size: 13, color: p.t3),
                    const SizedBox(width: 12),
                    ChevRight(color: p.t6),
                  ],
                ],
              ),
            ),
          ),
        Tap(
          onTap: v['logout'],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tx((v['L'] as Map)['logout'] as String, size: 14.5, w: FontWeight.w600, color: p.ink),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Tx(L0['versionFooter'] as String, size: 11, color: p.t6)),
        ),
      ],
        ),
        // #34: profil o'chirish — SMS kod bilan tasdiqlash modali
        if (v['delOtpOpen'] == true) _DelOtpModal(v: v),
      ],
    );
  }
}

/// #34: Profilni o'chirish — OTP tasdiqlash modali.
/// Telefon QAYTA yozilmaydi (bazadagi raqamga kod yuborilgan); faqat kod kiritiladi.
/// Ogohlantirish: tasdiqlansa profil o'chiriladi va yozuvlarga kirish yopiladi.
class _DelOtpModal extends StatefulWidget {
  final Map<String, dynamic> v;
  const _DelOtpModal({required this.v});

  @override
  State<_DelOtpModal> createState() => _DelOtpModalState();
}

class _DelOtpModalState extends State<_DelOtpModal> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _t(String key, String fb) => (store.L()[key] as String?) ?? fb;

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final v = widget.v;
    final busy = v['delOtpBusy'] == true;
    final phone = '${v['delOtpPhone'] ?? ''}';
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : () => (v['delOtpCancel'] as Function)(),
        child: Container(
          color: p.dim,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.bg,
                border: Border.all(color: p.bd2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 40, offset: const Offset(0, 16)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx(_t('delOtpTitle', "Profil o'chirilsinmi?"), size: 16, w: FontWeight.w700, color: p.red),
                  const SizedBox(height: 6),
                  Tx(
                    _t('delOtpWarn',
                        "Diqqat: profilingiz o'chiriladi va barcha yozuvlaringizga kirish yopiladi."),
                    size: 12.5, color: p.t1, lh: 17,
                  ),
                  const SizedBox(height: 4),
                  Tx(
                    phone.isEmpty
                        ? _t('delOtpSentTo', 'Raqamingizga yuborilgan SMS kodni kiriting:')
                        : '${_t('delOtpSentTo2', 'SMS kod yuborildi:')} $phone',
                    size: 12.5, color: p.t3, lh: 17,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TextStyle(
                        color: p.ink, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 6),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '•••••',
                      hintStyle: TextStyle(color: p.t5, letterSpacing: 6),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.bd)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.bd)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.red)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GhostBtn(
                          label: _t('btnCancel', 'Bekor qilish'), h: 42, fs: 13.5,
                          onTap: () { if (!busy) (v['delOtpCancel'] as Function)(); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkBtn(
                          label: _t('delOtpBtn', "O'chirish"), h: 42, fs: 13.5, loading: busy,
                          onTap: () => (v['delOtpConfirm'] as Function)(_code.text),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Obuna holati kartasi — profildagi "obuna bo'limi" + Apple IAP paywall.
///
/// iOS: StoreKit orqali $9/oy premium sotib olish (store.buyPremium) + Apple
///   Guideline 3.1.2 MAJBURIY ma'lumotlari: avtomatik yangilanish, narx/davr,
///   bekor qilish yo'li, "Xaridni tiklash", Foydalanish shartlari + Maxfiylik havolalari.
///   Bularsiz App Store rad etadi.
/// Android: hozircha halol xabar (Play Billing keyin) — kvota modeli serverda (402).
class _SubCard extends StatelessWidget {
  const _SubCard();

  String _d2(int x) => x.toString().padLeft(2, '0');

  void _renewTap() {
    // Android / IAP mavjud emas — halol xabar (yangi tarif: 3 ta yozuv bepul).
    store.toast_(store.L()['subInfo'] as String? ??
        "3 ta yozuv bepul, keyin \$9/oy — to'lov tez orada ulanadi");
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final sub = SubInfo.read();
    final L0 = store.L();
    final w = subWarnInk(store.S['dark'] == true);
    final bool ios = Platform.isIOS;
    final bool busy = store.S['iapBusy'] == true;
    final bool isPremium = sub.status == 'premium';

    // Narx — StoreKit lokalizatsiyalangan narxi bo'lsa o'shani (masalan "$8.99"),
    // aks holda $9/oy. Apple do'kon narxini ko'rsatishni talab qiladi.
    final String storePrice = IapService.priceLabel;
    final String priceMonthly =
        storePrice.isNotEmpty ? storePrice : subTr('subPriceMonthly', '\$9/oy');
    final String priceTop = storePrice.isNotEmpty ? '$storePrice/oy' : priceMonthly;

    // Holat sarlavhasi
    String title;
    Color titleColor = p.ink;
    if (isPremium) {
      final u = sub.until;
      title = u == null
          ? (L0['subPremium'] as String? ?? 'Premium')
          : subTr('subPremiumUntil', 'Premium · {d} gacha',
              {'d': '${_d2(u.day)}.${_d2(u.month)}.${u.year}'});
    } else if (sub.expired) {
      title = subTr('subExpiredTitle', "To'lov muddati tugagan");
      titleColor = p.red;
    } else {
      title = subTr('subFreeTitle', 'Bepul reja');
    }

    // Karta matni
    final String body = isPremium
        ? subTr('subPremiumBody', 'Cheksiz qarz va xarajat yozuvlari yoqilgan. Rahmat!')
        : sub.expired
            ? subTr('subExpiredBody', 'Yangi yozuv kirita olmaysiz — obunani yangilang')
            : ios
                ? subTr('subPitch', 'Cheksiz qarz va xarajat yozuvlari — {price}.',
                    {'price': priceMonthly})
                : (L0['subInfo'] as String? ??
                    "3 ta yozuv bepul, keyin \$9/oy — to'lov tez orada ulanadi");

    // CTA yo'nalishi: iOS'da StoreKit xaridi; boshqa joyda halol xabar.
    final VoidCallback cta = ios ? () => store.buyPremium() : _renewTap;
    final String ctaLabel =
        isPremium ? subTr('subManage', 'Obunani boshqarish') : subTr('subRenew', 'Obunani yangilash');

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sub.expired ? p.red.withValues(alpha: .07) : p.hov2,
        border: Border.all(color: sub.expired ? p.red.withValues(alpha: .30) : p.bd2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Cap((L0['profSub'] as String? ?? 'Obuna').toUpperCase())),
              // Narx — har doim ko'rinadi (do'kon narxi bo'lsa o'shani)
              Tx(priceTop, size: 12.5, w: FontWeight.w700, color: p.ink, tab: true),
            ],
          ),
          const SizedBox(height: 10),
          Tx(title, size: 16, w: FontWeight.w700, color: titleColor),
          const SizedBox(height: 4),
          Tx(body, size: 12.5, color: p.t1, lh: 17),
          // ≤3 kun qolgan bo'lsa — kartada ham ogohlantirish (banner bilan bir ohangda)
          if (sub.warnSoon) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: w),
                const SizedBox(width: 6),
                Expanded(
                  child: Tx(
                    subTr('subWarnSoon', "To'lov muddati yaqinlashdi — {n} kun qoldi",
                        {'n': '${sub.daysLeft}'}),
                    size: 12, w: FontWeight.w600, color: w, lh: 16,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          // CTA — busy bo'lsa spinnerli (bosish bloklangan). Tugaganda asosiy (qora),
          // aks holda kontur. loading param InkBtn/GhostBtn'da o'zi spinner ko'rsatadi.
          sub.expired
              ? InkBtn(label: ctaLabel, h: 44, fs: 14, onTap: cta, loading: busy)
              : GhostBtn(label: ctaLabel, h: 42, fs: 13.5, onTap: cta, loading: busy),

          // ---- iOS: Apple 3.1.2 majburiy ma'lumotlari + Restore + havolalar ----
          if (ios) ...[
            const SizedBox(height: 10),
            // "Xaridni tiklash" — Apple talabi (qurilma almashsa obuna qaytadi)
            Center(
              child: Tap(
                onTap: busy ? () {} : () => store.restorePremium(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Tx(subTr('subRestore', 'Xaridni tiklash'),
                      size: 12.5, w: FontWeight.w600, color: p.t2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Avtomatik yangilanish sharti + bekor qilish yo'li (majburiy oshkorlik)
            Tx(
              subTr(
                'subAutoRenewNote',
                'Obuna avtomatik yangilanadi. Joriy davr tugashidan 24 soat oldin '
                    'hisobingizdan {price} yechiladi. Istalgan vaqtda bekor qilish: '
                    'App Store → Apple ID → Obunalar.',
                {'price': priceMonthly},
              ),
              size: 11, color: p.t4, lh: 15,
            ),
            const SizedBox(height: 7),
            // Foydalanish shartlari (Apple standart EULA) + Maxfiylik siyosati — tappable
            Row(
              children: [
                Tap(
                  onTap: () => _openUrl(
                      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                  child: Text(
                    subTr('subTerms', 'Foydalanish shartlari'),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: p.t2,
                        decoration: TextDecoration.underline),
                  ),
                ),
                Tx('   ·   ', size: 11, color: p.t6),
                Tap(
                  onTap: () => _openUrl('$apiUrl/privacy'),
                  child: Text(
                    subTr('subPrivacy', 'Maxfiylik siyosati'),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: p.t2,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
