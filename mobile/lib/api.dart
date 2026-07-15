// Trust backend API klienti (src/routes/*). Har bir javob ApiRes: ok/data/error.
// Backend xato xabarlari o'zbekcha — UI ularni to'g'ridan-to'g'ri toast qiladi.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'secure.dart';

// Backend manzili. Default — PRODUCTION Render serveri (release APK to'g'ri ishlashi uchun).
// Lokal test: flutter run --dart-define=API_URL=http://localhost:3000 (+ adb reverse tcp:3000 tcp:3000).
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://trust-backend-ft1s.onrender.com');

class ApiRes {
  final bool ok;
  final dynamic data;
  final String error;
  final int status;
  ApiRes(this.ok, this.data, this.error, this.status);
}

class Api {
  static String? token;
  // Sessiya davomida token muddati o'tsa (401) — store shu callback orqali logout qiladi.
  static void Function()? onUnauthorized;

  static Future<void> loadToken() async {
    token = await SecureStore.readToken();
    // Bir martalik migratsiya: eski (plaintext SharedPreferences) token'ni secure storage'ga ko'chiramiz.
    if (token == null) {
      final sp = await SharedPreferences.getInstance();
      final legacy = sp.getString('trust_token');
      if (legacy != null) {
        token = legacy;
        await SecureStore.writeToken(legacy);
        await sp.remove('trust_token'); // plaintext nusxani o'chiramiz
      }
    }
  }

  static Future<void> saveToken(String? t) async {
    token = t;
    await SecureStore.writeToken(t);
  }

