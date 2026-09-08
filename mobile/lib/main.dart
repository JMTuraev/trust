// Trust — asosiy kompozitsiya. Prototipdagi ekran/overlay z-tartibi bilan 1:1.
import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
// Tizim vidjetlari (sana tanlagich, matn menyulari) ilova tilida chiqishi uchun
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'store.dart';
import 'theme.dart';
import 'ui.dart';
import 'flags.dart';
import 'push.dart';

import 'screens/onboarding.dart';
import 'screens/ai_chat.dart';
import 'screens/cc_sheet.dart';
import 'screens/home.dart';
import 'screens/home_hub.dart';
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
import 'screens/toyxona.dart';
import 'screens/ijara.dart';
import 'screens/profil.dart';
import 'screens/tab_bar.dart';
import 'screens/client_screen.dart';
import 'screens/notifs.dart';
import 'screens/support_chat.dart';
import 'screens/receipt.dart';
import 'screens/pdf_preview.dart';
import 'screens/new_tx_sheet.dart';
import 'screens/new_partner_sheet.dart';
import 'screens/edit_form_sheet.dart';
import 'screens/link_decision_sheet.dart';
import 'screens/rejected_links.dart';
import 'screens/archive.dart';
import 'screens/lang_sheet.dart';
import 'screens/paywall_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // MUHIM (2026-08-13, Apple 2.1(a) reject — iPad'da OQ EKRAN):
  // Ilgari store.init() va PushService.init() runApp'dan OLDIN await qilinardi.
  // Ulardan bittasi (keychain o'qish, Firebase init, SharedPreferences) osilib
  // qolsa yoki istisno bersa runApp UMUMAN chaqirilmasdi — Flutter birinchi
  // kadrni chizmasdi va foydalanuvchi ABADIY oq ekran ko'rardi (App Review
  // iPad Air 11 M3 / iPadOS 26.6 da aynan shu: skrinshotda faqat status bar).
  // Endi birinchi kadr (boot-splash) DARHOL chiziladi, init fonda ketadi —
  // har qadam timeout + try/catch bilan. Eng yomon holatda ham foydalanuvchi
  // welcome ekranini ko'radi (store.bootFallback_), oq ekran EMAS.
  runApp(const TrustApp());
  unawaited(_bootstrap());
}

