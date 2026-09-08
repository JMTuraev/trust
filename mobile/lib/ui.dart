// Trustbook — umumiy UI primitivlari. Dizayn: prototype/redesign/DESIGN_SPEC.md
// ("dark glass + gradient", Claude Design 2026-09-07).
//
// ESKI KLASS NOMLARI VA IMZOLARI SAQLANGAN (Tx, Tap, BackBtn, InkBtn, GhostBtn,
// SheetShell, KeyPad, CodeBoxes, TrustAvatar, ToastView, Skel, StoreField…) —
// ular ichidan yangi ko'rinishga o'tkazildi, chaqiruvchi kod o'zgarmaydi.
// Yangi primitivlar: GlassCard, GradientBtn, SolidBtn, GlassBtn, GlassIconBtn,
// ScreenHeader, RingAvatar, PillBadge, PillChip, PinDots, BottomPanel,
// SuccessOverlay, Aurora, ScreenBg, Illustration, TbToggle, GlassField.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, HapticFeedback;
import 'package:google_fonts/google_fonts.dart';
import 'store.dart';
import 'theme.dart';

Pal curPal() => pal(store.S['dark'] == true);

/// Shrift oilasi: body = Plus Jakarta Sans, head = Inter Tight, num = Space Grotesk.
/// auto: tab → num; size ≥ 20 va w ≥ 600 → head; aks holda body.
enum TbFont { auto, body, head, num }

TextStyle tbStyle({
  required double size,
  FontWeight w = FontWeight.w400,
  required Color color,
  double? ls,
  double? lh,
  bool tab = false,
  TbFont font = TbFont.auto,
}) {
  var f = font;
  if (f == TbFont.auto) {
    if (tab) {
      f = TbFont.num;
    } else if (size >= 20 && w.index >= FontWeight.w600.index) {
      f = TbFont.head;
    } else {
      f = TbFont.body;
    }
  }
  final height = lh != null ? lh / size : null;
  final feats = tab ? const [FontFeature.tabularFigures()] : null;
  switch (f) {
    case TbFont.head:
      return GoogleFonts.interTight(
          fontSize: size, fontWeight: w, color: color, letterSpacing: ls ?? -0.3, height: height, fontFeatures: feats);
    case TbFont.num:
      return GoogleFonts.spaceGrotesk(
          fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: height, fontFeatures: feats);
    case TbFont.body:
    case TbFont.auto:
      return GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: height, fontFeatures: feats);
  }
}

/// Matn. lh — px'dagi line-height.
class Tx extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight w;
  final Color color;
  final double? ls;
  final double? lh;
  final bool tab;
  final TextAlign? align;
  final int? maxLines;
  final bool ellipsis;
  final TbFont font;
  const Tx(
    this.text, {
    super.key,
    required this.size,
    this.w = FontWeight.w400,
    required this.color,
    this.ls,
    this.lh,
    this.tab = false,
    this.align,
    this.maxLines,
    this.ellipsis = false,
    this.font = TbFont.auto,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      overflow: ellipsis ? TextOverflow.ellipsis : null,
      textScaler: TextScaler.noScaling,
      style: tbStyle(size: size, w: w, color: color, ls: ls, lh: lh, tab: tab, font: font),
    );
  }
}

