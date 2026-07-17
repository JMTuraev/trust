// Pastki navigatsiya paneli — prototype/template.html 684–720 bilan 1:1
// Ikonkalar mazmunga moslandi: Hamkorlar — 2 kishilik, Xarajat — hamyon.
//
// QO'SHIMCHA (obuna): SubBanner + SubInfo shu faylda yashaydi — main.dart bu
// faylni allaqachon import qilgani uchun global joylashtirish main.dart'da
// import'siz, bitta qatorlik patch bo'ladi (hisobot §NEW-PATCHES).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';
import '../flags.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

// ---------------------------------------------------------------------------
// OBUNA (subscription) UI yordamchilari
// Model (mahsulot qarori): 7 kun bepul sinov -> $9/oy. To'lanmagan bo'lsa —
// READ-ONLY: hamma narsa ko'rinadi, yangi yozuv kiritilmaydi (server 402 beradi).
// ---------------------------------------------------------------------------

/// Ogohlantirish (warning) toni — brend palitrasida yo'q, shu yerda lokal.
/// Oxra/oltin: qizil (expired) bilan adashtirmaydigan, xotirjam "shoshilmang" rangi.
const Color kSubWarnL = Color(0xFF8A6116); // och fon uchun quyuq oxra
const Color kSubWarnD = Color(0xFFD9B35C); // to'q fon uchun yumshoq oltin
Color subWarnInk(bool dark) => dark ? kSubWarnD : kSubWarnL;

