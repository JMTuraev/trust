// Trust — FCM push xizmati (Android).
// init(): Firebase'ni ko'taradi (google-services.json bo'lmasa jim o'tadi — dev muhit yiqilmasin).
// sync(): bildirishnoma ruxsatini so'raydi, FCM tokenni oladi va backendga bog'laydi.
// unregister(): logout'da tokenni serverdan uzadi va FCM tokenni bekor qiladi
//   (shu qurilmada boshqa akkaunt kirsa, eski akkauntning push'i kelmasin).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';

class PushService {
  static bool _ready = false;
  static String? _lastToken;

  /// Ilova OCHIQ paytida kelgan push — tizim tray ko'rsatmaydi, UI o'zi ko'rsatadi
  /// (main.dart bu callback'ni store.toast_ ga ulaydi).
  static void Function(String title, String body)? onForeground;

  /// Foreground push DATA payload — data: { type, partner_id, amount, currency,
  /// link_id, ... }. main.dart wires it to store.pushArrived_: the partner-card
  /// notification badge bumps instantly and a silent hydrate reconciles.
  static void Function(Map<String, dynamic> data)? onForegroundData;

  /// Push BOSILGANDA chaqiriladi — data: { type, link_id, circle_id }.
  /// MUHIM (2026-08-02 audit): ilgari bosish UMUMAN qayta ishlanmasdi. Backend har
  /// push'da marshrut ma'lumotini yuboradi (services/push.js), lekin klient uni
  /// tashlab yuborardi: foydalanuvchi "qarzni tasdiqlaysizmi?" bildirishnomasini
  /// bosardi va bosh ekranga tushardi — ya'ni mahsulotning asosiy siklida yo'qotish.
  static void Function(Map<String, dynamic> data)? onOpened;

  /// Ilova YOPIQ holatdan push bilan ochilgan bo'lsa — payload shu yerda kutib turadi
  /// (store tayyor bo'lgach `drainInitial()` uni beradi).
  static Map<String, dynamic>? _pendingOpen;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
      // FCM token o'zi yangilanib qolsa — serverga qayta bog'laymiz
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _lastToken = t;
        _save(t);
      });
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground?.call(n.title ?? '', n.body ?? '');
        // Data payload separately: badge/refresh logic works even for pushes
        // whose toast was skipped (data-only messages have no notification).
        if (m.data.isNotEmpty) onForegroundData?.call(Map<String, dynamic>.from(m.data));
      });
      // Ilova fonda turib push bosilgan
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final d = Map<String, dynamic>.from(m.data);
        if (onOpened != null) { onOpened!(d); } else { _pendingOpen = d; }
      });
      // Ilova butunlay yopiq bo'lib, push bilan ochilgan
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingOpen = Map<String, dynamic>.from(initial.data);
    } catch (_) {
      // Firebase sozlanmagan — push'siz davom etamiz (ilova yiqilmasin)
      _ready = false;
    }
  }

  /// Kutib turgan "push bosildi" payloadini olib, tozalaydi.
  static Map<String, dynamic>? drainInitial() {
    final d = _pendingOpen;
    _pendingOpen = null;
    return d;
  }

  /// Login bo'lgach (yoki startapda, token bor bo'lsa) chaqiriladi.
  static Future<void> sync() async {
    if (!_ready || Api.token == null) return;
    try {
      // Android 13+ da POST_NOTIFICATIONS runtime dialogini chiqaradi
      final perm = await FirebaseMessaging.instance.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final t = await FirebaseMessaging.instance.getToken();
      if (t == null) return;
      _lastToken = t;
      await _save(t);
    } catch (_) {
      // Tarmoq/Play Services xatosi — keyingi ochilishda qayta uriniladi
    }
  }

  static Future<void> _save(String t) async {
    if (Api.token == null) return;
    await Api.savePushToken(t);
  }

  /// logout_() ichida SINXRON chaqiriladi (Api.saveToken(null) dan OLDIN):
  /// _req headers'ni birinchi await'gacha sinxron quradi, shuning uchun
  /// auth token hali joyida bo'ladi (fire-and-forget).
  static void unregister() {
    if (!_ready) return;
    final t = _lastToken;
    if (t != null && Api.token != null) Api.deletePushToken(t);
    FirebaseMessaging.instance.deleteToken().catchError((_) {});
    _lastToken = null;
  }
}
