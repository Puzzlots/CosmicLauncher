import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:polaris/utils/cache_utils.dart';
import 'package:polaris/utils/download_utils.dart';
import 'package:polaris/utils/version_cache.dart';

import 'cosmic_downloader.dart';

Future<void> downloadPuzzleVersion(
    String coreVersion,
    String cosmicVersion
    ) async {
  coreVersion = resolveLatest('Puzzle', 'Core', coreVersion);
  cosmicVersion = resolveLatest('Puzzle', 'Cosmic', cosmicVersion);
  final libDir = Directory(p.join(getPersistentCacheDir().path, 'puzzle_runtime'));
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

  final libFile = File(p.join(libDir.path, "$coreVersion-$cosmicVersion.txt"));
  await libFile.parent.create(recursive: true);
  if (!await libFile.exists()) {
    await libFile.create();
  }

  for (List<String> dep in urls) {
    downloadLogger.log("Checking if ${dep[0]} is in library list");
    String filePath = p.join(libDir.path, dep[0]) ;
    if (!libFile.readAsLinesSync().contains(filePath)) await libFile.writeAsString("$filePath\n", mode: FileMode.append);
  }

  for (final dep in allDeps) {
    final group = dep['groupId'] as String;
    final artifact = dep['artifactId'] as String;
    final version = dep['version'] as String;
    final fileName = "$artifact-$version.jar";
    final dir = p.join(libDir.path, fileName);

    bool downloaded = false;
    final file = File(dir);
    downloadLogger.log("Checking if $fileName exists");
    if (file.existsSync()) {
      downloadLogger.log("$fileName exists");
      if ((await libFile.readAsLines()).contains(dir)) {
        downloadLogger.log("$fileName is in library list");
        downloaded = true;
      } else {
        downloadLogger.log("$fileName was not in library list");
        await libFile.writeAsString(
            "$dir\n",
            mode: FileMode.append
        );
        downloaded = true;
      }
    }
    if (downloaded) continue;


    for (final repo in repos) {
      final url = buildDependencyUrlForRepo(repo, group, artifact, version);

      if (await tryDownload(url, file)) {
        downloaded = true;
        await libFile.writeAsString(
            "$dir\n",
            mode: FileMode.append
        );
        break;
      }
    }

    if (!downloaded) {
      downloaderLogger.log("failed to download $group:$artifact:$version");
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
    final file = File(p.join(libDir.path, fileName));
    if (await file.exists()) continue;
    downloaderLogger.log("Downloading $url");
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
  } catch (e) {
    downloaderLogger.log("download error: $e");
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

