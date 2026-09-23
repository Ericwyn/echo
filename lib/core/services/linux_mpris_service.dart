import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dbus/dbus.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../providers/player/playback_contract.dart';
import '../../providers/player/player_state.dart' show PlaybackMode;
import '../utils/logger.dart';

const _mprisRootInterface = 'org.mpris.MediaPlayer2';
const _mprisPlayerInterface = 'org.mpris.MediaPlayer2.Player';
const _mprisBusName = 'org.mpris.MediaPlayer2.echoes';
const _mprisObjectPath = '/org/mpris/MediaPlayer2';
const _mprisNoTrackPath = '/org/mpris/MediaPlayer2/TrackList/NoTrack';

typedef LinuxMprisArtworkResolver =
    Future<Uri?> Function(PlaybackSnapshot snapshot);

/// Linux MPRIS v2 adapter. It owns only a session-bus connection; playback
/// commands and the audio engine remain owned by [PlaybackCommands].
class LinuxMprisService {
  LinuxMprisService({
    required this.commands,
    this.onRaise,
    this.onQuit,
    this.artworkResolver,
  });

  final PlaybackCommands commands;
  final Future<void> Function()? onRaise;
  final Future<void> Function()? onQuit;
  final LinuxMprisArtworkResolver? artworkResolver;
  DBusClient? _client;
  _MprisObject? _object;
  var _remoteSeekCount = 0;
  Uri? _artworkUri;
  int _artworkGeneration = 0;

  bool get isStarted => _client != null && _object != null;
  bool get remoteSeekPending => _remoteSeekCount > 0;

  Future<void> start() async {
    if (isStarted) return;
    final client = DBusClient.session();
    try {
      final request = await client.requestName(
        _mprisBusName,
        flags: const <DBusRequestNameFlag>{DBusRequestNameFlag.doNotQueue},
      );
      if (request != DBusRequestNameReply.primaryOwner &&
          request != DBusRequestNameReply.alreadyOwner) {
        throw StateError('MPRIS bus name is already owned: $_mprisBusName');
      }
      final object = _MprisObject(this);
      _client = client;
      _object = object;
      await client.registerObject(object);
      await object.publishInitialProperties();
      unawaited(_resolveArtwork(_snapshot));
    } catch (_) {
      await client.close();
      _client = null;
      _object = null;
      rethrow;
    }
  }

  Future<void> updateSnapshot(PlaybackSnapshot snapshot) async {
    final previous = _snapshot;
    final artworkChanged =
        previous.libraryId != snapshot.libraryId ||
        previous.sourceGeneration != snapshot.sourceGeneration ||
        previous.songId != snapshot.songId ||
        previous.entryId != snapshot.entryId ||
        previous.artworkReference != snapshot.artworkReference;
    if (artworkChanged) {
      _artworkGeneration += 1;
      _artworkUri = null;
    }

    final object = _object;
    if (object == null) {
      _snapshot = snapshot;
    } else {
      await object.updateSnapshot(snapshot);
    }
    if (artworkChanged) unawaited(_resolveArtwork(snapshot));
  }

  Future<void> _resolveArtwork(PlaybackSnapshot snapshot) async {
    final resolver = artworkResolver;
    if (resolver == null || snapshot.artworkReference == null) return;
    final generation = ++_artworkGeneration;
    try {
      final uri = await resolver(snapshot);
      if (generation != _artworkGeneration ||
          snapshot.sourceGeneration != _snapshot.sourceGeneration ||
          snapshot.songId != _snapshot.songId ||
          snapshot.libraryId != _snapshot.libraryId ||
          snapshot.entryId != _snapshot.entryId ||
          snapshot.artworkReference != _snapshot.artworkReference ||
          uri == null ||
          uri.scheme != 'file' ||
          uri.query.isNotEmpty ||
          uri.fragment.isNotEmpty) {
        return;
      }
      _artworkUri = uri;
      await _object?.emitMetadataChanged();
    } catch (_) {
      // System artwork is optional and must never affect playback controls.
    }
  }

