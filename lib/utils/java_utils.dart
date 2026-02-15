import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'cache_utils.dart';

Future<List<Map<String, String>>> detectJavaInstallations() async {
  final javaPaths = <String>{};

  // 1. JAVA_HOME
  final javaHome = Platform.environment['JAVA_HOME'];
  if (javaHome != null && await Directory(javaHome).exists()) {
    javaPaths.add(javaHome);
  }

  // 2. OS-specific detection
  if (Platform.isWindows) {
    try {
      final regResult = await Process.run(
        'reg',
        ['query', r'HKLM\SOFTWARE\JavaSoft\Java Development Kit', '/s'],
      );

      if (regResult.exitCode == 0) {
        final output = regResult.stdout.toString();
        final regex = RegExp(r'JavaHome\s+REG_SZ\s+(.+)', multiLine: true);
        for (final match in regex.allMatches(output)) {
          final path = match.group(1);
          if (path != null && await Directory(path).exists()) {
            javaPaths.add(path);
          }
        }
      }
    } catch (_) {}
  } else if (Platform.isLinux) {
    try {
      final result = await Process.run('update-alternatives', ['--list', 'java']);
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split('\n')) {
          final path = line.trim();
          if (path.isNotEmpty) {
            javaPaths.add(Directory(path).parent.parent.path);
          }
        }
      }
    } catch (_) {}
  } else if (Platform.isMacOS) {
    try {
      final result = await Process.run('/usr/libexec/java_home', ['-V']);
      if (result.exitCode == 0) {
        final lines = result.stderr.toString().split('\n');
        for (final line in lines) {
          final match = RegExp(r'(/.*?)/Contents/Home').firstMatch(line);
          if (match != null) javaPaths.add('${match.group(1)!}/Contents/Home');
        }
      }
    } catch (_) {}
  }

  // 3. Fallback: standard directories
  final standardDirs = <String>[];
  if (Platform.isWindows) {
    standardDirs.addAll([
      'C:\\Program Files\\Java',
      'C:\\Program Files (x86)\\Java',
    ]);
  } else if (Platform.isLinux) {
    standardDirs.addAll(['/usr/lib/jvm', '/usr/java']);
  } else if (Platform.isMacOS) {
    standardDirs.add('/Library/Java/JavaVirtualMachines');
  }

  standardDirs.add("${getPersistentCacheDir().path}/java");

  for (final path in standardDirs) {
    final dir = Directory(path);
    if (await dir.exists()) {
      for (final sub in dir.listSync()) {
        if (sub is Directory) javaPaths.add(sub.path);
      }
    }
  }

  // 4. Get version names
  final javaList = <Map<String, String>>[];
  for (final path in javaPaths) {
    String javaExecutable = path;
    if (Platform.isWindows) {
      javaExecutable = '$path\\bin\\java.exe';
    } else {
      javaExecutable = '$path/bin/java';
    }

    if (!File(javaExecutable).existsSync()) continue;

    try {
      final result = await Process.run(javaExecutable, ['-version']);
      String versionLine = result.stderr.toString().split('\n').first;
      final match = RegExp(r'version\s+"([\d._]+)"').firstMatch(versionLine);
      if (match != null) {
        javaList.add({
          'name': 'Java ${match.group(1)}',
          'path': path,
        });
      }
    } catch (_) {}
  }

  return javaList;
}

class JavaTesterButton extends StatefulWidget {
  final Map<String, String> java;
  const JavaTesterButton({super.key, required this.java});

  @override
  State<JavaTesterButton> createState() => _JavaTesterButtonState();
}

enum JavaStatus {
  idle,
  testing,
  working,
  broken,
  error
}

class _JavaTesterButtonState extends State<JavaTesterButton> {
  JavaStatus _status = JavaStatus.idle;

  Future<void> _testJar(Map<String, String> java) async {
    setState(() => _status = JavaStatus.testing);

    try {
      final javaPath = _resolveJavaExecutable(java['path'] ?? '');
      if (javaPath == null) {
        setState(() => _status = JavaStatus.broken);
        return;
      }

      // Ensure the file exists and is executable
      final file = File(javaPath);
      if (!file.existsSync()) {
        setState(() => _status = JavaStatus.broken);
        return;
      }

      // Run java -version directly, without inheriting PATH fallback
      final result = await Process.run(javaPath, ['-version'],
        runInShell: false,
        workingDirectory: Directory(javaPath).parent.path,
      ).timeout(const Duration(seconds: 5));

      final stderrStr = result.stderr.toString().trim();
      final stdoutStr = result.stdout.toString().trim();

      // A valid java should always print version info to stderr
      if (result.exitCode == 0 &&
          (stderrStr.contains('version') || stdoutStr.contains('version'))) {
        setState(() => _status = JavaStatus.working);
      } else {
        setState(() => _status = JavaStatus.broken);
      }
    } on ProcessException {
      setState(() => _status = JavaStatus.broken);
    } on TimeoutException {
      setState(() => _status = JavaStatus.error);
    } catch (_) {
      setState(() => _status = JavaStatus.error);
    }
  }

  String? _resolveJavaExecutable(String basePath) {
    final execName = Platform.isWindows ? 'java.exe' : 'java';
    final file = File(basePath);

    if (file.existsSync()) {
      // Directly provided full path to java binary
      return file.path;
    }

    final dir = Directory(basePath);
    if (!dir.existsSync()) return null;

    // Typical Java structures
    final candidates = [
      File('${dir.path}/bin/$execName'),
      File('${dir.path}/$execName'),
    ];

    for (final f in candidates) {
      if (f.existsSync()) return f.path;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;

    switch (_status) {
      case JavaStatus.testing:
        icon = Icons.hourglass_bottom;
        label = 'Testing...';
      case JavaStatus.working:
        icon = Icons.check_circle;
        label = 'Working';
      case JavaStatus.broken:
        icon = Icons.error;
        label = 'Broken';
      case JavaStatus.error:
        icon = Icons.warning;
        label = 'Error';
      default:
        icon = Icons.play_arrow;
        label = 'Test';
    }

    return ElevatedButton.icon(
      onPressed: _status == JavaStatus.testing
          ? null
          : () => _testJar(widget.java),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

