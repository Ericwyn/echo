import 'package:echoes/core/services/artwork_file_cache.dart';
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCacheManager extends Mock implements BaseCacheManager {}

void main() {
  test('returns a local URI for a cached authenticated artwork URL', () async {
    final manager = _MockCacheManager();
    final file = MemoryFileSystem().file('/cache/album-art.jpg');
    await file.create(recursive: true);
    await file.writeAsBytes(<int>[1, 2, 3]);
    const url = 'https://music.example.test/cover?id=123&token=secret';
    when(
      () => manager.getSingleFile(url, key: any(named: 'key')),
    ).thenAnswer((_) async => file);

    final uri = await ArtworkFileCache(cacheManager: manager).resolve(url);

    expect(uri, file.uri);
    expect(uri.toString(), startsWith('file:'));
    expect(uri.toString(), isNot(contains('secret')));
    verify(() => manager.getSingleFile(url, key: any(named: 'key'))).called(1);
  });

  test(
    'rejects non-http artwork references before touching the cache',
    () async {
      final manager = _MockCacheManager();
      final cache = ArtworkFileCache(cacheManager: manager);

      expect(await cache.resolve('file:///tmp/cover.jpg'), isNull);
      expect(await cache.resolve('javascript:alert(1)'), isNull);
      verifyNever(() => manager.getSingleFile(any(), key: any(named: 'key')));
    },
  );
}