  Future<void> dispose() async {
    final client = _client;
    final object = _object;
    _client = null;
    _object = null;
    if (client == null) return;
    try {
      if (object != null) await client.unregisterObject(object);
    } catch (error, stackTrace) {
      Logger.warnWithTag('MPRIS', 'failed to unregister media object', error);
      Logger.debugWithTag('MPRIS', 'unregister stack', stackTrace);
    }
    try {
      await client.releaseName(_mprisBusName);
    } catch (error, stackTrace) {
      Logger.warnWithTag('MPRIS', 'failed to release media bus name', error);
      Logger.debugWithTag('MPRIS', 'release name stack', stackTrace);
    } finally {
      try {
        await client.close();
      } catch (error, stackTrace) {
        Logger.warnWithTag('MPRIS', 'failed to close session bus', error);
        Logger.debugWithTag('MPRIS', 'session bus close stack', stackTrace);
      }
    }
  }

  PlaybackSnapshot _snapshot = const PlaybackSnapshot(
    songId: null,
    entryId: null,
    title: '',
    artist: '',
    album: '',
    artworkReference: null,
    position: Duration.zero,
    positionSeekRevision: 0,
    duration: Duration.zero,
    isPlaying: false,
    playbackRequested: false,
    isStopped: true,
    isLoading: false,
    hasError: false,
    canPlay: false,
    canPause: false,
    canGoNext: false,
    canGoPrevious: false,
    canSeek: false,
    volume: 1,
    isMuted: false,
    loopMode: LoopMode.off,
    shuffleEnabled: false,
  );

  String get _playbackStatus {
    if (_snapshot.isStopped) return 'Stopped';
    return _snapshot.playbackRequested ? 'Playing' : 'Paused';
  }

  String get _loopStatus {
    return switch (_snapshot.loopMode) {
      LoopMode.one => 'Track',
      LoopMode.all => 'Playlist',
      LoopMode.off => 'None',
    };
  }

  String? get _currentTrackPath {
    final identity = _snapshot.entryId ?? _snapshot.songId;
    if (identity == null) return null;
    final compositeIdentity = jsonEncode(<String?>[
      _snapshot.libraryId,
      identity,
    ]);
    return _trackObjectPath(compositeIdentity);
  }

  Map<String, DBusValue> _rootProperties() => <String, DBusValue>{
    'CanQuit': DBusBoolean(onQuit != null),
    'Fullscreen': const DBusBoolean(false),
    'CanSetFullscreen': const DBusBoolean(false),
    'CanRaise': DBusBoolean(onRaise != null),
    'HasTrackList': const DBusBoolean(false),
    'Identity': const DBusString('Echoes'),
    'DesktopEntry': const DBusString('echoes'),
    'SupportedUriSchemes': DBusArray(DBusSignature('s'), const <DBusValue>[]),
    'SupportedMimeTypes': DBusArray(DBusSignature('s'), const <DBusValue>[]),
  };

  Map<String, DBusValue> _playerProperties() => <String, DBusValue>{
    'PlaybackStatus': DBusString(_playbackStatus),
    'LoopStatus': DBusString(_loopStatus),
    'Rate': const DBusDouble(1),
    'Shuffle': DBusBoolean(_snapshot.shuffleEnabled),
    'Metadata': DBusDict.stringVariant(_metadata),
    'Volume': DBusDouble(_snapshot.isMuted ? 0 : _snapshot.volume),
    'Position': DBusInt64(_snapshot.position.inMicroseconds),
    'MinimumRate': const DBusDouble(1),
    'MaximumRate': const DBusDouble(1),
    'CanGoNext': DBusBoolean(_snapshot.canGoNext),
    'CanGoPrevious': DBusBoolean(_snapshot.canGoPrevious),
    'CanPlay': DBusBoolean(_snapshot.canPlay),
    'CanPause': DBusBoolean(_snapshot.canPause || _snapshot.playbackRequested),
    'CanSeek': DBusBoolean(_snapshot.canSeek),
    'CanControl': const DBusBoolean(true),
  };

