import 'package:lumide_muse/src/core/lyric_service.dart';
import 'package:test/test.dart';

void main() {
  late LyricService lyrics;

  setUp(() => lyrics = LyricService());

  test('parses timestamps with centiseconds and milliseconds', () {
    lyrics.parseLrc('[00:01.29]one\n[00:02.500]two\n[01:03]three');

    expect(lyrics.lines, const [
      LyricLine(Duration(seconds: 1, milliseconds: 290), 'one'),
      LyricLine(Duration(seconds: 2, milliseconds: 500), 'two'),
      LyricLine(Duration(minutes: 1, seconds: 3), 'three'),
    ]);
  });

  test('handles CRLF, metadata tags and repeated stamps', () {
    lyrics.parseLrc(
      '[ar:Artist]\r\n[ti:Title]\r\n[00:10.00][00:30.00]Chorus\r\n[00:20.00]Verse\r\n',
    );

    expect(lyrics.lines.map((l) => l.text), ['Chorus', 'Verse', 'Chorus']);
    expect(lyrics.lines.first.time, const Duration(seconds: 10));
  });

  test('sorts lines that are out of order', () {
    lyrics.parseLrc('[00:05.00]b\n[00:01.00]a');

    expect(lyrics.lines.map((l) => l.text), ['a', 'b']);
  });

  test('applies the offset tag', () {
    lyrics.parseLrc('[offset:+500]\n[00:01.00]early\n[00:00.20]clamped');

    expect(lyrics.lines.map((l) => l.time), const [
      Duration.zero,
      Duration(milliseconds: 500),
    ]);
  });

  test('finds the active line for a position', () {
    lyrics.parseLrc('[00:01.00]one\n[00:03.00]two\n[00:05.00]');

    expect(lyrics.getLineAt(Duration.zero), '');
    expect(lyrics.indexAt(Duration.zero), -1);
    expect(lyrics.getLineAt(const Duration(seconds: 1)), 'one');
    expect(lyrics.getLineAt(const Duration(milliseconds: 2999)), 'one');
    expect(lyrics.getLineAt(const Duration(seconds: 4)), 'two');
    expect(lyrics.getLineAt(const Duration(seconds: 9)), '');
  });

  test('clear and re-parse replace previous lyrics', () {
    lyrics.parseLrc('[00:01.00]old');
    lyrics.parseLrc('[00:02.00]new');
    expect(lyrics.lines.single.text, 'new');

    lyrics.clear();
    expect(lyrics.isEmpty, isTrue);
    expect(lyrics.getLineAt(const Duration(seconds: 5)), '');
  });
}
