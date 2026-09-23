import 'package:flutter_test/flutter_test.dart';
import 'package:echoes/core/utils/audio_spec_formatter.dart';

void main() {
  group('AudioSpecFormatter', () {
    test('formats valid bit depth and sample rate together', () {
      expect(
        AudioSpecFormatter.format(bitDepth: 24, samplingRate: 96000),
        '24bit/96kHz',
      );
      expect(
        AudioSpecFormatter.format(bitDepth: 16, samplingRate: 44100),
        '16bit/44.1kHz',
      );
    });

    test('omits missing or non-positive values', () {
      expect(
        AudioSpecFormatter.format(bitDepth: 0, samplingRate: 44100),
        '44.1kHz',
      );
      expect(AudioSpecFormatter.format(bitDepth: -1, samplingRate: 0), '');
      expect(
        AudioSpecFormatter.format(bitDepth: 24, samplingRate: -1),
        '24bit',
      );
      expect(AudioSpecFormatter.format(), '');
    });
  });
}
