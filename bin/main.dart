import 'dart:async';
import 'dart:io';

import 'package:lumide_muse/muse_extension.dart';

/// Stdout carries JSON-RPC, so any `print` (including media_kit's own
/// diagnostics) is redirected to stderr, where Lumide collects plugin logs.
Future<void> main() {
  return runZoned(
    () => MuseExtension().run(),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => stderr.writeln(line),
    ),
  );
}
