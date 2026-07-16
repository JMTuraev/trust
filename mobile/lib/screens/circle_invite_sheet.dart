// A'zo taklif qilish sheet — real (ism + telefon), backendga yuboriladi.
// "Share invite link" — haqiqiy nusxalash (clipboard): matn ichida join kodi.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../store.dart';
import '../ui.dart';
import '../circles_data.dart';
import '../circle_ui.dart';
import '../circles_l10n.dart';

class CircleInviteSheet extends StatefulWidget {
  const CircleInviteSheet({super.key});

  @override
  State<CircleInviteSheet> createState() => _CircleInviteSheetState();
}

class _CircleInviteSheetState extends State<CircleInviteSheet> {
  String _name = '';
  String _phone = '';
  bool _busy = false;

  Future<void> _copyLink(Circle c) async {
    // join_token'ni server faqat egasiga beradi
    final token = c.joinToken;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: cf('joinCodeShare', {'name': c.name, 'token': token})));
    store.toast_(cf('linkCopied'));
  }

  // Faqat kodning o'zi (qabul qiluvchi "Taklif kodini kiriting"ga joylaydi)
  Future<void> _copyCode(Circle c) async {
    final token = c.joinToken;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token));
    store.toast_(cf('codeCopied'));
  }

  // Kodni o'qish oson bo'lishi uchun 6 belgidan guruhlab ko'rsatamiz
  String _grouped(String t) => t.replaceAllMapped(RegExp('.{6}'), (m) => '${m.group(0)} ').trim();

  @override
  Widget build(BuildContext context) {
    final v = store.vals();
    final p = curPal();
    final c = circlesRepo.byId(v['circleId'] as String?);
    final ready = !_busy && _phone.replaceAll(RegExp(r'\D'), '').length >= 7;

    Widget field(String hint, String value, ValueChanged<String> onCh, {TextInputType? kb}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
          child: StoreField(
            value: value,
            onChanged: onCh,
            hint: hint,
            keyboardType: kb,
            style: GoogleFonts.inter(fontSize: 14, color: p.ink),
          ),
        );

    return SheetShell(
      onClose: () => v['closeCircleInvite'](),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tx(cf('inviteTitle'), size: 16.5, w: FontWeight.w600, color: p.ink),
          const SizedBox(height: 14),
          field(cf('name'), _name, (t) => setState(() => _name = t)),
          const SizedBox(height: 8),
          field('+998…', _phone, (t) => setState(() => _phone = t), kb: TextInputType.phone),
          const SizedBox(height: 10),
          // Taklif KODI — ko'zga tashlanadigan joyda, bosilganda nusxalanadi
          // (qabul qiluvchi Circles -> "Taklif orqali qo'shilish"ga kiritadi)
          if (c?.joinToken != null)
            Tap(
              onTap: () => _copyCode(c!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tx(cf('inviteCodeCap').toUpperCase(), size: 10.5, w: FontWeight.w600, color: p.t3, ls: 0.4),
                          const SizedBox(height: 4),
                          Tx(_grouped(c!.joinToken!), size: 15, w: FontWeight.w600, color: p.ink, ls: 1.1, tab: true),
                        ],
                      ),
                    ),
                    Tx(cf('copy'), size: 13, color: p.t2),
                  ],
                ),
              ),
            ),
          // Havolani ulashish — faqat egasida token bor (server shunday beradi)
          if (c?.joinToken != null)
            Tap(
              onTap: () => _copyLink(c!),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
                      child: Icon(Icons.link_rounded, size: 16, color: p.ink),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Tx(cf('shareLink'), size: 13.5, color: p.ink)),
                    Tx(cf('copy'), size: 13, color: p.t2),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Opacity(
            opacity: ready ? 1 : 0.5,
            child: CircleBtn(
              label: _busy ? '…' : cf('addN', {'n': '1'}),
              onTap: () {
                if (!ready) return;
                setState(() => _busy = true);
                v['circleInviteAdd']([
                  {'name': _name.trim(), 'phone': _phone.trim()}
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
