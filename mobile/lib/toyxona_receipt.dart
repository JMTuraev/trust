// To'yxona bron CHEKI — PDF (024, PO ro'yxati 10-band).
// Mazmun: to'yxona, sana/slot, mijoz, narx rejimi (kishi boshiga / butun to'yxona),
// stol turi va stol ustidagi taomlar, servislar (bonus alohida, jamiga kirmaydi),
// to'lovlar (avans/yakuniy/qaytarim), JAMI / TO'LANGAN / QOLDIQ, bekor shartlari
// (to'yxona siyosati) va bekor qilingan bo'lsa jarima/qaytarim.
// Matnlar joriy tilda (toyxona_l10n). Shrift: PdfGoogleFonts (kirill/lotin) —
// tarmoq bo'lmasa Helvetica (lotin) ga tushadi, PDF baribir chiqadi.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'toyxona_data.dart';
import 'toyxona_l10n.dart';

/// Bron chekini yasab, tizim ulashish varag'ini ochadi.
Future<void> shareBookingReceipt(Booking b, {Hall? hall, String ownerName = ''}) async {
  final bytes = await buildBookingReceipt(b, hall: hall, ownerName: ownerName);
  final safeName = b.clientName.replaceAll(RegExp(r'[^\w\d]+'), '_');
  await Printing.sharePdf(bytes: bytes, filename: 'trustbook_${toyYmd(b.eventDate)}_$safeName.pdf');
}

