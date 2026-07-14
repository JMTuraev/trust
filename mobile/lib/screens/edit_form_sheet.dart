// O'zgartirish so'rovi (forma) — prototip 1482–1499 qatorlar bilan 1:1
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';

class EditFormSheet extends StatelessWidget {
  const EditFormSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    return SheetShell(
      onClose: () => v['closeEditForm'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx("O'zgartirish so'rovi", size: 18, w: FontWeight.w700, color: p.ink),
          const SizedBox(height: 6),
          Tx(
            "O'zgarish faqat ikkinchi tomon tasdiqlagandan keyin kuchga kiradi. Asl yozuv o'chirilmaydi.",
            size: 12.5, color: p.t3, lh: 18.75,
          ),
          const SizedBox(height: 20),
          const Cap('ESKI SUMMA'),
          const SizedBox(height: 8),
          Text(
            v['editOld'] as String,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.t3,
              decoration: TextDecoration.lineThrough,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          const Cap('YANGI SUMMA'),
          const SizedBox(height: 10),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(12),
            ),
            child: StoreField(
              value: v['editAText'] as String,
              onChanged: (t) => v['onEditA'](t),
              hint: v['editOldRaw'] as String,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: p.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Cap('YANGI IZOH'),
          const SizedBox(height: 10),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(10),
            ),
            child: StoreField(
              value: v['editNote'] as String,
              onChanged: (t) => v['onEditNote'](t),
              hint: 'Izoh (ixtiyoriy)',
              style: GoogleFonts.inter(fontSize: 14, color: p.ink),
            ),
          ),
          const SizedBox(height: 22),
          InkBtn(label: "So'rov yuborish", onTap: () => v['submitEdit']()),
        ],
      ),
    );
  }
}
