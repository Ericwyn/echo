class PlaybackLogStore {
  static Future<PlaybackLogStore> open() async => PlaybackLogStore();
  void append(String line) {}
  Future<void> flush() async {}
  Future<String> read() async => '';
}
