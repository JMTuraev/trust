// Trust — asosiy kompozitsiya. Prototipdagi ekran/overlay z-tartibi bilan 1:1.
import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';
import 'ui.dart';

import 'screens/onboarding.dart';
import 'screens/cc_sheet.dart';
import 'screens/home.dart';
import 'screens/circles.dart';
import 'screens/circle_detail.dart';
import 'screens/circle_create.dart';
import 'screens/circle_history.dart';
import 'screens/circle_manage.dart';
import 'screens/circle_join.dart';
import 'screens/circle_pay_sheet.dart';
import 'screens/circle_confirm_sheet.dart';
import 'screens/circle_invite_sheet.dart';
import 'screens/xarajat.dart';
import 'screens/profil.dart';
import 'screens/tab_bar.dart';
import 'screens/client_screen.dart';
import 'screens/notifs.dart';
import 'screens/receipt.dart';
import 'screens/pdf_preview.dart';
import 'screens/new_tx_sheet.dart';
import 'screens/new_partner_sheet.dart';
import 'screens/edit_form_sheet.dart';
import 'screens/link_decision_sheet.dart';
import 'screens/rejected_links.dart';
import 'screens/archive.dart';
import 'screens/lang_sheet.dart';

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
            // Scaffold body'ga bo'sh (min-0) balandlik beradi; Stack faqat Positioned
            // bolalardan iborat bo'lgani uchun 0 balandlikka yig'ilib qolardi — to'liq ekranga majburlaymiz.
            child: SizedBox.expand(
              child: Stack(
              // DIQQAT: bu bolalar `const` bo'lmasligi kerak — const instance kanonik bo'lgani
              // uchun Root qayta qurilganda Element rebuild'ni o'tkazib yuboradi va store'dan
              // o'qiydigan ekranlar muzlab qoladi.
              children: [
                if (v['isApp'] == true) ...[
                  // Asosiy tab ekranlari + tab bar
                  Positioned.fill(
                    child: Column(
                      children: [
                        // Obuna banneri (tugagan / ≤3 kun qoldi) — header hududida,
                        // layout'da joy egallaydi. const EMAS (store'dan o'qiydi).
                        SubBanner(),
                        Expanded(
                          child: Stack(
                            children: [
                              if (v['isHome'] == true) Positioned.fill(child: HomeScreen()),
                              if (v['isCircles'] == true) Positioned.fill(child: CirclesScreen()),
                              if (v['isProfil'] == true) Positioned.fill(child: ProfilScreen()),
                            ],
                          ),
                        ),
                        if (v['clientOpen'] != true) TrustTabBar(),
                      ],
                    ),
                  ),
                  // Xarajatlar — TO'LIQ EKRAN (dizayn: bottom navsiz, header'da orqaga) (z:8)
                  if (v['isXarajat'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: XarajatScreen())),
                  // Circle to'liq-ekran overlaylar (z:9 — tab bar ustida). Manage/History
                  // detaildan ochilsa uning ustida ko'rinishi uchun detaildan KEYIN keladi.
                  if (v['circleOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: CircleDetailScreen())),
                  if (v['circleHistoryOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: CircleHistoryScreen())),
                  if (v['circleManageOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: CircleManageScreen())),
                  if (v['circleCreateOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: CircleCreateScreen())),
                  if (v['circleJoinOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: CircleJoinScreen())),
                  // Hamkor sahifasi (z:10)
                  if (v['clientOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: ClientScreen())),
                  // Bildirishnomalar (z:12)
                  if (v['notifOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: NotifsScreen())),
                  // Rad etilgan bog'lanishlar (z:14)
                  if (v['rejOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: RejectedLinksScreen())),
                  // Arxiv (z:16)
                  if (v['archOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: ArchiveScreen())),
                  // Dalil (z:20)
                  if (v['receiptOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: ReceiptScreen())),
                  // PDF dalil (z:22)
                  if (v['pdfOpen'] == true)
                    Positioned.fill(child: Container(color: p.field, child: PdfPreviewScreen())),
                  // Bottom sheetlar (z:30/34)
                  if (v['sheetOpen'] == true) NewTxSheet(),
                  if (v['npOpen'] == true) NewPartnerSheet(),
                  if (v['editFormOpen'] == true) EditFormSheet(),
                  // Circle sheetlar (z:35 — barcha overlaylardan yuqori)
                  if (v['circlePayOpen'] == true) CirclePaySheet(),
                  if (v['circleConfirmOpen'] == true) CircleConfirmSheet(),
                  if (v['circleInviteOpen'] == true) CircleInviteSheet(),
                  // Bog'lanish qarori (z:50) — minimal preview bilan qabul/rad
                  if (v['linkDecisionOpen'] == true) LinkDecisionSheet(),
                ] else
                  Positioned.fill(child: OnboardingScreen()),
                // Davlat kodi sheet (z:60)
                if (v['ccOpen'] == true) CcSheet(),
                // Til tanlash sheet (z:62)
                if (v['langOpen'] == true) LangSheet(),
                // Toast (z:70)
                ToastView(open: v['toastOpen'] == true, text: v['toast'] as String),
              ],
              ),
            ),
          ),
        );
      },
    );
  }
}