/// Bosiladigan element — bosilganda 0.97 kichrayish + haptik.
class Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  const Tap({super.key, this.onTap, required this.child, this.scale = 0.97});

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  void _set(bool d) {
    if (mounted && _down != d) setState(() => _down = d);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled
          ? (_) {
              _set(true);
              HapticFeedback.selectionClick();
            }
          : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────────── FON ─────────────────────────────

/// Aurora — ekranning ustki 460px'ida uchta xira rangli doira (pastga so'nadi).
class Aurora extends StatelessWidget {
  final double height;
  const Aurora({super.key, this.height = 460});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    if (!p.isDark) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, .35, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: const [
                Positioned(top: -90, left: -70, child: _Blob(size: 320, color: kViolet, opacity: .40)),
                Positioned(top: -40, right: -90, child: _Blob(size: 280, color: kBlue, opacity: .40)),
                Positioned(top: 130, left: 130, child: _Blob(size: 220, color: kMint, opacity: .25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Blob({required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Ekran foni: bg + aurora + kontent. main.dart'dagi Positioned.fill o'ramlari uchun.
class ScreenBg extends StatelessWidget {
  final Widget child;
  final bool aurora;
  const ScreenBg({super.key, required this.child, this.aurora = true});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      color: p.bg,
      child: Stack(
        children: [
          if (aurora) const Positioned(top: 0, left: 0, right: 0, child: Aurora()),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

// ───────────────────────────── KARTALAR ─────────────────────────────

/// Shisha karta: glass fon + glassBd chegara + ustki 1px oq chiziq.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double r;
  final EdgeInsetsGeometry? pad;
  final Color? color;
  final Color? border;
  final bool glow;
  final List<BoxShadow>? shadow;
  final Clip clip;
  const GlassCard({
    super.key,
    required this.child,
    this.r = Tb.rCard,
    this.pad,
    this.color,
    this.border,
    this.glow = false,
    this.shadow,
    this.clip = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Container(
      clipBehavior: clip,
      decoration: BoxDecoration(
        color: color ?? p.glass,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border ?? p.glassBd),
        boxShadow: shadow ?? (glow ? Tb.glow : null),
      ),
      child: Stack(
        children: [
          // inset 0 1px 0 white/8 — ustki yorug' chiziq
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(child: Container(height: 1, color: p.ink.withValues(alpha: p.isDark ? .08 : 0))),
          ),
          Padding(padding: pad ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

/// Illyustratsiya — asset yo'q bo'lsa gradient qutidagi ikonka.
class Illustration extends StatelessWidget {
  final String asset;
  final IconData fallback;
  final double? size;
  final BoxFit fit;
  const Illustration({super.key, required this.asset, required this.fallback, this.size, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _IllFallback(icon: fallback, size: size ?? 72),
    );
  }
}

class _IllFallback extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IllFallback({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    final s = size.clamp(48.0, 120.0);
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        gradient: Tb.brandDiag,
        borderRadius: BorderRadius.circular(s * 0.28),
        boxShadow: Tb.glow,
      ),
      child: Icon(icon, size: s * 0.5, color: Colors.white),
    );
  }
}

// ───────────────────────────── TUGMALAR ─────────────────────────────

/// Brend gradient pill tugma (asosiy harakat).
class GradientBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double h;
  final double fs;
  final IconData? icon;
  final bool loading;
  final bool enabled;
  final bool glow;
  const GradientBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.h = 56,
    this.fs = 16,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final on = enabled && onTap != null && !loading;
    final fg = enabled ? Colors.white : p.t5;
    return Tap(
      onTap: on ? onTap : null,
      child: Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? Tb.brand : null,
          color: enabled ? null : p.glass2,
          borderRadius: BorderRadius.circular(Tb.rPill),
          boxShadow: enabled && glow ? Tb.glow : null,
        ),
        child: loading
            ? SizedBox(
                width: fs + 4,
                height: fs + 4,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: fs + 4, color: fg), const SizedBox(width: 8)],
                  Flexible(child: Tx(label, size: fs, w: FontWeight.w600, color: fg, maxLines: 1, ellipsis: true)),
                ],
              ),
      ),
    );
  }
}

/// To'liq rangli pill (mint: Qarz berdim / To'lov keldi; coral: Rad etish).
class SolidBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;
  final double h;
  final double fs;
  final IconData? icon;
  final bool loading;
  final bool glow;
  const SolidBtn({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    required this.fg,
    this.h = 52,
    this.fs = 15,
    this.icon,
    this.loading = false,
    this.glow = false,
  });

  /// Mint (pul kirdi / tasdiq)
  factory SolidBtn.mint(String label, VoidCallback? onTap,
      {double h = 52, double fs = 15, IconData? icon, bool loading = false, bool glow = false}) {
    final p = curPal();
    return SolidBtn(label: label, onTap: onTap, color: p.mint, fg: p.onMint, h: h, fs: fs, icon: icon, loading: loading, glow: glow);
  }

  /// Coral (rad etish / xavfli)
  factory SolidBtn.coral(String label, VoidCallback? onTap,
      {double h = 52, double fs = 15, IconData? icon, bool loading = false}) {
    final p = curPal();
    return SolidBtn(label: label, onTap: onTap, color: p.coral, fg: p.onCoral, h: h, fs: fs, icon: icon, loading: loading);
  }

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: loading ? null : onTap,
      child: Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Tb.rPill),
          boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 36, offset: const Offset(0, 12))] : null,
        ),
        child: loading
            ? SizedBox(
                width: fs + 4,
                height: fs + 4,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: fs + 4, color: fg), const SizedBox(width: 6)],
                  Flexible(child: Tx(label, size: fs, w: FontWeight.w700, color: fg, maxLines: 1, ellipsis: true)),
                ],
              ),
      ),
    );
  }
}

