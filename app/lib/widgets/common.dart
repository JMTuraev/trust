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
