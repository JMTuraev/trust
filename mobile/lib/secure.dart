// Maxfiy saqlash — Android Keystore / iOS Keychain (flutter_secure_storage).
// JWT token va PIN hashi shu yerda; oddiy sozlamalar (til, tema) SharedPreferences'da qoladi.
//
// MUHIM (2026-08-13, Apple 2.1(a) reject): keychain o'qish/yozish HECH QACHON
// istisno otmasin. Ilgari PlatformException (masalan, errSecMissingEntitlement
// yoki qurilma qulflanganda errSecInteractionNotAllowed) startup zanjiridan
// to'g'ri o'tib main()'ni o'ldirardi — runApp chaqirilmay OQ EKRAN qolardi.
// Endi: o'qishda xato -> null/false (sessiya yo'q deb qaraladi, foydalanuvchi
// qayta kiradi), yozish/o'chirishda xato -> jim (keyingi urinishda qayta yoziladi).
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kToken = 'trust_token';
  static const _kPinHash = 'trust_pin_hash';
  // MUHIM (2026-08-02 audit): o'z user id'imiz ham saqlanadi. U bo'lmasa qarz
  // YO'NALISHI teskari hisoblanadi (DebtEntry.fromServer created_by != meId bo'lsa
  // yo'nalishni ag'daradi) — ya'ni "menga qarzdor" o'rniga "men qarzdorman" ko'rinadi.
  static const _kMeId = 'trust_me_id';
  static const _kMePhone = 'trust_me_phone';

  // ---- Himoyalangan past daraja: istisno chiqmaydi (yuqoridagi izoh) ----
  static Future<String?> _read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null; // keychain o'qib bo'lmadi — "yo'q" deb qaraymiz
    }
  }

  static Future<void> _put(String key, String? v) async {
    try {
      if (v == null) {
        await _s.delete(key: key);
      } else {
        await _s.write(key: key, value: v);
      }
    } catch (_) {/* yozib bo'lmadi — jim (crash'dan yaxshi) */}
  }

  // PIN'ni ochiq saqlamaymiz — SHA-256 hash (qurilmaga bog'liq tuz bilan emas, lekin
  // secure storage o'zi Keystore bilan shifrlangani uchun yetarli himoya).
  static String _hash(String pin) => sha256.convert(utf8.encode('trust:$pin')).toString();

  // ---- Token ----
  static Future<String?> readToken() => _read(_kToken);
  static Future<void> writeToken(String? t) => _put(_kToken, t);

  // ---- Shaxsiyat (offline/xatolik holatida yo'nalishni to'g'ri hisoblash uchun) ----
  static Future<String?> readMeId() => _read(_kMeId);
  static Future<String?> readMePhone() => _read(_kMePhone);
  static Future<void> writeMe(String? id, String? phone) async {
    await _put(_kMeId, id);
    await _put(_kMePhone, phone);
  }

  // ---- PIN ----
  static Future<bool> hasPin() async => (await _read(_kPinHash)) != null;
  static Future<void> setPin(String pin) => _put(_kPinHash, _hash(pin));
  static Future<bool> checkPin(String pin) async {
    final h = await _read(_kPinHash);
    return h != null && h == _hash(pin);
  }
  static Future<void> clearPin() => _put(_kPinHash, null);

  // Chiqishda hammasini tozalash
  static Future<void> clearAll() async {
    await _put(_kToken, null);
    await _put(_kPinHash, null);
    await _put(_kMeId, null);
    await _put(_kMePhone, null);
  }
}
