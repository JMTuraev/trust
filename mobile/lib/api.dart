// Trust backend API klienti (src/routes/*). Har bir javob ApiRes: ok/data/error.
// Backend xato xabarlari o'zbekcha — UI ularni to'g'ridan-to'g'ri toast qiladi.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Backend manzili — lokal test: adb reverse tcp:3000 tcp:3000 (USB) yoki kompyuter IP.
// Boshqa server uchun: flutter run --dart-define=API_URL=https://...
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');

class ApiRes {
  final bool ok;
  final dynamic data;
  final String error;
  final int status;
  ApiRes(this.ok, this.data, this.error, this.status);
}

class Api {
  static String? token;

  static Future<void> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString('trust_token');
  }

  static Future<void> saveToken(String? t) async {
    token = t;
    final sp = await SharedPreferences.getInstance();
    if (t == null) {
      await sp.remove('trust_token');
    } else {
      await sp.setString('trust_token', t);
    }
  }

  static Future<ApiRes> _req(String method, String path, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$apiUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      late http.Response res;
      const t = Duration(seconds: 10);
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(t);
        case 'PUT':
          res = await http.put(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(t);
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(t);
        default:
          res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(t);
      }
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 400 || map['success'] == false) {
        return ApiRes(false, null, (map['error'] as String?) ?? 'Server xatosi (${res.statusCode})', res.statusCode);
      }
      return ApiRes(true, map['data'], '', res.statusCode);
    } catch (_) {
      return ApiRes(false, null, 'Server bilan aloqa yo\'q — internetni tekshiring', 0);
    }
  }

  // ---- Auth ----
  static Future<ApiRes> sendOtp(String phone) => _req('POST', '/api/auth/send-otp', body: {'phone': phone});
  static Future<ApiRes> verifyOtp(String phone, String code) =>
      _req('POST', '/api/auth/verify-otp', body: {'phone': phone, 'code': code});

  // ---- Profile ----
  static Future<ApiRes> me() => _req('GET', '/api/profile/me');
  static Future<ApiRes> updateProfile({String? fullName}) =>
      _req('PUT', '/api/profile/me', body: {if (fullName != null) 'full_name': fullName});

  // ---- Partners ----
  static Future<ApiRes> partners() => _req('GET', '/api/partners');
  static Future<ApiRes> partnerDetail(String id) => _req('GET', '/api/partners/$id');
  static Future<ApiRes> createPartner(String name, String phone, bool onTrust) =>
      _req('POST', '/api/partners', body: {'name': name, 'counterparty_phone': phone, 'on_trust': onTrust});
  static Future<ApiRes> patchPartner(String id, {String? name, bool? archived}) => _req('PATCH', '/api/partners/$id',
      body: {if (name != null) 'name': name, if (archived != null) 'archived': archived});
  static Future<ApiRes> remind(String id) => _req('POST', '/api/partners/$id/remind');

  // ---- Operations ----
  static Future<ApiRes> createOp(String partnerId, String type, num amount, String currency, String note) =>
      _req('POST', '/api/operations', body: {
        'partner_id': partnerId, 'type': type, 'amount': amount, 'currency': currency,
        if (note.isNotEmpty) 'note': note,
      });
  static Future<ApiRes> opDetail(String id) => _req('GET', '/api/operations/$id');
  static Future<ApiRes> confirmOp(String id, String code) =>
      _req('POST', '/api/operations/$id/confirm', body: {'code': code});
  static Future<ApiRes> cancelOp(String id) => _req('POST', '/api/operations/$id/cancel');
  static Future<ApiRes> archiveOp(String id) => _req('POST', '/api/operations/$id/archive');
  static Future<ApiRes> editRequest(String id, num newAmount, String newNote) =>
      _req('POST', '/api/operations/$id/edit-request',
          body: {'new_amount': newAmount, if (newNote.isNotEmpty) 'new_note': newNote});
  static Future<ApiRes> resolveEdit(String opId, String reqId, bool approve) =>
      _req('POST', '/api/operations/$opId/edit-request/$reqId/resolve', body: {'approve': approve});

  // ---- Expenses / Limits ----
  static Future<ApiRes> expenses() => _req('GET', '/api/expenses');
  static Future<ApiRes> addExpense(num amount, bool income, String category, String note) =>
      _req('POST', '/api/expenses', body: {
        'amount': amount, 'income': income,
        if (category.isNotEmpty) 'category': category,
        if (note.isNotEmpty) 'note': note,
      });
  static Future<ApiRes> getLimit() => _req('GET', '/api/limits');
  static Future<ApiRes> setLimit(num v) => _req('PUT', '/api/limits', body: {'monthly_limit': v});

  // ---- Notifications ----
  static Future<ApiRes> notifications() => _req('GET', '/api/notifications');
  static Future<ApiRes> readNotif(String id) => _req('POST', '/api/notifications/$id/read');
  static Future<ApiRes> readAllNotifs() => _req('POST', '/api/notifications/read-all');

  /// Ovoz -> matn (backend: 1-qatlam Groq whisper, 2-qatlam OpenAI zaxira).
  /// null = ishlamadi (token yo'q / server / STT) — ilova matn rejimiga qaytadi.
  static Future<String?> transcribe(List<int> audioBytes) async {
    try {
      if (token == null) await loadToken();
      if (token == null) return null; // faqat real login bilan
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
      if (res.statusCode >= 400 || data['success'] == false) return null;
      return ((data['data'] as Map?)?['text'] as String?);
    } catch (_) {
      return null;
    }
  }
}
