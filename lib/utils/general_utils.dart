import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../main.dart';
import 'os_utils.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: this));
  }

  void revealFile() {
    switch (Platform.operatingSystem) {
      case OS.windows: Process.run('explorer', ['/select,', this]);
      case OS.macos: Process.run('open', ['-R', this]);
      case OS.linux: Process.run('xdg-open', [Directory(this).parent.path]);
    }
  }

  Future<void> browseFolder() async {
    final dir = Directory(this);
    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $this');
    }

    switch (Platform.operatingSystem) {
      case OS.windows: await Process.start('explorer', [dir.path]);
      case OS.macos: await Process.start('open', [dir.path]);

      case OS.linux: {
        var fileManager = await Process.run("xdg-mime", ["query", "default", "inode/directory"]);
        switch (fileManager.stdout.toString()) {
          case FileManager.kdeDolphin:
            await Process.run('dolphin', ['--select', dir.path]);

          case FileManager.gnomeNautilus:
            await Process.run('nautilus', ['--select', dir.path]);

          case FileManager.xfceThunar:
            await Process.run('thunar', [dir.path]);

          case FileManager.cinnamonNemo:
            await Process.run('nemo', ['--no-desktop', dir.path]);

          case FileManager.lxqtPcmanfm:
            await Process.run('pcmanfm-qt', ['--select', dir.path]);

          case FileManager.mateCaja:
            await Process.run('caja', ['--select', dir.path]);

          default:
          // Fallback: open parent directory
            await Process.run('xdg-open', [File(dir.path).parent.path]);
        }
      }
      default: throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    return;
  }
}

Future<bool> findAndCopyFile({
  required Directory searchDir,
  required String fileName,
  required Directory destinationDir,
}) async {
  await for (final entity in searchDir.list(recursive: true)) {
    if (entity is File && p.basename(entity.path) == fileName) {
        logger.log('Copying $fileName to ${destinationDir.path} from ${entity.path}');
      await destinationDir.create(recursive: true);
      await entity.copy(p.join(destinationDir.path, fileName));
      return true;
    }
  }
  return false;
}