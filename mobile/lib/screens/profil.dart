// Profil ekrani — prototype/template.html 654–681 bilan 1:1
// Qo'shimcha (prototipdan keyingi mahsulot qarori): obuna holati kartasi —
// sinov kunlari / premium sanasi / tugagan holat + $9/oy narxi (SubInfo: tab_bar.dart).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import 'tab_bar.dart' show SubInfo, subTr, subWarnInk;

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

    return ListView(
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
    );
  }
}

/// Obuna holati kartasi — profildagi "obuna bo'limi".
/// Uch holat aniq ko'rsatiladi: sinov (N kun qoldi) / Premium (sanagacha) /
/// tugagan (read-only ogohlantirish). Narx har doim ko'rinadi: $9/oy.
/// CTA hozircha halol dev-stub (Play Billing keyingi bosqichda —
/// keyin bu yerda in_app_purchase + POST /me/subscription/verify chaqiriladi).
class _SubCard extends StatelessWidget {
  const _SubCard();

  String _d2(int x) => x.toString().padLeft(2, '0');

  void _renewTap() {
    // To'lov hali ulanmagan — halol xabar (subInfo: "7 kun bepul, keyin $9/oy ...")
    store.toast_(store.L()['subInfo'] as String? ??
        "7 kun bepul, keyin \$9/oy — to'lov tez orada ulanadi");
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final sub = SubInfo.read();
    final L0 = store.L();
    final price = subTr('subPriceMonthly', '\$9/oy');
    final w = subWarnInk(store.S['dark'] == true);

    // Holat sarlavhasi
    String title;
    Color titleColor = p.ink;
    if (sub.expired) {
      title = subTr('subExpiredTitle', "To'lov muddati tugagan");
      titleColor = p.red;
    } else if (sub.status == 'premium') {
      final u = sub.until;
      title = u == null
          ? (L0['subPremium'] as String? ?? 'Premium')
          : subTr('subPremiumUntil', 'Premium · {d} gacha',
              {'d': '${_d2(u.day)}.${_d2(u.month)}.${u.year}'});
    } else {
      // trial; muddat hali kelmagan bo'lsa (birinchi soniyalar) — umumiy sarlavha
      title = sub.until == null
          ? subTr('subTrialTitle', 'Sinov davri')
          : store.Lf('subTrialLeft', {'n': '${sub.daysLeft}'});
    }

    final String body = sub.expired
        ? subTr('subExpiredBody', 'Yangi yozuv kirita olmaysiz — obunani yangilang')
        : (L0['subInfo'] as String? ?? "7 kun bepul, keyin \$9/oy — to'lov tez orada ulanadi");

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
              // Narx — har doim ko'rinadi
              Tx(price, size: 12.5, w: FontWeight.w700, color: p.ink, tab: true),
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
          // CTA: tugaganda asosiy (qora), aks holda kontur — bosim darajasi holatga mos
          sub.expired
              ? InkBtn(label: subTr('subRenew', 'Obunani yangilash'), h: 44, fs: 14, onTap: _renewTap)
              : GhostBtn(label: subTr('subRenew', 'Obunani yangilash'), h: 42, fs: 13.5, onTap: _renewTap),
        ],
      ),
    );
  }
}
