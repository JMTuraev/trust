import 'package:flutter/material.dart';
import '../theme.dart';

/// Uppercase micro-label (masalan "SOF BALANS")
class MicroLabel extends StatelessWidget {
  final String text;
  final P p;
  const MicroLabel(this.text, this.p);
  @override
  Widget build(BuildContext c) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 1.6, color: p.t2));
}

/// Qora (ink) to'ldirilgan tugma
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final P p;
  final double height;
  const InkButton(this.label, this.onTap, this.p, {this.height = 50});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(color: p.bg, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      );
}

/// Trust rozetkasi (ikki tomonlama tasdiq belgisi) yoki one-sided
class TrustBadge extends StatelessWidget {
  final bool onTrust;
  final P p;
  final double size;
  const TrustBadge(this.onTrust, this.p, {this.size = 16});
  @override
  Widget build(BuildContext c) {
    if (onTrust) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle,
            border: Border.all(color: p.bg, width: 2)),
        child: Icon(Icons.check, size: size * 0.62, color: p.bg),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle,
          border: Border.all(color: p.t4, width: 1.4)),
      child: Icon(Icons.person_outline, size: size * 0.6, color: p.t2),
    );
  }
}

/// Boshdagi harf(lar)li avatar doira
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final P p;
  final double size;
  const InitialsAvatar(this.initials, this.p, {this.size = 44});
  @override
  Widget build(BuildContext c) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(initials,
            style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w600, color: p.ink)),
      );
}

/// Pastdan chiquvchi sheet (scrim + panel)
class BottomSheetShell extends StatelessWidget {
  final P p;
  final VoidCallback onClose;
  final Widget child;
  final double? heightFactor;
  const BottomSheetShell({required this.p, required this.onClose, required this.child, this.heightFactor});
  @override
  Widget build(BuildContext c) => Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: onClose, child: Container(color: p.dim))),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
              child: SafeArea(top: false, child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: p.bd, borderRadius: BorderRadius.circular(2)))),
                  child,
                ]),
              )),
            ),
          ),
        ),
      ]);
}

/// Raqamli klaviatura (0-9, bo'sh, delete)
class Keypad extends StatelessWidget {
  final P p;
  final void Function(String) onKey;
  const Keypad({required this.p, required this.onKey});
  @override
  Widget build(BuildContext c) {
    final keys = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1.9,
      children: [ for (final k in keys)
        GestureDetector(
          onTap: k.isEmpty ? null : () => onKey(k),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(k, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.ink)),
          ),
        ) ],
    );
  }
}

/// Orqaga tugmali sarlavha (overlay ekranlar uchun)
class OverlayHeader extends StatelessWidget {
  final P p;
  final String title;
  final VoidCallback onBack;
  final String? trailing;
  const OverlayHeader({required this.p, required this.title, required this.onBack, this.trailing});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
        child: Row(children: [
          GestureDetector(onTap: onBack, child: SizedBox(width: 34, height: 34,
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink))),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
          if (trailing != null) ...[const Spacer(), Text(trailing!, style: TextStyle(fontSize: 12, color: p.t3))],
        ]),
      );
}
