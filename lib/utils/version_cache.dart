import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VersionCache {
  /// Fetch all loaders/mod types and aggregate into { loader: { modType: [ {version: url}, ... ] } }
  static Future<Map<String, Map<String, List<Map<String, String>>>>> fetchAllLoaders({
    required Map<String, Map<String, String>> loaderRepos,
    required String cacheDirPath,
    bool forceRefresh = false,
  }) async {
    final aggregated = <String, Map<String, List<Map<String, String>>>>{};

    for (final loaderEntry in loaderRepos.entries) {
      final loader = loaderEntry.key;
      aggregated[loader] = {};

      for (final modTypeEntry in loaderEntry.value.entries) {
        final modType = modTypeEntry.key;
        final repo = modTypeEntry.value;

        final cacheFile = File('$cacheDirPath/$loader-$modType.json');
        Map<String, dynamic>? data;

        if (!forceRefresh && cacheFile.existsSync()) {
          try {
            data = jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>;
          } catch (_) {
            data = null;
          }
        }

        if (data == null) {
          final url = 'https://raw.githubusercontent.com/$repo/versions.json';
          final response = await http.get(Uri.parse(url));
          if (response.statusCode != 200) continue;

          data = jsonDecode(response.body) as Map<String, dynamic>;
          await cacheFile.parent.create(recursive: true);
          await cacheFile.writeAsString(jsonEncode(data));
        }

        final dynamic versionsRaw = data['versions'];
        final List<Map<String, String>> versionList = [];

        if (versionsRaw is List) {
          // CRArchive-style format: list of objects with id/client/server fields
          final sortedList = versionsRaw
              .whereType<Map<String, dynamic>>()
              .where((v) => v['id'] != null)
              .toList();

          sortedList.sort((a, b) {
            final at = (a['releaseTime'] ?? 0) as int;
            final bt = (b['releaseTime'] ?? 0) as int;
            return bt.compareTo(at); // newest first
          });

          for (final v in sortedList) {
            final id = v['id'] as String;
            final clientUrl = (v['client']?['url'] ?? '') as String;
            final serverUrl = (v['server']?['url'] ?? '') as String;
            versionList.add({
              id: clientUrl.isNotEmpty ? clientUrl : serverUrl,
            });
          }
        } else if (versionsRaw is Map<String, dynamic>) {
          // Puzzle loader-style format: map of version IDs to dependency info
          final entries = versionsRaw.entries.toList();

          entries.sort((a, b) {
            final at = (a.value['epoch'] ?? 0) as int;
            final bt = (b.value['epoch'] ?? 0) as int;
            return bt.compareTo(at); // newest first
          });

          for (final e in entries) {
            final depUrl = e.value is Map && (e.value['dependencies'] is String)
                ? e.value['dependencies'] as String
                : '';
            versionList.add({ e.key: depUrl });
          }
        }

        if (versionList.isNotEmpty) {
          versionList.insert(0, { 'latest': '' });
        }

        aggregated[loader]![modType] = versionList;
      }
    }

    return aggregated;
  }
}
