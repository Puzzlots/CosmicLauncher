import 'dart:io';

import 'package:flutter/services.dart';

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

void revealFile(String filePath) {
  if (Platform.isWindows) {
    // explorer /select,"C:\path\to\file.txt"
    Process.run('explorer', ['/select,', filePath]);
  } else if (Platform.isMacOS) {
    // open Finder and select the file
    Process.run('open', ['-R', filePath]);
  } else if (Platform.isLinux) {
    // use xdg-open to open the folder (cannot reliably highlight)
    Process.run('xdg-open', [Directory(filePath).parent.path]);
  }
}

Future<void> copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}