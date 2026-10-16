import 'dart:async';

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_muse/src/core/audio_player.dart';
import 'package:lumide_muse/src/core/music_service.dart';
import 'package:lumide_muse/src/core/playback_queue.dart';
import 'package:test/test.dart';

void main() {
  late _FakeContext context;
  late _FakePlayer player;
  late MusicService music;

  setUp(() {
    context = _FakeContext();
    player = _FakePlayer();
    music = MusicService(context, player, log: (_) {});
  });

  test('play/pause starts the first track when nothing is loaded', () async {
    await music.setPlaylist(['/m/a.mp3', '/m/b.mp3'], autoPlay: false);
    expect(player.opened, isEmpty);

    await music.playOrPause();
    expect(player.opened, ['/m/a.mp3']);
    expect(player.toggles, 0);

    await music.playOrPause();
    expect(player.toggles, 1);
  });

  test('loads lyrics from the .lrc file next to the track', () async {
    context.fs.files['/m/b.lrc'] = '[00:01.00]hello';
    await music.setPlaylist(['/m/a.mp3', '/m/b.mp3']);
    expect(music.lyricService.isEmpty, isTrue);

    await music.next();
    expect(music.lyricService.getLineAt(const Duration(seconds: 2)), 'hello');
  });

  test('announces track changes', () async {
    final changes = <String>[];
    music.trackChanged.listen(changes.add);

    await music.setPlaylist(['/m/a.mp3', '/m/b.mp3']);
    await music.playAt(1);
    await Future<void>.delayed(Duration.zero);

    expect(changes, ['/m/a.mp3', '/m/b.mp3']);
  });

  test('repeat one replays only on completion', () async {
    await music.setPlaylist(['/m/a.mp3', '/m/b.mp3']);
    music.queue.repeatMode = RepeatMode.one;

    await music.next(auto: true);
    await music.next();

    expect(player.opened, ['/m/a.mp3', '/m/a.mp3', '/m/b.mp3']);
  });

  test('engine errors propagate and leave nothing loaded', () async {
    player.failWith = const AudioEngineException('no libmpv');
    await music.setPlaylist(['/m/a.mp3'], autoPlay: false);

    await expectLater(
        music.playOrPause(), throwsA(isA<AudioEngineException>()));
    expect(music.hasLoadedTrack, isFalse);
  });

  test('persists the playlist in plugin storage', () async {
    await music.setPlaylist(['/m/a.mp3', '/m/b.mp3'],
        fromLibrary: '/m', autoPlay: false);

    final restored = MusicService(context, _FakePlayer(), log: (_) {});
    await restored.loadCache();

    expect(restored.playlist, ['/m/a.mp3', '/m/b.mp3']);
    expect(restored.libraryPath, '/m');
    expect(restored.currentTrackPath, isNull);
    expect(context.fs.files.keys, contains('/storage/playlist.json'));
  });

  test('ignores a corrupt cache', () async {
    context.fs.files['/storage/playlist.json'] = 'not json';
    await music.loadCache();
    expect(music.playlist, isEmpty);
  });
}

class _FakePlayer implements BaseAudioPlayer {
  final opened = <String>[];
  var toggles = 0;
  Object? failWith;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> open(String path) async {
    if (failWith case final error?) throw error;
    opened.add(path);
  }

  @override
  Future<void> playOrPause() async => toggles++;

  @override
  Future<void> seek(double progress) async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Stream<Duration> get duration => const Stream.empty();

  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Stream<bool> get completed => const Stream.empty();
}

class _FakeContext implements LumideContext {
  @override
  final _FakeFileSystem fs = _FakeFileSystem();

  @override
  final LumideWorkspace workspace = _FakeWorkspace();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFileSystem implements LumideFileSystem {
  final files = <String, String>{};

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<String> readString(String path) async =>
      files[path] ?? (throw StateError('No such file: $path'));

  @override
  Future<void> writeString(String path, String content) async =>
      files[path] = content;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWorkspace implements LumideWorkspace {
  @override
  Future<String> getPluginStorageDir() async => '/storage';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