/// Fon initsializatsiya — runApp'dan KEYIN ishlaydi; hech bir xato/osilish
/// birinchi kadrni to'sa olmaydi. Tartib eski main() bilan bir xil:
/// store.init -> push init -> pending push -> sync.
Future<void> _bootstrap() async {
  try {
    // store.init() tarmoqni KUTMAYDI (_tryResume fire-and-forget), shuning
    // uchun 8s faqat lokal storage/keychain osilib qolishidan himoya.
    await store.init().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Init yiqildi yoki osildi — boot-splashda qolib ketmaymiz: welcome'ga.
    store.bootFallback_();
  }
  // FCM push: Firebase'ni ko'taramiz (google-services.json bo'lmasa jim o'tadi).
  // Ilova ochiq payt kelgan push tizim tray'da chiqmaydi — toast qilib ko'rsatamiz.
  // Callback'lar init'dan OLDIN o'rnatiladi: listener birinchi xabaridan boshlab ushlansin.
  PushService.onForeground = (title, body) => store.toast_(body.isEmpty ? title : body);
  // Foreground push DATA: partner-card badge appears within a second (optimistic
  // bump + silent hydrate) — no app restart needed.
  PushService.onForegroundData = (data) => store.pushArrived_(data);
  // Push BOSILGANDA tegishli ekranga o'tamiz (2026-08-02 audit: ilgari e'tiborsiz qolardi).
  PushService.onOpened = (data) => store.openFromPush(data);
  try {
    await PushService.init().timeout(const Duration(seconds: 12));
  } catch (_) {/* push'siz davom etamiz — UI allaqachon ochiq */}
  final pendingPush = PushService.drainInitial(); // ilova push bilan ochilgan bo'lsa
  if (pendingPush != null) store.openFromPush(pendingPush);
  PushService.sync(); // login bo'lgan bo'lsa tokenni serverga bog'laydi (await EMAS — UI kutmasin)
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
        // Ilova tili -> MaterialApp locale: tizim sana tanlagichi (showDatePicker),
        // copy/paste menyusi va h.k. ilova tilida chiqadi. MaterialApp shu
        // ListenableBuilder ichida — setLang() notifyListeners() chaqiradi va
        // locale DARHOL almashadi (dark rejim bilan bir xil yo'l).
        final lang = '${store.S['lang'] ?? 'uz'}';
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          // l10n.dart kLangs bilan BIR XIL olti til (tartib kLangMeta'dagidek)
          supportedLocales: const [
            Locale('uz'), Locale('en'), Locale('ru'),
            Locale('es'), Locale('fr'), Locale('zh'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Qo'llanmaydigan til so'ralsa (kelajakda yangi til qo'shilsa-yu,
          // ro'yxat yangilanmasa) — birinchi tilga emas, INGLIZCHAGA tushamiz.
          localeResolutionCallback: (locale, supported) {
            for (final l in supported) {
              if (l.languageCode == locale?.languageCode) return l;
            }
            return const Locale('en');
          },
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

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  // Apparat "orqaga" hub ildizida: 2 soniya ichida ikkinchi bosishda chiqadi.
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ilova fonga o'tsa polling to'xtaydi (batareya/trafik/429 — 2026-08-02 audit).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.appResumed_();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      store.appPaused_();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final v = store.vals();
        final p = curPal();
        final backToHub = v['hubBackable'] == true;
        final atRoot = v['hubAtRoot'] == true;
        // layerOpen ONBOARDING'da ham true bo'la oladi: davlat-kodi varag'i
        // (ccOpen, z:60) telefon/OTP bosqichida ochiladi — store.layerOpen()
        // uni stage'dan mustaqil bloklaydi (2026-08-10 audit).
        final layerOpen = v['layerOpen'] == true;
        // OTP bosqichi: apparat "orqaga" telefon qadamiga qaytaradi (ekrandagi
        // < tugma bilan AYNAN bir yo'l — backToPhone), ilova yopilmaydi.
        final onbOtp = v['isOnbOtp'] == true;
        return PopScope(
          // Android apparat "orqaga": ochiq overlay/sheet bo'lsa — o'shani yopadi;
          // bo'lim ekranidan (Hamkorlar / Xarajat / AI / Profil) hub'ga qaytadi;
          // hub ildizida — 2 marta bosilsa chiqadi (aks holda "yana bosing" toast).
          //
          // MUHIM (2026-08-02 audit): ilgari `canPop` overlay ochiq bo'lganda TRUE
          // bo'lardi. Ilovada bitta route bo'lgani uchun tizim buni "chiqish" deb
          // bajarardi — ya'ni hamkor daftaridan/chekdan orqaga bosish ILOVANI
          // YOPARDI. Endi qatlam ochiq bo'lsa pop tizimga berilmaydi.
          canPop: !layerOpen && !backToHub && !atRoot && !onbOtp,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (layerOpen) {
              (v['closeTopLayer'] as bool Function())();
              return;
            }
            // OTP'da orqaga — telefon qadamiga (SMS kutish tuzog'idan chiqish
            // yo'li; ilgari bu bosish ILOVANI butunlay yopardi). ccOpen ochiq
            // bo'lsa yuqoridagi layerOpen avval varaqni yopadi.
            if (onbOtp) {
              v['backToPhone']();
              return;
            }
            // Modul ekranining O'Z qatlami (Ijaradagi uylar / To'yxona: uy
            // tafsiloti, forma modallari, oy menyusi) store'da ko'rinmaydi —
            // modul uni initState'da store.setModuleBack_ orqali ro'yxatdan
            // o'tkazadi. Hub'ga qaytishdan OLDIN chaqiriladi, aks holda ochiq
            // forma bilan birga kiritilgan ma'lumot yo'qolardi (review
            // 2026-08-04, FINDING 2). Qatlam yo'q bo'lsa false qaytadi va
            // odatdagi "hub'ga qaytish" davom etadi.
            if ((v['moduleBack'] as bool Function())()) return;
            if (backToHub) {
              v['hubBack']();
              return;
            }
            final now = DateTime.now();
            if (_lastBack != null &&
                now.difference(_lastBack!) <= const Duration(seconds: 2)) {
              SystemNavigator.pop();
            } else {
              _lastBack = now;
              store.toast_(store.L()['tExitAgain'] as String);
            }
          },
          child: Scaffold(
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
                  // Ildiz (hub) + bo'lim ekranlari. Pastki nav olib tashlandi:
                  // flags.kBottomNavEnabled=false (TrustTabBar kodi joyida qoladi).
                  Positioned.fill(
                    child: Column(
                      children: [
                        // Obuna banneri (tugagan / ≤3 kun qoldi) — header hududida,
                        // layout'da joy egallaydi. const EMAS (store'dan o'qiydi).
                        // MUHIM: Column'ning eng boshida — shu sababli HUB va HAR BIR
                        // bo'lim ekrani (Hamkorlar / Xarajat / AI / Profil) ustida
                        // ko'rinadi (avval Xarajat uni to'liq-ekran overlay bilan yopardi).
                        SubBanner(),
                        Expanded(
                          child: Stack(
                            children: [
                              // BOSH HUB — ildiz ekran (dizayn: prototype/bosh-ekran.dc.html)
                              if (v['isHub'] == true) Positioned.fill(child: ScreenBg(child: HomeHubScreen())),
                              // Hamkorlar — hub'dan ochiladigan TO'LIQ EKRAN bo'lim.
                              // Orqaga (<) endi home.dart'ning O'Z headerida (PO 2026-07-17:
                              // ikkita header o'rniga bitta) — HubSection kerak emas.
                              if (v['isHome'] == true)
                                Positioned.fill(
                                  child: ScreenBg(child: HomeScreen()),
                                ),
                              // Xarajat — o'z header'ida orqaga bor (xfBack -> hub)
                              if (v['isXarajat'] == true)
                                Positioned.fill(child: ScreenBg(child: XarajatScreen())),
                              // Ijaradagi uylar / To'yxona — hub kartasidan ochiladigan
                              // TO'LIQ EKRAN modullar. `handleSystemBack` UZATILMAYDI
                              // (false bo'lib qoladi): apparat "orqaga" tugmasini FAQAT
                              // yuqoridagi Root PopScope boshqaradi — ikkita PopScope
                              // birga ishlasa bir bosishda ikki qavat orqaga ketardi.
                              // Modulning O'Z qatlamlari esa store.setModuleBack_ hook'i
                              // orqali yopiladi (yuqoridagi `moduleBack` chaqiruvi).
                              if (v['isIjara'] == true)
                                Positioned.fill(
                                  child: ScreenBg(
                                    child: IjaraScreen(onBack: () => v['goHub']()),
                                  ),
                                ),
                              if (v['isToyxona'] == true)
                                Positioned.fill(
                                  child: ScreenBg(
                                    child: ToyxonaScreen(onBack: () => v['goHub']()),
                                  ),
                                ),
                              // Circles bayroq ostida (flags.dart) — tabdan olib tashlandi,
                              // kod va ekran joyida: kCirclesEnabled=true qilsang qaytadi.
                              if (kCirclesEnabled && v['isCircles'] == true)
                                Positioned.fill(child: CirclesScreen()),
                              // Trust AI — o'z header'ida orqaga bor (goAiBack -> hub)
                              if (kAiEnabled && v['isAi'] == true) Positioned.fill(child: AiChatScreen()),
                              // Profil — avatar orqali ochiladi; orqaga HubSection'da
                              if (v['isProfil'] == true)
                                Positioned.fill(
                                  child: ScreenBg(child: HubSection(child: ProfilScreen())),
                                ),
                            ],
                          ),
                        ),
                        // Pastki nav — kBottomNavEnabled=false (flags.dart): chizilmaydi.
                        // Bayroqni true qilsang bir qatorda qaytadi.
                        if (kBottomNavEnabled && v['clientOpen'] != true && v['isAi'] != true)
                          TrustTabBar(),
                      ],
                    ),
                  ),
                  // Circle to'liq-ekran overlaylar (z:9). Manage/History
                  // detaildan ochilsa uning ustida ko'rinishi uchun detaildan KEYIN keladi.
                  if (v['circleOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: CircleDetailScreen())),
                  if (v['circleHistoryOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: CircleHistoryScreen())),
                  if (v['circleManageOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: CircleManageScreen())),
                  if (v['circleCreateOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: CircleCreateScreen())),
                  if (v['circleJoinOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: CircleJoinScreen())),
                  // Hamkor sahifasi (z:10)
                  if (v['clientOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: ClientScreen())),
                  // Bildirishnomalar (z:12)
                  if (v['notifOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: NotifsScreen())),
                  // Yordam chati (z:13) — Telegram'ga ulangan support (PO #10)
                  if (v['supportOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: SupportChatScreen())),
                  // Rad etilgan bog'lanishlar (z:14)
                  if (v['rejOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: RejectedLinksScreen())),
                  // Arxiv (z:16)
                  if (v['archOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: ArchiveScreen())),
                  // Dalil (z:20)
                  if (v['receiptOpen'] == true)
                    Positioned.fill(child: ScreenBg(child: ReceiptScreen())),
                  // PDF dalil (z:22)
                  if (v['pdfOpen'] == true)
                    Positioned.fill(child: Container(color: p.bg, child: PdfPreviewScreen())),
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
                  Positioned.fill(child: ScreenBg(child: OnboardingScreen())),
                // Davlat kodi sheet (z:60)
                if (v['ccOpen'] == true) CcSheet(),
                // Til tanlash sheet (z:62)
                if (v['langOpen'] == true) LangSheet(),
                // Modul obunasi paywall'i (z:64) — GLOBAL, ilovadagi eng ustki
                // modal (faqat toast undan yuqori).
                //
                // NEGA BU YERDA: paywall'ni store'ning 402 ishlovchisi ISTALGAN
                // ekrandan ochadi (Xarajat, hamkor daftari, yangi operatsiya
                // sheet'i...). Ilgari u faqat home_hub.dart ichida chizilardi —
                // hub'dan tashqarida foydalanuvchi hech narsa ko'rmasdi (modulli
                // 402'da global qizil banner ham ataylab o'chirilgan), ammo
                // S['paywall'] null bo'lmay qolar va sheet keyinroq hub'ga
                // o'tilganda kutilmaganda "otilib chiqardi".
                //
                // DIQQAT: `const` EMAS — const instance kanonik bo'lgani uchun
                // qayta qurishda Element rebuild'ni o'tkazib yuborardi (yuqoridagi izoh).
                if (v['paywall'] is Map) PaywallSheet(),
                // Toast (z:70)
                ToastView(open: v['toastOpen'] == true, text: v['toast'] as String),
              ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}
