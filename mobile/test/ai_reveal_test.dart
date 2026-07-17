// "Marjon" so'z-reveal helperlari (ai_blocks.dart) — AiTextBubble va
// _AiAnswer._tick SHU formulalar orqali sinxron turadi.
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_mobile/ai_blocks.dart';

void main() {
  test('aiRevealChunks: bo\'laklar qo\'shilsa ASL matn aynan tiklanadi', () {
    const samples = [
      'Salom',
      'Bu oy 2.4 mln sarfladingiz.',
      'Ikki  bo\'shliq va\nyangi qator saqlanadi.',
      ' boshida bo\'shliq',
      'oxirida bo\'shliq ',
      '',
      '   ',
    ];
    for (final s in samples) {
      expect(aiRevealChunks(s).join(), s, reason: 'sample: "$s"');
    }
  });

  test('aiRevealChunks: so\'z soni to\'g\'ri', () {
    expect(aiRevealChunks('').length, 0);
    expect(aiRevealChunks('Salom').length, 1);
    expect(aiRevealChunks('Bu oy 2.4 mln sarfladingiz.').length, 5);
  });

  test('aiTextRevealMs: 0-1 so\'z animatsiyasiz, ~55ms/so\'z', () {
    expect(aiTextRevealMs(''), 0);
    expect(aiTextRevealMs('Salom'), 0);
    expect(aiTextRevealMs('Bu oy 2.4 mln sarfladingiz.'), 5 * 55);
  });

  test('aiTextRevealMs: uzun matn 2.5s bilan cheklanadi', () {
    final long = List.generate(120, (i) => 'soz$i').join(' ');
    expect(aiTextRevealMs(long), 2500);
  });
}