/// Shisha pill tugma (ikkilamchi harakat).
class GlassBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double h;
  final double fs;
  final IconData? icon;
  final Color? fg;
  final bool loading;
  const GlassBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.h = 48,
    this.fs = 15,
    this.icon,
    this.fg,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final c = fg ?? p.ink;
    return Tap(
      onTap: loading ? null : onTap,
      child: Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.glass2,
          border: Border.all(color: p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: loading
            ? SizedBox(
                width: fs + 4,
                height: fs + 4,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(c)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: fs + 4, color: c), const SizedBox(width: 6)],
                  Flexible(child: Tx(label, size: fs, w: FontWeight.w600, color: c, maxLines: 1, ellipsis: true)),
                ],
              ),
      ),
    );
  }
}

/// Faqat matnli (fonsiz) tugma — "Bekor qilish".
class TextBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double h;
  final double fs;
  const TextBtn({super.key, required this.label, required this.onTap, this.color, this.h = 48, this.fs = 15});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Tap(
      onTap: onTap,
      child: SizedBox(
        height: h,
        child: Center(child: Tx(label, size: fs, w: FontWeight.w500, color: color ?? p.t1)),
      ),
    );
  }
}

/// Dumaloq shisha ikonka tugmasi (header). badge — o'qilmaganlar soni.
class GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;
  final int badge;
  final bool gradient;
  const GlassIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
    this.color,
    this.badge = 0,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final btn = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient ? Tb.brandDiag : null,
        color: gradient ? null : p.glass,
        border: gradient ? null : Border.all(color: p.glassBd),
        boxShadow: gradient ? Tb.glow : null,
      ),
      child: Icon(icon, size: iconSize, color: gradient ? Colors.white : (color ?? p.ink)),
    );
    return Tap(
      onTap: onTap,
      child: badge <= 0
          ? btn
          : Stack(
              clipBehavior: Clip.none,
              children: [
                btn,
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: Tb.coralRose,
                      borderRadius: BorderRadius.circular(Tb.rPill),
                      border: Border.all(color: p.bg, width: 2),
                    ),
                    child: Tx(badge > 99 ? '99+' : '$badge', size: 11, w: FontWeight.w700, color: Colors.white, font: TbFont.body),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Orqaga (dumaloq shisha chevron). Imzo eski BackBtn bilan bir xil.
class BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Color? color;
  const BackBtn({super.key, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) =>
      GlassIconBtn(icon: Icons.chevron_left_rounded, onTap: onTap, color: color, iconSize: 26);
}

/// Orqaga strelka (moslik uchun — endi ikonka)
class BackChevron extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  const BackChevron({super.key, required this.color, this.size = 10, this.thickness = 2});

  @override
  Widget build(BuildContext context) => Icon(Icons.chevron_left_rounded, size: size * 2.2, color: color);
}

/// O'ngga chevron (moslik uchun)
class ChevRight extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  const ChevRight({super.key, required this.color, this.size = 7, this.thickness = 1.5});

  @override
  Widget build(BuildContext context) => Icon(Icons.chevron_right_rounded, size: size * 2.6, color: color);
}

