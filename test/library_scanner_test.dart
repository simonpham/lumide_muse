import 'package:lumide_muse/src/core/library_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('scanAudioFiles', () {
    final tree = <String, List<String>>{
      '/music': [
        '/music/b.MP3',
        '/music/Album',
        '/music/.hidden',
        '/music/cover.jpg'
      ],
      '/music/Album': [
        '/music/Album/a.flac',
        '/music/Album/a.lrc',
        '/music/Album/Disc 2'
      ],
      '/music/Album/Disc 2': ['/music/Album/Disc 2/c.opus'],
      '/music/.hidden': ['/music/.hidden/secret.mp3'],
    };

    test('finds audio files recursively, sorted, skipping hidden entries',
        () async {
      final directoryChecks = <String>[];
      final tracks = await scanAudioFiles(
        '/music',
        list: (path) async => tree[path] ?? const [],
        isDirectory: (path) async {
          directoryChecks.add(path);
          return tree.containsKey(path);
        },
      );

      expect(tracks, [
        '/music/Album/a.flac',
        '/music/Album/Disc 2/c.opus',
        '/music/b.MP3',
      ]);
      expect(directoryChecks, isNot(contains('/music/b.MP3')));
      expect(directoryChecks, isNot(contains('/music/.hidden')));
    });

    test('stops at maxDepth', () async {
      final tracks = await scanAudioFiles(
        '/music',
        list: (path) async => tree[path] ?? const [],
        isDirectory: (path) async => tree.containsKey(path),
        maxDepth: 0,
      );

      expect(tracks, ['/music/b.MP3']);
    });
  });

  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