/// Sof qurish (testlanadi): Booking + Hall -> PDF baytlar.
Future<Uint8List> buildBookingReceipt(Booking b, {Hall? hall, String ownerName = ''}) async {
  pw.Font? base;
  pw.Font? bold;
  try {
    base = await PdfGoogleFonts.notoSansRegular();
    bold = await PdfGoogleFonts.notoSansBold();
  } catch (_) {
    // oflayn — Helvetica (kirill harflari chiqmasligi mumkin, lekin chek yo'qolmaydi)
  }
  final theme = base == null
      ? pw.ThemeData.base()
      : pw.ThemeData.withFont(base: base, bold: bold ?? base);

  final ink = PdfColor.fromHex('#111111');
  final muted = PdfColor.fromHex('#6B6B6B');
  final line = PdfColor.fromHex('#DDDDDD');
  final green = PdfColor.fromHex('#2F7A54');
  final red = PdfColor.fromHex('#A94438');

  pw.Widget row(String l, String v, {bool big = false, PdfColor? color, bool strike = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Text(l, style: pw.TextStyle(fontSize: big ? 12 : 10.5, color: color ?? ink))),
            pw.SizedBox(width: 12),
            pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: big ? 13 : 10.5,
                fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? ink,
                decoration: strike ? pw.TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      );
  pw.Widget cap(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
        child: pw.Text(t.toUpperCase(), style: pw.TextStyle(fontSize: 8.5, color: muted, letterSpacing: 1.2)),
      );
  pw.Widget hr() => pw.Container(height: 0.6, color: line, margin: const pw.EdgeInsets.symmetric(vertical: 6));

  final menu = hall?.menus.where((m) => m.id == b.menuId).firstOrNull;
  final policy = hall?.cancelPolicy ?? const <CancelRule>[];
  final paidRows = b.payments.where((p) => p.kind != 'qaytarim').toList();
  final refundRows = b.payments.where((p) => p.kind == 'qaytarim').toList();

  final doc = pw.Document(theme: theme, title: 'Trustbook — ${b.clientName}');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Sarlavha
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(ty('receiptTitle'), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: ink)),
              pw.SizedBox(height: 2),
              pw.Text(hall?.name ?? ty('noHallLabel'), style: pw.TextStyle(fontSize: 11, color: muted)),
              if (ownerName.isNotEmpty) pw.Text(ownerName, style: pw.TextStyle(fontSize: 10, color: muted)),
            ]),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: b.cancelled ? red : ink, width: 1.2)),
              child: pw.Text(tyStatus(b.status).toUpperCase(),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: b.cancelled ? red : ink)),
            ),
          ],
        ),
        hr(),
        cap(ty('receiptEventCap')),
        row(ty('dateLabel'), '${toyDateLong(b.eventDate)} · ${tySlot(b.slot)}'),
        row(ty('guestsLabel'), '${b.guests}'),
        row(ty('priceModeLabel'), tyPriceMode(b.priceMode)),
        cap(ty('clientCap')),
        row(ty('nameLabel'), b.clientName),
        if (b.clientPhone.isNotEmpty) row(ty('phoneLabel'), '+${b.clientPhone}'),
        if (b.note.isNotEmpty) row(ty('noteLabel'), b.note),

        cap(ty('moneyCap')),
        if (b.isTotalMode)
          row(ty('totalModeLine', {'guests': '${b.guests}'}), toyMoney(b.food))
        else
          row(
            b.menuTitle.isEmpty
                ? ty('guestsMath', {'guests': '${b.guests}', 'price': toyFx(b.pricePerGuest)})
                : ty('tierMath', {'title': b.menuTitle, 'guests': '${b.guests}', 'price': toyFx(b.pricePerGuest)}),
            toyMoney(b.food),
          ),
        if (menu != null && menu.items.isNotEmpty) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
            child: pw.Text('${ty('tableItemsLabel')}: ${menu.items.map((i) => i.label).join(', ')}',
                style: pw.TextStyle(fontSize: 9, color: muted)),
          ),
        ],
        // 025: xizmatlar KATEGORIYA bo'yicha guruhlanadi (chekda ham ekrandagi
        // tartib). Rasm QO'YILMAYDI: PDF ni tarmoqqa bog'lab qo'yardi va chek
        // oflayn (to'yxonada internet yo'q paytda) chiqmay qolardi.
        if (b.items.isNotEmpty) ...[
          cap(ty('extrasCap')),
          for (final c in kToyServiceCats)
            if (b.items.any((it) => it.category == c.slug)) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
                child: pw.Text(tyCat(c.slug),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: muted)),
              ),
              for (final it in b.items.where((x) => x.category == c.slug))
                row(
                  '${it.title}${it.qty > 1 ? ' × ${it.qty}' : ''}${it.isBonus ? ' · ${ty('bonusBadge')}' : ''}',
                  it.isBonus ? '${toyMoney(it.total)} → 0' : toyMoney(it.total),
                  color: it.isBonus ? muted : null,
                ),
            ],
        ],
        hr(),
        row(ty('totalLabel'), toyMoney(b.total), big: true),
        if (b.bonus > 0) row(ty('bonusLabel'), toyMoney(b.bonus), color: muted),

        cap(ty('paymentsCap')),
        if (paidRows.isEmpty && refundRows.isEmpty) row(ty('noPayments'), ''),
        for (final p in paidRows)
          row('${tyPayKind(p.kind)}${p.date != null ? ' · ${toyDateLong(p.date!)}' : ''}${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
              toyMoney(p.amount), color: green),
        for (final p in refundRows)
          row('${tyPayKind(p.kind)}${p.date != null ? ' · ${toyDateLong(p.date!)}' : ''}', '−${toyMoney(p.amount)}', color: red),
        hr(),
        row(ty('paidLabel'), toyMoney(b.paid), big: true, color: green),
        if (b.cancelled) ...[
          if (b.cancelPenalty > 0) row(ty('penaltyLabel'), toyMoney(b.cancelPenalty), color: red),
          if (b.refundDue > 0) row(ty('refundDueLabel'), toyMoney(b.refundDue), big: true),
          if (b.cancelReason.isNotEmpty) row(ty('cancelReasonLabel'), b.cancelReason, color: muted),
        ] else
          row(ty('leftLabel'), toyMoney(b.left), big: true, color: b.left > 0 ? red : green),

        if (policy.isNotEmpty || (hall?.depositPct ?? 0) > 0) ...[
          cap(ty('receiptTermsCap')),
          if ((hall?.depositPct ?? 0) > 0)
            pw.Text(ty('depositMinLine', {'pct': '${hall!.depositPct}', 'sum': toyMoney(toyDepositMin(b.total, hall.depositPct))}),
                style: pw.TextStyle(fontSize: 9.5, color: ink)),
          for (final r in policy)
            pw.Text('${tyPolicyDays(r.days)}: ${r.pct}%', style: pw.TextStyle(fontSize: 9.5, color: ink)),
          pw.SizedBox(height: 2),
          pw.Text(ty('cancelPolicyHint'), style: pw.TextStyle(fontSize: 8.5, color: muted)),
        ],

        pw.Spacer(),
        hr(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Trustbook · trustbook.uz', style: pw.TextStyle(fontSize: 8.5, color: muted)),
            pw.Text('${ty('receiptCreated')}: ${toyDateLong(DateTime.now())}', style: pw.TextStyle(fontSize: 8.5, color: muted)),
          ],
        ),
      ],
    ),
  ));
  return doc.save();
}
