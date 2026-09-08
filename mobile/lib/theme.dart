// Trustbook v2 dizayn tokenlari — "dark glass + gradient"
// (Claude Design: prototype/redesign/DESIGN_SPEC.md bilan 1:1).
//
// ESKI TOKEN NOMLARI SAQLANGAN (bg, ink, card2, field, bd, t1..t6, green, red…)
// — ularni ishlatadigan barcha ekranlar avtomatik yangi palitraga o'tadi.
// Yangi nomlar (glass, violet, cyan, mint, coral, amber…) — yangi ekranlar uchun.
import 'package:flutter/material.dart';

class Pal {
  // ── Eski (moslik uchun) ──
  final Color bg, ink, hair, hair2, card2, field, hov, hov2, bd, bd2, barbg;
  final Color t1, t2, t3, t4, t5, t6;
  final Color dim, green, red, idle, skelDot;
  // ── Yangi ──
  /// Shaffofsiz karta (daftar qatorlari) va ikkilamchi yuza (avatar ichi, panel)
  final Color surface, surface2, sheetBg;
  /// Shisha yuzalar: karta foni (6%), ikkilamchi tugma (8%), chegara (10%), ajratgich (6%)
  final Color glass, glass2, glassBd, hairline;
  /// Brend va pul ranglari
  final Color violet, cyan, mint, coral, amber, onMint, onCoral;
  /// Pastki suzuvchi panel foni (85% surface2)
  final Color panel;
  final bool isDark;

  const Pal({
    required this.bg, required this.ink,
    required this.hair, required this.hair2,
    required this.card2, required this.field,
    required this.hov, required this.hov2,
    required this.bd, required this.bd2, required this.barbg,
    required this.t1, required this.t2, required this.t3,
    required this.t4, required this.t5, required this.t6,
    required this.dim, required this.green, required this.red,
    required this.idle, required this.skelDot,
    required this.surface, required this.surface2, required this.sheetBg,
    required this.glass, required this.glass2, required this.glassBd, required this.hairline,
    required this.violet, required this.cyan, required this.mint, required this.coral,
    required this.amber, required this.onMint, required this.onCoral,
    required this.panel, required this.isDark,
  });

  /// Rangni 0..1 alfa bilan (yordamchi)
  static Color a(Color c, double o) => c.withValues(alpha: o);
}

// Brend ranglari — ikkala temada bir xil
const Color kViolet = Color(0xFF7C5CFF);
const Color kCyan = Color(0xFF22D3EE);
const Color kMint = Color(0xFF34D399);
const Color kCoral = Color(0xFFFB7185);
const Color kAmber = Color(0xFFFBBF24);
const Color kBlue = Color(0xFF2563EB);

const _dark = Pal(
  isDark: true,
  bg: Color(0xFF07080D), ink: Color(0xFFFFFFFF),
  hair: Color(0x0FFFFFFF), hair2: Color(0x0AFFFFFF),
  card2: Color(0x0FFFFFFF), field: Color(0x0FFFFFFF),
  hov: Color(0x14FFFFFF), hov2: Color(0x0AFFFFFF),
  bd: Color(0x1AFFFFFF), bd2: Color(0x14FFFFFF), barbg: Color(0x1AFFFFFF),
  t1: Color(0xCCFFFFFF), t2: Color(0x99FFFFFF), t3: Color(0x8CFFFFFF),
  t4: Color(0x80FFFFFF), t5: Color(0x66FFFFFF), t6: Color(0x4DFFFFFF),
  dim: Color(0xB307080D), // bg 70%
  green: kMint, red: kCoral,
  idle: Color(0x66FFFFFF), skelDot: Color(0x1FFFFFFF),
  surface: Color(0xFF151823), surface2: Color(0xFF12141C), sheetBg: Color(0xF20F1119),
  glass: Color(0x0FFFFFFF), glass2: Color(0x14FFFFFF), glassBd: Color(0x1AFFFFFF), hairline: Color(0x0FFFFFFF),
  violet: kViolet, cyan: kCyan, mint: kMint, coral: kCoral, amber: kAmber,
  onMint: Color(0xFF052E1C), onCoral: Color(0xFF2A0B12),
  panel: Color(0xD912141C),
);

// Yorug' tema — dizaynda yo'q («Yorug' rejim tez orada»), ammo toggle saqlanadi:
// xuddi shu tuzilma, och fon, qora matn, shisha = qora 4–8%.
const _light = Pal(
  isDark: false,
  bg: Color(0xFFF4F5FB), ink: Color(0xFF0B0C12),
  hair: Color(0x0F0B0C12), hair2: Color(0x0A0B0C12),
  card2: Color(0x0F0B0C12), field: Color(0x0F0B0C12),
  hov: Color(0x140B0C12), hov2: Color(0x0A0B0C12),
  bd: Color(0x1A0B0C12), bd2: Color(0x140B0C12), barbg: Color(0x1A0B0C12),
  t1: Color(0xCC0B0C12), t2: Color(0x990B0C12), t3: Color(0x8C0B0C12),
  t4: Color(0x800B0C12), t5: Color(0x660B0C12), t6: Color(0x4D0B0C12),
  dim: Color(0x8C0B0C12),
  green: Color(0xFF059669), red: Color(0xFFE11D48),
  idle: Color(0x660B0C12), skelDot: Color(0x1F0B0C12),
  surface: Color(0xFFFFFFFF), surface2: Color(0xFFFFFFFF), sheetBg: Color(0xF2FFFFFF),
  glass: Color(0xB3FFFFFF), glass2: Color(0x0F0B0C12), glassBd: Color(0x1A0B0C12), hairline: Color(0x0F0B0C12),
  violet: kViolet, cyan: Color(0xFF0891B2), mint: Color(0xFF059669), coral: Color(0xFFE11D48), amber: Color(0xFFD97706),
  onMint: Color(0xFFFFFFFF), onCoral: Color(0xFFFFFFFF),
  panel: Color(0xE6FFFFFF),
);

Pal pal(bool dark) => dark ? _dark : _light;

/// Gradientlar, soyalar, radiuslar — DESIGN_SPEC.md §1
class Tb {
  Tb._();
  static const LinearGradient brand = LinearGradient(colors: [kViolet, kCyan]);
  static const LinearGradient brandDiag = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kViolet, kCyan]);
  static const LinearGradient mintCyan = LinearGradient(colors: [kMint, kCyan]);
  static const LinearGradient amberCoral = LinearGradient(colors: [kAmber, kCoral]);
  static const LinearGradient coralRose = LinearGradient(colors: [kCoral, Color(0xFFF43F5E)]);
  static const LinearGradient userBubble = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kViolet, Color(0xFF5B8DEF)]);

  /// Avatar halqalari — hamkorga barqaror rang (ism hash'idan)
  static const List<List<Color>> ringPairs = [
    [kViolet, kCyan],
    [kCyan, kMint],
    [Color(0xFFF472B6), kViolet],
    [kAmber, kCoral],
    [kMint, kCyan],
    [Color(0xFF60A5FA), kViolet],
    [kCoral, Color(0xFFF59E0B)],
  ];
  static LinearGradient ringFor(String seed) {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final p = ringPairs[h % ringPairs.length];
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p);
  }

  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x737C5CFF), blurRadius: 36, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> glowMint = [
    BoxShadow(color: Color(0x6634D399), blurRadius: 36, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> panelShadow = [
    BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> imgShadow = [
    BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static const double rCard = 24, rRow = 20, rIcon = 14, rKey = 16, rSheet = 32, rPill = 999;
  static const double padX = 20;
}
