import 'package:lumide_muse/src/core/music_service.dart';
import 'package:path/path.dart' as p;

/// Recursively finds audio files under [root], sorted by path.
///
/// [list] and [isDirectory] are injected so the scan goes through Lumide's
/// permission-checked file system. Hidden entries are skipped, and entries
/// with an audio extension are assumed to be files, which saves a round trip
/// per track. [onProgress] is called every 50 entries.
Future<List<String>> scanAudioFiles(
  String root, {
  required Future<List<String>> Function(String path) list,
  required Future<bool> Function(String path) isDirectory,
  void Function(int checked)? onProgress,
  int maxDepth = 32,
}) async {
  final found = <String>[];
  var checked = 0;

  Future<void> visit(String dir, int depth) async {
    for (final entry in await list(dir)) {
      if (p.basename(entry).startsWith('.')) continue;
      checked++;
      if (onProgress != null && checked % 50 == 0) onProgress(checked);

      if (isAudioFile(entry)) {
        found.add(entry);
      } else if (depth < maxDepth && await isDirectory(entry)) {
        await visit(entry, depth + 1);
      }
    }
  }

  await visit(root, 0);
  found.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return found;
}

/// Formats [duration] as `m:ss`, or `h:mm:ss` from one hour up.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  return '$minutes:$seconds';
}
