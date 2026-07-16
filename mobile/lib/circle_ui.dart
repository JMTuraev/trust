// Trust — Circles bo'limi uchun umumiy vizual primitivlar (prototip bilan 1:1).
// Avatar tint'lari (a-warm/a-green/a-blue) prototipning o'ziga xos ranglari —
// butun ilovada FAQAT shu yerda markazlashgan va light/dark bardosh (prototip
// body.dark override'lari kabi). Qolgan barcha ranglar Pal (theme.dart) dan.
import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';
import 'circles_data.dart';

bool _dark() => store.S['dark'] == true;

/// (bg, fg) — tint bo'yicha avatar ranglari (light/dark).
(Color, Color) tintColors(Tint t, Pal p) {
  final d = _dark();
  switch (t) {
    case Tint.warm:
      return d ? (const Color(0xFF2A2622), const Color(0xFFB9AE9A)) : (const Color(0xFFEDE7DE), const Color(0xFF8A7F6B));
    case Tint.green:
      return d ? (const Color(0xFF1E2A24), const Color(0xFF7FA890)) : (const Color(0xFFE4ECE6), const Color(0xFF5E7A68));
    case Tint.blue:
      return d ? (const Color(0xFF20242B), const Color(0xFF9098A6)) : (const Color(0xFFE7E9EE), const Color(0xFF6E7480));
    case Tint.me:
      return (p.ink, p.bg);
    case Tint.more:
      return (p.field, p.t2);
  }
}

/// Tintli initsial avatar (prototip .av). ring=true — stack ichida ajratuvchi halqa.
class CAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Tint tint;
  final bool ring;
  const CAvatar({super.key, required this.initials, this.size = 26, this.tint = Tint.more, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final (bg, fg) = tintColors(tint, p);
    final fs = initials.length > 2 ? size * 0.30 : size * 0.40;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: p.bg, width: 1.5) : null,
      ),
      child: Tx(initials, size: fs, w: FontWeight.w600, color: fg, lh: fs),
    );
  }
}

/// Dashli "qo'shish" avatari (prototip .dash) — a'zo qo'shish tugmasi.
class DashAvatar extends StatelessWidget {
  final double size;
  const DashAvatar({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return CustomPaint(
      painter: _DashedCircle(color: p.bd),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: Tx('+', size: size * 0.54, w: FontWeight.w400, color: p.t3, lh: size * 0.54)),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  final Color color;
  _DashedCircle({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final r = size.width / 2 - 1;
    final c = Offset(size.width / 2, size.height / 2);
    const seg = 0.42, gap = 0.34; // radianlar
    for (double a = 0; a < 6.28318; a += seg + gap) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, seg, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCircle old) => old.color != color;
}

class AvSpec {
  final String initials;
  final Tint tint;
  const AvSpec(this.initials, this.tint);
}

/// Ustma-ust avatar to'plami (prototip .stack, -7px overlap).
class AvStack extends StatelessWidget {
  final List<AvSpec> items;
  final double size;
  final double overlap;
  const AvStack({super.key, required this.items, this.size = 24, this.overlap = 7});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final step = size - overlap;
    final width = size + (items.length - 1) * step;
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: i * step,
              child: CAvatar(initials: items[i].initials, size: size, tint: items[i].tint, ring: true),
            ),
        ],
      ),
    );
  }
}

/// Aylanma (rotation) ikonka — Circles brendi (prototip nav/join glyph).
class CircleGlyph extends StatelessWidget {
  final double size;
  final Color color;
  const CircleGlyph({super.key, this.size = 19, required this.color});

  @override
  Widget build(BuildContext context) => Icon(Icons.refresh_rounded, size: size, color: color);
}

/// Qalqon + belgi (proof / ikki-tomonlama tasdiq) ikonkasi (prototip shield-check).
class ShieldCheck extends StatelessWidget {
  final double size;
  final Color color;
  const ShieldCheck({super.key, this.size = 14, required this.color});

  @override
  Widget build(BuildContext context) => Icon(Icons.verified_user_outlined, size: size, color: color);
}

/// Oddiy belgi (✓) — to'langan / tasdiqlangan.
class CheckGlyph extends StatelessWidget {
  final double size;
  final Color color;
  const CheckGlyph({super.key, this.size = 14, required this.color});

