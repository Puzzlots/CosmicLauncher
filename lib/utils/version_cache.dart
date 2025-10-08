import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VersionCache {
  /// Fetch all versions from the version.json in the repo.
  /// The returned Map has version strings as keys and download URLs (or full metadata) as values.
  static Future<Map<String, dynamic>> fetchVersions({
    required String owner,
    required String repo,
    required String cacheFilePath,
    bool forceRefresh = false,
  }) async {
    final cacheFile = File(cacheFilePath);

    // Ensure the directory exists
    await cacheFile.parent.create(recursive: true);

    // Try loading from disk cache first
    if (!forceRefresh && cacheFile.existsSync()) {
      try {
        final cachedData = jsonDecode(await cacheFile.readAsString());
        if (cachedData is Map<String, dynamic>) {
          return cachedData;
        }
      } catch (_) {
        // Ignore cache errors
      }
    }

    // Fetch from GitHub raw content
    final url = 'https://raw.githubusercontent.com/$owner/$repo/main/versions.json';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch versions.json: ${response.statusCode}');
    }

    final Map<String, dynamic> versions = jsonDecode(response.body) as Map<String, dynamic>;

    // Cache to disk
    await cacheFile.writeAsString(jsonEncode(versions));

    return versions;
  }

  /// Helper: return a sorted list of version strings, with 'latest' prepended.
  static Future<List<String>> fetchVersionList({
    required String owner,
    required String repo,
    required String cacheFilePath,
    bool forceRefresh = false,
  }) async {
    final versionsMap = await fetchVersions(
      owner: owner,
      repo: repo,
      cacheFilePath: cacheFilePath,
      forceRefresh: forceRefresh,
    );

    final versionKeys = versionsMap['versions'] is Map<String, dynamic>
        ? (versionsMap['versions'] as Map<String, dynamic>).keys.toList()
        : <String>[];

    versionKeys.sort((a, b) => b.compareTo(a));

    return ['latest', ...versionKeys];
  }
}
