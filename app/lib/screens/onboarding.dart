import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/common.dart';

class Onboarding extends StatefulWidget {
  final P p;
  final VoidCallback onDone;
  const Onboarding({required this.p, required this.onDone});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0; // 0 welcome, 1 phone, 2 otp, 3 pin
  String otp = '';
  String pin = '';

  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    switch (step) {
      case 0: return _welcome(p);
      case 1: return _phone(p);
      case 2: return _otp(p);
      default: return _pin(p);
    }
  }

  Widget _welcome(P p) => Column(children: [
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                alignment: Alignment.center, child: Text('T', style: TextStyle(color: p.bg, fontSize: 24, fontWeight: FontWeight.w700))),
            const SizedBox(height: 20),
            Text('Trust', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.5)),
            const SizedBox(height: 14),
            Text('Qarz va hisob-kitoblaringizni ikki tomonlama tasdiq bilan yuriting. Har bir yozuv — o’chirilmas halol dalil.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.t1, height: 1.6)),
          ]),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 30), child: Column(children: [
          InkButton('Boshlash', () => setState(() => step = 1), p, height: 52),
          const SizedBox(height: 14),
          Text('Davom etish orqali foydalanish shartlariga rozilik bildirasiz',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.t5)),
        ])),
      ]);

  Widget _backBar(P p, VoidCallback onBack) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: onBack,
          child: SizedBox(width: 34, height: 34, child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink)))));

  Widget _phone(P p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _backBar(p, () => setState(() => step = 0)),
        Padding(padding: const EdgeInsets.fromLTRB(28, 6, 28, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Telefon raqami', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Text('Hisobingiz shu raqamga bog’lanadi', style: TextStyle(fontSize: 13.5, color: p.t2)),
          const SizedBox(height: 28),
          Row(children: [
            Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Text('🇺🇿', style: TextStyle(fontSize: 19)),
                  const SizedBox(width: 6),
                  Text('+998', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.ink)),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: p.t3),
                ])),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.centerLeft,
                child: Text('90 123 45 67', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.t5)))),
          ]),
          const SizedBox(height: 24),
          InkButton('Davom etish', () => setState(() => step = 2), p, height: 52),
        ])),
      ]);

  Widget _otp(P p) => Column(children: [
        Align(alignment: Alignment.centerLeft, child: _backBar(p, () => setState(() => step = 1))),
        Padding(padding: const EdgeInsets.fromLTRB(28, 6, 28, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tasdiqlash kodi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Text('+998 90 123 45 67 raqamiga yuborildi', style: TextStyle(fontSize: 13.5, color: p.t2)),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < 5; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 4.5),
              child: Container(width: 50, height: 58,
                  decoration: BoxDecoration(border: Border.all(color: i < otp.length ? p.ink : p.bd), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(i < otp.length ? otp[i] : '', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.ink)))),
          ]),
          const SizedBox(height: 14),
          Center(child: Text('Demo: istalgan 5 raqam qabul qilinadi', style: TextStyle(fontSize: 12, color: p.t4))),
          const SizedBox(height: 20),
          InkButton('Tasdiqlash', () => setState(() => step = 3), p, height: 52),
        ])),
        const Spacer(),
        Padding(padding: const EdgeInsets.fromLTRB(30, 0, 30, 26), child: Keypad(p: p, onKey: (k) {
          setState(() {
            if (k == '⌫') { if (otp.isNotEmpty) otp = otp.substring(0, otp.length - 1); }
            else if (otp.length < 5) otp += k;
          });
        })),
      ]);

  Widget _pin(P p) => Column(children: [
        Align(alignment: Alignment.centerLeft, child: _backBar(p, () => setState(() => step = 2))),
        const SizedBox(height: 6),
        Text('PIN o’rnating', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.ink, letterSpacing: -0.4)),
        const SizedBox(height: 8),
        Text('Ilovaga kirish uchun 4 xonali kod', style: TextStyle(fontSize: 13.5, color: p.t2)),
        const SizedBox(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < 4; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: p.ink, width: 1.5), color: i < pin.length ? p.ink : Colors.transparent))),
        ]),
        const Spacer(),
        Padding(padding: const EdgeInsets.fromLTRB(30, 0, 30, 26), child: Keypad(p: p, onKey: (k) {
          setState(() {
            if (k == '⌫') { if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1); }
            else if (pin.length < 4) { pin += k; if (pin.length == 4) Future.delayed(const Duration(milliseconds: 200), widget.onDone); }
          });
        })),
      ]);
}