  static Future<ApiRes> _req(String method, String path, {Map<String, dynamic>? body, int timeoutSec = 20}) async {
    try {
      final uri = Uri.parse('$apiUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      late http.Response res;
      final t = Duration(seconds: timeoutSec);
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(t);
        case 'PUT':
          res = await http.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(t);
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(t);
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(t);
        default:
          res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(t);
      }
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 400 || map['success'] == false) {
        // Token muddati o'tgan/yaroqsiz — markazlashgan logout (har ekran alohida ishlamasin)
        if (res.statusCode == 401 && token != null) {
          onUnauthorized?.call();
        }
        return ApiRes(false, null, (map['error'] as String?) ?? 'Server xatosi (${res.statusCode})', res.statusCode);
      }
      return ApiRes(true, map['data'], '', res.statusCode);
    } on TimeoutException {
      // Render bepul plan cold-start ~30-50s uxlaydi — buni tarmoq uzilishidan ajratamiz.
      return ApiRes(false, null, 'Server uyg\'onmoqda — biroz kuting va qayta urinib ko\'ring', 0);
    } catch (_) {
      return ApiRes(false, null, 'Server bilan aloqa yo\'q — internetni tekshiring', 0);
    }
  }

  // ---- Auth ----
  // Auth va birinchi (resume) so'rovlar uchun uzunroq timeout — Render cold-start'ni ushlaydi.
  static Future<ApiRes> sendOtp(String phone) =>
      _req('POST', '/api/auth/send-otp', body: {'phone': phone}, timeoutSec: 45);
  static Future<ApiRes> verifyOtp(String phone, String code) =>
      _req('POST', '/api/auth/verify-otp', body: {'phone': phone, 'code': code}, timeoutSec: 45);

  // ---- Profile ----
  static Future<ApiRes> me() => _req('GET', '/api/profile/me', timeoutSec: 45);
  static Future<ApiRes> updateProfile({String? fullName, bool? notifEnabled}) =>
      _req('PUT', '/api/profile/me', body: {
        if (fullName != null) 'full_name': fullName,
        if (notifEnabled != null) 'notif_enabled': notifEnabled,
      });

  // ---- Partners (sotuvchi tomoni) ----
  static Future<ApiRes> partners() => _req('GET', '/api/partners');
  static Future<ApiRes> partnerDetail(String id) => _req('GET', '/api/partners/$id');
  static Future<ApiRes> createPartner(String name, String phone) =>
      _req('POST', '/api/partners', body: {'name': name, 'counterparty_phone': phone});
  static Future<ApiRes> patchPartner(String id, {String? name, bool? archived}) => _req('PATCH', '/api/partners/$id',
      body: {if (name != null) 'name': name, if (archived != null) 'archived': archived});
  static Future<ApiRes> remind(String id) => _req('POST', '/api/partners/$id/remind');
  static Future<ApiRes> movePartner(String id, String newPhone) =>
      _req('POST', '/api/partners/$id/move', body: {'new_phone': newPhone});

  // ---- Links (mijoz tomoni: meni kontragent qilib qo'shganlar) ----
  static Future<ApiRes> links() => _req('GET', '/api/links');
  static Future<ApiRes> linkAction(String id, String action) => _req('POST', '/api/links/$id/$action');
  static Future<ApiRes> linkAlias(String id, String alias) =>
      _req('PATCH', '/api/links/$id', body: {'alias': alias});
  static Future<ApiRes> linkOperations(String id) => _req('GET', '/api/links/$id/operations');

  // ---- Operations (bir tomonlama da'vo — tasdiqsiz) ----
  static Future<ApiRes> createOp(String partnerId, String type, num amount, String currency, String note) =>
      _req('POST', '/api/operations', body: {
        'partner_id': partnerId, 'type': type, 'amount': amount, 'currency': currency,
        if (note.isNotEmpty) 'note': note,
      });
  static Future<ApiRes> opDetail(String id) => _req('GET', '/api/operations/$id');
  static Future<ApiRes> patchOp(String id, {num? amount, String? note}) =>
      _req('PATCH', '/api/operations/$id',
          body: {if (amount != null) 'amount': amount, if (note != null) 'note': note});
  static Future<ApiRes> cancelOp(String id) => _req('POST', '/api/operations/$id/cancel');
  static Future<ApiRes> archiveOp(String id) => _req('POST', '/api/operations/$id/archive');

  // ---- Expenses / Limits ----
  static Future<ApiRes> expenses() => _req('GET', '/api/expenses');
  static Future<ApiRes> addExpense(num amount, bool income, String category, String note) =>
      _req('POST', '/api/expenses', body: {
        'amount': amount, 'income': income,
        if (category.isNotEmpty) 'category': category,
        if (note.isNotEmpty) 'note': note,
      });
  // Chatdagi yozuvni inline tahrirlash / o'chirish
  static Future<ApiRes> patchExpense(String id, {num? amount, bool? income, String? category, String? note}) =>
      _req('PATCH', '/api/expenses/$id', body: {
        if (amount != null) 'amount': amount,
        if (income != null) 'income': income,
        if (category != null) 'category': category,
        if (note != null) 'note': note,
      });
  static Future<ApiRes> deleteExpense(String id) => _req('DELETE', '/api/expenses/$id');

  // ---- AI parse (Xarajat: matn -> daromad/xarajat/qarz) ----
  // parse hech narsa saqlamaydi; saqlash confirmExpense orqali (tasdiqlash kartasi oqimi).
  static Future<ApiRes> parseExpense(String text, String source) =>
      _req('POST', '/api/expenses/parse', body: {'text': text, 'source': source}, timeoutSec: 20);
  static Future<ApiRes> confirmExpense(String text, String source,
          List<Map<String, dynamic>> actions, {List<Map<String, dynamic>>? parsed}) =>
      _req('POST', '/api/expenses/confirm', body: {
        'text': text, 'source': source, 'actions': actions,
        if (parsed != null) 'parsed': parsed,
      });

  // ---- Toifalar (CRUD: qo'shish/qayta nomlash/arxivlash — o'chirish yo'q) ----
  static Future<ApiRes> categories() => _req('GET', '/api/categories');
  static Future<ApiRes> addCategory(String name) => _req('POST', '/api/categories', body: {'name': name});
  static Future<ApiRes> patchCategory(String id, {String? name, bool? archived}) =>
      _req('PATCH', '/api/categories/$id',
          body: {if (name != null) 'name': name, if (archived != null) 'archived': archived});
  static Future<ApiRes> getLimit() => _req('GET', '/api/limits');
  static Future<ApiRes> setLimit(num v) => _req('PUT', '/api/limits', body: {'monthly_limit': v});

  // ---- Notifications ----
  static Future<ApiRes> notifications() => _req('GET', '/api/notifications');
  static Future<ApiRes> readNotif(String id) => _req('POST', '/api/notifications/$id/read');
  static Future<ApiRes> readAllNotifs() => _req('POST', '/api/notifications/read-all');

  /// Ovoz -> matn (backend: 1-qatlam Groq whisper, 2-qatlam OpenAI zaxira).
  /// null = ishlamadi — sabab [lastSttError] da (UI aniq toast ko'rsatadi).
  static String? lastSttError;

  static Future<String?> transcribe(List<int> audioBytes) async {
    lastSttError = null;
    try {
      if (token == null) await loadToken();
      if (token == null) {
        lastSttError = "Ovoz uchun avval raqamingiz bilan kiring (demo rejimda ishlamaydi)";
        return null;
      }
      final res = await http
          .post(
            Uri.parse('$apiUrl/api/stt/transcribe'),
            headers: {
              'Content-Type': 'audio/wav',
              'Authorization': 'Bearer $token',
            },
            body: audioBytes,
          )
          .timeout(const Duration(seconds: 25));
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 400 || data['success'] == false) {
        // Token muddati o'tgan bo'lsa — boshqa so'rovlar kabi markazlashgan logout.
        if (res.statusCode == 401 && token != null) onUnauthorized?.call();
        lastSttError = (data['error'] as String?) ?? 'Server xatosi (${res.statusCode})';
        return null;
      }
      return ((data['data'] as Map?)?['text'] as String?);
    } catch (_) {
      lastSttError = "Serverga ulanib bo'lmadi — internet yoki API_URL'ni tekshiring";
      return null;
    }
  }
}
