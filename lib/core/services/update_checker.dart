import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

/// Represents the result of an update check.
@immutable
class UpdateCheckResult {
  /// Whether a newer version is available.
  final bool hasUpdate;

  /// Current app version string (e.g. "0.3.2").
  final String currentVersion;

  /// Latest release version string from GitHub (e.g. "0.4.0").
  final String latestVersion;

  /// HTML URL of the latest release page on GitHub.
  final String? releaseUrl;

  /// Release notes body (markdown).
  final String? releaseNotes;

  /// Direct download URLs for release assets (APK, etc.).
  final List<ReleaseAsset> assets;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.releaseUrl,
    this.releaseNotes,
    this.assets = const [],
  });
}

@immutable
class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });
}

/// Service that checks for app updates via GitHub Releases API.
class UpdateChecker {
  static const _logTag = 'UPDATE';
  static const _owner = 'Azincc';
  static const _repo = 'echo';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/vnd.github+json'},
    ),
  );

  /// Check for updates against the latest GitHub release.
  static Future<UpdateCheckResult> check() async {
    Logger.infoWithTag(_logTag, 'checking for updates…');

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // e.g. "0.3.2"

    try {
      final response = await _dio.get(_apiUrl);
      final data = response.data as Map<String, dynamic>;

      // tag_name is typically "v0.4.0" or "0.4.0"
      final tagName = (data['tag_name'] as String?) ?? '';
      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      final releaseUrl = data['html_url'] as String?;
      final releaseNotes = data['body'] as String?;

      final rawAssets = data['assets'] as List<dynamic>? ?? [];
      final assets = rawAssets.map((a) {
        final m = a as Map<String, dynamic>;
        return ReleaseAsset(
          name: m['name'] as String? ?? '',
          downloadUrl: m['browser_download_url'] as String? ?? '',
          size: m['size'] as int? ?? 0,
        );
      }).toList();

      final hasUpdate = compareVersions(currentVersion, latestVersion) < 0;

      Logger.infoWithTag(
        _logTag,
        'current=$currentVersion latest=$latestVersion hasUpdate=$hasUpdate',
      );

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        releaseNotes: releaseNotes,
        assets: assets,
      );
    } catch (e, st) {
      Logger.errorWithTag(_logTag, 'update check failed', e, st);
      // Return a result indicating no update with current version info.
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
      );
    }
  }

  /// Compare two semver-like version strings.
  /// Returns negative if a < b, 0 if equal, positive if a > b.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    final aVersion = _ParsedVersion.parse(a);
    final bVersion = _ParsedVersion.parse(b);
    final length = aVersion.core.length > bVersion.core.length
        ? aVersion.core.length
        : bVersion.core.length;

    for (var i = 0; i < length; i++) {
      final av = i < aVersion.core.length ? aVersion.core[i] : 0;
      final bv = i < bVersion.core.length ? bVersion.core[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }

    if (aVersion.preRelease.isEmpty && bVersion.preRelease.isEmpty) return 0;
    if (aVersion.preRelease.isEmpty) return 1;
    if (bVersion.preRelease.isEmpty) return -1;

    final preReleaseLength =
        aVersion.preRelease.length > bVersion.preRelease.length
        ? aVersion.preRelease.length
        : bVersion.preRelease.length;
    for (var i = 0; i < preReleaseLength; i++) {
      if (i >= aVersion.preRelease.length) return -1;
      if (i >= bVersion.preRelease.length) return 1;
      final comparison = _comparePreReleasePart(
        aVersion.preRelease[i],
        bVersion.preRelease[i],
      );
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static int _comparePreReleasePart(String a, String b) {
    final aNumber = int.tryParse(a);
    final bNumber = int.tryParse(b);
    if (aNumber != null && bNumber != null) return aNumber.compareTo(bNumber);
    if (aNumber != null) return -1;
    if (bNumber != null) return 1;
    return a.compareTo(b);
  }
}

class _ParsedVersion {
  const _ParsedVersion({required this.core, required this.preRelease});

  final List<int> core;
  final List<String> preRelease;

  factory _ParsedVersion.parse(String value) {
    final withoutPrefix = value.trim().replaceFirst(RegExp(r'^v'), '');
    final withoutBuild = withoutPrefix.split('+').first;
    final separator = withoutBuild.indexOf('-');
    final coreText = separator < 0
        ? withoutBuild
        : withoutBuild.substring(0, separator);
    final preReleaseText = separator < 0
        ? ''
        : withoutBuild.substring(separator + 1);
    return _ParsedVersion(
      core: coreText
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: false),
      preRelease: preReleaseText.isEmpty
          ? const <String>[]
          : preReleaseText.split('.'),
    );
  }
}
