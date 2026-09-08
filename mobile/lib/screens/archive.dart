// Arxiv ekrani — Qarz daftar headeridagi tugma orqali ochiladi.
// Arxivlangan hamkorlar ro'yxati; "Arxivdan chiqarish" bosilsa asosiy ro'yxatga qaytadi.
// Dizayn: DESIGN_SPEC "dark glass + gradient" (ScreenHeader · surface qatorlar · RingAvatar · GlassBtn).
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    final rows = (v['archRows'] as List).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          title: L0['archTitle'] as String,
          subtitle: L0['archSub'] as String,
          onBack: () => v['closeArch'](),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Tx(L0['archEmpty'] as String, size: 15, color: p.t3))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
                  children: [
                    for (final r in rows)
                      Container(
                        constraints: const BoxConstraints(minHeight: 76),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(Tb.rRow),
                          border: Border.all(color: p.glassBd),
                        ),
                        child: Row(
                          children: [
                            RingAvatar(initials: r['initials'] as String, size: 48, seed: '${r['name']}', dot: p.t6),
                            const SizedBox(width: 12),
                            Expanded(
                              // Hamkor nomi to'liq ko'rinsin — 2 qatorgacha o'raladi
                              child: Tx(r['name'], size: 16, w: FontWeight.w600, color: p.ink, maxLines: 2),
                            ),
                            const SizedBox(width: 10),
                            // Ichki padding'li shisha pill (PillChip) — qatorda ixcham tugma
                            PillChip(
                              label: L0['restoreBtn'] as String,
                              selected: false,
                              onTap: r['restore'],
                              h: 36,
                              leading: Icon(Icons.refresh_rounded, size: 16, color: p.t1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
