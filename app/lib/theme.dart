import 'package:flutter/material.dart';

/// Prototipdagi aniq ranglar (CSS o'zgaruvchilari).
class P {
  final Color bg, ink, hair, hair2, card2, field, hov, hov2, bd, bd2, barbg;
  final Color t1, t2, t3, t4, t5, t6, dim;
  final Color green, red;
  const P({
    required this.bg, required this.ink, required this.hair, required this.hair2,
    required this.card2, required this.field, required this.hov, required this.hov2,
    required this.bd, required this.bd2, required this.barbg,
    required this.t1, required this.t2, required this.t3, required this.t4,
    required this.t5, required this.t6, required this.dim,
    required this.green, required this.red,
  });

  static const light = P(
    bg: Color(0xFFFFFFFF), ink: Color(0xFF111111), hair: Color(0xFFECECEC),
    hair2: Color(0xFFF2F2F0), card2: Color(0xFFF3F3F1), field: Color(0xFFF4F4F2),
    hov: Color(0xFFF7F7F5), hov2: Color(0xFFFBFBFA), bd: Color(0xFFE0E0DC),
    bd2: Color(0xFFE4E4E0), barbg: Color(0xFFE6E6E2),
    t1: Color(0xFF7A7A76), t2: Color(0xFF9C9C98), t3: Color(0xFFA2A29E),
    t4: Color(0xFFB0B0AC), t5: Color(0xFFB8B8B4), t6: Color(0xFFC4C4C0),
    dim: Color(0x57111111),
    green: Color(0xFF2F7A54), red: Color(0xFFA94438),
  );

  static const dark = P(
    bg: Color(0xFF0F0F10), ink: Color(0xFFF5F5F5), hair: Color(0xFF262626),
    hair2: Color(0xFF202021), card2: Color(0xFF232324), field: Color(0xFF1C1C1E),
    hov: Color(0xFF1E1E1F), hov2: Color(0xFF161617), bd: Color(0xFF2E2E2F),
    bd2: Color(0xFF2A2A2B), barbg: Color(0xFF2E2E2F),
    t1: Color(0xFFA0A0A5), t2: Color(0xFF8A8A8E), t3: Color(0xFF86868A),
    t4: Color(0xFF6E6E73), t5: Color(0xFF66666B), t6: Color(0xFF55555A),
    dim: Color(0x8C000000),
    green: Color(0xFF3E9B6C), red: Color(0xFFC15A4C),
  );
}
