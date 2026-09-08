// Yangi hamkor bottom sheet — DESIGN_SPEC §5.9 uslubi ("dark glass + gradient").
// Callback'lar: npClose / onNpName / ccOpenNp / onNpPhone / npCreate — o'zgarmagan.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class NewPartnerSheet extends StatelessWidget {
  const NewPartnerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    final name = (v['npName'] as String?) ?? '';
    final phone = (v['npPhoneText'] as String?) ?? '';

    return SheetShell(
      onClose: () => v['npClose'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Tx(L0['newPartnerTitle'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head)),
            GlassIconBtn(icon: Icons.close_rounded, onTap: () => v['npClose']()),
          ]),
          const SizedBox(height: 20),
          Cap(L0['capName'] as String),
          const SizedBox(height: 10),
          GlassField(
            h: 52,
            icon: Icons.person_outline_rounded,
            focused: name.isNotEmpty,
            child: StoreField(
              value: name,
              onChanged: (t) => v['onNpName'](t),
              hint: L0['namePh'] as String,
              style: tbStyle(size: 15, color: p.ink),
            ),
          ),
          const SizedBox(height: 20),
          Cap(L0['capPhone'] as String),
          const SizedBox(height: 10),
          GlassField(
            h: 52,
            focused: phone.isNotEmpty,
            child: Row(
              children: [
                // Davlat kodi — bosilsa CcSheet ochiladi
                Tap(
                  onTap: () => v['ccOpenNp'](),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tx(v['npCcFlag'], size: 18, color: p.ink, lh: 18),
                      const SizedBox(width: 6),
                      Tx(v['npCcDial'], size: 15, w: FontWeight.w600, color: p.ink, tab: true),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: p.t3),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 22, color: p.glassBd),
                const SizedBox(width: 10),
                Expanded(
                  child: StoreField(
                    value: phone,
                    onChanged: (t) => v['onNpPhone'](t),
                    hint: v['npPh'],
                    keyboardType: TextInputType.number,
                    style: tbStyle(size: 15, color: p.ink, tab: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: p.t4),
              const SizedBox(width: 7),
              Expanded(child: Tx(v['npHint'], size: 13, color: p.t4, lh: 18)),
            ],
          ),
          const SizedBox(height: 24),
          GradientBtn(
            label: L0['btnAdd'] as String,
            icon: Icons.add_rounded,
            onTap: () => v['npCreate'](),
            loading: v['busy'] == 'npCreate',
          ),
        ],
      ),
    );
  }
}
