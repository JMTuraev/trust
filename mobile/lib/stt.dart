// Ovoz yozish + backend STT — XOTIRA-ovoz-va-kategoriya.md bo'yicha.
// Oqim: mikrofon (16kHz mono wav, maks 10 s) -> POST /api/stt/transcribe
// (backend: Groq whisper-large-v3, zaxira OpenAI). Xato bo'lsa null —
// ilova matn kiritish/demolarga qaytadi (spec: doim fallback bor).
import 'dart:async';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'api.dart';

class Stt {
  static final AudioRecorder _rec = AudioRecorder();
  static Timer? _timer;
  static void Function(String?)? _onDone;

  /// Yozishni boshlash. Ruxsat berilmasa jim qoladi (demo rejim davom etadi).
  static Future<void> start({
    void Function()? onStarted,
    required void Function(String?) onDone,
  }) async {
    await cancel();
    _onDone = onDone;
    try {
      if (!await _rec.hasPermission()) {
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
    } catch (_) {
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
        cb(null);
        return;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.length < 4000) {
        cb(null); // juda qisqa yozuv
        return;
      }
      cb(await Api.transcribe(bytes));
    } catch (_) {
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
