// O'zgartirish so'rovi (forma) — DESIGN_SPEC §5.9 uslubi ("dark glass + gradient").
// Callback'lar: closeEditForm / onEditA / onEditNote / submitEdit — o'zgarmagan.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

class EditFormSheet extends StatelessWidget {
  const EditFormSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final newA = v['editAText'] as String;
    return SheetShell(
      onClose: () => v['closeEditForm'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Tx(L0['editReqTitle'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head)),
            GlassIconBtn(icon: Icons.close_rounded, onTap: () => v['closeEditForm']()),
          ]),
          const SizedBox(height: 6),
          Tx(L0['editReqSub'] as String, size: 14, color: p.t2, lh: 20),
          const SizedBox(height: 20),
          Cap(L0['capOldAmount'] as String),
          const SizedBox(height: 8),
          Text(
            v['editOld'] as String,
            textScaler: TextScaler.noScaling,
            style: tbStyle(size: 16, w: FontWeight.w600, color: p.t3, tab: true).copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: p.t3,
            ),
          ),
          const SizedBox(height: 18),
          Cap(L0['capNewAmount'] as String),
          const SizedBox(height: 10),
          GlassField(
            h: 56,
            focused: newA.isNotEmpty,
            child: StoreField(
              value: newA,
              onChanged: (t) => v['onEditA'](t),
              hint: v['editOldRaw'] as String,
              hintColor: p.t6,
              keyboardType: TextInputType.number,
              style: tbStyle(size: 22, w: FontWeight.w600, color: p.ink, tab: true),
            ),
          ),
          const SizedBox(height: 18),
          Cap(L0['capNewNote'] as String),
          const SizedBox(height: 10),
          GlassField(
            h: 48,
            child: StoreField(
              value: v['editNote'] as String,
              onChanged: (t) => v['onEditNote'](t),
              hint: L0['noteHintOptional'] as String,
              style: tbStyle(size: 15, color: p.ink),
            ),
          ),
          const SizedBox(height: 22),
          GradientBtn(
            label: L0['sendRequest'] as String,
            icon: Icons.send_rounded,
            onTap: () => v['submitEdit'](),
            loading: v['busy'] == 'submitEdit',
          ),
        ],
      ),
    );
  }
}
