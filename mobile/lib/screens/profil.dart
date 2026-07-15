// Profil ekrani — prototype/template.html 654–681 bilan 1:1
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final rows = (v['profRows'] as List).cast<Map<String, dynamic>>();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.card2, shape: BoxShape.circle),
                child: Tx(v['meInitials'], size: 22, w: FontWeight.w600, color: p.ink),
              ),
              if (v['meEditing'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border.all(color: p.bd),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: StoreField(
                            value: v['meEditVal'],
                            onChanged: (t) => v['onMeName'](t),
                            hint: 'Ismingiz',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
                            onSubmit: () => v['meNameSave'](),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tap(
                        onTap: () => v['meNameSave'](),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(18)),
                          child: Tx('OK', size: 12.5, w: FontWeight.w600, color: p.bg),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  // Ism — mijozlarga shu ko'rinadi; bosib tahrirlash mumkin
                  child: Tap(
                    onTap: () => v['meEditToggle'](),
                    child: Tx(v['meName'], size: 18, w: FontWeight.w700, color: p.ink),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tx(v['mePhoneFmt'], size: 13, color: p.t2),
              ),
            ],
          ),
        ),
        for (final pr in rows)
          Tap(
            onTap: pr['tap'],
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hair2))),
              child: Row(
                children: [
                  Expanded(child: Tx(pr['label'], size: 14.5, color: p.ink)),
                  const SizedBox(width: 12),
                  if (pr['isSwitch'] == true)
                    Container(
                      width: 44,
                      height: 26,
                      decoration: BoxDecoration(
                        color: pr['trk'],
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 200),
                            top: 3,
                            left: pr['knobLeft'],
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: pr['knob'],
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (pr['isPlain'] == true) ...[
                    Tx(pr['value'], size: 13, color: p.t3),
                    const SizedBox(width: 12),
                    ChevRight(color: p.t6),
                  ],
                ],
              ),
            ),
          ),
        Tap(
          onTap: v['logout'],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tx('Chiqish', size: 14.5, w: FontWeight.w600, color: p.ink),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Tx('Trust · v1.1 · Toshkent', size: 11, color: p.t6)),
        ),
      ],
    );
  }
}