/// l10n kaliti hali qo'shilmagan bo'lsa — o'zbekcha fallback (default til).
/// Kalitlar 6 tilga hisobot §NEW-PATCHES bilan qo'shiladi; qo'shilgach shu
/// funksiya avtomatik tarjimani ishlata boshlaydi (kod o'zgarmaydi).
String subTr(String key, String fb, [Map<String, String>? vars]) {
  var s = (store.L()[key] as String?) ?? fb;
  (vars ?? const <String, String>{}).forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

/// Obuna holatining yengil o'qilishi (store.S -> banner / profil kartasi).
/// store.dart'ga tegmasdan ishlaydi; 'premUntil' hali store patch bilan
/// qo'shilmagan bo'lsa — regressiyasiz: premium warn shunchaki o'chiq qoladi.
class SubInfo {
  final String status; // 'trial' | 'premium' | 'expired'
  final int daysLeft; // amaldagi muddat oxirigacha kunlar; -1 = noma'lum
  final DateTime? until; // trial oxiri yoki premium_until (lokal vaqt)
  const SubInfo(this.status, this.daysLeft, this.until);

  bool get expired => status == 'expired';

  /// ≤3 kun qolganda (trial HAM premium HAM) — "To'lov muddati yaqinlashdi"
  bool get warnSoon => !expired && until != null && daysLeft >= 0 && daysLeft <= 3;

  static DateTime? _parse(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static SubInfo read() {
    final st = store.S['subStatus'] as String? ?? 'trial';
    final end =
        st == 'premium' ? _parse(store.S['premUntil']) : _parse(store.S['trialEnd']);
    var dl = -1;
    if (end != null) {
      // store.dart profRows bilan bir xil hisob: difference().inDays + 1
      dl = end.difference(DateTime.now()).inDays + 1;
      if (dl < 0) dl = 0;
      if (st == 'trial' && dl > 7) dl = 7;
    }
    return SubInfo(st, dl, end);
  }
}

/// Global obuna banneri — header hududida (main.dart asosiy Column boshi).
/// - expired: DOIMIY (yopib bo'lmaydi), bosilsa Profil (obuna kartasi) ochiladi.
/// - trial/premium ≤3 kun: ogohlantirish; kuniga bir marta yopish mumkin
///   (SharedPreferences'da 'trust_subwarn_day' — ertasi kuni yana ko'rinadi).
class SubBanner extends StatefulWidget {
  const SubBanner({super.key});

  @override
  State<SubBanner> createState() => _SubBannerState();
}

class _SubBannerState extends State<SubBanner> {
  static const _kDismissKey = 'trust_subwarn_day';
  String? _dismissedDay; // 'yyyy-mm-dd' — warning shu kunga yopilgan

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      final d = sp.getString(_kDismissKey);
      if (mounted && d != null) setState(() => _dismissedDay = d);
    }).catchError((_) {});
  }

  String _today() {
    final n = DateTime.now();
    String d2(int x) => x.toString().padLeft(2, '0');
    return '${n.year}-${d2(n.month)}-${d2(n.day)}';
  }

  void _dismiss() {
    final t = _today();
    setState(() => _dismissedDay = t);
    SharedPreferences.getInstance()
        .then((sp) => sp.setString(_kDismissKey, t))
        .catchError((_) => false); // saqlash yiqilsa ham UI holati buzilmaydi
  }

  // Profilga o'tish — store.vals()['goProfil'] bilan aynan bir xil patch
  void _openProfil() =>
      store.set({'screen': 'profil', 'clientId': null, 'receiptId': null, 'inLinkId': null});

  @override
  Widget build(BuildContext context) {
    final Pal p = curPal();
    final sub = SubInfo.read();

    // ---- EXPIRED: doimiy, xotirjam lekin e'tibordan chetda qolmaydigan karta ----
    if (sub.expired) {
      return Tap(
        onTap: _openProfil,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: p.red.withValues(alpha: .10),
            border: Border.all(color: p.red.withValues(alpha: .32)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: p.red),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(subTr('subExpiredTitle', "To'lov muddati tugagan"),
                        size: 13.5, w: FontWeight.w700, color: p.red),
                    const SizedBox(height: 2),
                    Tx(subTr('subExpiredBody', 'Yangi yozuv kirita olmaysiz — obunani yangilang'),
                        size: 12, color: p.ink, lh: 16),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChevRight(color: p.red),
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
    }

    // ---- ≤3 KUN QOLDI: ogohlantirish, kuniga bir marta yopiladi ----
    if (sub.warnSoon && _dismissedDay != _today()) {
      final w = subWarnInk(store.S['dark'] == true);
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          color: w.withValues(alpha: .10),
          border: Border.all(color: w.withValues(alpha: .30)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 17, color: w),
            const SizedBox(width: 10),
            Expanded(
              child: Tap(
                onTap: _openProfil,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Tx(
                    subTr('subWarnSoon', "To'lov muddati yaqinlashdi — {n} kun qoldi",
                        {'n': '${sub.daysLeft}'}),
                    size: 12.5, w: FontWeight.w600, color: w, lh: 17,
                  ),
                ),
              ),
            ),
            // Yopish (faqat bugungi kunga) — ertaga yana eslatadi
            Tap(
              onTap: _dismiss,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: Icon(Icons.close, size: 16, color: w)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

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
                // Circles — kCirclesEnabled=false (flags.dart): o'rniga Trust AI keldi.
                // Kod joyida: bayroqni true qilsang tugma qaytadi.
                if (kCirclesEnabled)
                  _tab(
                    onTap: () => v['goCircles'](),
                    color: v['cCircle'],
                    label: cl()['navCircle'] as String,
                    // Circles: aylanma (rotation) ikonka — navbat aylanishi metaforasi
                    icon: SizedBox(
                      height: 20,
                      child: Center(child: CircleGlyph(size: 20, color: v['cCircle'])),
                    ),
                  ),
                if (kAiEnabled)
                  _tab(
                    onTap: () => v['goAi'](),
                    color: v['cAi'],
                    label: L0['navAi'] as String,
                    // Trust AI: uchqun (sparkle) — mavjud outline ikonka uslubida
                    icon: SizedBox(
                      height: 20,
                      child: Center(
                        child: Icon(Icons.auto_awesome_outlined, size: 19, color: v['cAi']),
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
          // Qora "home-indicator" chizig'i olib tashlandi (foydalanuvchi so'rovi,
          // 2026-07-17 — prototype 684–720 dan ataylab chetlashish). O'rniga
          // xotirjam pastki bo'shliq: nav qatori tag gesture-bar bilan urishmasin
          // (OS inset'ini main.dart'dagi SafeArea allaqachon zaxiralaydi).
          const SizedBox(height: 12),
        ],
      ),
    );
  }

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
