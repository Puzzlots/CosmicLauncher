import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:polaris/utils/version_cache.dart';

import '../main.dart';
import 'cache_utils.dart';
import 'downloaders/cosmic_downloader.dart';
import 'downloaders/puzzle_downloader.dart';
import 'logger.dart';

Logger instanceLogger = Logger.logger("Instances");

class InstanceManager {
  //Loaders
  final loaderRepos = {
    "Vanilla": {
      "Client": "PuzzlesHQ/CRArchive/main"
    },
    "Puzzle": {
      "Core": "PuzzlesHQ/puzzle-loader-core/versioning",
      "Cosmic": "PuzzlesHQ/puzzle-loader-cosmic/versioning",
    }
  };

  static final InstanceManager _instance =
  InstanceManager._internal(baseDir: installPath);

  factory InstanceManager() => _instance;

  InstanceManager._internal({required this.baseDir});

  final String baseDir;

  Map<String, Map<String, List<Map<String, String>>>> currentVersions = {};

  Directory get _instancesDir {
    final dir = Directory(p.join(getPersistentCacheDir(installPath: baseDir).path, 'instances'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String getInstanceFilePath(String id) {
    return p.join(_instancesDir.path, '$id.json');
  }

  Future<void> saveInstance(String id, Map<String, dynamic> details) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    await file.writeAsString(jsonEncode(details));
  }

  Future<Map<String, dynamic>?> loadInstance(String id) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    if (!await file.exists()) return null;

    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadAllInstances() async {
    final ids = _instancesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) {
          final name = f.uri.pathSegments.last;
          final parts = name.split('.');
          return parts.length > 1 ? parts.sublist(0, parts.length - 1).join('.') : name;
        })
        .toList();

    instanceLogger.log("Loaded: $ids");

    final raw = await Future.wait(ids.map(loadInstance));
    return raw.whereType<Map<String, dynamic>>().toList();
  }


  Future<void> deleteInstance(dynamic id) async {
    final file = File(p.join(_instancesDir.path, '$id.json')); // did u accidentally press the exit button?
    if (await file.exists()) await file.delete(); //shit it crashed idk if that was me pressing the exit button?, it was when i pressed enter on the search
  }

  Future<void> clearAll() async {
    await for (final f in _instancesDir.list()) {
      if (f is File && f.path.endsWith('.json')) await f.delete();
    }
  }

  Future<bool> instanceExists(String id) async {
    final file = File(getInstanceFilePath(id));
    return file.exists();
  }

  Future<void> loadInstances(BuildContext context) async {
    unawaited(
        VersionCache.fetchVersions(
          loaderRepos: loaderRepos,
          cacheDirPath: p.join(getPersistentCacheDir().path, 'caches' 'versions'),
          onUpdate: (versions) {
            if (context.mounted) {
              CosmicReachLauncher.launcherHomeKey.currentState?.setState(() {
                currentVersions = versions;
              });
            }
          },
        ));
    LauncherHomeState.instances = await LauncherHomeState.instanceManager.loadAllInstances();
    CosmicReachLauncher.launcherHomeKey.currentState?.setState(() {});

    for (var instance in LauncherHomeState.instances) {if (instance['downloaded'] != true) {
      if (!context.mounted) return;
      unawaited(refreshInstance(context, instance));
    }}
  }

