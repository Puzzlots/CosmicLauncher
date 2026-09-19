import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:polaris/utils/crmm/crmm_project.dart';

import '../logger.dart';

class CrmmService {
  static final modDir = "mods";
  static final dataModDir = "dmods";
  static final javaModDir = "jmods";

  static Logger crmmLogger = Logger.logger("CRMM Service");

  static Future<List<CrmmProject>> searchProjects(String query, String type, String gameVersion, String sortBy, bool versionLocked, ReleaseChannel releaseChannel) async {

    crmmLogger.log("Searching for '$query' as $type ${versionLocked ? "on Cosmic Reach version $gameVersion" : ''}");

    final url = Uri.https('api.crmods.org', '/api/search',
        {
          'q': query,
          'type': type,
          if (type == 'mod') 'l': 'puzzle_loader',
          'sortby': sortBy,
          if (type == 'mod') 'e': 'client', // must support client
          if (versionLocked) 'v': gameVersion,
          'releaseChannel': releaseChannel.name
        }
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) crmmLogger.log("Error fetching CRMM projects ${response.statusCode}");
      final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;

      final List<dynamic> hits = data['hits'] as List<dynamic>;

      // Get latest project version info
      if (hits.isEmpty) return [];
      final versionsUrl = Uri.https('api.crmods.org', '/api/projects/versions',
          {
            'ids': hits.map((hit) => hit["id"]).join(','),
            'limit': '1',
            if (type == 'mod') 'l': 'puzzle_loader',
            if (versionLocked) 'v': gameVersion,
            'releaseChannel': releaseChannel.name
          }
      );
      final versionsResponse = await http.get(versionsUrl);

      if (versionsResponse.statusCode != 200) crmmLogger.log("Error fetching version info ${versionsResponse.statusCode}");
      var versionData = json.decode(versionsResponse.body) as Map<String, dynamic>;

      for (var hit in hits) {
        if ((versionData[hit["id"]] as List<dynamic>).isEmpty) continue;
        hit["latestVersionSlug"] = (versionData[hit["id"]]?[0]?["slug"] as String? ?? '');
        hit["latestVersionPrimaryFileName"] = (versionData[hit["id"]]?[0]?["primaryFile"]["name"] as String? ?? '');
        hit["latestVersionPrimaryFileHash"] = (versionData[hit["id"]]?[0]?["primaryFile"]["sha512_hash"] as String? ?? '');
      }

      // Convert each hit to CrmmProject
      final projects = hits.map<CrmmProject>((hit) {
        return CrmmProject.fromJson(hit as Map<String, dynamic>);
      }).toList();

      return projects;

    } catch (e) {
      crmmLogger.log(e.toString());
    }

    return [];
  }

  static Future<bool> downloadLatestProject(String slug, String type, bool versionLocked, String path, String gameVersion) async {
    final url = Uri.https('api.crmods.org', '/api/project/$slug/version/latest/primary-file',
        {
          if (versionLocked) 'gameVersion': gameVersion,
          if (type == 'mod') 'loader': 'puzzle_loader',
        }
    );

    crmmLogger.log(url.toString());
    crmmLogger.log('Downloading from: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      String? fileName;
      final contentDisp = response.headers['content-disposition'];
      if (contentDisp != null) {
        final regex = RegExp(r'filename="?(.+?)"?$');
        final match = regex.firstMatch(contentDisp);
        if (match != null) {
          fileName = match.group(1);
        }
      }

      fileName ??= '$slug-$type.jar';
      final file = File(p.join(path, fileName));

      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      final outputDir = Directory(p.join(file.parent.path, type == 'mod' ? javaModDir : dataModDir));
      await outputDir.create(recursive: true);
      unawaited(file.rename(p.join(outputDir.path, file.uri.pathSegments.last)));

      return true;

    } catch (e, stack) {
      crmmLogger.log('Download failed: $e');
      crmmLogger.log(stack.toString());
      rethrow;
    }
  }

  static Future<void> unzipDataMod(File inputFile) async {
    crmmLogger.log("Unpacking ${inputFile.path}");

    if (lookupMimeType(inputFile.path) != "application/zip") return;

    final fileStream = InputFileStream(inputFile.path);
    final archive = ZipDecoder().decodeStream(fileStream);

    final outputDir = Directory(p.join(inputFile.parent.parent.path, modDir));
    await outputDir.create(recursive: true);

    crmmLogger.log("Extracting to: ${outputDir.path}");
    await extractArchiveToDisk(archive, outputDir.path);
  }

  static List<String> sortBy = [
    "relevance",
    "downloads",
    "follow_count",
    "recently_updated",
    "recently_published"
  ];

}