  Map<String, DBusValue> get _metadata {
    if (_snapshot.songId == null) return const <String, DBusValue>{};
    final metadata = <String, DBusValue>{
      'mpris:trackid': DBusObjectPath(_currentTrackPath ?? _mprisNoTrackPath),
      'xesam:title': DBusString(_snapshot.title),
    };
    if (_snapshot.artist.isNotEmpty) {
      metadata['xesam:artist'] = DBusArray(DBusSignature('s'), <DBusValue>[
        DBusString(_snapshot.artist),
      ]);
    }
    if (_snapshot.album.isNotEmpty) {
      metadata['xesam:album'] = DBusString(_snapshot.album);
    }
    if (_snapshot.duration > Duration.zero) {
      metadata['mpris:length'] = DBusInt64(_snapshot.duration.inMicroseconds);
    }
    final artworkUri = _artworkUri;
    if (artworkUri != null) {
      metadata['mpris:artUrl'] = DBusString(artworkUri.toString());
    }
    return metadata;
  }

  Future<void> _setLoopStatus(String value) async {
    switch (value) {
      case 'None':
        await commands.setPlaybackMode(PlaybackMode.sequential);
      case 'Track':
        await commands.setPlaybackMode(PlaybackMode.repeatOne);
      case 'Playlist':
        await commands.setPlaybackMode(PlaybackMode.repeatAll);
      default:
        throw const FormatException('Unknown MPRIS LoopStatus');
    }
  }

  Duration _clampPosition(Duration position) {
    if (_snapshot.duration <= Duration.zero) return Duration.zero;
    final micros = position.inMicroseconds
        .clamp(0, _snapshot.duration.inMicroseconds)
        .toInt();
    return Duration(microseconds: micros);
  }

  Future<void> _seek(Duration target) async {
    if (!_snapshot.canSeek) return;
    _remoteSeekCount += 1;
    final position = _clampPosition(target);
    try {
      await commands.seek(position);
      await _object?.emitSeeked(position);
    } finally {
      if (_remoteSeekCount > 0) _remoteSeekCount -= 1;
    }
  }
}

class _MprisObject extends DBusObject {
  _MprisObject(this.service) : super(DBusObjectPath(_mprisObjectPath));

  final LinuxMprisService service;

  @override
  List<DBusIntrospectInterface> introspect() => <DBusIntrospectInterface>[
    _rootIntrospection,
    _playerIntrospection,
  ];

  Future<void> publishInitialProperties() async {
    await emitPropertiesChanged(
      _mprisRootInterface,
      changedProperties: service._rootProperties(),
    );
    await emitPropertiesChanged(
      _mprisPlayerInterface,
      changedProperties: service._playerProperties(),
    );
  }

