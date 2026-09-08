// Yangi operatsiya bottom sheet — DESIGN_SPEC §5.9 ("dark glass + gradient").
// Sarlavha 20/600 + ✕ · hamkor chiplari (RingAvatar 24) · turi (PillChip 2×2) ·
// summa 46/600 (berdim mint / oldim coral / to'lov oq) + valyuta segmenti ·
// izoh GlassField · GradientBtn(send) · hint 13 t4. Callback'lar o'zgarmagan.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class NewTxSheet extends StatelessWidget {
  const NewTxSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final L0 = v['L'] as Map<String, dynamic>;
    final Pal p = curPal();
    final types = (v['types'] as List).cast<Map<String, dynamic>>();
    final curs = (v['curs'] as List).cast<Map<String, dynamic>>();
    final clients = (v['sheetClients'] as List).cast<Map<String, dynamic>>();
    // Tanlangan tur: store 'bg' ni ink qiladi (tanlangan) — rang bo'yicha aniqlanadi
    bool sel(Map<String, dynamic> m) => m['bg'] == p.ink;
    final selType = types.indexWhere(sel);
    final amtColor = selType == 0
        ? p.mint
        : selType == 1
            ? p.coral
            : p.ink;
    final amountText = (v['formAmountText'] as String?) ?? '';

    return SheetShell(
      onClose: () => v['closeSheet'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Tx(v['sheetTitle'], size: 20, w: FontWeight.w600, color: p.ink, font: TbFont.head)),
            GlassIconBtn(icon: Icons.close_rounded, onTap: () => v['closeSheet']()),
          ]),
          if (v['sheetFixed'] == true) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: PillChip(
                label: store.Lf('forX', {'name': '${v['sheetFixedName']}'}),
                selected: false,
                onTap: null,
                leading: RingAvatar(initials: v['sheetFixedInitials'], size: 24, ring: 1.5, seed: '${v['sheetFixedName']}'),
              ),
            ),
          ],
          if (v['sheetClientMode'] == true) ...[
            const SizedBox(height: 20),
            Cap(L0['capPartner'] as String),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < clients.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    PillChip(
                      label: clients[i]['name'] as String,
                      selected: sel(clients[i]),
                      onTap: () => clients[i]['pick'](),
                      leading: RingAvatar(
                        initials: _ini(clients[i]['name'] as String),
                        size: 24,
                        ring: 1.5,
                        seed: clients[i]['name'] as String,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Cap(L0['capType'] as String),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _typeChip(types[0], sel(types[0]))),
            const SizedBox(width: 8),
            Expanded(child: _typeChip(types[1], sel(types[1]))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _typeChip(types[2], sel(types[2]))),
            const SizedBox(width: 8),
            Expanded(child: _typeChip(types[3], sel(types[3]))),
          ]),
          const SizedBox(height: 20),
          Cap(L0['capAmount'] as String),
          const SizedBox(height: 6),
          // Summa 46/600 (bo'sh: t6) + o'ngda valyuta segmenti (h40 shisha pill)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: StoreField(
                  value: amountText,
                  onChanged: (t) => v['onAmount'](t),
                  hint: '0',
                  hintColor: p.t6,
                  keyboardType: TextInputType.number,
                  style: tbStyle(size: 46, w: FontWeight.w600, color: amtColor, tab: true, ls: -1),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: p.glass,
                  border: Border.all(color: p.glassBd),
                  borderRadius: BorderRadius.circular(Tb.rPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final cu in curs)
                      Tap(
                        onTap: () => cu['pick'](),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel(cu) ? p.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(Tb.rPill),
                          ),
                          child: Tx(cu['label'], size: 13, w: FontWeight.w700, color: sel(cu) ? p.bg : p.t2, font: TbFont.num),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Cap(L0['capNote'] as String),
          const SizedBox(height: 10),
          GlassField(
            h: 48,
            child: StoreField(
              value: v['formNote'],
              onChanged: (t) => v['onNote'](t),
              hint: L0['notePh'] as String,
              style: tbStyle(size: 15, color: p.ink),
            ),
          ),
          if (v['shTwoSided'] == true) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: p.t4),
                const SizedBox(width: 7),
                Expanded(child: Tx(L0['twoSidedCur'] as String, size: 13, color: p.t4, lh: 18)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          GradientBtn(
            label: v['sheetBtnLabel'],
            icon: Icons.send_rounded,
            onTap: () => v['createTx'](),
            loading: v['busy'] == 'createTx',
            enabled: amountText.trim().isNotEmpty,
          ),
          const SizedBox(height: 12),
          Center(
            child: Tx(v['sheetHint'], size: 13, color: p.t4, lh: 18, align: TextAlign.center),
          ),
        ],
      ),
    );
  }

  static String _ini(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _typeChip(Map<String, dynamic> tp, bool on) {
    return PillChip(label: tp['label'] as String, selected: on, onTap: () => tp['pick'](), h: 44);
  }
}
