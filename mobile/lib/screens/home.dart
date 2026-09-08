// Qarz daftar (Home) ekrani — hamkorlar ro'yxati.
// Dizayn: prototype/redesign/DESIGN_SPEC.md §5.7 ("dark glass + gradient").
//   ScreenHeader · GlassField qidiruv · PillChip davr filtri · surface qatorlar
//   (RingAvatar + holat nuqtasi, "Trustbook'da" badge, summa) · chapga surish → Arxiv.
// "SOF BALANS" bloki dizaynda yo'q — hisob-kitob hamkor chatidagi balans kartasida.
// Arxiv va bildirishnomalar — headerdagi GlassIconBtn'lar (openArch / openNotifs).
import 'package:flutter/material.dart';
import '../flags.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';

/// Dizayn matni uchun L() kaliti yo'q bo'lsa — uz-fallback (xarajat.dart _t naqshi).
String _t(String key, String fb) => (store.L()[key] as String?) ?? fb;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final L0 = v['L'] as Map<String, dynamic>;
    final rows = v['clientRows'] as List;
    final skel = v['skelHome'] == true;

    final listChildren = <Widget>[];
    if (skel) {
      for (final s in (v['skelRows'] as List)) {
        listChildren.add(_skelRow(p, s['w1'] as double, s['w2'] as double));
      }
    }
    for (final r in rows) {
      listChildren.add(_SwipeRow(key: ValueKey(r['id']), r: r as Map<String, dynamic>));
    }
    if (v['homeLoadingMore'] == true) {
      listChildren.add(_skelRow(p, 0.48, 0.30));
    }
    if (!skel && rows.isEmpty) {
      // Bo'sh holat — "Hech narsa topilmadi" 15 t3, py64
      listChildren.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: Tx(_t('homeEmpty', 'Hech narsa topilmadi'), // TODO l10n
              size: 15, color: p.t3, align: TextAlign.center),
        ),
      ));
    }

    final opts = (v['homeFilterOpts'] as List).cast<Map<String, dynamic>>();
    final customOn = v['homeFilterCustomOn'] == true;

    return Stack(
      children: [
        Column(
          children: [
            // Header — orqaga (<) → hub; o'ngda Arxiv va Bildirishnomalar.
            ScreenHeader(
              title: v['homeTitle'] as String,
              subtitle: (v['hubDebtSub'] as String?) ?? '',
              onBack: () => v['goHub'](),
              trailing: [
                GlassIconBtn(icon: Icons.archive_outlined, onTap: () => v['openArch'](), iconSize: 20),
                GlassIconBtn(
                  icon: Icons.notifications_none_rounded,
                  onTap: () => v['openNotifs'](),
                  badge: v['bellDot'] == true ? ((v['notifUnread'] as int?) ?? 1) : 0,
                ),
              ],
            ),
            // Qidiruv — h48 shisha pill
            Padding(
              padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 0),
              child: GlassField(
                h: 48,
                icon: Icons.search_rounded,
                focused: (v['search'] as String).isNotEmpty,
                trailing: (v['search'] as String).isNotEmpty
                    ? Tap(
                        onTap: () => v['onSearch'](''),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.close_rounded, size: 18, color: p.t3),
                        ),
                      )
                    : null,
                child: StoreField(
                  value: v['search'],
                  onChanged: (t) => v['onSearch'](t),
                  hint: L0['searchPh'] as String,
                  style: tbStyle(size: 15, color: p.ink),
                ),
              ),
            ),
            // Davr filtri — PillChip'lar (gorizontal skroll): Jami · Bugun · Kecha ·
            // Hafta · Oy · Maxsus davr. Callback'lar: opts[i].pick / homeFilterCustom.
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(Tb.padX, 0, Tb.padX, 0),
                children: [
                  for (var i = 0; i < opts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    PillChip(
                      label: opts[i]['label'] as String,
                      selected: opts[i]['on'] == true,
                      onTap: () => opts[i]['pick'](),
                    ),
                  ],
                  const SizedBox(width: 8),
                  PillChip(
                    label: customOn
                        ? (v['homeFilterLabel'] as String)
                        : (v['homeFilterCustomLabel'] as String),
                    selected: customOn,
                    leading: Icon(Icons.calendar_today_rounded, size: 14, color: customOn ? p.bg : p.t2),
                    onTap: () {
                      v['homeFilterCustomPick']();
                      _pickCustomRange(context, v, p);
                    },
                  ),
                  if (v['homeFilterActive'] == true) ...[
                    const SizedBox(width: 8),
                    // Filtrni Jami'ga qaytarish (×)
                    GlassIconBtn(icon: Icons.close_rounded, onTap: () => v['homeFilterReset'](), size: 40, iconSize: 18),
                  ],
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 140) {
                    v['homeMore']();
                  }
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Tb.padX, 16, Tb.padX, 120),
                  children: listChildren,
                ),
              ),
            ),
          ],
        ),
        // FAB "+" — yangi hamkor (openSheetHome): 60px gradient doira
        Positioned(
          right: 20,
          bottom: 40,
          child: Tap(
            onTap: () => v['openSheetHome'](),
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                gradient: Tb.brandDiag,
                shape: BoxShape.circle,
                boxShadow: Tb.glow,
              ),
              child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// Maxsus davr — sana oralig'i tanlagichi (ilova palitrasida).
  /// Chegaralar epoch ms sifatida store'ga o'tadi; kun boshlari/oxirlari
  /// homePeriodRange'da QURILMA-LOKAL hisoblanadi.
  Future<void> _pickCustomRange(BuildContext context, Map<String, dynamic> v, Pal p) async {
    final now = DateTime.now();
    final from = v['homeFilterFrom'] as int, to = v['homeFilterTo'] as int;
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: (from > 0 && to > 0)
          ? DateTimeRange(
              start: DateTime.fromMillisecondsSinceEpoch(from),
              end: DateTime.fromMillisecondsSinceEpoch(to))
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: (p.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
            primary: p.violet,
            onPrimary: Colors.white,
            surface: p.surface,
            onSurface: p.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (r != null) {
      v['homeFilterCustom'](r.start.millisecondsSinceEpoch, r.end.millisecondsSinceEpoch);
    }
  }

  Widget _skelRow(Pal p, double w1, double w2) {
    return Container(
      height: 76,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Tb.rRow),
        border: Border.all(color: p.glassBd),
      ),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: p.glass2, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skel(wf: w1, h: 12),
                const SizedBox(height: 8),
                Skel(wf: w2, h: 9, r: 5),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Skel(w: 64, h: 12),
        ],
      ),
    );
  }
}

