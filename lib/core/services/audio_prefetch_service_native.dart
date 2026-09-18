import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Downloads into a separate file so prefetch and the playing cache never write
/// to the same partial file. Only a complete response is published to callers.
class AudioPrefetchService {
  AudioPrefetchService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;
  CancelToken? _token;
  int _generation = 0;
  Future<String?>? _pending;
  static const maxBytes = 64 * 1024 * 1024;

  Future<void> cancel() async {
    _generation++;
    _token?.cancel('playback context changed');
    await _pending;
  }

  Future<String?> download(String url, String cachePath) async {
    final generation = ++_generation;
    _token?.cancel('new prefetch');
    await _pending;
    if (generation != _generation) return null;
    final token = CancelToken();
    _token = token;
    final pending = _download(url, cachePath, token);
    _pending = pending;
    return pending;
  }

  Future<String?> _download(
    String url,
    String cachePath,
    CancelToken token,
  ) async {
    final partial = File('$cachePath.prefetch.part');
    final complete = File('$cachePath.prefetch');
    try {
      final response = await _dio
          .download(
            url,
            partial.path,
            cancelToken: token,
            onReceiveProgress: (received, total) {
              if (received > maxBytes || total > maxBytes) {
                token.cancel('prefetch size limit');
              }
            },
          )
          .timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              token.cancel('prefetch deadline');
              throw TimeoutException('prefetch deadline');
            },
          );
      final type = response.headers.value(Headers.contentTypeHeader) ?? '';
      if (token.isCancelled ||
          response.statusCode != 200 ||
          type.startsWith('text/') ||
          type.contains('json') ||
          type.contains('xml')) {
        return null;
      }
      final size = await partial.length();
      final expected = int.tryParse(
        response.headers.value(Headers.contentLengthHeader) ?? '',
      );
      if (size == 0 ||
          size > maxBytes ||
          (expected != null && expected != size)) {
        return null;
      }
      if (token.isCancelled) return null;
      await partial.rename(complete.path);
      return complete.path;
    } on Exception {
      // URL contains authentication parameters; callers log only song/context.
      return null;
    } finally {
      try {
        if (await partial.exists()) await partial.delete();
      } on FileSystemException {
        // Cleanup failure must not escape cancellation into playback.
      }
      if (identical(_token, token)) _token = null;
    }
  }
}
