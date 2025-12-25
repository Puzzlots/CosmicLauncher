import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'instance_utils.dart';

class VersionCache {
  static Future<void> fetchVersions({
    required Map<String, Map<String, String>> loaderRepos,
    required String cacheDirPath,
    required void Function(Map<String, Map<String, List<Map<String, String>>>>) onUpdate,
  }) async {
    for (final loaderEntry in loaderRepos.entries) {
      final loader = loaderEntry.key;

      final versions = InstanceManager().currentVersions;
      versions.putIfAbsent(loader, () => {});

      for (final modTypeEntry in loaderEntry.value.entries) {
        final modType = modTypeEntry.key;
        final cacheFile = File('$cacheDirPath/$loader-$modType.json');

        Map<String, dynamic>? localData;
        if (cacheFile.existsSync()) {
          try {
            localData =
            jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
          } catch (_) {}
        }

        versions[loader]![modType] = _parseVersions(localData);
      }
    }

    onUpdate(InstanceManager().currentVersions);

    await Future(() async {
      for (final loaderEntry in loaderRepos.entries) {
        final loader = loaderEntry.key;

        final versions = InstanceManager().currentVersions;
        versions.putIfAbsent(loader, () => {});

        for (final modTypeEntry in loaderEntry.value.entries) {
          final modType = modTypeEntry.key;
          final repo = modTypeEntry.value;
          final cacheFile = File('$cacheDirPath/$loader-$modType.json');

          Map<String, dynamic>? localData;
          if (cacheFile.existsSync()) {
            try {
              localData =
              jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
            } catch (_) {}
          }

          Map<String, dynamic>? remoteData;
          try {
            final url =
                'https://raw.githubusercontent.com/$repo/versions.json';
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              remoteData = jsonDecode(response.body) as Map<String, dynamic>;
            }
          } catch (_) {}

          final localLatest = _getLatestVersionId(localData);
          final remoteLatest = _getLatestVersionId(remoteData);

          if (remoteLatest != null && remoteLatest != localLatest) {
            await cacheFile.parent.create(recursive: true);
            await cacheFile.writeAsString(jsonEncode(remoteData));
            localData = remoteData;
          }

          versions[loader]![modType] = _parseVersions(localData);
        }
      }

      // Call UI again with updated remote versions
      onUpdate(InstanceManager().currentVersions);
    });
  }

  static List<Map<String, String>> _parseVersions(Map<String, dynamic>? data) {
    final versionList = <Map<String, String>>[];
    final versionsRaw = data?['versions'];

    if (versionsRaw is List && versionsRaw.isNotEmpty) {
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
        versionList.add({id: clientUrl.isNotEmpty ? clientUrl : serverUrl});
      }
    } else if (versionsRaw is Map<String, dynamic> && versionsRaw.isNotEmpty) {
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
        versionList.add({e.key: depUrl});
      }
    }

    if (versionList.isNotEmpty) versionList.insert(0, {'latest': ''});
    return versionList;
  }

  static String? _getLatestVersionId(Map<String, dynamic>? data) {
    if (data == null) return null;
    final versions = data['versions'];
    if (versions is List && versions.isNotEmpty) {
      versions.sort((a, b) {
        final at = (a['releaseTime'] ?? 0) as int;
        final bt = (b['releaseTime'] ?? 0) as int;
        return bt.compareTo(at);
      });
      return versions.first['id'] as String?;
    } else if (versions is Map<String, dynamic> && versions.isNotEmpty) {
      final entries = versions.entries.toList();
      entries.sort((a, b) {
        final at = (a.value['epoch'] ?? 0) as int;
        final bt = (b.value['epoch'] ?? 0) as int;
        return bt.compareTo(at);
      });
      return entries.first.key;
    }

    return null;
  }
}

String resolveLatest(String loader, String modType, String? version) {

  if (version != "latest" && version != null) return version;

  final list = InstanceManager().currentVersions[loader]?[modType];
  if (list == null || list.isEmpty) {
    throw StateError("No versions available for $loader/$modType");
  }

  return (list.length > 1 ? list[1] : list.first).keys.first;
}
