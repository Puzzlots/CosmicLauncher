import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:polaris/utils/cache_utils.dart';

class Logger {
  static final File _logFile = File('${getPersistentCacheDir().path}/caches/app.log');

  final String name;

  Logger._(this.name);

  static Logger logger(String name) {
    return Logger._(name);
  }

  static Future<void> init() async {
    if (!await _logFile.exists()) {
      await _logFile.create();
    }
    await _logFile.writeAsString('');
  }

  void log(String message) {
    final timestamp = DateTime.now();
    final shortTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    const totalWidth = 15;
    int nameLen = name.length;
    int dashCount = totalWidth - nameLen;
    int leftDashes = dashCount ~/ 2;
    int rightDashes = dashCount - leftDashes;

    final paddedName =
        '${'~' * leftDashes} $name ${'~' * rightDashes}';

    String log = '[$paddedName] [$shortTime] $message\n';

    _logFile.writeAsStringSync(
      log,
      mode: FileMode.append,
      flush: true,
    );

    if (kDebugMode) {
      print(log);
    }
  }

  static Process? _tailProcess;

  static Future<void> tailLogs() async {
    if (_tailProcess != null) return; // already running

    if (Platform.isWindows) {
      _tailProcess = await Process.start(
        'cmd',
        [
          '/c',
          'start',
          'powershell',
          '-NoExit',
          '-Command',
          'Get-Content "${_logFile.path}" -Wait'
        ],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      _tailProcess = await Process.start(
        'osascript',
        [
          '-e',
          'tell application "Terminal" to do script "tail -f ${_logFile.path}"'
        ],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isLinux) {
      _tailProcess = await Process.start(
        'xterm',
        ['-hold', '-e', 'bash', '-c', 'tail -f ${_logFile.path}'],
        mode: ProcessStartMode.detached,
      );
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  static Future<void> dispose() async {
    if (_tailProcess != null) {
      _tailProcess!.kill();
      _tailProcess = null;
    }
  }
}