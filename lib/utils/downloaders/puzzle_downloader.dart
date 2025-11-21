import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:polaris/utils/cache_utils.dart';

Future<void> downloadPuzzleVersion(
    String coreVersion,
    String cosmicVersion
    ) async {
  final libDir = Directory("${getPersistentCacheDir().path}/puzzle_runtime");
  await libDir.create(recursive: true);

  final coreClientJar = "puzzle-loader-core-$coreVersion-client.jar";
  final coreCommonJar = "puzzle-loader-core-$coreVersion-common.jar";
  final cosmicClientJar = "puzzle-loader-cosmic-$cosmicVersion-client.jar";
  final cosmicCommonJar = "puzzle-loader-cosmic-$cosmicVersion-common.jar";

  String loaderUrl(String module, String version, String environment) =>
      "https://repo1.maven.org/maven2/dev/puzzleshq/puzzle-loader-$module/$version/puzzle-loader-$module-$version-$environment.jar";

  final urls = [
    [coreClientJar, loaderUrl("core", coreVersion, "client")],
    [coreCommonJar, loaderUrl("core", coreVersion, "common")],
    [cosmicClientJar, loaderUrl("cosmic", cosmicVersion, "client")],
    [cosmicCommonJar, loaderUrl("cosmic", cosmicVersion, "common")],
  ];

  await downloadJars(urls, libDir);

  final coreDepsData = await fetchJson("https://github.com/PuzzlesHQ/puzzle-loader-core/releases/download/$coreVersion/dependencies.json");
  final cosmicDepsData = await fetchJson("https://github.com/PuzzlesHQ/puzzle-loader-cosmic/releases/download/$cosmicVersion/dependencies.json");

  final repos = [
    ...List<String>.from((coreDepsData['repos'] as List).map((e) => e['url'])),
    ...List<String>.from((cosmicDepsData['repos'] as List).map((e) => e['url'])),
  ];

  final allDeps = [
    ...(coreDepsData['common'] as List),
    ...(coreDepsData['client'] as List),
    ...(cosmicDepsData['common'] as List),
    ...(cosmicDepsData['client'] as List),
  ].where((e) => e['type'] == 'implementation').toList();

  for (final dep in allDeps) {
    final group = dep['groupId'] as String;
    final artifact = dep['artifactId'] as String;
    final version = dep['version'] as String;

    final file = File("${libDir.path}/$artifact-$version.jar");
    if (await file.exists()) continue;

    bool downloaded = false;

    for (final repo in repos) {
      final url = buildDependencyUrlForRepo(repo, group, artifact, version);

      if (await tryDownload(url, file)) {
        downloaded = true;
        break;
      }
    }

    if (!downloaded) {
      if (kDebugMode) {
        print("[Exception] failed to download $group:$artifact:$version");
      } else {
        throw Exception("failed to download $group:$artifact:$version");
      }
    }
  }
}

Future<Map<String, dynamic>> fetchJson(String url) async {
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) {
    throw Exception("failed to download $url");
  }
  return json.decode(resp.body) as Map<String, dynamic>;
}

Future<void> downloadJars(List<List<String>> files, Directory libDir) async {
  for (final pair in files) {
    final fileName = pair[0];
    final url = pair[1];
    final file = File("${libDir.path}/$fileName");
    if (await file.exists()) continue;
    if (kDebugMode) {
      print("Downloading $url");

    }await tryDownload(url, file);
  }
}

Future<bool> tryDownload(String url, File target) async {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      await target.writeAsBytes(resp.bodyBytes);
      return true;
    }
  } catch (e) {
    if (kDebugMode) {
      print("[Exception] download error: $e");
    }
  }
  return false;
}

String buildDependencyUrlForRepo(String repo, String group, String artifact, String version) {
  if (repo.contains("jitpack.io")) {
    final ownerRepo = "${group.replaceFirst("com.github.", "")}/$artifact";
    return "https://jitpack.io/com/github/$ownerRepo/$version/$artifact-$version.jar";
  }

  final g = group.replaceAll('.', '/');
  if (!repo.endsWith('/')) repo += '/';
  return "$repo$g/$artifact/$version/$artifact-$version.jar";
}