  Future<void> updateSnapshot(PlaybackSnapshot next) async {
    final old = service._snapshot;
    final oldStatus = service._playbackStatus;
    final oldLoop = service._loopStatus;
    final oldTrack = service._currentTrackPath;
    final oldShuffle = old.shuffleEnabled;
    final positionSeeked =
        old.positionSeekRevision != next.positionSeekRevision &&
        old.songId == next.songId &&
        old.entryId == next.entryId;
    final oldCapabilities = _capabilityValues(old);
    service._snapshot = next;

    if (client == null) return;
    final changed = <String, DBusValue>{};
    if (oldStatus != service._playbackStatus) {
      changed['PlaybackStatus'] = DBusString(service._playbackStatus);
    }
    if (oldLoop != service._loopStatus) {
      changed['LoopStatus'] = DBusString(service._loopStatus);
    }
    if (oldShuffle != next.shuffleEnabled) {
      changed['Shuffle'] = DBusBoolean(next.shuffleEnabled);
    }
    if (oldTrack != service._currentTrackPath ||
        old.title != next.title ||
        old.artist != next.artist ||
        old.album != next.album ||
        old.duration != next.duration ||
        old.artworkReference != next.artworkReference) {
      changed['Metadata'] = DBusDict.stringVariant(service._metadata);
      changed['Position'] = DBusInt64(next.position.inMicroseconds);
    } else {
      final positionDelta = (next.position - old.position).inMicroseconds.abs();
      if (positionDelta >= Duration(seconds: 1).inMicroseconds) {
        changed['Position'] = DBusInt64(next.position.inMicroseconds);
      }
    }
    if (positionSeeked) {
      changed['Position'] = DBusInt64(next.position.inMicroseconds);
      if (!service.remoteSeekPending) await emitSeeked(next.position);
    }
    if (oldCapabilities['CanGoNext'] != next.canGoNext) {
      changed['CanGoNext'] = DBusBoolean(next.canGoNext);
    }
    if (oldCapabilities['CanGoPrevious'] != next.canGoPrevious) {
      changed['CanGoPrevious'] = DBusBoolean(next.canGoPrevious);
    }
    if (oldCapabilities['CanPlay'] != next.canPlay) {
      changed['CanPlay'] = DBusBoolean(next.canPlay);
    }
    final canPause = next.canPause || next.playbackRequested;
    if (oldCapabilities['CanPause'] != canPause) {
      changed['CanPause'] = DBusBoolean(canPause);
    }
    if (oldCapabilities['CanSeek'] != next.canSeek) {
      changed['CanSeek'] = DBusBoolean(next.canSeek);
    }
    final volume = next.isMuted ? 0.0 : next.volume;
    if (old.isMuted != next.isMuted || old.volume != next.volume) {
      changed['Volume'] = DBusDouble(volume);
    }
    if (changed.isNotEmpty) {
      await emitPropertiesChanged(
        _mprisPlayerInterface,
        changedProperties: changed,
      );
    }
  }

  Map<String, bool> _capabilityValues(PlaybackSnapshot snapshot) =>
      <String, bool>{
        'CanGoNext': snapshot.canGoNext,
        'CanGoPrevious': snapshot.canGoPrevious,
        'CanPlay': snapshot.canPlay,
        'CanPause': snapshot.canPause || snapshot.playbackRequested,
        'CanSeek': snapshot.canSeek,
      };

  Future<void> emitSeeked(Duration position) async {
    await emitSignal(_mprisPlayerInterface, 'Seeked', <DBusValue>[
      DBusInt64(position.inMicroseconds),
    ]);
  }

  Future<void> emitMetadataChanged() async {
    await emitPropertiesChanged(
      _mprisPlayerInterface,
      changedProperties: <String, DBusValue>{
        'Metadata': DBusDict.stringVariant(service._metadata),
      },
    );
  }

  Map<String, DBusValue>? _propertiesFor(String interface) {
    if (interface == _mprisRootInterface) return service._rootProperties();
    if (interface == _mprisPlayerInterface) return service._playerProperties();
    return null;
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final properties = _propertiesFor(interface);
    if (properties == null) return DBusMethodErrorResponse.unknownInterface();
    final value = properties[name];
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final properties = _propertiesFor(interface);
    if (properties == null) return DBusMethodErrorResponse.unknownInterface();
    return DBusGetAllPropertiesResponse(properties);
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface != _mprisPlayerInterface) {
      if (interface == _mprisRootInterface) {
        return DBusMethodErrorResponse.notSupported();
      }
      return DBusMethodErrorResponse.unknownInterface();
    }

