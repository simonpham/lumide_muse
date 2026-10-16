import 'dart:async';
import 'dart:convert';

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_muse/src/core/audio_player.dart';
import 'package:lumide_muse/src/core/lyric_service.dart';
import 'package:lumide_muse/src/core/playback_queue.dart';
import 'package:path/path.dart' as p;

/// File extensions treated as playable audio.
const audioExtensions = {
  '.mp3',
  '.wav',
  '.flac',
  '.m4a',
  '.aac',
  '.ogg',
  '.opus'
};

bool isAudioFile(String path) =>
    audioExtensions.contains(p.extension(path).toLowerCase());

/// Ties the playback queue, the audio engine and lyrics together.
class MusicService {
  MusicService(
    this._context,
    this.player, {
    required void Function(String) log,
    PlaybackQueue? queue,
  })  : _log = log,
        queue = queue ?? PlaybackQueue();

  final LumideContext _context;
  final BaseAudioPlayer player;
  final PlaybackQueue queue;
  final LyricService lyricService = LyricService();
  final void Function(String) _log;

  final _trackChanged = StreamController<String>.broadcast();

  /// The library folder the cached playlist was scanned from.
  String? libraryPath;

  /// Emits the path of each track as it starts.
  Stream<String> get trackChanged => _trackChanged.stream;

  List<String> get playlist => queue.tracks;
  int get currentIndex => queue.currentIndex;
  String? get currentTrackPath => queue.current;
  bool get isShuffle => queue.shuffle;
  RepeatMode get repeatMode => queue.repeatMode;

  bool _loaded = false;

  /// Whether the current track has been handed to the engine.
  bool get hasLoadedTrack => _loaded;

  void toggleShuffle() => queue.toggleShuffle();

  void cycleRepeatMode() => queue.cycleRepeatMode();

  Future<String> _cacheFile() async =>
      p.join(await _context.workspace.getPluginStorageDir(), 'playlist.json');

  /// Restores the last scanned playlist without starting playback.
  Future<void> loadCache() async {
    try {
      final path = await _cacheFile();
      if (!await _context.fs.exists(path)) return;
      final data = jsonDecode(await _context.fs.readString(path));
      if (data is! Map) return;
      libraryPath = data['libraryPath'] as String?;
      final tracks = (data['tracks'] as List?)?.whereType<String>().toList() ??
          const <String>[];
      queue.setTracks(tracks, startIndex: null);
      _log('[MusicService] Loaded ${tracks.length} tracks from cache.');
    } catch (e) {
      _log('[MusicService] Failed to load cache: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      await _context.fs.writeString(
        await _cacheFile(),
        jsonEncode({'libraryPath': libraryPath, 'tracks': queue.tracks}),
      );
    } catch (e) {
      _log('[MusicService] Failed to save cache: $e');
    }
  }

  /// Replaces the playlist with [paths] scanned from [fromLibrary].
  Future<void> setPlaylist(
    List<String> paths, {
    String? fromLibrary,
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    libraryPath = fromLibrary ?? libraryPath;
    queue.setTracks(paths, startIndex: autoPlay ? startIndex : null);
    _loaded = false;
    await _saveCache();
    if (!autoPlay) return;
    if (queue.current case final track?) await _play(track);
  }

  /// Plays the track at [index] in [playlist].
  Future<void> playAt(int index) async {
    queue.select(index);
    if (queue.current case final track?) await _play(track);
  }

  Future<void> playOrPause() async {
    if (!_loaded) {
      final track = queue.current ?? queue.moveNext();
      if (track != null) await _play(track);
      return;
    }
    await player.playOrPause();
  }

  Future<void> next({bool auto = false}) async {
    final track = queue.moveNext(auto: auto);
    if (track != null) await _play(track);
  }

  Future<void> previous() async {
    final track = queue.movePrevious();
    if (track != null) await _play(track);
  }

  Future<void> seek(double progress) => player.seek(progress);

  Future<void> _play(String path) async {
    await _loadLyrics(path);
    await player.open(path);
    _loaded = true;
    _trackChanged.add(path);
  }

  /// Loads `<track>.lrc` from next to the track, if there is one.
  Future<void> _loadLyrics(String trackPath) async {
    lyricService.clear();
    final lrcPath = p.setExtension(trackPath, '.lrc');
    try {
      if (await _context.fs.exists(lrcPath)) {
        lyricService.parseLrc(await _context.fs.readString(lrcPath));
      }
    } catch (e) {
      _log('[MusicService] Failed to read $lrcPath: $e');
    }
  }

  Future<void> dispose() async {
    await player.dispose();
    await _trackChanged.close();
  }
}
