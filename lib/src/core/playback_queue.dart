import 'dart:math';

/// How the queue behaves at the end of a track or of the playlist.
enum RepeatMode {
  off,
  all,
  one;

  /// The mode that follows this one when cycling: off → all → one → off.
  RepeatMode get next => switch (this) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      };

  String get label => switch (this) {
        RepeatMode.off => 'Off',
        RepeatMode.all => 'All',
        RepeatMode.one => 'One',
      };
}

/// Playlist order, shuffle and repeat logic, independent of audio playback.
class PlaybackQueue {
  PlaybackQueue({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<String> _tracks = const [];
  List<int> _order = const [];
  int _currentIndex = -1;
  bool _shuffle = false;

  /// What to do at the end of the playlist and on track completion.
  RepeatMode repeatMode = RepeatMode.all;

  List<String> get tracks => _tracks;
  bool get isEmpty => _tracks.isEmpty;
  bool get shuffle => _shuffle;

  /// Index into [tracks] of the current track, or -1 if none is selected.
  int get currentIndex => _currentIndex;

  String? get current => _currentIndex == -1 ? null : _tracks[_currentIndex];

  /// Replaces the playlist and selects [startIndex] (clamped), or nothing
  /// if [startIndex] is null.
  void setTracks(List<String> tracks, {int? startIndex = 0}) {
    _tracks = List.unmodifiable(tracks);
    _currentIndex = _tracks.isEmpty || startIndex == null
        ? -1
        : startIndex.clamp(0, _tracks.length - 1);
    _rebuildOrder();
  }

  /// Selects the track at [index] in [tracks].
  void select(int index) {
    RangeError.checkValidIndex(index, _tracks);
    _currentIndex = index;
    if (_shuffle) _rebuildOrder();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _rebuildOrder();
  }

  void cycleRepeatMode() => repeatMode = repeatMode.next;

  /// Moves to the next track and returns it, or returns null when playback
  /// should stop.
  ///
  /// [auto] is true when the current track finished on its own; only then
  /// does [RepeatMode.one] replay the same track.
  String? moveNext({bool auto = false}) {
    if (_tracks.isEmpty) return null;
    if (_currentIndex == -1) return _moveTo(_order.first);
    if (auto && repeatMode == RepeatMode.one) return current;

    final position = _order.indexOf(_currentIndex);
    if (position == _order.length - 1) {
      if (repeatMode == RepeatMode.off) return null;
      return _moveTo(_order.first);
    }
    return _moveTo(_order[position + 1]);
  }

  /// Moves to the previous track and returns it, or returns null when there
  /// is none.
  String? movePrevious() {
    if (_tracks.isEmpty) return null;
    if (_currentIndex == -1) return _moveTo(_order.first);

    final position = _order.indexOf(_currentIndex);
    if (position == 0) {
      if (repeatMode == RepeatMode.off) return null;
      return _moveTo(_order.last);
    }
    return _moveTo(_order[position - 1]);
  }

  String _moveTo(int index) {
    _currentIndex = index;
    return _tracks[index];
  }

  /// Rebuilds the play order. When shuffling, the current track goes first
  /// so the rest of the playlist follows it in random order.
  void _rebuildOrder() {
    final order = List<int>.generate(_tracks.length, (i) => i);
    if (_shuffle) {
      order.shuffle(_random);
      if (_currentIndex != -1) {
        order
          ..remove(_currentIndex)
          ..insert(0, _currentIndex);
      }
    }
    _order = order;
  }
}
