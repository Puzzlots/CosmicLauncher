import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:polaris/utils/cache_utils.dart';
import 'package:polaris/utils/version_cache.dart';

Future<void> downloadPuzzleVersion(
    String unresolvedCoreVersion,
    String unresolvedCosmicVersion,
    Map<String, Map<String, List<Map<String, String>>>> aggregated,
    ) async {
  final libDir = Directory("${getPersistentCacheDir().path}/puzzle_runtime");
  await libDir.create(recursive: true);

  final coreVersion = resolveLatest(aggregated, "Puzzle", "Core", unresolvedCoreVersion);
  final cosmicVersion = resolveLatest(aggregated, "Puzzle", "Cosmic", unresolvedCosmicVersion);
  print("Core: $coreVersion");
  print("Cosmic: $cosmicVersion");

  final coreClientJar = "puzzle-loader-core-$coreVersion-client.jar";
  final coreCommonJar = "puzzle-loader-core-$coreVersion-common.jar";
  final cosmicClientJar = "puzzle-loader-cosmic-$cosmicVersion-client.jar";
  final cosmicCommonJar = "puzzle-loader-cosmic-$cosmicVersion-common.jar";

  String jitpackUrl(String artifact) =>
      "https://jitpack.io/com/github/PuzzlesHQ/$artifact/$artifact";

  final dependenciesJsonUrl =
      "https://github.com/PuzzlesHQ/puzzle-loader-cosmic/releases/download/$cosmicVersion/dependencies.json";

  await downloadJars([
    [coreClientJar, jitpackUrl("puzzle-loader-core/$coreClientJar")],
    [coreCommonJar, jitpackUrl("puzzle-loader-core/$coreCommonJar")],
    [cosmicClientJar, jitpackUrl("puzzle-loader-cosmic/$cosmicClientJar")],
    [cosmicCommonJar, jitpackUrl("puzzle-loader-cosmic/$cosmicCommonJar")]
  ], libDir);

  final depsJsonResp = await http.get(Uri.parse(dependenciesJsonUrl));
  if (depsJsonResp.statusCode != 200) {
    throw Exception("failed to download dependencies.json");
  }
  final depsData = json.decode(depsJsonResp.body);
  final repos = List<String>.from(
      (depsData['repos'] as List).map((e) => e['url'] as String)
  );

  final allDeps = [...(depsData['common'] as List), ...(depsData['client'] as List)];


  for (final dep in allDeps) {
    final group = dep['groupId'];
    final artifact = dep['artifactId'];
    final version = dep['version'];
    bool downloaded = false;
    for (final repo in repos) {
      final url = mavenUrl(repo, group as String, artifact as String, version as String);
      final file = File("${libDir.path}/$artifact-$version.jar");
      if (await file.exists()) {
        downloaded = true;
        break;
      }
      if (await tryDownload(url, file)) {
        downloaded = true;
        break;
      }
    }
    if (!downloaded) {
      throw Exception("failed to download $group:$artifact:$version");
    }
  }
}

Future<void> downloadJars(List<List<String>> files, Directory libDir) async {
  for (final pair in files) {
    final fileName = pair[0];
    final url = pair[1];
    final file = File("${libDir.path}/$fileName");
    if (await file.exists()) continue;
    await tryDownload(url, file);
  }
}

Future<bool> tryDownload(String url, File target) async {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      await target.writeAsBytes(resp.bodyBytes);
      return true;
    }
  } catch (_) {}
  return false;
}

String mavenUrl(String repo, String group, String artifact, String version) {
  final g = group.replaceAll('.', '/');
  return "$repo$g/$artifact/$version/$artifact-$version.jar";
}
