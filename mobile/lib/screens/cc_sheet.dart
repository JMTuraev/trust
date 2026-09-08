// Davlat kodi tanlash sheet'i.
// Dizayn: SheetShell ichida qidiruv (GlassField) + GlassCard ro'yxat, tanlangan → cyan check.
// Store shartnomasi o'zgarmadi: ccClose, ccSearch/onCcSearch, ccRows (flag/name/dial/sel/pick).
import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class CcSheet extends StatelessWidget {
  const CcSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final p = curPal();
    final rows = (v['ccRows'] as List).cast<Map<String, dynamic>>();
    return SheetShell(
      onClose: () => v['ccClose'](),
      scroll: false,
      heightPct: 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tb.padX),
            child: Tx(L0['countryCode'] as String, size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Tb.padX, 14, Tb.padX, 0),
            child: GlassField(
              h: 48,
              icon: Icons.search_rounded,
              child: StoreField(
                value: v['ccSearch'],
                onChanged: (t) => v['onCcSearch'](t),
                hint: L0['searchPh'] as String,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 24),
              children: [
                if (rows.isNotEmpty)
                  GlassCard(
                    r: 24,
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          ListRow(
                            leading: Tx('${rows[i]['flag'] ?? ''}', size: 22, color: p.ink, lh: 22),
                            // Davlat nomi to'liq ko'rinsin — ListRow 2 qatorgacha o'raydi
                            title: '${rows[i]['name'] ?? ''}',
                            chevron: false,
                            last: i == rows.length - 1,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tx('${rows[i]['dial'] ?? ''}', size: 14, w: FontWeight.w600, color: p.t1, tab: true),
                                if (rows[i]['sel'] == true) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.check_rounded, size: 20, color: p.cyan),
                                ],
                              ],
                            ),
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
