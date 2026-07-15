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
