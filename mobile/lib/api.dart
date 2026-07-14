// Trust backend API (src/routes/*). OTP demo rejimda ham ishlayveradi.
import 'dart:convert';
import 'package:http/http.dart' as http;

// Backend manzili — kerak bo'lsa o'zgartiring (lokal test: kompyuter IP:3000)
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');

Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body, {String? token}) async {
  try {
    final res = await http
        .post(
          Uri.parse('$apiUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || data['success'] == false) return null;
    return (data['data'] ?? data) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

class Api {
  static Future<Map<String, dynamic>?> sendOtp(String phone) =>
      _post('/api/auth/send-otp', {'phone': phone});

  static Future<Map<String, dynamic>?> verifyOtp(String phone, String code) =>
      _post('/api/auth/verify-otp', {'phone': phone, 'code': code});
}
