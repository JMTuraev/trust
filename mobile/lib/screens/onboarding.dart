// Onboarding — Xush kelibsiz / Telefon / OTP / PIN (template 1310–1400)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    Widget body;
    if (v['isBoot'] == true) {
      // Sessiya tekshirilmoqda — animatsiyali splash (welcome "miltillab" o'tmasin)
      body = const Center(child: TrustMarkAnim(size: 96, boxed: true));
    } else if (v['isOnbWelcome'] == true) {
      body = _welcome(v, p, L0);
    } else if (v['isOnbPhone'] == true) {
      body = _phone(v, p, L0);
    } else if (v['isOnbOtp'] == true) {
      body = _otp(v, p, L0);
    } else if (v['isOnbPin'] == true) {
      body = _pin(v, p, L0);
    } else {
      return const SizedBox.shrink();
    }
    return Container(color: p.bg, child: body);
  }

  // 0a · Xush kelibsiz — markazda brend logotip (Qavat toshlar)
  Widget _welcome(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const TrustMarkAnim(size: 84, boxed: true), // kirishda animatsiyali logo
                const SizedBox(height: 22),
                Tx('Trust', size: 32, w: FontWeight.w700, color: p.ink, ls: -0.5),
                const SizedBox(height: 14),
                Tx(
                  L0['tagline'] as String,
                  size: 14,
                  color: p.t1,
                  lh: 22.4,
                  align: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
          child: Column(
            children: [
              InkBtn(label: L0['start'] as String, h: 52, onTap: () => v['startOnb']()),
              const SizedBox(height: 14),
              Tx(
                L0['terms'] as String,
                size: 11,
                color: p.t5,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 0b · Telefon raqami
  Widget _phone(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: BackBtn(onTap: () => v['backToWelcome']()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tx(L0['phoneTitle'] as String, size: 24, w: FontWeight.w700, color: p.ink, ls: -0.4),
              const SizedBox(height: 8),
              Tx(L0['phoneSub'] as String, size: 13.5, color: p.t2, lh: 20.25),
              const SizedBox(height: 28),
              Row(
                children: [
                  Tap(
                    onTap: () => v['ccOpenOnb'](),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: p.bd),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tx(v['onbFlag'], size: 19, color: p.ink, lh: 19),
                          const SizedBox(width: 7),
                          Tx(v['onbDial'], size: 17, w: FontWeight.w600, color: p.ink, tab: true),
                          const SizedBox(width: 7),
                          Transform.translate(
                            offset: const Offset(0, -3),
                            child: Transform.rotate(
                              angle: 0.785398,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: p.t3, width: 1.6),
                                    bottom: BorderSide(color: p.t3, width: 1.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: Border.all(color: p.bd),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: StoreField(
                        value: v['phoneText'],
                        onChanged: (t) => v['onPhone'](t),
                        hint: v['onbPh'],
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              InkBtn(label: L0['cont'] as String, h: 52, onTap: () => v['phoneNext']()),
            ],
          ),
        ),
      ],
    );
  }

  // 0c · Tasdiqlash kodi
  Widget _otp(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: BackBtn(onTap: () => v['backToPhone']()),
        ),
        // Expanded+scroll: klaviatura/kichik ekranda kontent siqilib overflow bermasligi uchun
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(L0['otpTitle'] as String, size: 24, w: FontWeight.w700, color: p.ink, ls: -0.4),
                const SizedBox(height: 8),
                Tx('${v['otpPhone']}', size: 13.5, w: FontWeight.w600, color: p.t2, maxLines: 1, tab: true),
                const SizedBox(height: 28),
                Center(
                  child: CodeBoxes(
                    boxes: (v['otpBoxes'] as List).cast<Map<String, dynamic>>(),
                    w: 50,
                    h: 58,
                    fs: 24,
                    gap: 9,
                    r: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Tx(v['L']['otpDemo'] as String, size: 12, color: p.t4),
                const SizedBox(height: 24),
                InkBtn(label: L0['confirm'] as String, h: 52, onTap: () => v['otpConfirm']()),
              ],
            ),
          ),
        ),
        KeyPad(keys: (v['otpKeys'] as List).cast<Map<String, dynamic>>()),
      ],
    );
  }

  // 0d · PIN o'rnating
  Widget _pin(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: BackBtn(onTap: () => v['backToOtp']()),
          ),
        ),
        // Expanded+scroll: kichik joyda overflow bermasligi uchun
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Tx(v['pinTitle'] as String, size: 24, w: FontWeight.w700, color: p.ink, ls: -0.4, align: TextAlign.center),
                const SizedBox(height: 8),
                Tx(v['pinSub'] as String, size: 13.5, color: p.t2, align: TextAlign.center),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < (v['pinDots'] as List).length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Noto'g'ri PIN — nuqtalar qizil (xato signali)
                          border: Border.all(
                            color: v['pinErr'] == true ? const Color(0xFFE5484D) : p.ink,
                            width: 1.5,
                          ),
                          color: v['pinErr'] == true
                              ? const Color(0xFFE5484D)
                              : (v['pinDots'] as List)[i]['bg'] as Color,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        KeyPad(keys: (v['pinKeys'] as List).cast<Map<String, dynamic>>()),
      ],
    );
  }
}
