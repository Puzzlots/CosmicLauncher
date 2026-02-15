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
  static final dataModDir = "mods";
  static final javaModDir = "jmods";

  static Logger crmmLogger = Logger.logger("CRMM Service");

  static Future<List<CrmmProject>> searchProjects(String query, String type, String gameVersion, String sortBy, bool versionLocked) async {

      crmmLogger.log("Searching for $query as $type ${versionLocked ? "on Cosmic Reach version $gameVersion" : ''}");

    final url = Uri.https('api.crmm.tech', '/api/search',
        {
          'q': query,
          'type': type,
          if (type == 'mod') 'l': 'puzzle_loader',
          'sortby': sortBy,
          if (versionLocked) 'v': gameVersion
        }
    );
      crmmLogger.log(url.toString());


    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;

        final List<dynamic> hits = data['hits'] as List<dynamic>;

        // Convert each hit to CrmmProject
        final projects = hits.map<CrmmProject>((hit) {
          return CrmmProject.fromJson(hit as Map<String, dynamic>);
        }).toList();

        return projects;
      } else {
          crmmLogger.log("Error fetching CRMM projects ${response.statusCode}");

      }
    } catch (e) {
      crmmLogger.log(e.toString());
    }

    return [];

  }

  static Future<void> downloadLatestProject(String slug, String type, bool versionLocked, String path, String gameVersion) async {
    final url = Uri.https('api.crmm.tech', '/api/project/$slug/version/latest/primary-file',
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

      if (type == 'mod'){
        final outputDir = Directory(p.join(file.parent.path, javaModDir));
        await outputDir.create(recursive: true);
        unawaited(file.rename(p.join(outputDir.path, file.path.split("/").last)));
      } else {
        await unzipDataMod(file);

        file.deleteSync();
      }

    } catch (e, stack) {
      crmmLogger.log('Download failed: $e');
      crmmLogger.log(stack.toString());
      rethrow;
    }
  }

  static Future<void> unzipDataMod(File inputFile) async {
    crmmLogger.log("Unpacking ${inputFile.path} \n to parent ${inputFile.parent.toString()}/$dataModDir");

    if (lookupMimeType(inputFile.path) != "application/zip") return;

    final fileStream = InputFileStream(inputFile.path);
    final archive = ZipDecoder().decodeStream(fileStream);

    final outputDir = Directory(p.join(inputFile.parent.path, dataModDir));
    await outputDir.create(recursive: true);

    crmmLogger.log("Extracting to: ${outputDir.path}");
    await extractArchiveToDisk(archive, outputDir.path);
    crmmLogger.log("Extraction complete.");
  }

  static List<String> sortBy = [
    "relevance",
    "downloads",
    "follow_count",
    "recently_updated",
    "recently_published"
  ];

}