  Future<void> refreshInstance(
      BuildContext context,
      Map<String, dynamic> instance,
      ) async {
    if (instance['downloading'] == true) return;

    CosmicReachLauncher.launcherHomeKey.currentState?.setState(() {
      instance['downloading'] = true;
    });

    if (!await instanceExists(instance['uuid'] as String)) return;

    try {
      await downloadCosmicReachVersion(
          (instance['version'] as String?) ?? 'latest'
      );

      if (instance['loader'] == 'Puzzle') {
        await downloadPuzzleVersion(
            (instance['Core'] as String?) ?? 'latest',
            (instance['Cosmic'] as String?) ?? 'latest'
        );
      }
      await saveInstance(instance['uuid'] as String, {...instance, "downloaded":true}..remove('downloading'));
    } catch (e) {
      logger.log("Failed to refresh instance $e");
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to refresh instance ${instance['version']}: $e",
          ),
        ),
      );
      logger.log(e.toString());
    } finally {
      CosmicReachLauncher.launcherHomeKey.currentState?.setState(() {
        instance['downloading'] = false;
      });
    }
  }

  Future<Map<String, dynamic>?> askForInstanceDetails(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    String selectedVersion = "latest";

    final loaders = loaderRepos.keys.toList();
    String selectedLoader = loaders.first;

    final Map<String, String> selectedSubVersions = {};

    const double dialogWidth = 400;
    const double dialogMaxHeight = 400;

    Widget buildDropdown({
      required String label,
      required List<String> items,
      required String selected,
      required void Function(String) onChanged,
    }) {
      return DropdownSearch<String>(
        items: (filter, _) {
          if (filter.isEmpty) return items;
          return items
              .where((v) => v.toLowerCase().contains(filter.toLowerCase()))
              .toList();
        },
        selectedItem: selected,
        onSaved: (v) {
          if (v != null) onChanged(v);
        },
        popupProps: const PopupProps.menu(showSearchBox: true),
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(
              labelText: label
          ),
        ),
      );
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool onSubVersionPage = false;
        bool hasFetchedVersions = false;

        return StatefulBuilder(
          builder: (context, setState) {
            if (!hasFetchedVersions) {
              hasFetchedVersions = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                VersionCache.fetchVersions(
                  loaderRepos: loaderRepos,
                  cacheDirPath: p.join(getPersistentCacheDir().path, 'caches' 'versions'),
                  onUpdate: (versions) {
                    if (context.mounted) {
                      setState(() {
                        InstanceManager().currentVersions = versions;
                      });
                    }
                  },
                );
              });
            }

            void goToSubVersionPage() => setState(() => onSubVersionPage = true);
            void goBack() => setState(() => onSubVersionPage = false);

            return AlertDialog(
              title: Text(onSubVersionPage ? "$selectedLoader Versions" : "New Instance"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogMaxHeight),
                child: SingleChildScrollView(
                  child: InstanceManager().currentVersions.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: onSubVersionPage
                        ? [
                      for (final modType in InstanceManager().currentVersions[selectedLoader]?.keys ?? [])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: buildDropdown(
                            label: "$modType Version",
                            items: (InstanceManager().currentVersions[selectedLoader]?[modType] ?? [])
                                .map((v) => v.keys.first)
                                .toList(),
                            selected: selectedSubVersions[modType] ??
                                ((InstanceManager().currentVersions[selectedLoader]?[modType]?.isNotEmpty ?? false)
                                    ? InstanceManager().currentVersions[selectedLoader]![modType]!.first.keys.first
                                    : ""),
                            onChanged: (v) => setState(() => selectedSubVersions[modType as String] = v),
                          ),
                        ),
                    ]
                        : [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Instance Name"),
                        autofocus: true,
                        maxLength: 40,
                      ),
                      const SizedBox(height: 12),
                      buildDropdown(
                        label: "Game Version",
                        items: (InstanceManager().currentVersions['Vanilla']?['Client'] ?? [])
                            .map((v) => v.keys.first)
                            .toList(),
                        selected: selectedVersion,
                        onChanged: (v) => setState(() => selectedVersion = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLoader,
                        items: loaders
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => selectedLoader = value);
                        },
                        borderRadius: BorderRadius.circular(12),
                        decoration: const InputDecoration(labelText: "Loader"),
                        dropdownColor: backgroundColour,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (onSubVersionPage)
                  TextButton(onPressed: goBack, child: const Text("Back"))
                else
                  TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(ctx);
                    if (!onSubVersionPage && selectedLoader != "Vanilla") {
                      goToSubVersionPage();
                      return;
                    }

                    String versionInfo = selectedVersion;
                    Map<String,dynamic> loaderInfo = {
                      "name": nameController.text.trim(),
                      "version": versionInfo,
                      "loader": selectedLoader,
                    };

                    if (selectedLoader == "Puzzle") {
                      loaderInfo.addEntries(selectedSubVersions.entries);
                      loaderInfo.addAll({"versions": "$versionInfo | ${selectedSubVersions.entries.map((e) => "${e.key}:${e.value}").join(", ")}"});

                    } else {loaderInfo.addEntries(selectedSubVersions.entries);}
                    loaderInfo['downloaded'] = false;
                    navigator.pop(loaderInfo);
                  },
                  child: Text(onSubVersionPage ? "Create" : (selectedLoader == "Vanilla" ? "Create" : "Next")),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