/// Chapga surib arxivlash qatori (surish mantig'i store.swBegin/swMove/swEnd).
class _SwipeRow extends StatefulWidget {
  final Map<String, dynamic> r;
  const _SwipeRow({super.key, required this.r});

  @override
  State<_SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<_SwipeRow> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final p = curPal();
    final r = widget.r;
    // Kiruvchi (link) qatorlarda amal yo'q (actLabel bo'sh) — surish o'chiriladi,
    // aks holda bo'sh panel ochilardi (2026-08-04 audit topilmasi).
    final canSwipe = ((r['actLabel'] as String?) ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tb.rRow),
        child: Stack(
          children: [
            // Orqa fon: coral "Arxiv" tugmasi (76×52, r16) — surilganda ochiladi (snap −96)
            if (canSwipe)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Tap(
                    onTap: () => r['archTap'](),
                    child: Container(
                      width: 76,
                      height: 52,
                      decoration: BoxDecoration(color: p.coral, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.archive_outlined, size: 18, color: p.onCoral),
                          const SizedBox(height: 2),
                          Tx(r['actLabel'] as String, size: 14, w: FontWeight.w700, color: p.onCoral, maxLines: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset((r['tx'] as num).toDouble(), 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => r['open'](),
                onHorizontalDragStart: canSwipe
                    ? (_) {
                        _dx = 0;
                        store.swBegin(r['id']);
                      }
                    : null,
                onHorizontalDragUpdate: canSwipe
                    ? (d) {
                        _dx += d.delta.dx;
                        store.swMove(r['id'], _dx);
                      }
                    : null,
                onHorizontalDragEnd: canSwipe ? (_) => store.swEnd(r['id'], r['archAct']) : null,
                onHorizontalDragCancel: canSwipe ? () => store.swEnd(r['id'], r['archAct']) : null,
                child: _clientContent(p, r),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Holat nuqtasi: kutilmoqda (o'qilmagan hodisa) amber · sizga qarz mint ·
  /// siz qarzdorsiz coral · hisob teng/yopiq t6.
  Color _dot(Pal p, Map<String, dynamic> r) {
    if (r['notifOn'] == true) return p.amber;
    final c = r['color'];
    if (c == p.green) return p.mint;
    if (c == p.red) return p.coral;
    return p.t6;
  }

  Widget _clientContent(Pal p, Map<String, dynamic> r) {
    final inTrust = r['inTrust'] == true;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Tb.rRow),
        border: Border.all(color: p.glassBd),
      ),
      child: Row(
        children: [
          // Avatar + o'qilmagan qarz-hodisalar soni («9+» cap) — coralRose pufak
          Stack(
            clipBehavior: Clip.none,
            children: [
              RingAvatar(initials: r['initials'] as String, size: 48, seed: r['name'] as String?, dot: _dot(p, r)),
              if (r['notifOn'] == true)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: Tb.coralRose,
                      borderRadius: BorderRadius.circular(Tb.rPill),
                      border: Border.all(color: p.surface, width: 2),
                    ),
                    child: Tx(r['notifCountTxt'] as String,
                        size: 10, w: FontWeight.w700, color: Colors.white, font: TbFont.body),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hamkor nomi — sig'masa 2 qatorga o'raladi
                Tx(r['name'], size: 16, w: FontWeight.w600, color: p.ink, maxLines: 2),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (inTrust)
                      PillBadge.cyan(_t('inTrustBadge', "Trustbook'da"), icon: Icons.check_rounded) // TODO l10n
                    else
                      PillBadge.muted(_t('inviteBadge', 'Taklif qiling')), // TODO l10n
                    if (((r['sub'] as String?) ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(child: Tx(r['sub'] as String, size: 12, color: p.t3, maxLines: 1, ellipsis: true)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // O'qilmagan xabarlar badge — chat UI yashirilganda KO'RSATILMAYDI (flags.dart)
          if (kChatEnabled && (r['unread'] as int? ?? 0) > 0) ...[
            PillBadge.mint('${r['unread']}'),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summa "..." bilan kesilmaydi
              Tx(r['bal'], size: 16, w: FontWeight.w600, color: r['color'], tab: true, maxLines: 1),
              // So'nggi o'qilmagan bildirishnoma summasi — chip (count > 0 bo'lsa);
              // aks holda oddiy balSub qatori.
              if (r['notifAmtOn'] == true) ...[
                const SizedBox(height: 3),
                PillBadge.amber(r['notifAmtTxt'] as String, h: 20),
              ] else if ((r['balSub'] as String).isNotEmpty) ...[
                const SizedBox(height: 2),
                Tx(r['balSub'], size: 13, color: p.t3, maxLines: 1),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
