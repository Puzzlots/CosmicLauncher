import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;

class TemurinDownloader {
  static Future<File?> downloadLatest({
    required int version, // 17 or 24
    String? outDir,
  }) async {
    final os = _detectOs();
    final arch = _detectArch();

    final url =
        'https://api.adoptium.net/v3/binary/latest/'
        '$version/ga/$os/$arch/jdk/hotspot/normal/eclipse?project=jdk';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      return null;
    }

    final fileName = _extractFilename(res.headers) ??
        'temurin-$version-$os-$arch.tar.gz';

    final directory = Directory(outDir ?? Directory.current.path);
    directory.createSync(recursive: true);


    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(res.bodyBytes);

    return file;
  }

  static Future<String?> download({
    required int version, // 17 or 24
    String? outDir,
  }) async {
    final file = await downloadLatest(version: version, outDir: outDir);
    if (file == null) return null;

    final extractDir =
        '${file.parent.path}/${file.uri.pathSegments.last.replaceAll(RegExp(r'(\.zip|\.tar\.gz)$'), '')}';

    Directory(extractDir).createSync(recursive: true);

    if (file.path.endsWith('.zip')) {
      await _extractZip(file, extractDir);
    } else if (file.path.endsWith('.tar.gz')) {
      await _extractTarGz(file, extractDir);
    }

    return extractDir;
  }

  // -------- OS / ARCH DETECTION --------

  static String _detectOs() {
    if (['windows', 'macos', 'linux'].contains(Platform.operatingSystem)) {return Platform.operatingSystem;}
    throw UnsupportedError('Unsupported OS');
  }

  static String _detectArch() {
    final env = Platform.environment['PROCESSOR_ARCHITECTURE'] ??
        Platform.environment['HOSTTYPE'] ??
        '';

    if (env.toLowerCase().contains('arm') ||
        env.toLowerCase().contains('aarch64')) {
      return 'aarch64';
    }

    return 'x64';
  }

  // -------- EXTRACTION --------

  static Future<void> _extractZip(File zipFile, String outDir) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    await extractArchiveToDisk(archive, outDir);
  }

  static Future<void> _extractTarGz(File tarGz, String outDir) async {
    final gzBytes = await tarGz.readAsBytes();
    final tarBytes = GZipDecoder().decodeBytes(gzBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    await extractArchiveToDisk(archive, outDir);
  }

  // -------- HELPERS --------

  static String? _extractFilename(Map<String, String> headers) {
    final cd = headers['content-disposition'];
    if (cd == null) return null;
    if (!cd.contains('filename=')) return null;
    return cd.split('filename=').last.replaceAll('"', '');
  }
}