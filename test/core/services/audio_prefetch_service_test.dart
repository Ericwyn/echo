import 'dart:io';
import 'dart:async';
import 'package:echoes/core/services/audio_prefetch_service_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late AudioPrefetchService service;
  late String url;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('echo-prefetch-test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/song';
    service = AudioPrefetchService();
  });
  tearDown(() async {
    await service.cancel();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test('actually downloads and publishes the complete audio file', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    final path = await service.download(url, '${directory.path}/song.cache');
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), [1, 2, 3, 4]);
    expect(
      File('${directory.path}/song.cache.prefetch.part').existsSync(),
      isFalse,
    );
  });

  test('server error payload is never registered as playable audio', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"error":"not found"}');
      await request.response.close();
    });
    expect(await service.download(url, '${directory.path}/song.cache'), isNull);
    expect(directory.listSync(), isEmpty);
  });

  test('cancelling an in-flight download removes the partial file', () async {
    final started = Completer<void>();
    server.listen((request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = 100000;
      request.response.add([1, 2, 3]);
      await request.response.flush();
      started.complete();
    });
    final pending = service.download(url, '${directory.path}/song.cache');
    await started.future;
    await service.cancel();
    expect(await pending, isNull);
    expect(directory.listSync(), isEmpty);
  });

  test('immediate cancellation cannot start a delayed new download', () async {
    final pending = service.download(url, '${directory.path}/song.cache');
    await service.cancel();
    expect(await pending, isNull);
    expect(directory.listSync(), isEmpty);
  });
}
