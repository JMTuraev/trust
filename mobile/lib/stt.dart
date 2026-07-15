// Ovoz yozish + backend STT — XOTIRA-ovoz-va-kategoriya.md bo'yicha.
// Oqim: mikrofon (16kHz mono wav, maks 10 s) -> POST /api/stt/transcribe
// (backend: Groq whisper-large-v3, zaxira OpenAI). Xato bo'lsa null —
// sabab [lastError] da turadi, UI aniq toast ko'rsatadi (jim yiqilish yo'q).
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'api.dart';

class Stt {
  static final AudioRecorder _rec = AudioRecorder();
  static Timer? _timer;
  static void Function(String?)? _onDone;

  /// Oxirgi xato sababi (diagnostika uchun; muvaffaqiyatda null)
  static String? lastError;

  /// Yozishni boshlash. Ruxsat berilmasa demo rejim qoladi, lekin sabab lastError'da.
  static Future<void> start({
    void Function()? onStarted,
    required void Function(String?) onDone,
  }) async {
    await cancel();
    lastError = null;
    _onDone = onDone;
    try {
      if (!await _rec.hasPermission()) {
        lastError = "Mikrofon ruxsati berilmagan — Sozlamalar > Ilovalar > Trust > Ruxsatlar";
        _onDone = null; // demo rejimda qolamiz
        return;
      }
      final dir = await getTemporaryDirectory();
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: '${dir.path}/trust_voice.wav',
      );
      onStarted?.call();
      _timer = Timer(const Duration(seconds: 10), finish); // spec: 3–10 s klip
    } catch (e) {
      lastError = 'Yozib olishni boshlab bo\'lmadi: $e';
      _onDone = null;
    }
  }

  /// Yozishni yakunlab, matnga aylantirish.
  static Future<void> finish() async {
    _timer?.cancel();
    final cb = _onDone;
    _onDone = null;
    if (cb == null) return;
    try {
      final path = await _rec.stop();
      if (path == null) {
        lastError ??= 'Yozuv olinmadi — qayta urinib ko\'ring';
        cb(null);
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.length < 4000) {
        lastError = 'Juda qisqa yozuv — kamida 2-3 soniya gapiring';
        cb(null);
        return;
      }
      final text = await Api.transcribe(bytes);
      if (text == null || text.trim().isEmpty) {
        lastError = Api.lastSttError ?? 'Ovoz tushunarsiz chiqdi — qayta ayting';
      }
      cb(text);
    } catch (e) {
      lastError = 'STT xatosi: $e';
      cb(null);
    }
  }

  /// Bekor qilish (sheet yopildi yoki demo jumla tanlandi).
  static Future<void> cancel() async {
    _timer?.cancel();
    _onDone = null;
    try {
      if (await _rec.isRecording()) await _rec.stop();
    } catch (_) {}
  }
}

/// Ovozli XABAR yozgichi (chat uchun) — STT emas: audio o'zi yuboriladi (Telegram kabi).
/// start -> yozadi (m4a, maks 10 daqiqa emas — 2 daqiqa cheklov), stop -> (fayl yo'li, davomiylik s).
class ChatRec {
  static final AudioRecorder _rec = AudioRecorder();
  static Timer? _cap;
  static DateTime? _t0;
  static String? lastError;

  static Future<bool> start() async {
    lastError = null;
    try {
      if (!await _rec.hasPermission()) {
        lastError = "Mikrofon ruxsati berilmagan — Sozlamalar > Ilovalar > Trust > Ruxsatlar";
        return false;
      }
      final dir = await getTemporaryDirectory();
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: '${dir.path}/trust_note_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      _t0 = DateTime.now();
      _cap?.cancel();
      _cap = Timer(const Duration(minutes: 2), () {}); // yuqori chegara belgisi
      return true;
    } catch (e) {
      lastError = 'Yozib olishni boshlab bo\'lmadi: $e';
      return false;
    }
  }

  /// Yakunlash: (yo'l, davomiylik). Juda qisqa (<1s) bo'lsa null — tasodifiy bosish.
  static Future<(String, int)?> stop() async {
    _cap?.cancel();
    final t0 = _t0;
    _t0 = null;
    try {
      final path = await _rec.stop();
      if (path == null || t0 == null) return null;
      final dur = DateTime.now().difference(t0).inMilliseconds;
      if (dur < 800) {
        try { File(path).deleteSync(); } catch (_) {}
        lastError = "Juda qisqa — bosib turib gapiring";
        return null;
      }
      return (path, (dur / 1000).round().clamp(1, 120));
    } catch (e) {
      lastError = 'Yozuvni yakunlab bo\'lmadi: $e';
      return null;
    }
  }
}
