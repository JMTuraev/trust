// Til tanlash sheet'i — 6 til (uz, en, ru, es, fr, zh)
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

class LangSheet extends StatelessWidget {
  const LangSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    return SheetShell(
      onClose: () => v['closeLang'](),
      scroll: false,
      heightPct: 0.56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Tx(L0['langTitle'] as String, size: 18, w: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                for (final lg in (v['langRows'] as List))
                  Tap(
                    onTap: () => lg['pick'](),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: p.hair2)),
                      ),
                      child: Row(
                        children: [
                          Tx(lg['flag'], size: 20, color: p.ink, lh: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Tx(lg['name'], size: 14.5, w: FontWeight.w500, color: p.ink),
                          ),
                          if (lg['sel'] == true)
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
