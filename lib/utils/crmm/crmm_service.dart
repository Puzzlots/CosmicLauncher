import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:polaris/utils/crmm/crmm_project.dart';


class CrmmService {
  static Future<List<CrmmProject>> searchProjects(String query, String type, String gameVersion, String sortBy, bool versionLocked) async {
    if (kDebugMode) {
      print("Searching for $query as $type ${versionLocked ? "on Cosmic Reach version $gameVersion" : ''}");
    }
    final url = Uri.https('api.crmm.tech', '/api/search',
        {
          'q': query,
          'type': type,
          if (type == 'mod') 'l': 'puzzle_loader',
          'sortby': sortBy,
          if (versionLocked) 'v': gameVersion
        }
    );
    if (kDebugMode) {
      print(url);
    }

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
        if (kDebugMode) {
          print("Error fetching CRMM projects ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
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

    if (kDebugMode) {
      print(url);
    }

    if (kDebugMode) {
      print('Downloading from: $url');
    }

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

      // Write file
      await file.writeAsBytes(response.bodyBytes);

      if (kDebugMode) {
        print('Downloaded to: ${file.path}');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        print('Download failed: $e');
        print(stack);
      }
      rethrow;
    }
  }

  static List<String> sortBy = [
    "relevance",
    "downloads",
    "follow_count",
    "recently_updated",
    "recently_published"
  ];

}

// [
// CrmmProject(
// author: "Spicy",
// categories: ["vanilla"],
// datePublished: DateTime(2026),
// dateUpdated: DateTime(2026),
// downloads: 100,
// featuredCategories: [],
// featuredGalleryUrl: null,
// followers: 10,
// gameVersions: ["0.5.6"],
// iconUrl: null,
// id: "1234",
// loaders: [Loader.puzzle],
// name: "Zoom",
// projectType: "mod",
// slug: "zoom",
// summary: "")
// ];