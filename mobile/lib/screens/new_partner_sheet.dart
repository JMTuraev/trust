// Yangi hamkor bottom sheet — prototype/template.html 1250–1282 bilan 1:1
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class NewPartnerSheet extends StatelessWidget {
  const NewPartnerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();

    return SheetShell(
      onClose: () => v['npClose'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx('Yangi hamkor', size: 18, w: FontWeight.w700, color: p.ink),
          const SizedBox(height: 20),
          const Cap('ISM'),
          const SizedBox(height: 10),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(10),
            ),
            child: StoreField(
              value: v['npName'],
              onChanged: (t) => v['onNpName'](t),
              hint: 'Ism yozing',
              style: GoogleFonts.inter(fontSize: 14.5, color: p.ink),
            ),
          ),
          const SizedBox(height: 20),
          const Cap('TELEFON'),
          const SizedBox(height: 10),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Tap(
                  onTap: () => v['ccOpenNp'](),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tx(v['npCcFlag'], size: 17, color: p.ink, lh: 17),
                      const SizedBox(width: 6),
                      Tx(v['npCcDial'], size: 14.5, w: FontWeight.w600, color: p.ink, tab: true),
                      const SizedBox(width: 6),
                      Transform.translate(
                        offset: const Offset(0, -3),
                        child: Transform.rotate(
                          angle: 0.785398,
                          child: Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: p.t3, width: 1.6),
                                bottom: BorderSide(color: p.t3, width: 1.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: p.bd),
                const SizedBox(width: 8),
                Expanded(
                  child: StoreField(
                    value: v['npPhoneText'],
                    onChanged: (t) => v['onNpPhone'](t),
                    hint: v['npPh'],
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      color: p.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Cap('HOLAT'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stateBtn(
                  "Trust'da bor",
                  bg: v['npOnBg'],
                  bd: v['npOnBd'],
                  fg: v['npOnFg'],
                  onTap: () => v['npPickOn'](),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stateBtn(
                  'Taklif qilish',
                  bg: v['npInvBg'],
                  bd: v['npInvBd'],
                  fg: v['npInvFg'],
                  onTap: () => v['npPickInv'](),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Tx(v['npHint'], size: 11, color: p.t3, lh: 16.5),
          const SizedBox(height: 24),
          InkBtn(label: "Qo'shish", onTap: () => v['npCreate']()),
        ],
      ),
    );
  }

  Widget _stateBtn(String label, {required Color bg, required Color bd, required Color fg, required VoidCallback onTap}) {
    return Tap(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: bd),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Tx(label, size: 13, w: FontWeight.w600, color: fg),
      ),
    );
  }
}
