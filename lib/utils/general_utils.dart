import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

Future<void> browseFolder(String? path) async {
  final dir = Directory(path!);
  if (!await dir.exists()) {
    throw Exception('Directory does not exist: $path');
  }

  if (Platform.isWindows) {
    await Process.start('explorer', [dir.path]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [dir.path]);
  } else if (Platform.isLinux) {
    await Process.start('xdg-open', [dir.path]);
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
  return;
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: this));
  }

  void revealFile() {
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', this]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', this]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [Directory(this).parent.path]);
    }
  }
}

Future<bool> findAndCopyFile({
  required Directory searchDir,
  required String fileName,
  required Directory destinationDir,
}) async {
  await for (final entity in searchDir.list(recursive: true)) {
    if (entity is File && p.basename(entity.path) == fileName) {
      if (kDebugMode) {
        print('Copying $fileName to ${destinationDir.path} from ${entity.path}');
      }
      await destinationDir.create(recursive: true);
      await entity.copy(p.join(destinationDir.path, fileName));
      return true;
    }
  }
  return false;
}