/// Ekran sarlavhasi: [Back] [title/subtitle] [trailing]
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leading;
  final List<Widget> trailing;
  final Widget? titleTrailing;
  final EdgeInsetsGeometry padding;
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.leading,
    this.trailing = const [],
    this.titleTrailing,
    this.padding = const EdgeInsets.fromLTRB(Tb.padX, 12, Tb.padX, 0),
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (onBack != null) ...[BackBtn(onTap: onBack!), const SizedBox(width: 12)],
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(child: Tx(title, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head, maxLines: 1, ellipsis: true)),
                    if (titleTrailing != null) ...[const SizedBox(width: 8), titleTrailing!],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Tx(subtitle!, size: 13, color: p.t2, maxLines: 1, ellipsis: true),
              ],
            ),
          ),
          for (var i = 0; i < trailing.length; i++) ...[
            const SizedBox(width: 8),
            trailing[i],
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── AVATAR / BADGE / CHIP ─────────────────────────────

/// Gradient halqali avatar. dot — holat nuqtasi (pastki-o'ng).
class RingAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final LinearGradient? gradient;
  final Color? dot;
  final double ring;
  final String? seed;
  const RingAvatar({super.key, required this.initials, this.size = 48, this.gradient, this.dot, this.ring = 2, this.seed});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final g = gradient ?? Tb.ringFor(seed ?? initials);
    final ini = initials.trim().isEmpty ? '?' : initials.trim();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(ring),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.surface2),
              alignment: Alignment.center,
              child: Tx(ini, size: size * 0.33, w: FontWeight.w600, color: p.ink, font: TbFont.num),
            ),
          ),
          if (dot != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot, border: Border.all(color: p.bg, width: 2)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hamkor avatari (eski imzo) — endi gradient halqa; onTrust → cyan nuqta.
class TrustAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool onTrust;
  const TrustAvatar({super.key, required this.initials, this.size = 44, this.onTrust = false});

  @override
  Widget build(BuildContext context) =>
      RingAvatar(initials: initials, size: size, dot: onTrust ? curPal().cyan : null);
}

/// Kichik holat pill'i (h24, 11/700).
class PillBadge extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color fg;
  final Gradient? gradient;
  final double h;
  final IconData? icon;
  const PillBadge(this.text, {super.key, this.bg, required this.fg, this.gradient, this.h = 24, this.icon});

  factory PillBadge.pro({String text = 'PRO', double h = 24}) =>
      PillBadge(text, gradient: Tb.brand, fg: Colors.white, h: h);
  factory PillBadge.mint(String text, {double h = 24, IconData? icon}) {
    final p = curPal();
    return PillBadge(text, bg: p.mint.withValues(alpha: .15), fg: p.mint, h: h, icon: icon);
  }
  factory PillBadge.amber(String text, {double h = 24, IconData? icon}) {
    final p = curPal();
    return PillBadge(text, bg: p.amber.withValues(alpha: .15), fg: p.amber, h: h, icon: icon);
  }
  factory PillBadge.coral(String text, {double h = 24, IconData? icon}) {
    final p = curPal();
    return PillBadge(text, bg: p.coral.withValues(alpha: .15), fg: p.coral, h: h, icon: icon);
  }
  factory PillBadge.cyan(String text, {double h = 24, IconData? icon}) {
    final p = curPal();
    return PillBadge(text, bg: p.cyan.withValues(alpha: .12), fg: p.cyan, h: h, icon: icon);
  }
  factory PillBadge.muted(String text, {double h = 24, IconData? icon}) {
    final p = curPal();
    return PillBadge(text, bg: p.glass2, fg: p.t2, h: h, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: h > 24 ? 10 : 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, gradient: gradient, borderRadius: BorderRadius.circular(Tb.rPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: h * 0.55, color: fg), const SizedBox(width: 3)],
          Tx(text, size: h > 24 ? 13 : 11, w: FontWeight.w700, color: fg, maxLines: 1, font: TbFont.body),
        ],
      ),
    );
  }
}

/// Filtr chipi (h40): tanlangan — oq fon, aks holda shisha.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double h;
  final Widget? leading;
  final Color? selectedBg;
  final Color? selectedFg;
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.h = 40,
    this.leading,
    this.selectedBg,
    this.selectedFg,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final sb = selectedBg ?? p.ink;
    final sf = selectedFg ?? p.bg;
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: h,
        padding: EdgeInsets.symmetric(horizontal: leading != null ? 12 : 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? sb : p.glass,
          border: Border.all(color: selected ? sb : p.glassBd),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Tx(label, size: 14, w: FontWeight.w600, color: selected ? sf : p.t1, maxLines: 1, font: TbFont.body),
          ],
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi (13/700 UPPERCASE, tracking .12em)
class Cap extends StatelessWidget {
  final String text;
  final double ls;
  const Cap(this.text, {super.key, this.ls = 1.5});

  @override
  Widget build(BuildContext context) =>
      Tx(text.toUpperCase(), size: 13, w: FontWeight.w700, color: curPal().t4, ls: ls, font: TbFont.body);
}

