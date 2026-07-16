// Circle detali — prototip frame 2 (boshqa navbati), 5 (sizning navbatingiz),
// 13 (yakunlangan). Bir ekran: faol / yakunlangan / yopilgan (soft-close) holatlar.
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';
import '../theme.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

class CircleDetailScreen extends StatelessWidget {
  const CircleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    if (c == null) return const SizedBox.shrink();

    if (c.status != CircleStatus.active) return _completed(c, v, p);
    return _active(c, v, p);
  }

  // ---------- FAOL: boshqa a'zo navbati yoki sizning navbatingiz ----------
  Widget _active(Circle c, Map<String, dynamic> v, Pal p) {
    final mine = c.isMyTurn;
    final rec = c.currentRecipient;
    final idx = c.currentRound.index, total = c.roundsTotal, len = c.members.length;

    // A'zolar ro'yxati (sizning navbatingizda o'zingizni ko'rsatmaymiz — frame 5)
    final members = mine ? c.members.where((m) => !m.isYou).toList() : c.members;

    return Column(
      children: [
        CircleHeader(
          leading: BackBtn(onTap: () => v['closeCircle']()),
          title: c.name,
          trailing: Tap(
            onTap: () => v['openCircleManage'](),
            child: Tx('$len ${cf('membersK').toLowerCase()}', size: 11.5, color: p.t3),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Hero
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(mine ? cf('youReceiveRound') : cf('poolThisRound'),
                        size: 11, w: FontWeight.w600, color: mine ? p.green : p.t3, ls: 1.5),
                    const SizedBox(height: 6),
                    Tx(money(c.pool, c.currency), size: 30, w: FontWeight.w700, color: p.ink, ls: -0.8),
                    const SizedBox(height: 2),
                    Tap(
                      onTap: () => v['openCircleHistory'](),
                      child: Tx(
                        c.currentRound.dueDate.isEmpty
                            ? cf('roundOf', {'a': '$idx', 'b': '$total'})
                            : cf('collectedBy', {'a': '$idx', 'b': '$total', 'date': c.currentRound.dueDate}),
                        size: 12,
                        color: p.t2,
                      ),
                    ),
                  ],
                ),
              ),
              // Recipient karta
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(12),
                  border: mine ? Border.all(color: p.green) : null,
                ),
                child: Row(
                  children: [
                    CAvatar(initials: mine ? 'You' : (rec?.initials ?? ''), size: 30, tint: mine ? Tint.me : (rec?.tint ?? Tint.warm)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tx(mine ? cf('yourTurn') : (rec?.name ?? ''), size: 13.5, w: FontWeight.w600, color: p.ink),
                          const SizedBox(height: 1),
                          Tx(mine ? cf('poolYours') : cf('receivesThisRound'), size: 11.5, color: p.t2),
                        ],
                      ),
                    ),
                    Tx(money(c.pool, c.currency), size: 14, w: FontWeight.w600, color: p.green),
                  ],
                ),
              ),
              ProofBanner(
                mine
                    ? cf('bannerYourTurn', {'n': '${c.paidCount}', 'm': '$len'})
                    : cf('bannerPaid', {'n': '${c.paidCount}', 'm': '$len', 'name': firstName(rec?.name ?? '')}),
              ),
              CircleSectionCap(cf('membersCap')),
              for (final m in members) _memberRow(c, m, mine, p),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // Amallar. Holatlar: taklif kutilmoqda / sizning navbatingiz / to'lagansiz / to'lash kerak.
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            children: [
              if (c.myStatus == 'invited')
                // Taklif qabul qilinmagan — avval qo'shilish (server pay'ga ruxsat bermaydi)
                CircleBtn(label: cf('joinBtn'), onTap: () => v['openCircleJoin'](c.id))
              else if (mine)
                CircleBtn(
                  label: cf('confirmReceiptBtn', {'amt': money(c.pool, c.currency)}),
                  check: true,
                  onTap: () => v['openCircleConfirm'](),
                )
              else if (c.youPaid)
                // Allaqachon to'lagansiz — qayta to'lov o'rniga kutish holati
                Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: p.green),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckGlyph(size: 16, color: p.green),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tx(cf('youPaidWait', {'name': firstName(rec?.name ?? '')}),
                            size: 13, w: FontWeight.w600, color: p.green, maxLines: 1, ellipsis: true),
                      ),
                    ],
                  ),
                )
              else
                CircleBtn(
                  label: cf('markPayment', {'amt': money(c.amount, c.currency)}),
                  check: true,
                  onTap: () => v['openCirclePay'](),
                ),
              if (mine && c.unpaidCount > 0)
                CircleLink(
                  label: cf('remindUnpaid', {'n': '${c.unpaidCount}'}),
                  onTap: () async {
                    final n = await circlesRepo.remindUnpaid(c.id);
                    store.toast_(n != null
                        ? cf('remindSent', {'n': '$n'})
                        : (circlesRepo.error ?? cf('toastError')));
                  },
                )
              else if (c.isOwner)
                // Faqat egasi taklif qila oladi (server shuni talab qiladi)
                CircleLink(label: cf('inviteMember'), onTap: () => v['openCircleInvite']()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _memberRow(Circle c, CircleMember m, bool mine, Pal p) {
    final isRecipient = m.id == c.currentRound.recipientId;
    Widget status;
    if (isRecipient && !m.isYou) {
      status = Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(20)),
        child: Tx(cf('thisRound'), size: 11.5, color: p.t1),
      );
    } else {
      final paid = c.paid(m.id);
      final suffix = mine
          ? ''
          : ' · ${m.payoutPosition < c.currentRound.index ? cf('gotRound', {'n': '${m.payoutPosition}'}) : cf('roundN', {'n': '${m.payoutPosition}'})}';
      status = paid
          ? Tx('✓ ${cf('paid')}$suffix', size: 11.5, w: FontWeight.w600, color: p.green)
          : Tx('${cf('pending')}$suffix', size: 11.5, color: p.t3);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
      child: Row(
        children: [
          CAvatar(initials: m.initials, size: 26, tint: m.tint),
          const SizedBox(width: 9),
          Expanded(child: Tx(m.name, size: 13.5, color: p.ink, maxLines: 1, ellipsis: true)),
          const SizedBox(width: 10),
          status,
        ],
      ),
    );
  }

  // ---------- YAKUNLANGAN (frame 13) yoki YOPILGAN (soft-close) ----------
  Widget _completed(Circle c, Map<String, dynamic> v, Pal p) {
    final len = c.members.length;
    final closed = c.status == CircleStatus.closed;
    final received = c.receivedIds; // round'i yopilgan a'zolar
    return Column(
      children: [
        CircleHeader(
          leading: BackBtn(onTap: () => v['closeCircle']()),
          title: c.name,
          trailing: Tx(closed ? cf('closedTag') : cf('complete'), size: 11.5, color: p.t3),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
                      child: closed ? CloseGlyph(size: 30, color: p.t2) : CheckGlyph(size: 30, color: p.green),
                    ),
                    const SizedBox(height: 14),
                    Tx(closed ? cf('closedTitle') : cf('completeTitle'), size: 18, w: FontWeight.w700, color: p.ink),
                    const SizedBox(height: 4),
                    Tx(
                      closed
                          ? cf('closedSub', {'n': '${c.doneRounds}', 'm': '${c.roundsTotal}'})
                          : cf('everyoneReceived'),
                      size: 12.5,
                      color: p.t2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: CircleStatCell(
                              k: cf('totalPooled'), val: money(c.pool * c.doneRounds, c.currency))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: CircleStatCell(
                              k: cf('roundsK'),
                              val: cf('nOfM', {'a': '${c.doneRounds}', 'b': '${c.roundsTotal}'}))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: CircleStatCell(k: cf('membersK'), val: cf('people', {'n': '$len'}))),
                      const SizedBox(width: 10),
                      Expanded(child: CircleStatCell(k: cf('period'), val: c.period.isEmpty ? '—' : c.period)),
                    ]),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Cap(closed ? cf('membersCap') : cf('everyoneGotTurn'), ls: 1.5)),
              ),
              for (final m in c.members)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair2))),
                  child: Row(
                    children: [
                      CAvatar(initials: m.initials, size: 26, tint: m.tint),
                      const SizedBox(width: 9),
                      Expanded(child: Tx(m.name, size: 13.5, color: p.ink, maxLines: 1, ellipsis: true)),
                      const SizedBox(width: 10),
                      // Yopilganda: faqat round'i haqiqatan yopilganlar ✓; qolganlari kulrang
                      received.contains(m.id) || !closed
                          ? Tx('✓ ${cf('roundN', {'n': '${m.payoutPosition}'})}',
                              size: 11.5, w: FontWeight.w600, color: p.green)
                          : Tx(cf('roundN', {'n': '${m.payoutPosition}'}), size: 11.5, color: p.t3),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hair))),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Column(
            children: [
              CircleBtn(label: cf('startNew'), onTap: () => v['openCircleCreate']()),
              CircleLink(label: cf('viewHistory'), onTap: () => v['openCircleHistory']()),
            ],
          ),
        ),
      ],
    );
  }
}
