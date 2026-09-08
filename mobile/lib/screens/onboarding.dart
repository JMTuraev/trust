// Onboarding — Splash / 3 slayd / Telefon / OTP / PIN.
// Dizayn: prototype/redesign/DESIGN_SPEC.md §5.1–5.5 ("dark glass + gradient").
//
// Store shartnomasi o'zgarmadi: isBoot / isOnbWelcome / isOnbPhone / isOnbOtp /
// isOnbPin, startOnb, backToWelcome/backToPhone/backToOtp, phoneText/onPhone/
// phoneNext, ccOpenOnb, onbFlag/onbDial/onbPh, otpBoxes/otpKeys/otpConfirm,
// pinTitle/pinSub/pinDots/pinKeys/pinErr, busy.
import 'dart:async';

import 'package:flutter/material.dart';
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
    if (v['isBoot'] == true) {
      // Sessiya tekshirilmoqda — animatsiyali splash (welcome "miltillab" o'tmasin)
      return _splash(p);
    } else if (v['isOnbWelcome'] == true) {
      return _OnbSlides(onStart: () => v['startOnb'](), terms: L0['terms'] as String, startLabel: L0['start'] as String);
    } else if (v['isOnbPhone'] == true) {
      return _phone(v, p, L0);
    } else if (v['isOnbOtp'] == true) {
      return _otp(v, p, L0);
    } else if (v['isOnbPin'] == true) {
      return _pin(v, p, L0);
    }
    return const SizedBox.shrink();
  }

  // 5.1 · Splash — markazda pulsli brend logotipi + "Trustbook"
  Widget _splash(Pal p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TrustMarkAnim(size: 96),
          const SizedBox(height: 24),
          Tx('Trustbook', size: 28, w: FontWeight.w600, color: p.ink, font: TbFont.head),
        ],
      ),
    );
  }

  // 5.3 · Telefon raqami
  Widget _phone(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    final phoneText = '${v['phoneText'] ?? ''}';
    final mask = '${v['onbPh'] ?? ''}';
    final digits = phoneText.replaceAll(RegExp(r'\D'), '').length;
    final need = mask.replaceAll(RegExp(r'\D'), '').length;
    // To'liq — raqam maskadagi xonalar soniga yetganda (store.onPhone o'zi kesadi)
    final full = need == 0 || digits >= need;
    // Maska qoldig'i: kiritilgan matn kengligida shaffof nusxa + qolgan qismi t6.
    // Ikkalasi bir xil uslubda (26 Space Grotesk) — qoldiq aynan matndan keyin turadi.
    final rest = mask.length > phoneText.length ? mask.substring(phoneText.length) : '';
    final numStyle = tbStyle(size: 26, w: FontWeight.w500, color: p.ink, tab: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
          child: BackBtn(onTap: () => v['backToWelcome']()),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 24, Tb.padX, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(L0['phoneTitle'] as String, size: 28, w: FontWeight.w600, color: p.ink, font: TbFont.head, ls: -0.5),
                const SizedBox(height: 8),
                Tx(L0['phoneSub'] as String, size: 15, color: p.t2, lh: 22),
                const SizedBox(height: 28),
                GlassCard(
                  r: 24,
                  pad: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        // Davlat kodi — bosilsa cc_sheet ochiladi (mantiq saqlangan)
                        Tap(
                          onTap: () => v['ccOpenOnb'](),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tx('${v['onbFlag'] ?? ''}', size: 20, color: p.ink, lh: 20),
                              const SizedBox(width: 6),
                              Tx('${v['onbDial'] ?? ''}', size: 22, w: FontWeight.w500, color: p.t2, tab: true),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: p.t4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Maska qoldig'i (faqat ko'rinish; bosishni o'tkazmaydi)
                              if (rest.isNotEmpty)
                                IgnorePointer(
                                  child: Row(
                                    children: [
                                      Text(phoneText,
                                          maxLines: 1,
                                          textScaler: TextScaler.noScaling,
                                          style: numStyle.copyWith(color: Colors.transparent)),
                                      Flexible(
                                        child: Text(rest,
                                            maxLines: 1,
                                            overflow: TextOverflow.clip,
                                            textScaler: TextScaler.noScaling,
                                            style: numStyle.copyWith(color: p.t6)),
                                      ),
                                    ],
                                  ),
                                ),
                              StoreField(
                                value: phoneText,
                                onChanged: (t) => v['onPhone'](t),
                                keyboardType: TextInputType.number,
                                style: numStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GradientBtn(
                  label: L0['cont'] as String,
                  enabled: full,
                  loading: v['busy'] == 'phone',
                  onTap: () => v['phoneNext'](),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5.4 · Tasdiqlash kodi
  Widget _otp(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    // "{{ otpPhone }} raqamiga yuborildi" — 'otpSentTo' bo'lmasa faqat raqam (regressiyasiz).
    final sentTo = (L0['otpSentTo'] as String?)?.replaceAll('{p}', '${v['otpPhone']}') ?? '${v['otpPhone']}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
          child: BackBtn(onTap: () => v['backToPhone']()),
        ),
        // Expanded+scroll: kichik ekranda kontent siqilib overflow bermasligi uchun
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 24, Tb.padX, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tx(L0['otpTitle'] as String, size: 28, w: FontWeight.w600, color: p.ink, font: TbFont.head, ls: -0.5),
                const SizedBox(height: 8),
                Tx(sentTo, size: 15, color: p.t2, maxLines: 2, tab: true),
                const SizedBox(height: 28),
                Center(
                  child: CodeBoxes(boxes: (v['otpBoxes'] as List).cast<Map<String, dynamic>>()),
                ),
                const SizedBox(height: 14),
                Center(child: Tx(v['L']['otpDemo'] as String, size: 13, color: p.t4, align: TextAlign.center)),
                const SizedBox(height: 4),
                // Qayta yuborish — 42s hisoblagich; 0 da cyan va bosiladi (phoneNext qayta SMS yuboradi)
                Center(child: _ResendTimer(onResend: () => v['phoneNext']())),
                const SizedBox(height: 8),
                GradientBtn(
                  label: L0['confirm'] as String,
                  loading: v['busy'] == 'otp',
                  onTap: () => v['otpConfirm'](),
                ),
              ],
            ),
          ),
        ),
        KeyPad(keys: (v['otpKeys'] as List).cast<Map<String, dynamic>>()),
      ],
    );
  }

  // 5.5 · PIN
  Widget _pin(Map<String, dynamic> v, Pal p, Map<String, dynamic> L0) {
    final dots = (v['pinDots'] as List).cast<Map<String, dynamic>>();
    // Store 'pinDots' — to'lgan katak 'bg' = ink, bo'sh = transparent
    final filled = dots.where((d) => d['bg'] != Colors.transparent).length;
    final err = v['pinErr'] == true;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
            child: BackBtn(onTap: () => v['backToOtp']()),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 24, Tb.padX, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                GlassCard(
                  r: 22,
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(Icons.lock_outline_rounded, size: 28, color: err ? p.coral : p.cyan),
                  ),
                ),
                const SizedBox(height: 20),
                Tx(v['pinTitle'] as String, size: 26, w: FontWeight.w600, color: p.ink, font: TbFont.head,
                    ls: -0.5, align: TextAlign.center),
                const SizedBox(height: 8),
                Tx(v['pinSub'] as String, size: 15, color: p.t2, align: TextAlign.center, lh: 22),
                const SizedBox(height: 36),
                // Noto'g'ri PIN — nuqtalar coral (xato signali)
                err ? _ErrDots(count: dots.length, color: p.coral) : PinDots(count: dots.length, filled: filled),
              ],
            ),
          ),
        ),
        KeyPad(keys: (v['pinKeys'] as List).cast<Map<String, dynamic>>()),
      ],
    );
  }
}

