import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

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

extension ListExtension on List {
  List append(dynamic value) {
    insert(length, value);
    return this;
  }

  List prepend(dynamic value) {
    insert(0, value);
    return this;
  }
}

extension UriExtension on Uri {
  Future<void> openInBrowser() async {
    if (!await launchUrl(this, mode: LaunchMode.externalApplication,)) {
      throw Exception('Could not launch $this');
    }
  }
}

Future<String?> getUsername(String? apiKey) async {
  if (apiKey == null) return null;
  final response = await http.get(
    Uri.parse('https://api.itch.io/profile'),
    headers: {
      'Authorization': 'Bearer $apiKey',
    },
  );

  if (response.statusCode != 200) {
    return null;
  }

  final json = jsonDecode(response.body);
  return json['user']['username'] as String;
}

Future<void> createSymlink(BuildContext context, String target, String linkPath) async {
  final link = Link(linkPath);

  if (await link.exists()) return;

  try {
    await link.create(target);
  } on FileSystemException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Skins require admin rights, the program will restart now")),
    );
    sleep(Duration(seconds: 3));
    await elevate();
    exit(0);
  } catch (e) {
    logger.log("Failed to create symlink: $e");
  }
}

Future<void> elevate() async {
  final exe = Platform.resolvedExecutable;

  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-Command',
      '''
      Start-Process -FilePath "$exe" -Verb RunAs
      ''',
    ],
  );

  if (result.exitCode != 0) {
    throw Exception('Failed to request administrator privileges');
  }
}