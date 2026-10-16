import 'dart:io';

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_muse/muse_extension.dart';
import 'package:test/test.dart';

void main() {
  final manifest =
      LumideManifest.fromYaml(File('plugin.yaml').readAsStringSync());

  test('plugin.yaml declares exactly the commands the plugin registers',
      () async {
    final context = _RecordingContext();
    final plugin = MuseExtension();
    await plugin.onActivate(context);
    await plugin.onDeactivate();

    expect(
      manifest.commands.map((c) => c.id).toSet(),
      context.commands.registered.keys.toSet(),
    );
    for (final command in manifest.commands) {
      expect(context.commands.registered[command.id], command.title);
    }
  });

  test('keybindings point at declared commands', () {
    final ids = manifest.commands.map((c) => c.id).toSet();
    expect(manifest.keybindings, isNotEmpty);
    for (final binding in manifest.keybindings) {
      expect(ids, contains(binding.command));
      expect(binding.key, isNot(contains(' ')), reason: 'Lumide has no chords');
    }
  });

  test('settings read by the plugin are declared', () {
    expect(
      manifest.configuration.map((c) => c.key),
      containsAll(['muse.libraryPath', 'muse.libmpvPath']),
    );
  });
}

class _RecordingContext implements LumideContext {
  @override
  final _RecordingCommands commands = _RecordingCommands();

  @override
  final LumideStatusBar statusBar = _NoopStatusBar();

  @override
  final LumideWorkspace workspace = _EmptyWorkspace();

  @override
  final LumideFileSystem fs = _EmptyFileSystem();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingCommands implements LumideCommands {
  final registered = <String, String>{};

  @override
  Future<void> registerCommand({
    required String id,
    required String title,
    String? category,
    required Future<void> Function([Map<String, dynamic>? args]) callback,
  }) async {
    registered[id] = title;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopStatusBar implements LumideStatusBar {
  @override
  Future<void> createItem({
    required String id,
    required String text,
    String? tooltip,
    String? command,
    String? color,
    String? iconName,
    String? iconPath,
    String alignment = 'right',
    int priority = 0,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyWorkspace implements LumideWorkspace {
  @override
  Future<Object?> getConfiguration(String section) async => null;

  @override
  Future<String> getPluginStorageDir() async => '/storage';

  @override
  LumideDisposable onDidChangeConfiguration(
    void Function(Map<String, Object?> settings) callback,
  ) =>
      LumideDisposable(() {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFileSystem implements LumideFileSystem {
  @override
  Future<bool> exists(String path) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
