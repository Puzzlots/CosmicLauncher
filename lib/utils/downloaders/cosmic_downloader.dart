import 'dart:io';

import 'package:http/http.dart' as http;

import '../cache_utils.dart';
import '../logger.dart';
import '../version_cache.dart';

Logger downloaderLogger = Logger.logger("Downloader");

Future<void> downloadCosmicReachVersion(
    String version,
    ) async {
  version = resolveLatest("Vanilla", "Client", version);
  var artifact = "cosmic-reach-client-$version.jar";
  var savePath = Directory("${getPersistentCacheDir().path}/cosmic_versions");
  await savePath.create(recursive: true);
  final url = "https://github.com/PuzzlesHQ/CRArchive/releases/download/$version/$artifact";

  if (File("${savePath.toString()}/$artifact").existsSync()) return;
  try {
    final resp = await http.get(Uri.parse(url));

    if (resp.statusCode != 200) throw Exception("HTTP ${resp.statusCode}");

    final file = File("${savePath.path}/$artifact");
    await file.writeAsBytes(resp.bodyBytes);
  } catch (e) {
      downloaderLogger.log("Failed to download cosmic reach jar: $e");
    rethrow;
  }
}
