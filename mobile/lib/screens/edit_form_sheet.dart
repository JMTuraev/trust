// O'zgartirish so'rovi (forma) — prototip 1482–1499 qatorlar bilan 1:1
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';

class EditFormSheet extends StatelessWidget {
  const EditFormSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    return SheetShell(
      onClose: () => v['closeEditForm'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx(L0['editReqTitle'] as String, size: 18, w: FontWeight.w700, color: p.ink),
          const SizedBox(height: 6),
          Tx(
            L0['editReqSub'] as String,
            size: 12.5, color: p.t3, lh: 18.75,
          ),
          const SizedBox(height: 20),
          Cap(L0['capOldAmount'] as String),
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
          Cap(L0['capNewAmount'] as String),
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
          Cap(L0['capNewNote'] as String),
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
              hint: L0['noteHintOptional'] as String,
              style: GoogleFonts.inter(fontSize: 14, color: p.ink),
            ),
          ),
          const SizedBox(height: 22),
          InkBtn(label: L0['sendRequest'] as String, onTap: () => v['submitEdit'](), loading: v['busy'] == 'submitEdit'),
        ],
      ),
    );
  }
}
