/// A single timed line of an `.lrc` file.
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LyricLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => 'LyricLine($time, $text)';
}

/// Parses `.lrc` lyrics and looks up the line for a playback position.
class LyricService {
  static final _timestamp =
      RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final _offsetTag =
      RegExp(r'^\s*\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

  List<LyricLine> _lines = const [];

  /// The parsed lines, sorted by time.
  List<LyricLine> get lines => _lines;

  bool get isEmpty => _lines.isEmpty;

  /// Parses [lrcContent], replacing any previously loaded lyrics.
  ///
  /// Supports `[mm:ss]`, `[mm:ss.x]`, `[mm:ss.xx]` and `[mm:ss.xxx]` stamps,
  /// several stamps on one line, and the `[offset:±ms]` tag. Metadata tags
  /// such as `[ar:...]` are ignored.
  void parseLrc(String lrcContent) {
    final byTime = <Duration, String>{};
    var offset = Duration.zero;

    for (final rawLine in lrcContent.split(RegExp(r'\r?\n'))) {
      final offsetMatch = _offsetTag.firstMatch(rawLine);
      if (offsetMatch != null) {
        // A positive offset shows lyrics sooner.
        offset = Duration(milliseconds: -int.parse(offsetMatch.group(1)!));
        continue;
      }

      final matches = _timestamp.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;

      final text = rawLine.substring(matches.last.end).trim();
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fraction = match.group(3);
        final millis =
            fraction == null ? 0 : int.parse(fraction.padRight(3, '0'));
        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        byTime[time] = text;
      }
    }

    final sorted = byTime.keys.toList()..sort();
    _lines = List.unmodifiable([
      for (final time in sorted)
        LyricLine(
          time + offset < Duration.zero ? Duration.zero : time + offset,
          byTime[time]!,
        ),
    ]);
  }

  /// Index of the line that is active at [position], or -1 if none is.
  int indexAt(Duration position) {
    var low = 0;
    var high = _lines.length - 1;
    var best = -1;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      if (_lines[mid].time <= position) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  /// Text of the line that is active at [position], or an empty string.
  String getLineAt(Duration position) {
    final index = indexAt(position);
    return index == -1 ? '' : _lines[index].text;
  }

  void clear() {
    _lines = const [];
  }
}