// ───────────────────────────── 5.2 · 3 slayd ─────────────────────────────

class _OnbSlide {
  final String title, body, asset;
  final IconData fallback;
  const _OnbSlide(this.title, this.body, this.asset, this.fallback);
}

// TODO l10n: onboarding slayd matnlari (spec §5.2) — L() da kalit yo'q
const List<_OnbSlide> _kSlides = [
  _OnbSlide("Qarzni yodda emas, Trustbook'da saqlang",
      "Kimga berdingiz, kimdan oldingiz — hammasi bir joyda, unutilmaydi.",
      'assets/illustrations/onb_1.png', Icons.description_outlined),
  _OnbSlide('Ikki tomon tasdiqlaydi',
      "Har bir yozuvni ikkala tomon tasdiqlaydi — bahs-munozara bo'lmaydi.",
      'assets/illustrations/onb_2.png', Icons.verified_user_outlined),
  _OnbSlide('Muddat va eslatma',
      "Qaytarish muddatini belgilang, Trustbook o'zi eslatib turadi.",
      'assets/illustrations/onb_3.png', Icons.schedule_rounded),
];

class _OnbSlides extends StatefulWidget {
  final VoidCallback onStart;
  final String terms;
  final String startLabel;
  const _OnbSlides({required this.onStart, required this.terms, required this.startLabel});

