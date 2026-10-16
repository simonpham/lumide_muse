import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_muse/src/core/music_service.dart';
import 'package:path/path.dart' as p;

/// Shows the player panel (a webview built from `web/dashboard`) and keeps
/// it in sync with playback.
class DashboardController {
  DashboardController(
    this._context,
    this._musicService,
    this._log, {
    String? assetsDir,
  }) : _assetsDir =
            assetsDir ?? p.join(Directory.current.path, 'web', 'dashboard');

  static const _styles = [
    'theme.css',
    'layout.css',
    'lyrics.css',
    'controls.css',
    'adaptive.css'
  ];
  static const _scripts = ['bridge.js', 'lyrics.js', 'playback.js', 'main.js'];

  final LumideContext _context;
  final MusicService _musicService;
  final void Function(String) _log;

  /// Lumide starts plugins in their package directory, which ships `web/`.
  final String _assetsDir;

  LumideWebviewPanel? _panel;
  LumideDisposable? _messageListener;
  String? _html;

  final Map<String, Object?> _state = {
    'title': 'No Track Playing',
    'subtitle': 'Run "MUSE: Scan Music Library" to load your music',
    'isPlaying': false,
    'progress': 0.0,
    'currentTime': '0:00',
    'totalTime': '0:00',
    'lyrics': const <Object>[],
    'currentMillis': 0,
  };

  bool get isOpen => _panel != null;

  /// Opens the player panel, replacing an existing one so it comes to front.
  Future<void> show() async {
    await _closePanel();
    try {
      final panel = await _context.window.createWebviewPanel(
        'muse.dashboard',
        'M.U.S.E. Player',
        options: {'html': await _loadHtml(), 'enableScripts': true},
      );
      _panel = panel;
      _messageListener = panel.onDidReceiveMessage(_handleMessage);
    } catch (e) {
      _log('[DashboardController] Could not open the player panel: $e');
      await _context.window.showMessage(
        'Could not open the M.U.S.E. player: $e',
        type: MessageType.error,
      );
    }
  }

  /// Inlines the dashboard's CSS and JS into `index.html`.
  ///
  /// These are the plugin's own bundled files, so they are read directly
  /// rather than through the permission-checked workspace file system.
  Future<String> _loadHtml() async {
    if (_html case final html?) return html;

    var html = await File(p.join(_assetsDir, 'index.html')).readAsString();
    for (final file in _styles) {
      final css = await File(p.join(_assetsDir, 'styles', file)).readAsString();
      html = html.replaceFirst(
        '<link rel="stylesheet" href="styles/$file">',
        '<style>/* $file */\n$css</style>',
      );
    }
    for (final file in _scripts) {
      final js = await File(p.join(_assetsDir, 'scripts', file)).readAsString();
      html = html.replaceFirst(
        '<script src="scripts/$file"></script>',
        '<script>/* $file */\n$js</script>',
      );
    }
    return _html = html;
  }

  void _handleMessage(Object message) {
    Object? data = message;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        return;
      }
    }
    if (data is! Map) return;

    if (data['lumideEvent'] == 'webviewDisposed') {
      _messageListener?.dispose();
      _messageListener = null;
      _panel = null;
      return;
    }

    switch (data['command']) {
      case 'ready':
        _sendState();
      case 'playPause':
        _guard(_musicService.playOrPause());
      case 'next':
        _guard(_musicService.next());
      case 'previous':
        _guard(_musicService.previous());
      case 'seek':
        final progress = data['value'];
        if (progress is num) _guard(_musicService.seek(progress.toDouble()));
    }
  }

  void _guard(Future<void> action) {
    unawaited(
        action.catchError((Object e) => _log('[DashboardController] $e')));
  }

  /// Merges the given fields into the player state and sends only those
  /// fields to the panel. The panel gets the full state when it loads.
  void updateState({
    String? title,
    String? subtitle,
    bool? isPlaying,
    double? progress,
    String? currentTime,
    String? totalTime,
    List<Map<String, Object>>? lyrics,
    int? currentMillis,
  }) {
    final patch = <String, Object?>{
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (isPlaying != null) 'isPlaying': isPlaying,
      if (progress != null) 'progress': progress,
      if (currentTime != null) 'currentTime': currentTime,
      if (totalTime != null) 'totalTime': totalTime,
      if (lyrics != null) 'lyrics': lyrics,
      if (currentMillis != null) 'currentMillis': currentMillis,
    };
    if (patch.isEmpty) return;
    _state.addAll(patch);
    _sendState(patch);
  }

  void _sendState([Map<String, Object?>? state]) {
    final panel = _panel;
    if (panel == null) return;
    // Lumide JSON-encodes the string again when handing it to the page,
    // which JSON.parse()s it, so no extra escaping is needed here.
    final message =
        jsonEncode({'type': 'updateState', 'state': state ?? _state});
    _guard(panel.postMessage(message));
  }

  Future<void> _closePanel() async {
    final panel = _panel;
    _messageListener?.dispose();
    _messageListener = null;
    _panel = null;
    if (panel == null) return;
    try {
      await panel.dispose();
    } catch (_) {
      // Already closed by the user.
    }
  }

  Future<void> dispose() => _closePanel();
}
