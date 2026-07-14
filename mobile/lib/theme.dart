// Trust dizayn tokenlari — prototip (prototype/template.html :root / body.dark) bilan 1:1
import 'package:flutter/material.dart';

class Pal {
  final Color bg, ink, hair, hair2, card2, field, hov, hov2, bd, bd2, barbg;
  final Color t1, t2, t3, t4, t5, t6;
  final Color dim, green, red, idle, skelDot;
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
  });
}

const _light = Pal(
  bg: Color(0xFFFFFFFF), ink: Color(0xFF111111),
  hair: Color(0xFFECECEC), hair2: Color(0xFFF2F2F0),
  card2: Color(0xFFF3F3F1), field: Color(0xFFF4F4F2),
  hov: Color(0xFFF7F7F5), hov2: Color(0xFFFBFBFA),
  bd: Color(0xFFE0E0DC), bd2: Color(0xFFE4E4E0), barbg: Color(0xFFE6E6E2),
  t1: Color(0xFF7A7A76), t2: Color(0xFF9C9C98), t3: Color(0xFFA2A29E),
  t4: Color(0xFFB0B0AC), t5: Color(0xFFB8B8B4), t6: Color(0xFFC4C4C0),
  dim: Color(0x57111111), // rgba(17,17,17,0.34)
  green: Color(0xFF2F7A54), red: Color(0xFFA94438),
  idle: Color(0xFFB5B5B1), skelDot: Color(0xFFC9C9C5),
);

const _dark = Pal(
  bg: Color(0xFF0F0F10), ink: Color(0xFFF5F5F5),
  hair: Color(0xFF262626), hair2: Color(0xFF202021),
  card2: Color(0xFF232324), field: Color(0xFF1C1C1E),
  hov: Color(0xFF1E1E1F), hov2: Color(0xFF161617),
  bd: Color(0xFF2E2E2F), bd2: Color(0xFF2A2A2B), barbg: Color(0xFF2E2E2F),
  t1: Color(0xFFA0A0A5), t2: Color(0xFF8A8A8E), t3: Color(0xFF86868A),
  t4: Color(0xFF6E6E73), t5: Color(0xFF66666B), t6: Color(0xFF55555A),
  dim: Color(0x8C000000), // rgba(0,0,0,0.55)
  green: Color(0xFF4CAF82), red: Color(0xFFD2695B),
  idle: Color(0xFF6B6B70), skelDot: Color(0xFF55555A),
);

Pal pal(bool dark) => dark ? _dark : _light;