  @override
  State<_OnbSlides> createState() => _OnbSlidesState();
}

class _OnbSlidesState extends State<_OnbSlides> {
  final PageController _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_i >= _kSlides.length - 1) {
      widget.onStart(); // "Boshlash" → telefon qadami (startOnb)
      return;
    }
    _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final last = _i >= _kSlides.length - 1;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
          child: Row(
            children: [
              const TrustMark(size: 32, boxed: true),
              const Spacer(),
              // TODO l10n: "O'tkazib yuborish"
              TextBtn(label: "O'tkazib yuborish", fs: 14, color: p.t2, onTap: widget.onStart),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: _kSlides.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final s = _kSlides[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      height: 270,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Center(child: Illustration(asset: s.asset, fallback: s.fallback, size: 270)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Tx(s.title, size: 30, w: FontWeight.w600, color: p.ink, font: TbFont.head, ls: -0.5,
                        align: TextAlign.center, lh: 36),
                    const SizedBox(height: 16),
                    Tx(s.body, size: 16, color: p.t2, align: TextAlign.center, lh: 24),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tb.padX, 8, Tb.padX, 24),
          child: Column(
            children: [
              // Nuqtalar: faol 28×8 gradient, boshqalari 8×8 white25
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _kSlides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _i ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: i == _i ? Tb.brand : null,
                        color: i == _i ? null : p.ink.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(Tb.rPill),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // TODO l10n: "Keyingi"
              GradientBtn(label: last ? widget.startLabel : 'Keyingi', onTap: _next),
              const SizedBox(height: 12),
              Tx(widget.terms, size: 11, color: p.t5, align: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── yordamchilar ─────────────────────────────

/// "Qayta yuborish 0:42" — 42s hisoblagich (t4); 0 ga tushganda cyan va bosiladi.
class _ResendTimer extends StatefulWidget {
  final VoidCallback onResend;
  const _ResendTimer({required this.onResend});

  @override
  State<_ResendTimer> createState() => _ResendTimerState();
}

class _ResendTimerState extends State<_ResendTimer> {
  static const int _total = 42;
  int _left = _total;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _t?.cancel();
    _left = _total;
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_left > 0) _left--;
        if (_left == 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final ready = _left <= 0;
    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');
    // TODO l10n: "Qayta yuborish"
    final label = ready ? 'Qayta yuborish' : 'Qayta yuborish $mm:$ss';
    return TextBtn(
      label: label,
      fs: 14,
      color: ready ? p.cyan : p.t4,
      onTap: ready
          ? () {
              widget.onResend();
              setState(_start);
            }
          : null,
    );
  }
}

/// Xato holatidagi PIN nuqtalari — hammasi coral (PinDots bilan bir xil o'lcham).
class _ErrDots extends StatelessWidget {
  final int count;
  final Color color;
  const _ErrDots({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 20),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        );
      }),
    );
  }
}
