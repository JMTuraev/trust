// Tasdiq so'rovi (ikkinchi tomon) — prototype/template.html 1099–1129 bilan 1:1
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Row(
            children: [
              BackBtn(onTap: v['closeConfirm']),
              const SizedBox(width: 10),
              Tx("Tasdiq so'rovi", size: 16, w: FontWeight.w700, color: p.ink),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
                child: Tx(v['cfInitials'], size: 17, w: FontWeight.w600, color: p.ink),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Tx(v['cfTitle'], size: 16, w: FontWeight.w600, color: p.ink, lh: 24, align: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Tx(v['cfSub'], size: 12.5, color: p.t3),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: CodeBoxes(
                  boxes: (v['cfBoxes'] as List).cast<Map<String, dynamic>>(),
                  w: 48,
                  h: 54,
                  fs: 24,
                  gap: 9,
                  r: 12,
                ),
              ),
              if (v['cfError'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Tx("Kod noto'g'ri. Qayta urinib ko'ring.", size: 12, color: p.t2),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: InkBtn(label: 'Tasdiqlash', onTap: v['cfConfirm']),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        KeyPad(keys: (v['cfKeys'] as List).cast<Map<String, dynamic>>()),
      ],
    );
  }
}
