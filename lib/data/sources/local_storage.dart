import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import '../models/server_config.dart';
import '../models/audio_quality.dart';

/// 本地存储封装（SharedPreferences）
class LocalStorage {
  static const String _logTag = 'LOCAL_STORAGE';
  static const String _keyServerConfig = 'server_config';
  static const String _keyAutoFallback = 'auto_fallback';
  static const String _keyAudioQualitySettings = 'audio_quality_settings';
  static const String _keyPlaybackMode = 'playback_mode';
  static const String _keyPlaybackModesV2 = 'playback_modes_v2';
  static const String _keyPlaybackSession = 'playback_session_v1';
  static const String _keyPlaybackSessionV2 = 'playback_session_v2';
  static const String _keyPlaybackSessionLibraryPrefix =
      'playback_session_v2_library_';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyThemeSeedColor = 'theme_seed_color';
  static const String _keyDynamicPlayerBackground =
      'dynamic_player_background_v1';
  static const String _keyMobileCacheSavedBytesByLibrary =
      'mobile_cache_saved_bytes_by_library_v1';
  static const String _keyMaxCacheSizeBytes = 'max_cache_size_bytes';
  static const String _keyHasLaunchedBefore = 'has_launched_before';
  static const String _keyCrossfadeDurationMs = 'crossfade_duration_ms';
  static const String _keyPlaybackVolume = 'playback_volume_v1';
  static const String _keyAllSongsSortOption = 'all_songs_sort_option';

