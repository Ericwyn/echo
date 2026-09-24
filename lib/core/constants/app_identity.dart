import 'dart:ui';

/// Stable application identifier used by platform integrations.
const echoApplicationId = 'com.az1n.echoes';
const echoBrandName = 'Echoes';

/// User-facing name selected for the current operating-system locale.
String echoDisplayName([Locale? locale]) {
  final languageCode = (locale ?? PlatformDispatcher.instance.locale)
      .languageCode
      .toLowerCase();
  return languageCode == 'zh' ? '回响' : echoBrandName;
}
