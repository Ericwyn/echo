import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Resolves remote artwork to one shared local cache file.
///
/// Android notifications and desktop media sessions can then read the same
/// file without receiving a server URL that may contain authentication data.
class ArtworkFileCache {
  ArtworkFileCache({BaseCacheManager? cacheManager})
    : _cacheManager = cacheManager ?? DefaultCacheManager();

  final BaseCacheManager _cacheManager;

  Future<Uri?> resolve(String? sourceUrl) async {
    final url = sourceUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    try {
      final key = 'echo-artwork-${sha256.convert(utf8.encode(url))}';
      final file = await _cacheManager.getSingleFile(url, key: key);
      if (!await file.exists() || await file.length() == 0) return null;
      return file.uri;
    } catch (_) {
      // Artwork is optional; a cache/network failure must not affect playback.
      return null;
    }
  }
}