  @override
  Widget build(BuildContext context) => Icon(Icons.check_rounded, size: size, color: color);
}

/// Timeline nuqtasi (done=green, current=ink, upcoming=bd).
class TlDot extends StatelessWidget {
  final Color color;
  final double size;
  const TlDot({super.key, required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Bo'lim sarlavhasi qatori (prototip .cap padding bilan)
class CircleSectionCap extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const CircleSectionCap(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 6)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Align(alignment: Alignment.centerLeft, child: Cap(text, ls: 1.5)),
      );
}

/// Circle detali/yaratish header (orqaga/✕ + sarlavha + o'ng yorliq).
class CircleHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget? trailing;
  final double titleSize;
  const CircleHeader({super.key, required this.leading, required this.title, this.trailing, this.titleSize = 16});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair))),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 4),
          Expanded(child: Tx(title, size: titleSize, w: FontWeight.w600, color: p.ink, maxLines: 1, ellipsis: true)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Info banner (prototip .banner) — shield ikonka + matn, field fonda.
class ProofBanner extends StatelessWidget {
  final String text;
  final EdgeInsets margin;
  const ProofBanner(this.text, {super.key, this.margin = const EdgeInsets.fromLTRB(20, 10, 20, 2)});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: ShieldCheck(size: 14, color: p.t2)),
          const SizedBox(width: 7),
          Expanded(child: Tx(text, size: 11.5, color: p.t1, lh: 16.1)),
        ],
      ),
    );
  }
}

/// "✕" belgisi (create/join header yopish)
class CloseGlyph extends StatelessWidget {
  final Color color;
  final double size;
  const CloseGlyph({super.key, required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) => Icon(Icons.close_rounded, size: size, color: color);
}

/// Asosiy qora pill tugma (prototip .btn — h46, r23). check=true — oldida ✓.
class CircleBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool check;
  const CircleBtn({super.key, required this.label, required this.onTap, this.check = false});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(23)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (check) ...[CheckGlyph(size: 16, color: p.bg), const SizedBox(width: 8)],
            Tx(label, size: 14, w: FontWeight.w600, color: p.bg),
          ],
        ),
      ),
    );
  }
}

/// Konturli pill tugma (prototip .btn2)
class CircleBtn2 extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const CircleBtn2({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: p.bd), borderRadius: BorderRadius.circular(23)),
        child: Tx(label, size: 14, w: FontWeight.w600, color: p.ink),
      ),
    );
  }
}

/// Ikkilamchi markazlangan link (prototip .link)
class CircleLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const CircleLink({super.key, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Tx(label, size: 12.5, w: FontWeight.w500, color: color ?? p.t2),
      ),
    );
  }
}

/// Segmentli tanlagich (prototip .seg/.sg/.sgA). options: (key, label).
class CircleSeg extends StatelessWidget {
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  const CircleSeg({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Tap(
                onTap: () => onChanged(o.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: o.$1 == value
                      ? BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.bd))
                      : null,
                  child: Tx(o.$2,
                      size: 12.5,
                      w: o.$1 == value ? FontWeight.w600 : FontWeight.w400,
                      color: o.$1 == value ? p.ink : p.t2,
                      maxLines: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sozlama qatori (prototip .srow) — nom + qiymat + chevron. danger=true — qizil.
class CircleSettingRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final bool hairBorder; // to'q chiziq (Close Circle uchun)
  const CircleSettingRow({
    super.key,
    required this.label,
    this.value,
    this.onTap,
    this.danger = false,
    this.hairBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: hairBorder ? p.hair : p.hair2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Tx(label, size: 13.5, w: danger ? FontWeight.w600 : FontWeight.w400, color: danger ? p.red : p.ink),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null) Tx(value!, size: 13, color: p.t2),
                if (value != null) const SizedBox(width: 6),
                ChevRight(color: danger ? p.red : p.t3, size: 7),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat katakcha (prototip .gcell) — k (cap) + v (qiymat).
class CircleStatCell extends StatelessWidget {
  final String k;
  final String val;
  const CircleStatCell({super.key, required this.k, required this.val});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(k.toUpperCase(), size: 10.5, w: FontWeight.w600, color: p.t3, ls: 0.4),
          const SizedBox(height: 4),
          Tx(val, size: 15, w: FontWeight.w600, color: p.ink),
        ],
      ),
    );
  }
}
