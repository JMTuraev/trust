// Arxiv ekrani — headerdagi tugma orqali ochiladi.
// Arxivlangan hamkorlar ro'yxati; "Qaytarish" bosilsa asosiy ro'yxatga qaytadi.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: BackBtn(onTap: () => v['closeArch']()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
          child: Tx(L0['archTitle'] as String, size: 22, w: FontWeight.w700, color: p.ink, ls: -0.3),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Tx(L0['archSub'] as String, size: 12.5, color: p.t3),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Tx(L0['archEmpty'] as String, size: 13.5, color: p.t3))
              : ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  children: [
                    for (final r in rows)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
                        child: Row(
                          children: [
                            TrustAvatar(initials: r['initials'] as String, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Tx(r['name'], size: 14.5, w: FontWeight.w600, color: p.ink,
                                  maxLines: 1, ellipsis: true),
                            ),
                            const SizedBox(width: 10),
                            Tap(
                              onTap: r['restore'],
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.ink,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Tx(L0['restoreBtn'] as String, size: 12.5, w: FontWeight.w600, color: p.bg),
                              ),
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
