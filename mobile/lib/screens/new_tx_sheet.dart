// Yangi operatsiya bottom sheet — prototype/template.html 1195–1248 bilan 1:1
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class NewTxSheet extends StatelessWidget {
  const NewTxSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();
    final types = (v['types'] as List).cast<Map<String, dynamic>>();
    final curs = (v['curs'] as List).cast<Map<String, dynamic>>();

    return SheetShell(
      onClose: () => v['closeSheet'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx(v['sheetTitle'], size: 18, w: FontWeight.w700, color: p.ink),
          if (v['sheetFixed'] == true)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.fromLTRB(7, 5, 12, 5),
              decoration: BoxDecoration(
                border: Border.all(color: p.bd2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                    child: Center(
                      child: Tx(v['sheetFixedInitials'], size: 9.5, w: FontWeight.w700, color: p.bg),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Tx('${v['sheetFixedName']} uchun', size: 12.5, w: FontWeight.w600, color: p.ink),
                ],
              ),
            ),
          if (v['sheetClientMode'] == true) ...[
            const SizedBox(height: 20),
            const Cap('HAMKOR'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < (v['sheetClients'] as List).length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _chip((v['sheetClients'] as List)[i] as Map<String, dynamic>),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Cap('TURI'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _typeBtn(types[0])),
            const SizedBox(width: 8),
            Expanded(child: _typeBtn(types[1])),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _typeBtn(types[2])),
            const SizedBox(width: 8),
            Expanded(child: _typeBtn(types[3])),
          ]),
          const SizedBox(height: 20),
          const Cap('SUMMA'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.bd),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: StoreField(
                    value: v['formAmountText'],
                    onChanged: (t) => v['onAmount'](t),
                    hint: '0',
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(color: p.bd),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final cu in curs)
                        Tap(
                          onTap: () => cu['pick'](),
                          child: Container(
                            width: 56,
                            height: double.infinity,
                            alignment: Alignment.center,
                            color: cu['bg'],
                            child: Tx(cu['label'], size: 13, w: FontWeight.w600, color: cu['fg']),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Cap('IZOH'),
          const SizedBox(height: 10),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: p.bd),
              borderRadius: BorderRadius.circular(10),
            ),
            child: StoreField(
              value: v['formNote'],
              onChanged: (t) => v['onNote'](t),
              hint: 'Masalan: mol savdosi uchun',
              style: GoogleFonts.inter(fontSize: 14, color: p.ink),
            ),
          ),
          if (v['shTwoSided'] == true) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 7,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.t3, width: 1.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Tx(
                    "Tanlangan valyuta yozuvning ikkala tomonida ham bir xil ko'rinadi",
                    size: 11,
                    color: p.t3,
                    lh: 15.4,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          InkBtn(label: v['sheetBtnLabel'], onTap: () => v['createTx']()),
          const SizedBox(height: 12),
          Center(
            child: Tx(v['sheetHint'], size: 11.5, color: p.t4, lh: 17.25, align: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _chip(Map<String, dynamic> sc) {
    return Tap(
      onTap: () => sc['pick'](),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sc['bg'],
          border: Border.all(color: sc['bd']),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Tx(sc['name'], size: 13, w: FontWeight.w600, color: sc['fg']),
      ),
    );
  }

  Widget _typeBtn(Map<String, dynamic> tp) {
    return Tap(
      onTap: () => tp['pick'](),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tp['bg'],
          border: Border.all(color: tp['bd']),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Tx(tp['label'], size: 13, w: FontWeight.w600, color: tp['fg']),
      ),
    );
  }
}
