// Trust — asosiy kompozitsiya. Prototipdagi ekran/overlay z-tartibi bilan 1:1.
import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';

import 'screens/onboarding.dart';
import 'screens/cc_sheet.dart';
import 'screens/home.dart';
import 'screens/moliya.dart';
import 'screens/xarajat.dart';
import 'screens/profil.dart';
import 'screens/tab_bar.dart';
import 'screens/client_screen.dart';
import 'screens/notifs.dart';
import 'screens/confirm_screen.dart';
import 'screens/receipt.dart';
import 'screens/pdf_preview.dart';
import 'screens/new_tx_sheet.dart';
import 'screens/new_partner_sheet.dart';
import 'screens/edit_form_sheet.dart';
import 'screens/review_screen.dart';
import 'screens/push_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  runApp(const TrustApp());
}

class TrustApp extends StatelessWidget {
  const TrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final dark = store.S['dark'] == true;
        final p = pal(dark);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: p.bg,
            useMaterial3: true,
          ),
          home: const Root(),
        );
      },
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final v = store.vals();
        final p = curPal();
        return Scaffold(
          backgroundColor: p.bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Stack(
              children: [
                if (v['isApp'] == true) ...[
                  // Asosiy tab ekranlari + tab bar
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              if (v['isHome'] == true) const Positioned.fill(child: HomeScreen()),
                              if (v['isMoliya'] == true) const Positioned.fill(child: MoliyaScreen()),
                              if (v['isXarajat'] == true) const Positioned.fill(child: XarajatScreen()),
                              if (v['isProfil'] == true) const Positioned.fill(child: ProfilScreen()),
                            ],
                          ),
                        ),
                        if (v['clientOpen'] != true) const TrustTabBar(),
                      ],
                    ),
                  ),
                  // Hamkor sahifasi (z:10)
                  if (v['clientOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: const ClientScreen())),
                  // Bildirishnomalar (z:12)
                  if (v['notifOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: const NotifsScreen())),
                  // Ikkinchi tomon tasdig'i (z:14)
                  if (v['confirmOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: const ConfirmScreen())),
                  // O'zgartirishni tasdiqlash (z:16)
                  if (v['reviewOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: const ReviewScreen())),
                  // Dalil (z:20)
                  if (v['receiptOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: const ReceiptScreen())),
                  // PDF dalil (z:22)
                  if (v['pdfOpen'] == true)
                    Positioned.fill(child: Container(color: p.field, child: const PdfPreviewScreen())),
                  // Bottom sheetlar (z:30/34)
                  if (v['sheetOpen'] == true) const NewTxSheet(),
                  if (v['npOpen'] == true) const NewPartnerSheet(),
                  if (v['editFormOpen'] == true) const EditFormSheet(),
                  // Android push demo (z:48)
                  if (v['pushOpen'] == true) const Positioned.fill(child: PushDemo()),
                ] else
                  const Positioned.fill(child: OnboardingScreen()),
                // Davlat kodi sheet (z:60)
                if (v['ccOpen'] == true) const CcSheet(),
                // Toast (z:70)
                ToastView(open: v['toastOpen'] == true, text: v['toast'] as String),
              ],
            ),
          ),
        );
      },
    );
  }
}
