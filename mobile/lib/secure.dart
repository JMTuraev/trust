// Maxfiy saqlash — Android Keystore / iOS Keychain (flutter_secure_storage).
// JWT token va PIN hashi shu yerda; oddiy sozlamalar (til, tema) SharedPreferences'da qoladi.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kToken = 'trust_token';
  static const _kPinHash = 'trust_pin_hash';

  // PIN'ni ochiq saqlamaymiz — SHA-256 hash (qurilmaga bog'liq tuz bilan emas, lekin
  // secure storage o'zi Keystore bilan shifrlangani uchun yetarli himoya).
  static String _hash(String pin) => sha256.convert(utf8.encode('trust:$pin')).toString();

  // ---- Token ----
  static Future<String?> readToken() => _s.read(key: _kToken);
  static Future<void> writeToken(String? t) =>
      t == null ? _s.delete(key: _kToken) : _s.write(key: _kToken, value: t);

  // ---- PIN ----
  static Future<bool> hasPin() async => (await _s.read(key: _kPinHash)) != null;
  static Future<void> setPin(String pin) => _s.write(key: _kPinHash, value: _hash(pin));
  static Future<bool> checkPin(String pin) async {
    final h = await _s.read(key: _kPinHash);
    return h != null && h == _hash(pin);
  }
  static Future<void> clearPin() => _s.delete(key: _kPinHash);

  // Chiqishda hammasini tozalash
  static Future<void> clearAll() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kPinHash);
  }
}