    try {
      switch (name) {
        case 'LoopStatus':
          await service._setLoopStatus(value.asString());
          return DBusMethodSuccessResponse();
        case 'Shuffle':
          await service.commands.setShuffleEnabled(value.asBoolean());
          return DBusMethodSuccessResponse();
        case 'Volume':
          final volume = value.asDouble();
          if (!volume.isFinite || volume < 0 || volume > 1) {
            return DBusMethodErrorResponse.invalidArgs(
              'Volume must be between 0 and 1',
            );
          }
          if (volume > 0) await service.commands.setMuted(false);
          await service.commands.setUserVolume(volume);
          return DBusMethodSuccessResponse();
        case 'Rate':
          if (value.asDouble() == 1) return DBusMethodSuccessResponse();
          return DBusMethodErrorResponse.notSupported();
        default:
          return DBusMethodErrorResponse.propertyReadOnly();
      }
    } on FormatException catch (error) {
      return DBusMethodErrorResponse.invalidArgs(error.message);
    } on TypeError {
      return DBusMethodErrorResponse.invalidArgs();
    } catch (error, stackTrace) {
      Logger.warnWithTag(
        'MPRIS',
        'remote property update failed: $name',
        error,
      );
      Logger.debugWithTag('MPRIS', 'property update stack', stackTrace);
      return DBusMethodErrorResponse.failed(
        'Echoes could not apply the requested media property.',
      );
    }
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    try {
      final interface = methodCall.interface;
      if (interface == _mprisRootInterface) {
        return await _handleRootCall(methodCall);
      }
      if (interface == _mprisPlayerInterface) {
        return await _handlePlayerCall(methodCall);
      }
      return DBusMethodErrorResponse.unknownInterface();
    } on FormatException catch (error) {
      return DBusMethodErrorResponse.invalidArgs(error.message);
    } on TypeError {
      return DBusMethodErrorResponse.invalidArgs();
    } catch (error, stackTrace) {
      Logger.warnWithTag(
        'MPRIS',
        'remote method failed: ${methodCall.interface}.${methodCall.name}',
        error,
      );
      Logger.debugWithTag('MPRIS', 'remote method stack', stackTrace);
      return DBusMethodErrorResponse.failed(
        'Echoes could not complete the requested media action.',
      );
    }
  }

  Future<DBusMethodResponse> _handleRootCall(DBusMethodCall call) async {
    if (call.values.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
    switch (call.name) {
      case 'Raise':
        if (service.onRaise != null) {
          await service.onRaise!();
          return DBusMethodSuccessResponse();
        }
        return DBusMethodErrorResponse.notSupported();
      case 'Quit':
        final onQuit = service.onQuit;
        if (onQuit != null) {
          unawaited(
            onQuit().catchError((Object error, StackTrace stackTrace) {
              Logger.warnWithTag('MPRIS', 'remote quit failed', error);
              Logger.debugWithTag('MPRIS', 'remote quit stack', stackTrace);
            }),
          );
          return DBusMethodSuccessResponse();
        }
        return DBusMethodErrorResponse.notSupported();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  Future<DBusMethodResponse> _handlePlayerCall(DBusMethodCall call) async {
    final args = call.values;
    switch (call.name) {
      case 'Next':
        if (args.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
        if (service._snapshot.canGoNext) await service.commands.next();
        return DBusMethodSuccessResponse();
      case 'Previous':
        if (args.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
        if (service._snapshot.canGoPrevious) {
          await service.commands.previous();
        }
        return DBusMethodSuccessResponse();
      case 'Pause':
        if (args.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
        if (service._snapshot.canPause || service._snapshot.playbackRequested) {
          await service.commands.pause();
        }
        return DBusMethodSuccessResponse();
      case 'PlayPause':
        if (args.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
        await service.commands.togglePlayPause();
        return DBusMethodSuccessResponse();
      case 'Stop':
        if (args.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
        await service.commands.stop();
        return DBusMethodSuccessResponse();
      case 'Play':
        if (args.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
        await service.commands.play();
        return DBusMethodSuccessResponse();
      case 'Seek':
        if (call.signature != DBusSignature('x')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final current = service._snapshot.position;
        await service._seek(
          current + Duration(microseconds: args[0].asInt64()),
        );
        return DBusMethodSuccessResponse();
      case 'SetPosition':
        if (call.signature != DBusSignature('ox')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final trackPath = args[0].asObjectPath().value;
        if (trackPath != service._currentTrackPath) {
          return DBusMethodSuccessResponse();
        }
        await service._seek(Duration(microseconds: args[1].asInt64()));
        return DBusMethodSuccessResponse();
      case 'OpenUri':
        return DBusMethodErrorResponse.notSupported();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

String _trackObjectPath(String entryId) {
  final hash = sha256.convert(utf8.encode(entryId));
  return '$_mprisObjectPath/Track/$hash';
}

final _rootIntrospection = DBusIntrospectInterface(
  _mprisRootInterface,
  methods: <DBusIntrospectMethod>[
    DBusIntrospectMethod('Raise'),
    DBusIntrospectMethod('Quit'),
  ],
  properties: <DBusIntrospectProperty>[
    DBusIntrospectProperty(
      'CanQuit',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty('Fullscreen', DBusSignature('b')),
    DBusIntrospectProperty(
      'CanSetFullscreen',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanRaise',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'HasTrackList',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'Identity',
      DBusSignature('s'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'DesktopEntry',
      DBusSignature('s'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'SupportedUriSchemes',
      DBusSignature('as'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'SupportedMimeTypes',
      DBusSignature('as'),
      access: DBusPropertyAccess.read,
    ),
  ],
);

final _playerIntrospection = DBusIntrospectInterface(
  _mprisPlayerInterface,
  methods: <DBusIntrospectMethod>[
    DBusIntrospectMethod('Next'),
    DBusIntrospectMethod('Previous'),
    DBusIntrospectMethod('Pause'),
    DBusIntrospectMethod('PlayPause'),
    DBusIntrospectMethod('Stop'),
    DBusIntrospectMethod('Play'),
    DBusIntrospectMethod(
      'Seek',
      args: <DBusIntrospectArgument>[
        DBusIntrospectArgument(
          DBusSignature('x'),
          DBusArgumentDirection.in_,
          name: 'Offset',
        ),
      ],
    ),
    DBusIntrospectMethod(
      'SetPosition',
      args: <DBusIntrospectArgument>[
        DBusIntrospectArgument(
          DBusSignature('o'),
          DBusArgumentDirection.in_,
          name: 'TrackId',
        ),
        DBusIntrospectArgument(
          DBusSignature('x'),
          DBusArgumentDirection.in_,
          name: 'Position',
        ),
      ],
    ),
    DBusIntrospectMethod(
      'OpenUri',
      args: <DBusIntrospectArgument>[
        DBusIntrospectArgument(
          DBusSignature('s'),
          DBusArgumentDirection.in_,
          name: 'Uri',
        ),
      ],
    ),
  ],
  signals: <DBusIntrospectSignal>[
    DBusIntrospectSignal(
      'Seeked',
      args: <DBusIntrospectArgument>[
        DBusIntrospectArgument(
          DBusSignature('x'),
          DBusArgumentDirection.out,
          name: 'Position',
        ),
      ],
    ),
  ],
  properties: <DBusIntrospectProperty>[
    DBusIntrospectProperty(
      'PlaybackStatus',
      DBusSignature('s'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty('LoopStatus', DBusSignature('s')),
    DBusIntrospectProperty('Rate', DBusSignature('d')),
    DBusIntrospectProperty('Shuffle', DBusSignature('b')),
    DBusIntrospectProperty(
      'Metadata',
      DBusSignature('a{sv}'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty('Volume', DBusSignature('d')),
    DBusIntrospectProperty(
      'Position',
      DBusSignature('x'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'MinimumRate',
      DBusSignature('d'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'MaximumRate',
      DBusSignature('d'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanGoNext',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanGoPrevious',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanPlay',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanPause',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanSeek',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
    DBusIntrospectProperty(
      'CanControl',
      DBusSignature('b'),
      access: DBusPropertyAccess.read,
    ),
  ],
);
