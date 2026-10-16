import 'dart:async';
import 'dart:io';

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_muse/src/core/audio_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Plays audio through libmpv using `media_kit`.
///
/// libmpv is resolved in this order:
/// 1. the `muse.libmpvPath` setting, if set;
/// 2. on macOS, an audio-only libmpv build that is downloaded once into the
///    plugin's private storage;
/// 3. the system library (`libmpv.so` on Linux, `libmpv-2.dll` on Windows).
class MediaKitAudioPlayer implements BaseAudioPlayer {
  MediaKitAudioPlayer(this._context, {required void Function(String) log})
      : _log = log;

  static const _macosBuild =
      'libmpv-xcframeworks_v0.6.0_macos-universal-audio-default';
  static const _macosUrl =
      'https://github.com/media-kit/libmpv-darwin-build/releases/download/v0.6.0/$_macosBuild.tar.gz';
  static const _macosLibs = [
    'Mbedcrypto',
    'Mbedtls',
    'Mbedx509',
    'Avutil',
    'Swresample',
    'Avcodec',
    'Avformat',
    'Swscale',
    'Avfilter',
    'Mpv',
  ];

  final LumideContext _context;
  final void Function(String) _log;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  Player? _player;
  Future<void>? _initializing;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<bool> get playing => _playing.stream.distinct();

  @override
  Stream<bool> get completed => _completed.stream.distinct();

  @override
  Future<void> initialize() {
    return _initializing ??= _initialize().catchError((Object error) {
      // Allow a retry, e.g. after the user installs libmpv.
      _initializing = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    final libmpv = await _resolveLibmpv();
    try {
      MediaKit.ensureInitialized(libmpv: libmpv);
    } catch (e) {
      _log('[MediaKitAudioPlayer] Failed to load libmpv ($libmpv): $e');
      throw AudioEngineException(_missingLibmpvMessage());
    }

    final player = Player();
    _subscriptions.addAll([
      player.stream.position.listen(_position.add),
      player.stream.duration.listen(_duration.add),
      player.stream.playing.listen(_playing.add),
      player.stream.completed.listen(_completed.add),
      player.stream.error.listen((e) => _log('[MediaKitAudioPlayer] $e')),
    ]);
    _player = player;
    _log('[MediaKitAudioPlayer] Audio engine ready.');
  }

  Future<String?> _resolveLibmpv() async {
    final configured =
        await _context.workspace.getConfiguration('muse.libmpvPath');
    if (configured is String && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    if (Platform.isMacOS) return _ensureMacosLibmpv();
    return null;
  }

  /// Downloads and prepares the macOS libmpv frameworks if needed, and
  /// returns the path of the `Mpv` binary.
  Future<String> _ensureMacosLibmpv() async {
    final storageDir = await _context.workspace.getPluginStorageDir();
    final engineDir = p.join(storageDir, 'engine', _macosBuild);
    final frameworksDir = p.join(engineDir, 'Frameworks');
    final readyMarker = p.join(engineDir, '.ready');
    String binary(String lib) =>
        p.join(frameworksDir, '$lib.framework', 'Versions', 'A', lib);

    if (await _context.fs.exists(readyMarker)) return binary('Mpv');

    _log('[MediaKitAudioPlayer] Downloading libmpv to $engineDir');
    try {
      // Start over after an interrupted setup. This is the plugin's private
      // storage, which Lumide lets plugins manage freely.
      final leftover = Directory(engineDir);
      if (await leftover.exists()) await leftover.delete(recursive: true);

      // With extract: true the destination is a directory; the archive is
      // unpacked into it.
      await _context.fs.downloadFile(
        _macosUrl,
        engineDir,
        label: 'Downloading M.U.S.E. audio engine (libmpv)',
        extract: true,
      );
      await _context.fs.createDirectory(frameworksDir, recursive: true);

      for (final lib in _macosLibs) {
        final framework = p.join(engineDir, _macosBuild, '$lib.xcframework',
            'macos-arm64_x86_64', '$lib.framework');
        if (!await _context.fs.exists(framework)) {
          throw StateError('Missing $lib.framework in the libmpv archive');
        }
        await _run('cp', ['-R', framework, frameworksDir]);
      }

      // The libraries load each other through @rpath, and macOS refuses to
      // load modified binaries until they are signed again.
      for (final lib in _macosLibs) {
        final libBinary = binary(lib);
        await _run(
            'install_name_tool', ['-add_rpath', frameworksDir, libBinary],
            allowFailure: true);
        await _run('codesign', ['--force', '--sign', '-', libBinary]);
      }

      await _context.fs.writeString(readyMarker, _macosUrl);
    } catch (e) {
      _log('[MediaKitAudioPlayer] libmpv setup failed: $e');
      throw AudioEngineException(
          'Could not set up the M.U.S.E. audio engine: $e');
    }
    return binary('Mpv');
  }

  Future<void> _run(String executable, List<String> args,
      {bool allowFailure = false}) async {
    final result = await _context.shell.run(executable, args);
    if (result.exitCode != 0 && !allowFailure) {
      throw StateError(
          '$executable exited with ${result.exitCode}: ${result.stderr}');
    }
  }

  String _missingLibmpvMessage() {
    if (Platform.isLinux) {
      return 'M.U.S.E. needs libmpv. Install it with your package manager '
          '(e.g. "sudo apt install libmpv2" or "sudo dnf install mpv-libs"), '
          'or set "muse.libmpvPath".';
    }
    if (Platform.isWindows) {
      return 'M.U.S.E. needs libmpv-2.dll. Put it on your PATH or set '
          '"muse.libmpvPath" to its location.';
    }
    return 'M.U.S.E. could not load libmpv. Set "muse.libmpvPath" to a '
        'working libmpv library.';
  }

  @override
  Future<void> open(String path) async {
    await initialize();
    await _player?.open(Media(path));
  }

  @override
  Future<void> playOrPause() async {
    await _player?.playOrPause();
  }

  @override
  Future<void> seek(double progress) async {
    final player = _player;
    if (player == null) return;
    final target = player.state.duration * progress.clamp(0.0, 1.0);
    await player.seek(target);
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player?.dispose();
    _player = null;
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _completed.close();
  }
}