/// Toggle 52×32 (faol: brend gradient).
class TbToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const TbToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onChanged!(!value);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: value ? Tb.brand : null,
          color: value ? null : p.ink.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(Tb.rPill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// Qidiruv belgisi (moslik) — endi ikonka
class SearchGlyph extends StatelessWidget {
  final Color color;
  final double size;
  const SearchGlyph({super.key, required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) => Icon(Icons.search_rounded, size: size + 4, color: color);
}

/// Trust logotipi: brend-gradient kvadrat ichida "T" (Space Grotesk).
/// boxed=false → faqat "T" harfi (ink rangida).
class TrustMark extends StatelessWidget {
  final double size;
  final bool boxed;
  final Color? color;
  const TrustMark({super.key, this.size = 24, this.boxed = false, this.color});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    if (boxed) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: Tb.brandDiag,
          borderRadius: BorderRadius.circular(size * 0.29),
          boxShadow: size >= 48 ? Tb.glow : null,
        ),
        child: Tx('T', size: size * 0.5, w: FontWeight.w700, color: Colors.white, font: TbFont.num),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: Tx('T', size: size * 0.8, w: FontWeight.w700, color: color ?? p.ink, font: TbFont.num)),
    );
  }
}

// ───────────────────────────── KIRITISH ─────────────────────────────

/// Raqamli klaviatura (3x4). keys: [{label, tap}] — eski imzo.
/// label '⌫' / 'del' / '<' — o'chirish ikonkasi; '' — bo'sh joy.
class KeyPad extends StatelessWidget {
  final List<Map<String, dynamic>> keys;
  final double h;
  const KeyPad({super.key, required this.keys, this.h = 56});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (row) {
          return Row(
            children: List.generate(3, (col) {
              final i = row * 3 + col;
              final k = i < keys.length ? keys[i] : const <String, dynamic>{'label': ''};
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _PadKey(label: '${k['label'] ?? ''}', onTap: k['tap'] as void Function()?, h: h),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

class _PadKey extends StatefulWidget {
  final String label;
  final void Function()? onTap;
  final double h;
  const _PadKey({required this.label, this.onTap, required this.h});

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;

  bool get _isDel {
    final l = widget.label.trim().toLowerCase();
    return l == '⌫' || l == 'del' || l == '<' || l == '←' || l == 'x' || l == '×';
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final empty = widget.label.trim().isEmpty;
    if (empty) return SizedBox(height: widget.h);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _down = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: widget.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down ? p.ink.withValues(alpha: .12) : p.ink.withValues(alpha: .05),
            border: Border.all(color: p.ink.withValues(alpha: .06)),
            borderRadius: BorderRadius.circular(Tb.rKey),
          ),
          child: _isDel
              ? Icon(Icons.backspace_outlined, size: 24, color: p.ink)
              : Tx(widget.label, size: 24, w: FontWeight.w500, color: p.ink, font: TbFont.num),
        ),
      ),
    );
  }
}

/// Kod kataklari. boxes: [{key, d, bd}] — eski imzo (bd = chegara rangi).
class CodeBoxes extends StatelessWidget {
  final List<Map<String, dynamic>> boxes;
  final double w, h, fs, gap, r;
  const CodeBoxes({
    super.key,
    required this.boxes,
    this.w = 58,
    this.h = 68,
    this.fs = 30,
    this.gap = 12,
    this.r = 20,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final children = <Widget>[];
    for (var i = 0; i < boxes.length; i++) {
      if (i > 0) children.add(SizedBox(width: gap));
      final b = boxes[i];
      final d = '${b['d'] ?? ''}';
      final filled = d.trim().isNotEmpty;
      final bd = (b['bd'] as Color?) ?? (filled ? p.violet : p.glassBd);
      children.add(AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? p.ink.withValues(alpha: .10) : p.ink.withValues(alpha: .04),
          border: Border.all(color: bd),
          borderRadius: BorderRadius.circular(r),
        ),
        child: Tx(d, size: fs, w: FontWeight.w500, color: p.ink, font: TbFont.num),
      ));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// PIN nuqtalari (16px): to'lgan — gradient (1.1×), bo'sh — white15.
class PinDots extends StatelessWidget {
  final int count;
  final int filled;
  const PinDots({super.key, this.count = 4, required this.filled});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final on = i < filled;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 20),
          child: AnimatedScale(
            scale: on ? 1.1 : 1,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on ? Tb.brandDiag : null,
                color: on ? null : p.ink.withValues(alpha: .15),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Shisha kiritish pill'i (qidiruv / izoh / AI input).
class GlassField extends StatelessWidget {
  final Widget child;
  final double h;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final bool focused;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  const GlassField({
    super.key,
    required this.child,
    this.h = 48,
    this.icon,
    this.iconColor,
    this.trailing,
    this.focused = false,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: h,
      padding: padding ?? EdgeInsets.only(left: 16, right: trailing != null ? 6 : 16),
      decoration: BoxDecoration(
        color: color ?? p.glass,
        border: Border.all(color: focused ? p.violet.withValues(alpha: .6) : p.glassBd),
        borderRadius: BorderRadius.circular(Tb.rPill),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: iconColor ?? p.t2), const SizedBox(width: 8)],
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Store bilan sinxron TextField (tashqi o'zgarishda kursorni saqlab yangilaydi).
class StoreField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextStyle? style;
  final Color? hintColor;
  final TextInputType? keyboardType;
  final VoidCallback? onSubmit;
  final TextAlign textAlign;
  final bool autofocus;
  final int maxLines;
  final int minLines;
  final List<TextInputFormatter>? inputFormatters;
  const StoreField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.style,
    this.hintColor,
    this.keyboardType,
    this.onSubmit,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines = 1,
    this.inputFormatters,
  });

  @override
  State<StoreField> createState() => _StoreFieldState();
}

class _StoreFieldState extends State<StoreField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant StoreField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final st = widget.style ?? tbStyle(size: 15, color: p.ink);
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
      keyboardType: widget.maxLines > 1 ? TextInputType.multiline : widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      style: st,
      cursorColor: p.cyan,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: st.copyWith(color: widget.hintColor ?? p.t5),
      ),
    );
  }
}