  /// 是否曾经启动过（用于判断是否显示开屏动画）
  static Future<bool> hasLaunchedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasLaunchedBefore) ?? false;
  }

  /// 标记已完成首次启动
  static Future<void> setHasLaunchedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasLaunchedBefore, true);
    Logger.infoWithTag(_logTag, 'hasLaunchedBefore set to true');
  }

  /// 保存服务器配置
  static Future<void> saveServerConfig(ServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(config.toJson());
    await prefs.setString(_keyServerConfig, json);
    Logger.infoWithTag(_logTag, 'server config saved');
  }

  /// 读取服务器配置
  static Future<ServerConfig?> getServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyServerConfig);
    if (json == null) {
      Logger.debugWithTag(_logTag, 'server config not found');
      return null;
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      Logger.debugWithTag(_logTag, 'server config loaded');
      return ServerConfig.fromJson(map);
    } catch (e) {
      Logger.warnWithTag(_logTag, 'failed to parse server config', e);
      return null;
    }
  }

  /// 删除服务器配置（登出）
  static Future<void> clearServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerConfig);
    Logger.infoWithTag(_logTag, 'server config cleared');
  }

  /// 检查是否有已保存的配置
  static Future<bool> hasServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final result = prefs.containsKey(_keyServerConfig);
    Logger.debugWithTag(_logTag, 'hasServerConfig=$result');
    return result;
  }

  /// 读取自动回退开关（默认开启）
  static Future<bool> getAutoFallback() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_keyAutoFallback) ?? true;
    Logger.debugWithTag(_logTag, 'autoFallback=$value');
    return value;
  }

  /// 保存自动回退开关
  static Future<void> setAutoFallback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoFallback, value);
    Logger.infoWithTag(_logTag, 'autoFallback updated: $value');
  }

  /// 读取音质设置
  static Future<AudioQualitySettings> getAudioQualitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyAudioQualitySettings);
    if (json == null) {
      Logger.debugWithTag(
        _logTag,
        'audio quality settings not found, use default',
      );
      return const AudioQualitySettings();
    }

    try {
      Logger.debugWithTag(_logTag, 'audio quality settings loaded');
      return AudioQualitySettings.fromJsonString(json);
    } catch (e) {
      Logger.warnWithTag(_logTag, 'failed to parse audio quality settings', e);
      return const AudioQualitySettings();
    }
  }

  /// 保存音质设置
  static Future<void> setAudioQualitySettings(
    AudioQualitySettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioQualitySettings, settings.toJsonString());
    Logger.infoWithTag(_logTag, 'audio quality settings saved');
  }

  /// 读取播放模式（sequential / repeatAll / repeatOne / shuffle）
  static Future<String> getPlaybackMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_keyPlaybackMode);
    if (mode == null) {
      Logger.debugWithTag(_logTag, 'playback mode not found, use default');
      return 'repeatAll';
    }

    switch (mode) {
      case 'sequential':
      case 'shuffle':
      case 'repeatAll':
      case 'repeatOne':
        Logger.debugWithTag(_logTag, 'playback mode loaded: $mode');
        return mode;
      default:
        Logger.warnWithTag(_logTag, 'invalid playback mode in storage: $mode');
        return 'repeatAll';
    }
  }

  /// 保存播放模式（sequential / repeatAll / repeatOne / shuffle）
  static Future<void> setPlaybackMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPlaybackMode, mode);
    Logger.infoWithTag(_logTag, 'playback mode saved: $mode');
  }

  /// Reads independently persisted shuffle and repeat settings.
  ///
  /// A null result means this installation only has the legacy combined mode
  /// (or no valid V2 value), so the caller should migrate from
  /// [getPlaybackMode].
  static Future<({String loopMode, bool shuffleEnabled})?>
  getPlaybackModes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlaybackModesV2);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final loopMode = decoded['loopMode'];
      final shuffleEnabled = decoded['shuffleEnabled'];
      if (loopMode is! String ||
          !const <String>{'off', 'one', 'all'}.contains(loopMode) ||
          shuffleEnabled is! bool) {
        Logger.warnWithTag(_logTag, 'invalid independent playback modes');
        return null;
      }
      return (loopMode: loopMode, shuffleEnabled: shuffleEnabled);
    } catch (error) {
      Logger.warnWithTag(
        _logTag,
        'failed to parse independent playback modes',
        error,
      );
      return null;
    }
  }

  /// Saves independent shuffle and repeat settings and keeps the legacy
  /// combined key synchronized for older application builds.
  static Future<void> setPlaybackModes({
    required String loopMode,
    required bool shuffleEnabled,
  }) async {
    if (!const <String>{'off', 'one', 'all'}.contains(loopMode)) {
      throw ArgumentError.value(loopMode, 'loopMode');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyPlaybackModesV2,
      jsonEncode(<String, Object>{
        'loopMode': loopMode,
        'shuffleEnabled': shuffleEnabled,
      }),
    );
    final legacyMode = shuffleEnabled
        ? 'shuffle'
        : switch (loopMode) {
            'off' => 'sequential',
            'one' => 'repeatOne',
            'all' => 'repeatAll',
            _ => 'repeatAll',
          };
    await prefs.setString(_keyPlaybackMode, legacyMode);
    Logger.infoWithTag(
      _logTag,
      'playback modes saved: loop=$loopMode shuffle=$shuffleEnabled',
    );
  }

  /// 保存播放会话（队列 + 索引 + 进度 + 播放状态）
  static Future<void> savePlaybackSession(
    Map<String, dynamic> session, {
    String? libraryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedLibraryId =
        _normalizePlaybackLibraryId(libraryId) ??
        _normalizePlaybackLibraryId(session['libraryId']?.toString());
    final payload = <String, dynamic>{
      ...session,
      if (normalizedLibraryId != null) 'libraryId': normalizedLibraryId,
    };
    final key = _playbackSessionKeyForLibrary(normalizedLibraryId);
    await prefs.setString(key, jsonEncode(payload));
    if (normalizedLibraryId == null) {
      await prefs.remove(_keyPlaybackSession);
    } else {
      await _removeLegacyPlaybackSessionsOwnedBy(prefs, normalizedLibraryId);
    }
    Logger.debugWithTag(_logTag, 'playback session saved');
  }

  /// 读取播放会话
  static Future<Map<String, dynamic>?> getPlaybackSession({
    String? libraryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedLibraryId = _normalizePlaybackLibraryId(libraryId);
    final scopedKey = _playbackSessionKeyForLibrary(normalizedLibraryId);
    final candidates = <(String, String?)>[
      if (normalizedLibraryId != null) (scopedKey, prefs.getString(scopedKey)),
      (_keyPlaybackSessionV2, prefs.getString(_keyPlaybackSessionV2)),
      (_keyPlaybackSession, prefs.getString(_keyPlaybackSession)),
    ];
    if (candidates.every(
      (candidate) => candidate.$2 == null || candidate.$2!.isEmpty,
    )) {
      Logger.debugWithTag(_logTag, 'playback session not found');
      return null;
    }

    for (final (key, raw) in candidates) {
      if (raw == null || raw.isEmpty) continue;
      final decoded = _decodePlaybackSession(raw);
      if (decoded == null) {
        if (key == scopedKey && normalizedLibraryId != null) {
          await prefs.remove(key);
        }
        continue;
      }

      final storedLibraryId = _normalizePlaybackLibraryId(
        decoded['libraryId']?.toString(),
      );
      if (normalizedLibraryId != null &&
          storedLibraryId != null &&
          storedLibraryId != normalizedLibraryId) {
        if (key == _keyPlaybackSessionV2) return null;
        continue;
      }

      if (normalizedLibraryId == null) {
        if (storedLibraryId != null) return null;
        return decoded;
      }

      final migrated = <String, dynamic>{
        ...decoded,
        'libraryId': normalizedLibraryId,
      };
      if (key != scopedKey || storedLibraryId == null) {
        await prefs.setString(scopedKey, jsonEncode(migrated));
      }
      if (key != scopedKey) {
        await _removeLegacyPlaybackSessionsOwnedBy(prefs, normalizedLibraryId);
      }
      return migrated;
    }
    return null;
  }

  /// Reads only the legacy snapshot when a syntactically valid v2 payload
  /// cannot be repaired by the queue codec.
  static Future<Map<String, dynamic>?> getLegacyPlaybackSession({
    String? libraryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPlaybackSession);
    if (raw == null || raw.isEmpty) return null;
    final decoded = _decodePlaybackSession(raw);
    if (decoded == null) return null;
    final normalizedLibraryId = _normalizePlaybackLibraryId(libraryId);
    final storedLibraryId = _normalizePlaybackLibraryId(
      decoded['libraryId']?.toString(),
    );
    if (normalizedLibraryId != null &&
        storedLibraryId != null &&
        storedLibraryId != normalizedLibraryId) {
      return null;
    }
    if (normalizedLibraryId == null) return decoded;
    return <String, dynamic>{...decoded, 'libraryId': normalizedLibraryId};
  }

  static Map<String, dynamic>? _decodePlaybackSession(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      Logger.warnWithTag(_logTag, 'invalid playback session payload type');
    } catch (e) {
      Logger.warnWithTag(_logTag, 'failed to parse playback session', e);
    }
    return null;
  }

  /// 清除播放会话
  static Future<void> clearPlaybackSession({String? libraryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedLibraryId = _normalizePlaybackLibraryId(libraryId);
    if (normalizedLibraryId == null) {
      await prefs.remove(_keyPlaybackSessionV2);
      await prefs.remove(_keyPlaybackSession);
    } else {
      await prefs.remove(_playbackSessionKeyForLibrary(normalizedLibraryId));
      await _removeLegacyPlaybackSessionsOwnedBy(prefs, normalizedLibraryId);
    }
    Logger.debugWithTag(_logTag, 'playback session cleared');
  }

  static String? _normalizePlaybackLibraryId(String? libraryId) {
    final normalized = libraryId?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String _playbackSessionKeyForLibrary(String? libraryId) {
    if (libraryId == null) return _keyPlaybackSessionV2;
    final encodedId = base64Url
        .encode(utf8.encode(libraryId))
        .replaceAll('=', '');
    return '$_keyPlaybackSessionLibraryPrefix$encodedId';
  }

  static Future<void> _removeLegacyPlaybackSessionsOwnedBy(
    SharedPreferences prefs,
    String libraryId,
  ) async {
    for (final key in <String>[_keyPlaybackSessionV2, _keyPlaybackSession]) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final decoded = _decodePlaybackSession(raw);
      if (decoded == null) {
        await prefs.remove(key);
        continue;
      }
      final storedLibraryId = _normalizePlaybackLibraryId(
        decoded['libraryId']?.toString(),
      );
      if (storedLibraryId == null || storedLibraryId == libraryId) {
        await prefs.remove(key);
      }
    }
  }

  /// 读取主题模式（system / light / dark）
  static Future<String> getThemeModeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_keyThemeMode) ?? 'system';
    switch (mode) {
      case 'light':
      case 'dark':
      case 'system':
        Logger.debugWithTag(_logTag, 'theme mode loaded: $mode');
        return mode;
      default:
        Logger.warnWithTag(_logTag, 'invalid theme mode in storage: $mode');
        return 'system';
    }
  }

  /// 保存主题模式（system / light / dark）
  static Future<void> setThemeModeSetting(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
    Logger.infoWithTag(_logTag, 'theme mode saved: $mode');
  }

  /// Whether player surfaces follow colours extracted from the current cover.
  static Future<bool> getDynamicPlayerBackground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDynamicPlayerBackground) ?? true;
  }

  static Future<void> setDynamicPlayerBackground(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDynamicPlayerBackground, enabled);
  }

  /// 读取主题主色（ARGB int）
  static Future<int> getThemeSeedColorValue() async {
    final prefs = await SharedPreferences.getInstance();
    final color = prefs.getInt(_keyThemeSeedColor) ?? 0xFF4CAF50;
    Logger.debugWithTag(
      _logTag,
      'theme seed color loaded: 0x${color.toRadixString(16)}',
    );
    return color;
  }

  /// 保存主题主色（ARGB int）
  static Future<void> setThemeSeedColorValue(int color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeSeedColor, color);
    Logger.infoWithTag(
      _logTag,
      'theme seed color saved: 0x${color.toRadixString(16)}',
    );
  }

  /// 读取指定音乐库的“移动网络缓存命中节省流量”累计值（字节）
  static Future<int> getMobileCacheSavedBytes({
    required String libraryId,
  }) async {
    if (libraryId.trim().isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMobileCacheSavedBytesByLibrary);
    if (raw == null || raw.isEmpty) return 0;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _parsePositiveInt(map[libraryId]);
    } catch (e) {
      Logger.warnWithTag(
        _logTag,
        'failed to parse mobile cache saved bytes map',
        e,
      );
      return 0;
    }
  }

  /// 增加指定音乐库的“移动网络缓存命中节省流量”累计值（字节）
  static Future<void> addMobileCacheSavedBytes({
    required String libraryId,
    required int bytes,
  }) async {
    final normalizedLibraryId = libraryId.trim();
    if (normalizedLibraryId.isEmpty || bytes <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMobileCacheSavedBytesByLibrary);

    Map<String, dynamic> map = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map = decoded;
        } else if (decoded is Map) {
          map = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (e) {
        Logger.warnWithTag(
          _logTag,
          'failed to parse existing mobile cache saved bytes map',
          e,
        );
      }
    }

    final current = _parsePositiveInt(map[normalizedLibraryId]);
    final next = current + bytes;
    map[normalizedLibraryId] = next;
    await prefs.setString(_keyMobileCacheSavedBytesByLibrary, jsonEncode(map));
    Logger.infoWithTag(
      _logTag,
      'mobile cache saved bytes +$bytes library=$normalizedLibraryId total=$next',
    );
  }

  static int _parsePositiveInt(Object? value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) {
      final converted = value.floor();
      return converted < 0 ? 0 : converted;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 0) return 0;
      return parsed;
    }
    return 0;
  }

  /// 读取音频缓存上限设置（字节）
  static Future<int?> getMaxCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_keyMaxCacheSizeBytes);
    if (value != null) {
      Logger.debugWithTag(_logTag, 'maxCacheSize loaded: $value');
    }
    return value;
  }

  /// 保存音频缓存上限设置（字节）
  static Future<void> setMaxCacheSize(int bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxCacheSizeBytes, bytes);
    Logger.infoWithTag(_logTag, 'maxCacheSize saved: $bytes');
  }

  /// 读取淡入淡出时长（毫秒，0 = 关闭）
  static Future<int> getCrossfadeDurationMs() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_keyCrossfadeDurationMs) ?? 0;
    Logger.debugWithTag(_logTag, 'crossfadeDurationMs loaded: $value');
    return value;
  }

  /// 保存淡入淡出时长（毫秒）
  static Future<void> setCrossfadeDurationMs(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCrossfadeDurationMs, ms);
    Logger.infoWithTag(_logTag, 'crossfadeDurationMs saved: $ms');
  }

  /// Reads the user playback volume in the inclusive range 0–1.
  static Future<double> getPlaybackVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_keyPlaybackVolume) ?? 1.0;
    return value.clamp(0.0, 1.0).toDouble();
  }

  /// Persists the user playback volume in the inclusive range 0–1.
  static Future<void> setPlaybackVolume(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPlaybackVolume, value.clamp(0.0, 1.0).toDouble());
  }

  /// 读取“全部歌曲”页面上次选择的排序方式。
  static Future<String?> getAllSongsSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences keeps an isolate-local cache. Echoes also runs an
    // audio-service engine, so refresh before reading UI preferences.
    await prefs.reload();
    final option = prefs.getString(_keyAllSongsSortOption);
    Logger.debugWithTag(_logTag, 'allSongsSortOption=$option');
    return option;
  }

  /// 保存“全部歌曲”页面的排序方式。
  static Future<void> setAllSongsSortOption(String option) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_keyAllSongsSortOption, option);
    if (!saved) {
      throw StateError('Failed to save all-songs sort option');
    }
    Logger.infoWithTag(_logTag, 'allSongsSortOption saved: $option');
  }
}
