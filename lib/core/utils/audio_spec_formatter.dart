/// Formats audio bit depth and sample rate for player surfaces on every platform.
class AudioSpecFormatter {
  const AudioSpecFormatter._();

  static String format({int? bitDepth, int? samplingRate}) {
    final validBitDepth = bitDepth != null && bitDepth > 0 ? bitDepth : null;
    final validSamplingRate = samplingRate != null && samplingRate > 0
        ? samplingRate
        : null;

    if (validBitDepth != null && validSamplingRate != null) {
      return '${validBitDepth}bit/${_formatSamplingRate(validSamplingRate)}';
    }
    if (validBitDepth != null) return '${validBitDepth}bit';
    if (validSamplingRate != null) {
      return _formatSamplingRate(validSamplingRate);
    }
    return '';
  }

  static String _formatSamplingRate(int rate) {
    final khz = rate / 1000;
    return rate % 1000 == 0
        ? '${khz.toInt()}kHz'
        : '${khz.toStringAsFixed(1)}kHz';
  }
}