// ───────────────────────────── QATLAMLAR ─────────────────────────────

/// Pastdan chiqadigan sheet (dim + panel). Stack ichida Positioned.fill.
class SheetShell extends StatelessWidget {
  final VoidCallback onClose;
  final Widget child;
  final bool scroll;
  final double? heightPct;
  const SheetShell({super.key, required this.onClose, required this.child, this.scroll = true, this.heightPct});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final handle = Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Center(
        child: Container(
          width: 40,
          height: 6,
          decoration: BoxDecoration(color: p.ink.withValues(alpha: .2), borderRadius: BorderRadius.circular(3)),
        ),
      ),
    );
    final panelChild = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [child]),
          )
        : child;
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, cons) {
        final maxH = (MediaQuery.of(context).size.height * 0.9).clamp(0.0, cons.maxHeight);
        return Column(
          children: [
            Expanded(child: GestureDetector(onTap: onClose, child: Container(color: p.dim))),
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(Tb.rSheet), topRight: Radius.circular(Tb.rSheet)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: double.infinity,
                  height: heightPct != null
                      ? (MediaQuery.of(context).size.height * heightPct!).clamp(0.0, cons.maxHeight)
                      : null,
                  constraints: BoxConstraints(maxHeight: maxH),
                  decoration: BoxDecoration(
                    color: p.sheetBg,
                    border: Border(top: BorderSide(color: p.glassBd)),
                  ),
                  child: heightPct != null
                      ? Column(children: [handle, Expanded(child: panelChild)])
                      : Column(mainAxisSize: MainAxisSize.min, children: [handle, Flexible(child: panelChild)]),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Pastki suzuvchi shisha panel (hamkor chati / xarajat input / AI input).
/// Stack ichida Positioned sifatida joylang (left/right 16, bottom 30).
class BottomPanel extends StatelessWidget {
  final Widget child;
  final double h;
  final EdgeInsetsGeometry padding;
  const BottomPanel({super.key, required this.child, this.h = 72, this.padding = const EdgeInsets.symmetric(horizontal: 8)});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tb.rPill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: h,
          padding: padding,
          decoration: BoxDecoration(
            color: p.panel,
            border: Border.all(color: p.glassBd),
            borderRadius: BorderRadius.circular(Tb.rPill),
            boxShadow: Tb.panelShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Asosiy tugma (eski imzo) — endi brend gradient pill.
class InkBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double h;
  final double fs;
  final bool loading;
  const InkBtn({super.key, required this.label, required this.onTap, this.h = 56, this.fs = 16, this.loading = false});

  @override
  Widget build(BuildContext context) =>
      GradientBtn(label: label, onTap: onTap, h: h < 50 ? h : (h == 50 ? 56 : h), fs: fs, loading: loading);
}

/// Konturli tugma (eski imzo) — endi shisha pill.
class GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double h;
  final double fs;
  final double r;
  final bool loading;
  const GhostBtn({super.key, required this.label, required this.onTap, this.h = 48, this.fs = 15, this.r = 999, this.loading = false});

  @override
  Widget build(BuildContext context) => GlassBtn(label: label, onTap: onTap, h: h < 44 ? h : h, fs: fs, loading: loading);
}

/// Toast — shisha pill, mint check ikonka.
class ToastView extends StatelessWidget {
  final bool open;
  final String text;
  const ToastView({super.key, required this.open, required this.text});

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();
    final p = curPal();
    return Positioned(
      left: Tb.padX,
      right: Tb.padX,
      bottom: 116,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: p.isDark ? const Color(0xF21A1D28) : const Color(0xF2FFFFFF),
                border: Border.all(color: p.ink.withValues(alpha: .15)),
                borderRadius: BorderRadius.circular(Tb.rPill),
                boxShadow: Tb.panelShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: p.mint),
                  const SizedBox(width: 8),
                  Flexible(child: Tx(text, size: 14, w: FontWeight.w600, color: p.ink, maxLines: 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Muvaffaqiyat qatlami: mint doira + ikki halqa "burst" + sarlavha.
class SuccessOverlay extends StatelessWidget {
  final String title;
  final String? sub;
  const SuccessOverlay({super.key, required this.title, this.sub});

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: p.bg.withValues(alpha: .85),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _Burst(color: p.mint, delay: 0),
                      _Burst(color: p.cyan, delay: 150),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .4, end: 1),
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.elasticOut,
                        builder: (_, t, child) => Transform.scale(scale: t, child: child),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.mint, boxShadow: Tb.glowMint),
                          child: Icon(Icons.check_rounded, size: 52, color: p.onMint),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Tx(title, size: 24, w: FontWeight.w600, color: p.ink, font: TbFont.head),
                if (sub != null) ...[const SizedBox(height: 4), Tx(sub!, size: 15, color: p.t2)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Burst extends StatelessWidget {
  final Color color;
  final int delay;
  const _Burst({required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 900 + delay),
      curve: Curves.easeOut,
      builder: (_, t, __) {
        final s = .6 + 1.8 * t;
        return Opacity(
          opacity: (0.9 * (1 - t)).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: s,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton blok (shisha rang). wf — kenglik ulushi, w — px.
class Skel extends StatelessWidget {
  final double? w;
  final double? wf;
  final double h;
  final double r;
  const Skel({super.key, this.w, this.wf, required this.h, this.r = 8});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: curPal().glass2, borderRadius: BorderRadius.circular(r)),
    );
    if (wf != null) return FractionallySizedBox(widthFactor: wf, alignment: Alignment.centerLeft, child: box);
    return box;
  }
}

/// Animatsiyali brend logotipi (splash) — pulse.
class TrustMarkAnim extends StatefulWidget {
  final double size;
  final bool boxed;
  const TrustMarkAnim({super.key, this.size = 96, this.boxed = true});

  @override
  State<TrustMarkAnim> createState() => _TrustMarkAnimState();
}

class _TrustMarkAnimState extends State<TrustMarkAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        return Opacity(
          opacity: 1 - 0.15 * t,
          child: Transform.scale(scale: 1 + 0.06 * t, child: TrustMark(size: widget.size, boxed: widget.boxed)),
        );
      },
    );
  }
}

/// Sozlamalar/ro'yxat qatori (h56): [ikonka] nom … qiymat [chevron]
class ListRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final Color? titleColor;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final bool last;
  final VoidCallback? onTap;
  final double h;
  const ListRow({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.titleColor,
    this.value,
    this.trailing,
    this.chevron = true,
    this.last = false,
    this.onTap,
    this.h = 56,
  });

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final row = Container(
      constraints: BoxConstraints(minHeight: h),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.hairline))),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          if (icon != null) ...[Icon(icon, size: 20, color: iconColor ?? p.t1), const SizedBox(width: 12)],
          Expanded(child: Tx(title, size: 15, w: FontWeight.w500, color: titleColor ?? p.ink, maxLines: 2)),
          if (value != null) ...[const SizedBox(width: 8), Tx(value!, size: 14, color: p.t2, maxLines: 1)],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (chevron && onTap != null) ...[const SizedBox(width: 4), Icon(Icons.chevron_right_rounded, size: 20, color: p.t6)],
        ],
      ),
    );
    return onTap == null ? row : Tap(onTap: onTap, scale: 0.99, child: row);
  }
}
