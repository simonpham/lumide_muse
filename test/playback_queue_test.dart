import 'dart:math';

import 'package:lumide_muse/src/core/playback_queue.dart';
import 'package:test/test.dart';

void main() {
  const tracks = ['a.mp3', 'b.mp3', 'c.mp3'];

  group('in order', () {
    late PlaybackQueue queue;

    setUp(() => queue = PlaybackQueue()..setTracks(tracks));

    test('starts at the requested index', () {
      queue.setTracks(tracks, startIndex: 5);
      expect(queue.current, 'c.mp3');

      queue.setTracks(tracks, startIndex: null);
      expect(queue.current, isNull);
      expect(queue.moveNext(), 'a.mp3');
    });

    test('wraps around with repeat all', () {
      queue.repeatMode = RepeatMode.all;
      expect([queue.moveNext(), queue.moveNext(), queue.moveNext()],
          ['b.mp3', 'c.mp3', 'a.mp3']);
      expect(queue.movePrevious(), 'c.mp3');
    });

    test('stops at the ends with repeat off', () {
      queue.repeatMode = RepeatMode.off;
      expect(queue.movePrevious(), isNull);
      expect(queue.current, 'a.mp3');

      queue.select(2);
      expect(queue.moveNext(), isNull);
      expect(queue.current, 'c.mp3');
    });

    test('repeat one replays only when a track finishes', () {
      queue.repeatMode = RepeatMode.one;
      expect(queue.moveNext(auto: true), 'a.mp3');
      expect(queue.moveNext(), 'b.mp3');
    });

    test('cycles repeat modes', () {
      queue.repeatMode = RepeatMode.off;
      queue.cycleRepeatMode();
      expect(queue.repeatMode, RepeatMode.all);
      queue.cycleRepeatMode();
      expect(queue.repeatMode, RepeatMode.one);
      queue.cycleRepeatMode();
      expect(queue.repeatMode, RepeatMode.off);
    });

    test('empty playlist has nothing to play', () {
      queue.setTracks(const []);
      expect(queue.current, isNull);
      expect(queue.moveNext(), isNull);
      expect(queue.movePrevious(), isNull);
    });
  });

  group('shuffle', () {
    final many = [for (var i = 0; i < 20; i++) 'track$i.mp3'];

    test('visits every track once per cycle, starting after the current', () {
      final queue = PlaybackQueue(random: Random(1))
        ..setTracks(many, startIndex: 7)
        ..toggleShuffle();

      final visited = <String>{queue.current!};
      for (var i = 0; i < many.length - 1; i++) {
        visited.add(queue.moveNext()!);
      }
      expect(visited, many.toSet());
      expect(queue.moveNext(), 'track7.mp3');
    });

    test('previous walks back through the shuffled order', () {
      final queue = PlaybackQueue(random: Random(2))
        ..setTracks(many)
        ..toggleShuffle();
      final first = queue.current;
      final second = queue.moveNext();
      queue.moveNext();

      expect(queue.movePrevious(), second);
      expect(queue.movePrevious(), first);
    });

    test('replacing the playlist while shuffling stays in range', () {
      final queue = PlaybackQueue(random: Random(3))
        ..setTracks(many)
        ..toggleShuffle()
        ..setTracks(tracks);

      final seen = <String>{queue.current!};
      for (var i = 0; i < 5; i++) {
        seen.add(queue.moveNext()!);
      }
      expect(seen, tracks.toSet());
    });

    test('turning shuffle off restores playlist order', () {
      final queue = PlaybackQueue(random: Random(4))
        ..setTracks(many)
        ..toggleShuffle()
        ..select(3)
        ..toggleShuffle();

      expect(queue.moveNext(), 'track4.mp3');
    });
  });
}
