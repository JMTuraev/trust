// Til tanlash sheet'i — 6 til (uz, en, ru, es, fr, zh).
// Dizayn: SheetShell ichida GlassCard ro'yxat, tanlangan → cyan check.
// Store shartnomasi o'zgarmadi: closeLang, langRows (flag/name/sel/pick).
import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class LangSheet extends StatelessWidget {
  const LangSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    final rows = (v['langRows'] as List).cast<Map<String, dynamic>>();
    return SheetShell(
      onClose: () => v['closeLang'](),
      scroll: false,
      heightPct: 0.56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tb.padX),
            child: Tx(L0['langTitle'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 24),
              children: [
                GlassCard(
                  r: 24,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        ListRow(
                          leading: Tx('${rows[i]['flag'] ?? ''}', size: 22, color: p.ink, lh: 22),
                          title: '${rows[i]['name'] ?? ''}',
                          chevron: false,
                          last: i == rows.length - 1,
                          trailing: rows[i]['sel'] == true
                              ? Icon(Icons.check_rounded, size: 20, color: p.cyan)
                              : null,
                          onTap: () => rows[i]['pick'](),
                        ),
                    ],
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
