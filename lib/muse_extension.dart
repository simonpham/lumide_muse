import 'dart:async';

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_muse/lumide_muse.dart';
import 'package:path/path.dart' as p;

/// Lumide plugin entry point for M.U.S.E.
class MuseExtension extends LumidePlugin {
  static const _controlsItem = 'muse.controls';
  static const _nowPlayingItem = 'muse.nowPlaying';
  static const _scanItem = 'muse.scan';
  static const _idleText = 'M.U.S.E.';

  late final LumideContext _context;
  late final MusicService _music;
  late final DashboardController _dashboard;
  final _subscriptions = <StreamSubscription<Object?>>[];

  bool _showNowPlaying = true;
  bool _scanning = false;

  /// The library folder most recently requested for a scan.
  String? _requestedLibrary;
  LumideDisposable? _configListener;
  String _statusText = _idleText;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _lastDashboardTick = -1;
  bool _activated = false;

  @override
  Future<void> onActivate(LumideContext context) async {
    _context = context;
    _music =
        MusicService(context, MediaKitAudioPlayer(context, log: log), log: log);
    _dashboard = DashboardController(context, _music, log);
    _activated = true;

    await _registerCommands();
    await _createStatusBarItems();
    _listenToPlayer();
    _configListener = context.workspace.onDidChangeConfiguration(
      _onConfigurationChanged,
    );

    await _music.loadCache();
    log('M.U.S.E. activated with ${_music.playlist.length} cached tracks.');

    // Refresh the library in the background if the setting points somewhere
    // other than the cached playlist. The audio engine itself is only loaded
    // when something is played.
    final library = await _configuredLibrary();
    if (library != null &&
        (library != _music.libraryPath || _music.playlist.isEmpty)) {
      unawaited(_scanLibrary(library, silent: true));
    }
  }

  Future<void> _registerCommands() async {
    final commands =
        <String, (String, Future<void> Function([Map<String, dynamic>?]))>{
      'muse.openPlayer': ('Open Player', ([_]) => _openPlayer()),
      'muse.playPause': ('Play/Pause', ([_]) => _run(_music.playOrPause)),
      'muse.next': ('Next Track', ([_]) => _run(_music.next)),
      'muse.previous': ('Previous Track', ([_]) => _run(_music.previous)),
      'muse.toggleShuffle': ('Toggle Shuffle', ([_]) => _toggleShuffle()),
      'muse.cycleRepeat': ('Cycle Repeat Mode', ([_]) => _cycleRepeat()),
      'muse.toggleNowPlaying': (
        'Toggle Lyrics in Status Bar',
        ([_]) => _toggleNowPlaying()
      ),
      'muse.showPlaylist': ('Show Playlist', _showPlaylist),
      'muse.showControls': ('Show Controls', _showControls),
      'muse.scanLibrary': (
        'Scan Music Library',
        ([_]) => _pickAndScanLibrary()
      ),
    };
    for (final MapEntry(key: id, value: (title, callback))
        in commands.entries) {
      await _context.commands.registerCommand(
        id: id,
        title: 'MUSE: $title',
        category: 'MUSE',
        callback: callback,
      );
    }
  }

  Future<void> _createStatusBarItems() async {
    await _context.statusBar.createItem(
      id: _controlsItem,
      text: '',
      iconName: 'play',
      tooltip: 'M.U.S.E. controls',
      command: 'muse.showControls',
      priority: 100,
    );
    await _context.statusBar.createItem(
      id: _nowPlayingItem,
      text: _statusText,
      iconName: 'music',
      tooltip: 'M.U.S.E. playlist',
      command: 'muse.showPlaylist',
      priority: 99,
    );
  }

  void _listenToPlayer() {
    final player = _music.player;
    _subscriptions.addAll([
      player.position.listen(_onPosition),
      player.duration.listen((duration) {
        _duration = duration;
        _updateDashboardProgress();
      }),
      player.playing.listen((isPlaying) {
        _ignore(_context.statusBar
            .updateItem(_controlsItem, iconName: isPlaying ? 'pause' : 'play'));
        _dashboard.updateState(isPlaying: isPlaying);
      }),
      player.completed.listen((completed) {
        if (completed) unawaited(_run(() => _music.next(auto: true)));
      }),
      _music.trackChanged.listen(_onTrackChanged),
    ]);
  }

