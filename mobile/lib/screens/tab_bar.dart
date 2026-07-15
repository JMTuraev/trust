// Pastki navigatsiya paneli — prototype/template.html 684–720 bilan 1:1
// Ikonkalar mazmunga moslandi: Hamkorlar — 2 kishilik, Xarajat — hamyon.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

class TrustTabBar extends StatelessWidget {
  const TrustTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final Pal p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.hair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 9, 6, 2),
            child: Row(
              children: [
                _tab(
                  onTap: () => v['goHome'](),
                  color: v['cMij'],
                  label: L0['navClients'] as String,
                  // Hamkorlar: 2 KISHILIK odamcha ikonka (foydalanuvchi so'rovi)
                  icon: SizedBox(
                    height: 20,
                    child: Center(
                      child: Icon(Icons.people_alt_outlined, size: 20, color: v['cMij']),
                    ),
                  ),
                ),
                _tab(
                  onTap: () => v['goXarajat'](),
                  color: v['cXar'],
                  label: L0['navXar'] as String,
                  // Xarajat: hamyon (chat pufagi mos emas edi)
                  icon: SizedBox(
                    height: 20,
                    child: Center(
                      child: Icon(Icons.account_balance_wallet_outlined, size: 19, color: v['cXar']),
                    ),
                  ),
                ),
                _tab(
                  onTap: () => v['goMoliya'](),
                  color: v['cMol'],
                  label: L0['navFin'] as String,
                  icon: SizedBox(
                    height: 20,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(9, v['cMol']),
                          const SizedBox(width: 2.5),
                          _bar(15, v['cMol']),
                          const SizedBox(width: 2.5),
                          _bar(12, v['cMol']),
                        ],
                      ),
                    ),
                  ),
                ),
                _tab(
                  onTap: () => v['goProfil'](),
                  color: v['cProf'],
                  label: L0['navProfile'] as String,
                  icon: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: v['cProf'], width: 1.6),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: v['cProf']),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Center(
              child: Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double h, Color c) => Container(
        width: 4,
        height: h,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1.5)),
      );

  Widget _tab({
    required VoidCallback onTap,
    required Color color,
    required String label,
    required Widget icon,
  }) {
    return Expanded(
      child: Tap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              Tx(label, size: 10, w: FontWeight.w600, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
