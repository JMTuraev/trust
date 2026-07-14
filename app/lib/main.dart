import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'nav.dart';
import 'data.dart';
import 'screens/onboarding.dart';
import 'screens/home.dart';
import 'screens/moliya.dart';
import 'screens/xarajat.dart';
import 'screens/profil.dart';
import 'screens/client_detail.dart';
import 'screens/notifs.dart';
import 'screens/receipt.dart';
import 'screens/new_op.dart';

void main() => runApp(const TrustApp());

class TrustApp extends StatefulWidget {
  const TrustApp();
  @override
  State<TrustApp> createState() => _TrustAppState();
}

class _TrustAppState extends State<TrustApp> {
  bool dark = true;
  @override
  Widget build(BuildContext c) {
    final p = dark ? P.dark : P.light;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trust',
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFE9E9E7),
      ),
      home: PhoneFrame(
        child: AppShell(p: p, dark: dark, toggleDark: () => setState(() => dark = !dark)),
      ),
    );
  }
}

/// Prototipdagi 390x844 telefon ramkasi — desktopda markazda, mobilda to'liq.
class PhoneFrame extends StatelessWidget {
  final Widget child;
  const PhoneFrame({required this.child});
  @override
  Widget build(BuildContext c) {
    final size = MediaQuery.of(c).size;
    final full = size.width < 460;
    if (full) return child;
    return Container(
      color: const Color(0xFFE9E9E7),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 390, height: 844,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9D9D5)),
            borderRadius: BorderRadius.circular(36),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  final P p;
  final bool dark;
  final VoidCallback toggleDark;
  const AppShell({required this.p, required this.dark, required this.toggleDark});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool onboarded = false;
  int tab = 0; // 0 home, 1 xarajat, 2 moliya, 3 profil
  Partner? client;
  bool sheetOpen = false, notifOpen = false, receiptOpen = false;

  @override
  Widget build(BuildContext c) {
    final p = widget.p;
    return Container(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: !onboarded
            ? Onboarding(p: p, onDone: () => setState(() => onboarded = true))
            : _main(p),
      ),
    );
  }

  Nav _nav(P p) => Nav(
        p: p,
        isDark: widget.dark,
        tab: tab,
        client: client,
        toggleDark: widget.toggleDark,
        goTab: (i) => setState(() => tab = i),
        openClient: (r) => setState(() => client = r),
        back: () => setState(() => client = null),
        openSheet: () => setState(() => sheetOpen = true),
        closeSheet: () => setState(() => sheetOpen = false),
        openNotifs: () => setState(() => notifOpen = true),
        closeNotifs: () => setState(() => notifOpen = false),
        openReceipt: () => setState(() => receiptOpen = true),
        closeReceipt: () => setState(() => receiptOpen = false),
      );

  Widget _main(P p) {
    final nav = _nav(p);
    Widget body;
    switch (tab) {
      case 1:
        body = XarajatScreen(nav);
        break;
      case 2:
        body = MoliyaScreen(nav);
        break;
      case 3:
        body = ProfilScreen(nav);
        break;
      default:
        body = HomeScreen(nav);
    }

    return Stack(children: [
      Column(children: [
        Expanded(child: body),
        _bottomNav(p, nav),
      ]),
      // FAB faqat home
      if (tab == 0)
        Positioned(right: 20, bottom: 84, child: GestureDetector(
          onTap: nav.openSheet,
          child: Container(width: 52, height: 52,
              decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 10, offset: const Offset(0, 3)),
              ]),
              child: Icon(Icons.add, color: p.bg, size: 26)),
        )),
      if (client != null) Positioned.fill(child: ClientDetail(nav)),
      if (notifOpen) Positioned.fill(child: NotifsScreen(nav)),
      if (receiptOpen) Positioned.fill(child: ReceiptScreen(nav)),
      if (sheetOpen) Positioned.fill(child: NewOpSheet(nav)),
    ]);
  }

  Widget _bottomNav(P p, Nav nav) {
    final items = [
      [Icons.people_outline, 'Hamkorlar'],
      [Icons.receipt_long_outlined, 'Xarajat'],
      [Icons.bar_chart, 'Moliya'],
      [Icons.person_outline, 'Profil'],
    ];
    return Container(
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.hair))),
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(children: [
        for (int i = 0; i < items.length; i++)
          Expanded(child: GestureDetector(
            onTap: () => nav.goTab(i),
            behavior: HitTestBehavior.opaque,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(items[i][0] as IconData, size: 21, color: tab == i ? p.ink : p.t4),
              const SizedBox(height: 4),
              Text(items[i][1] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: tab == i ? p.ink : p.t4)),
            ]),
          )),
      ]),
    );
  }
}