  void _onTrackChanged(String path) {
    _duration = Duration.zero;
    _position = Duration.zero;
    _dashboard.updateState(
      title: p.basenameWithoutExtension(path),
      subtitle: p.basename(p.dirname(path)),
      lyrics: [
        for (final line in _music.lyricService.lines)
          {'time': line.time.inMilliseconds, 'text': line.text},
      ],
      progress: 0,
      currentMillis: 0,
    );
    _updateNowPlaying();
  }

  void _onPosition(Duration position) {
    _position = position;
    _updateNowPlaying();
    // Position events arrive many times per second; the panel only needs a
    // few of them.
    final tick = position.inMilliseconds ~/ 250;
    if (tick != _lastDashboardTick) {
      _lastDashboardTick = tick;
      _updateDashboardProgress();
    }
  }

  void _updateDashboardProgress() {
    if (!_dashboard.isOpen) return;
    final total = _duration.inMilliseconds;
    _dashboard.updateState(
      progress:
          total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0,
      currentTime: formatDuration(_position),
      totalTime: formatDuration(_duration),
      currentMillis: _position.inMilliseconds,
    );
  }

  /// Shows the current lyric line, or the track title when the track has no
  /// lyrics. Only talks to Lumide when the text changes.
  void _updateNowPlaying() {
    final track = _music.currentTrackPath;
    var text = _idleText;
    if (track != null && _music.hasLoadedTrack) {
      text = _music.lyricService.isEmpty
          ? p.basenameWithoutExtension(track)
          : _music.lyricService.getLineAt(_position);
      if (text.isEmpty) text = '♪';
    }
    if (text == _statusText) return;
    _statusText = text;
    _ignore(_context.statusBar.updateItem(_nowPlayingItem, text: text));
  }

  Future<void> _toggleNowPlaying() async {
    _showNowPlaying = !_showNowPlaying;
    if (_showNowPlaying) {
      await _context.statusBar.show(_nowPlayingItem);
    } else {
      await _context.statusBar.hide(_nowPlayingItem);
    }
  }

  Future<void> _toggleShuffle() async {
    _music.toggleShuffle();
    await _context.window
        .showMessage('Shuffle: ${_music.isShuffle ? 'On' : 'Off'}');
  }

  Future<void> _cycleRepeat() async {
    _music.cycleRepeatMode();
    await _context.window.showMessage('Repeat: ${_music.repeatMode.label}');
  }

  Future<void> _showControls([Map<String, dynamic>? args]) async {
    final items = [
      const QuickPickItem(
          label: 'Play / Pause', icon: 'play', payload: 'playPause'),
      const QuickPickItem(
          label: 'Next Track', icon: 'skip-forward', payload: 'next'),
      const QuickPickItem(
          label: 'Previous Track', icon: 'skip-back', payload: 'previous'),
      const QuickPickItem(label: '', isSeparator: true),
      QuickPickItem(
          label: 'Shuffle: ${_music.isShuffle ? 'On' : 'Off'}',
          icon: 'shuffle',
          payload: 'shuffle'),
      QuickPickItem(
          label: 'Repeat: ${_music.repeatMode.label}',
          icon: 'repeat',
          payload: 'repeat'),
      const QuickPickItem(label: '', isSeparator: true),
      const QuickPickItem(
          label: 'Open Player', icon: 'layout-dashboard', payload: 'open'),
      const QuickPickItem(
          label: 'Scan Music Library', icon: 'folder-search', payload: 'scan'),
    ];

    final selected = await _context.window.showQuickPick(
      items,
      placeholder: 'M.U.S.E. Controls',
      position: _clickPosition(args),
    );
    switch (selected?.payload) {
      case 'playPause':
        await _run(_music.playOrPause);
      case 'next':
        await _run(_music.next);
      case 'previous':
        await _run(_music.previous);
      case 'shuffle':
        _music.toggleShuffle();
      case 'repeat':
        _music.cycleRepeatMode();
      case 'open':
        await _openPlayer();
      case 'scan':
        await _pickAndScanLibrary();
    }
  }

