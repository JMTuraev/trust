// Davlat kodi tanlash sheet'i (template 1284–1308)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';

class CcSheet extends StatelessWidget {
  const CcSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    return SheetShell(
      onClose: () => v['ccClose'](),
      scroll: false,
      heightPct: 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Tx(L0['countryCode'] as String, size: 18, w: FontWeight.w700, color: p.ink),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: StoreField(
                value: v['ccSearch'],
                onChanged: (t) => v['onCcSearch'](t),
                hint: L0['searchPh'] as String,
                style: GoogleFonts.inter(fontSize: 14, color: p.ink),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                for (final cc in (v['ccRows'] as List))
                  Tap(
                    onTap: () => cc['pick'](),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: p.hair2)),
                      ),
                      child: Row(
                        children: [
                          Tx(cc['flag'], size: 20, color: p.ink, lh: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Tx(
                              cc['name'],
                              size: 14.5,
                              w: FontWeight.w500,
                              color: p.ink,
                              maxLines: 1,
                              ellipsis: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tx(cc['dial'], size: 13.5, w: FontWeight.w600, color: p.t1, tab: true),
                          if (cc['sel'] == true) ...[
                            const SizedBox(width: 14),
                            Transform.translate(
                              offset: const Offset(0, -2),
                              child: Transform.rotate(
                                angle: -0.785398,
                                child: Container(
                                  width: 7,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: p.ink, width: 1.8),
                                      bottom: BorderSide(color: p.ink, width: 1.8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