  Future<void> _showPlaylist([Map<String, dynamic>? args]) async {
    final playlist = _music.playlist;
    if (playlist.isEmpty) {
      await _context.window.showMessage(
          'The playlist is empty. Run "MUSE: Scan Music Library" to load your music.');
      return;
    }

    final current = _music.hasLoadedTrack ? _music.currentIndex : -1;
    final items = [
      for (final (index, path) in playlist.indexed)
        QuickPickItem(
          label: p.basenameWithoutExtension(path),
          description: index == current ? 'Now playing' : null,
          detail: path,
          icon: index == current ? 'music' : null,
          payload: index,
        ),
    ];

    final selected = await _context.window.showQuickPick(
      items,
      placeholder: 'Playlist (${playlist.length} tracks)',
      position: _clickPosition(args),
    );
    if (selected?.payload case final int index) {
      await _run(() => _music.playAt(index));
    }
  }

  Future<void> _openPlayer() async {
    await _dashboard.show();
    _updateDashboardProgress();
    if (_music.playlist.isEmpty) {
      await _context.window.showMessage(
          'M.U.S.E. is ready. Run "MUSE: Scan Music Library" to load your music.');
    }
  }

  Future<String?> _configuredLibrary() async {
    final value = await _context.workspace.getConfiguration('muse.libraryPath');
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  /// Rescans when `muse.libraryPath` is changed in Settings.
  void _onConfigurationChanged(Map<String, Object?> settings) {
    final value = settings['muse.libraryPath'];
    if (value is! String || value.trim().isEmpty) return;
    final library = value.trim();
    if (library == _requestedLibrary) return;
    unawaited(_scanLibrary(library, silent: true));
  }

  /// Scans the configured library, asking for a folder (and saving it to
  /// `muse.libraryPath`) if none is set.
  Future<void> _pickAndScanLibrary() async {
    var library = await _configuredLibrary();
    if (library == null) {
      library = await _context.window
          .showOpenFolderDialog(title: 'Choose your music folder');
      if (library == null || library.isEmpty) return;
      _requestedLibrary = library;
      await _context.workspace.updateConfiguration('muse.libraryPath', library);
    }
    await _scanLibrary(library, silent: false);
  }

  Future<void> _scanLibrary(String library, {required bool silent}) async {
    if (_scanning) return;
    _scanning = true;
    _requestedLibrary = library;
    try {
      if (!await _context.fs.isDirectory(library)) {
        if (!silent) {
          await _context.window.showMessage('Music folder not found: $library',
              type: MessageType.error);
        }
        return;
      }

      await _context.statusBar.createItem(
        id: _scanItem,
        text: 'Scanning music…',
        iconName: 'folder-search',
        tooltip: 'M.U.S.E. is scanning $library',
        priority: 98,
      );

      final tracks = await scanAudioFiles(
        library,
        list: _context.fs.list,
        isDirectory: _context.fs.isDirectory,
        onProgress: (checked) => _ignore(
          _context.statusBar
              .updateItem(_scanItem, text: 'Scanning music… $checked files'),
        ),
      );

      if (tracks.isEmpty) {
        if (!silent) {
          await _context.window.showMessage('No audio files found in $library');
        }
        return;
      }

      await _music.setPlaylist(tracks, fromLibrary: library, autoPlay: false);
      if (!silent) {
        await _context.window.showMessage('Found ${tracks.length} tracks.');
        await _dashboard.show();
        await _run(() => _music.playAt(0));
      }
    } catch (e) {
      log('[MUSE] Scan failed: $e');
      if (!silent) {
        await _context.window.showMessage(
          'Could not scan $library: $e',
          type: MessageType.error,
        );
      }
    } finally {
      _scanning = false;
      _ignore(_context.statusBar.disposeItem(_scanItem));
    }
  }

  /// Runs a playback action and reports engine problems to the user.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on AudioEngineException catch (e) {
      await _context.window.showMessage(e.message, type: MessageType.error);
    } catch (e) {
      log('[MUSE] Playback failed: $e');
      await _context.window.showMessage(
          'M.U.S.E. could not play this track: $e',
          type: MessageType.error);
    }
  }

  Map<String, int>? _clickPosition(Map<String, dynamic>? args) {
    final position = args?['position'];
    if (position is Map && position['x'] is num && position['y'] is num) {
      return {
        'x': (position['x'] as num).toInt(),
        'y': (position['y'] as num).toInt()
      };
    }
    return null;
  }

  void _ignore(Future<void> future) {
    unawaited(future.catchError((Object e) => log('[MUSE] $e')));
  }

  @override
  Future<void> onDeactivate() async {
    if (!_activated) return;
    _configListener?.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _dashboard.dispose();
    await _music.dispose();
    log('M.U.S.E. deactivated');
  }
}
