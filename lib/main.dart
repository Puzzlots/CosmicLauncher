import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:polaris/utils/cache_utils.dart';
import 'package:polaris/utils/general_utils.dart';
import 'package:polaris/utils/instance_utils.dart';
import 'package:polaris/utils/java_utils.dart';
import 'package:polaris/utils/persistent_widgets.dart';
import 'package:polaris/utils/puzzle_downloader.dart';

import 'utils/version_cache.dart';

const String title = "Polaris Launcher";
final prefs = PersistentPrefs.open();

void main() {
  runApp(const CosmicReachLauncher());
  }

class CosmicReachLauncher extends StatelessWidget {
  const CosmicReachLauncher({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF81C784),
        ),
      ),
      home: const LauncherHome(),
    );
  }
}

enum LauncherTab { library, skins }

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final instanceManager = InstanceManager();
  late List<Map<String, String>> instances = [];

  LauncherTab activeTab = LauncherTab.library; // track which tab is active

  Future<void> _loadInstances() async {
    instances = await instanceManager.loadAllInstances();
    setState(() {}); // trigger UI update
  }

  @override
  void initState() {
    super.initState();
    _loadInstances();
  }

  Future<void> _addInstance({Map<String, String>? details}) async {
    details ??= await askForInstanceDetails(context);
    if (details == null) return;

    String id;
    do {
      final short = nanoid(5);
      id = '${details['name']}-$short';
    } while (await instanceManager.loadInstance(id) != null);

    details['uuid'] = id;
    await instanceManager.saveInstance(id, details);

    await _loadInstances();
  }


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

  Future<Map<String, String>?> askForInstanceDetails(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    String selectedVersion = "latest";

    final loaders = loaderRepos.keys.toList();
    String selectedLoader = loaders.first;

    final Map<String, String> selectedSubVersions = {};

    // Shared dimensions for both pages
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
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        popupProps: const PopupProps.menu(showSearchBox: true),
        decoratorProps: DropDownDecoratorProps(
          decoration: InputDecoration(labelText: label),
        ),
      );
    }

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool onSubVersionPage = false;
        Map<String, Map<String, List<Map<String, String>>>> currentVersions = {};
        bool hasFetchedVersions = false; // track if fetch already started

        return StatefulBuilder(
          builder: (context, setState) {
            // start async fetch only once after first build
            if (!hasFetchedVersions) {
              hasFetchedVersions = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                VersionCache.fetchVersions(
                  loaderRepos: loaderRepos,
                  cacheDirPath: "${getPersistentCacheDir().path}/caches/versions",
                  onUpdate: (versions) {
                    if (context.mounted) {
                      setState(() {
                        currentVersions = versions;
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
                  child: currentVersions.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: onSubVersionPage
                        ? [
                      for (final modType in currentVersions[selectedLoader]?.keys ?? [])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: buildDropdown(
                            label: "$modType Version",
                            items: (currentVersions[selectedLoader]?[modType] ?? [])
                                .map((v) => v.keys.first)
                                .toList(),
                            selected: selectedSubVersions[modType] ??
                                ((currentVersions[selectedLoader]?[modType]?.isNotEmpty ?? false)
                                    ? currentVersions[selectedLoader]![modType]!.first.keys.first
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
                        items: (currentVersions['Vanilla']?['Client'] ?? [])
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
                        decoration: const InputDecoration(labelText: "Loader"),
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
                    final messenger = ScaffoldMessenger.of(context);
                    if (!onSubVersionPage && selectedLoader != "Vanilla") {
                      goToSubVersionPage();
                      return;
                    }

                    String versionInfo = selectedVersion;
                    var loaderInfo = {
                      "name": nameController.text.trim(),
                      "version": versionInfo,
                      "loader": selectedLoader,
                    };

                    if (selectedLoader == "Puzzle") {
                      loaderInfo.addEntries(selectedSubVersions.entries);
                      loaderInfo.addAll({"versions": "$versionInfo | ${selectedSubVersions.entries.map((e) => "${e.key}:${e.value}").join(", ")}"});

                      loaderInfo['Core'] = resolveLatest(currentVersions, "Puzzle", "Core", loaderInfo['Core']);
                      loaderInfo['Cosmic'] = resolveLatest(currentVersions, "Puzzle", "Cosmic", loaderInfo['Cosmic']);

                      unawaited(downloadPuzzleVersion(
                        loaderInfo['Core']!,
                        loaderInfo['Cosmic']!,
                        currentVersions,
                      ).catchError((dynamic e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text("Failed to download Puzzle: $e")),
                        );
                      }));

                    } else {loaderInfo.addEntries(selectedSubVersions.entries);}
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


  Future<void> _launchInstance(Map<String, String> instance) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Launching ${instance['name']}...")),
    );

    final loader = instance['loader'];

    if (loader != null && loader.toLowerCase() == 'puzzle') {
    // build classpath for java launch
    // final libDir = Directory('puzzle_runtime');
    // final sep = Platform.isWindows ? ';' : ':';
    // final jars = libDir
    //     .listSync()
    //     .whereType<File>()
    //     .where((f) => f.path.endsWith('.jar'))
    //     .map((f) => f.path)
    //     .join(sep);

    // try {
    //   final process = await Process.start(
    //     'java',
    //     ['-cp', jars, 'dev.puzzleshq.puzzleloader.loader.launch.pieces.ClientPiece'],
    //     mode: ProcessStartMode.inheritStdio,
    //   );
    //   await process.exitCode;
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text("Failed to launch instance: $e")),
    //   );
    // }
    }
  }


  OverlayEntry? _activeOverlay;
  Widget _buildInstanceCard(BuildContext context, Map<String, String> instance) {
    bool hovering = false;

    void showContextMenu(Offset position) {
      _activeOverlay?.remove();
      _activeOverlay = null;

      final overlaySize = 180.0;
      final screenSize = MediaQuery.of(context).size;

      double left = position.dx;
      double top = position.dy;
      if (left + overlaySize > screenSize.width) left = screenSize.width - overlaySize - 8;
      if (top + 300 > screenSize.height) top = screenSize.height - 300 - 8;

      _activeOverlay = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _activeOverlay?.remove();
                  _activeOverlay = null;
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: overlaySize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _contextItem(
                        context,
                        icon: Icons.play_arrow,
                        label: "Play",
                        hoverColor: Colors.green.withValues(alpha: 0.15),
                        highlightColor: Colors.green,
                        onTap: () {
                          _activeOverlay?.remove();
                          _activeOverlay = null;
                          _launchInstance(instance);
                        },
                      ),
                      _contextItem(
                        context,
                        icon: Icons.add_circle_outline,
                        label: "Add Content",
                        onTap: () {
                          _activeOverlay?.remove();
                          _activeOverlay = null;
                          // TODO
                        },
                      ),
                      _contextDivider(),
                      _contextItem(
                        context,
                        icon: Icons.copy,
                        label: "Duplicate Instance",
                        onTap: () {
                          _addInstance(details: instance);
                          _activeOverlay?.remove();
                          _activeOverlay = null;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Duplicated instance")),
                          );
                        },
                      ),
                      _contextItem(
                        context,
                        icon: Icons.folder_open,
                        label: "Open Folder",
                        onTap: () {
                          revealFile(instanceManager.getInstanceFilePath(instance['uuid']!));
                          _activeOverlay?.remove();
                          _activeOverlay = null;
                        },
                      ),
                      _contextItem(
                        context,
                        icon: Icons.content_copy,
                        label: "Copy Path",
                        onTap: () {
                          copyToClipboard(instanceManager.getInstanceFilePath(instance['uuid']!));
                          _activeOverlay?.remove();
                          _activeOverlay = null;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Path copied to clipboard")),
                          );
                        },
                      ),
                      _contextDivider(),
                      _contextItem(
                        context,
                        icon: Icons.delete,
                        label: "Delete",
                        hoverColor: Colors.red.withValues(alpha: 0.15),
                        highlightColor: Colors.red,
                        onTap: () {
                          _activeOverlay?.remove();
                          _activeOverlay = null;
                          _confirmDelete(context, instance);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      Overlay.of(context).insert(_activeOverlay!);
    }

    return KeyedSubtree(
      child: StatefulBuilder(
        builder: (context, setHover) {
          return MouseRegion(
            onEnter: (_) => setHover(() => hovering = true),
            onExit: (_) => setHover(() => hovering = false),
            child: GestureDetector(
              onSecondaryTapDown: (details) => showContextMenu(details.globalPosition),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hovering
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.white24,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          switchInCurve: Curves.easeIn,
                          switchOutCurve: Curves.easeOut,
                          child: hovering
                              ? IconButton(
                            key: UniqueKey(),
                            icon: const Icon(Icons.play_arrow, size: 48),
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: () => _launchInstance(instance),
                          )
                              : Icon(
                            Icons.extension,
                            size: 48,
                            color: Colors.white54,
                            key: UniqueKey(),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      instance["name"]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${instance['loader']} | ${instance['version']}",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _contextItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        Color? hoverColor,
        Color? highlightColor,
      }) {
    bool hovering = false;
    return StatefulBuilder(
      builder: (context, setHover) => InkWell(
        onTap: onTap,
        onHover: (h) => setHover(() => hovering = h),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hovering ? hoverColor ?? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: hovering
                      ? highlightColor ?? Colors.white
                      : Colors.white70),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: hovering
                          ? highlightColor ?? Colors.white
                          : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextDivider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
    height: 1,
    color: Colors.white12,
  );

  void _confirmDelete(BuildContext context, Map<String, String> instance) {
    showDialog<void> (
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text(
            "Are you sure you want to delete '${instance['name']}'? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                instances.remove(instance);@override
                // ignore: unused_element
                void initState() {
                  super.initState();
                  _loadInstances();
                }
                instanceManager.deleteInstance(instance['uuid']!);
              });
              Navigator.pop(ctx);

              _scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text("${instance['name']} deleted")),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _signIn() {
    return; //TODO
  }

  Future<void> _openSettings() async {
    final prefs = await PersistentPrefs.open();

    if (!mounted) return;
    await showDialog<void> (
      context: context,
      builder: (ctx) {
        int activeTab = 0;
        // Controllers & values
        final TextEditingController appDirController = TextEditingController(text: getPersistentCacheDir().path);
        final TextEditingController  maxDownloadsController = TextEditingController(text: prefs.getValue('max_concurrent_downloads', defaultValue: 3).toString());
        double? maxDownloads = double.tryParse(maxDownloadsController.text);

        final TextEditingController maxWritesController = TextEditingController(text: prefs.getValue('max_concurrent_writes', defaultValue: 10).toString());
        double? maxWrites = double.tryParse(maxWritesController.text);

        final TextEditingController minMemoryController = TextEditingController(text: prefs.getValue('defaults_instance_memory_min', defaultValue: 1024).toString());
        double? minMemory = double.tryParse(minMemoryController.text);
        
        final TextEditingController maxMemoryController = TextEditingController(text: prefs.getValue('defaults_instance_memory_max', defaultValue: 4096).toString());
        double? maxMemory = double.tryParse(maxMemoryController.text);
        
        bool fullscreen = prefs.getValue("defaults_instance_fullscreen", defaultValue: false);

        OutlineInputBorder darkGreyBorder = const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: 1),
        );

        return StatefulBuilder(
          builder: (context, setState) {
            Widget tabButton(int index, IconData icon, String label) {
              final bool selected = activeTab == index;
              return InkWell(
                onTap: () => setState(() => activeTab = index),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: selected
                      ? BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    //Tab selection radius controls
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(12), left: Radius.circular(12)),
                  )
                      : null,
                  child: Row(
                    children: [
                      Icon(icon, color: selected ? Colors.green : Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(color: selected ? Colors.green : Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            //slider with controller
            // ignore: unused_element
            Widget buildSliderWithController({
              required String label,
              required double value,
              required TextEditingController controller,
              required double min,
              required double max,
              required ValueChanged<double> onChanged,
              double entryWidth = 80,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white)),
                  Flex(
                    direction: Axis.horizontal,
                    children: [
                      Expanded(
                        child: Slider(
                          value: value,
                          min: min,
                          max: max,
                          onChanged: onChanged,
                          divisions: (max - min).toInt(),
                          activeColor: Colors.green,
                        ),
                      ),
                      SizedBox(
                        width: entryWidth,
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            border: darkGreyBorder,
                            isDense: true,
                          ),
                          onSubmitted: (v) {
                            final val = double.tryParse(v);
                            if (val != null) onChanged(val.clamp(min, max));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            Widget buildPersistentSliderWithController({
              required String keyName,
              required String label,
              required double value,
              required TextEditingController controller,
              required double min,
              required double max,
              required ValueChanged<double> onChanged,
              double entryWidth = 80,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white)),
                  Flex(
                    direction: Axis.horizontal,
                    children: [
                      Expanded(
                        child: PersistentSlider(
                          value: value,
                          min: min,
                          max: max,
                          onChanged: onChanged,
                          divisions: (max - min).toInt(),
                          activeColor: Colors.green,
                          keyName: keyName,
                        ),
                      ),
                      SizedBox(
                        width: entryWidth,
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            border: darkGreyBorder,
                            isDense: true,
                          ),
                          onSubmitted: (v) {
                            final val = double.tryParse(v);
                            if (val != null) onChanged(val.clamp(min, max));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: 850,
                height: 650,
                child: Row(
                  children: [
                    // Tabs
                    IntrinsicWidth(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            tabButton(0, Icons.computer, "Java Installations"),
                            tabButton(1, Icons.settings, "Default Instance Options"),
                            tabButton(2, Icons.storage, "Resource Management"),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.white24),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Top header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Settings",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24),
                            Expanded(
                              child: Builder(builder: (_) {
                                switch (activeTab) {
                                  case 0: // Java Installations
                                    return FutureBuilder<List<Map<String, String>>>(
                                      future: detectJavaInstallations(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(child: CircularProgressIndicator());
                                        }
                                        if (snapshot.hasError) {
                                          return Center(child: Text('Error: ${snapshot.error}'));
                                        }
                                        final javaInstallations = snapshot.data ?? [];
                                        if (javaInstallations.isEmpty) {
                                          return const Center(child: Text('No Java installations found.'));
                                        }
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: ListView.builder(
                                                itemCount: javaInstallations.length,
                                                itemBuilder: (context, index) {
                                                  final java = javaInstallations[index];
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(java['name']!, style: const TextStyle(color: Colors.white, fontSize: 20)),
                                                        const SizedBox(height: 4),
                                                        TextField(
                                                          controller: TextEditingController(text: java['path']),
                                                          onChanged: (value) => java['path'] = value,
                                                          decoration: const InputDecoration(
                                                            border: OutlineInputBorder(),
                                                          ),
                                                        ),

                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            ElevatedButton.icon(
                                                              onPressed: () => browseFolder(java['path']),
                                                              icon: const Icon(Icons.folder_open),
                                                              label: const Text("Browse"),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            JavaTesterButton(java: java)
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  case 1:
                                  // Default Instance Options
                                    return SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Window Size", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Row(
                                            children: [
                                              PersistentCheckbox(value: fullscreen, onChanged: (v) => setState(() => fullscreen = v!), keyName: 'defaults_instance_fullscreen',),
                                              const Text("Fullscreen", style: TextStyle(color: Colors.white)), //TODO
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Flex(
                                            direction: Axis.horizontal,
                                            children: [
                                              Expanded(
                                                child: PersistentTextField(
                                                  enabled: !fullscreen,
                                                  decoration: InputDecoration(labelText: "Width", border: darkGreyBorder),
                                                  keyName: 'defaults_instance_width', //TODO
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: PersistentTextField(
                                                  enabled: !fullscreen,
                                                  decoration: InputDecoration(labelText: "Height", border: darkGreyBorder),
                                                  keyName: 'defaults_instance_height', //TODO
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          buildPersistentSliderWithController(
                                            label: "Min Memory (MB)",
                                            value: minMemory!.toDouble(),
                                            controller: minMemoryController,
                                            min: 256,
                                            max: 16384,
                                            onChanged: (v) => setState(() {
                                              minMemory = v;
                                              minMemoryController.text = v.toInt().toString(); //TODO
                                            }),
                                            entryWidth: 100,
                                            keyName: 'defaults_instance_memory_min',
                                          ),
                                          const SizedBox(height: 8),
                                          buildPersistentSliderWithController(
                                            label: "Max Memory (MB)",
                                            value: maxMemory!.toDouble(),
                                            controller: maxMemoryController,
                                            min: 256,
                                            max: 16384,
                                            onChanged: (v) => setState(() {
                                              maxMemory = v;
                                              maxMemoryController.text = v.toInt().toString(); //TODO
                                            }),
                                            entryWidth: 100,
                                            keyName: 'defaults_instance_memory_max',
                                          ),
                                          const SizedBox(height: 16),
                                          PersistentTextField(
                                            decoration: InputDecoration(
                                              labelText: "Java Arguments", //TODO
                                              border: darkGreyBorder,
                                            ), keyName: 'defaults_instance_args',
                                          ),
                                          const SizedBox(height: 8),
                                          PersistentTextField(
                                            decoration: InputDecoration(
                                              labelText: "Environment Variables", //TODO
                                              border: darkGreyBorder,
                                            ), keyName: 'defaults_instance_vars',
                                          ),
                                        ],
                                      ),
                                    );
                                  case 2:
                                  // Resource Management
                                    return SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Flex(
                                            direction: Axis.horizontal,
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: appDirController,
                                                  decoration: InputDecoration(
                                                    labelText: "App Directory",
                                                    border: darkGreyBorder,
                                                  ),
                                                ),
                                              ),
                                              IconButton(icon: const Icon(Icons.folder_open), onPressed: () {
                                                browseFolder(appDirController.text);
                                                }),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              ElevatedButton(onPressed: () {
                                                deleteCaches();
                                              }, child: const Text("Purge Cache")),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          buildPersistentSliderWithController(
                                            label: "Max Concurrent Downloads",
                                            value: maxDownloads!.toDouble(),
                                            controller: maxDownloadsController,
                                            min: 1,
                                            max: 10,
                                            onChanged: (v) => setState(() {
                                              maxDownloads = v.toDouble();
                                              maxDownloadsController.text = maxDownloads!.toInt().toString(); //TODO
                                            }),
                                            keyName: 'max_concurrent_downloads',
                                          ),
                                          const SizedBox(height: 8),
                                          buildPersistentSliderWithController(
                                            label: "Max Concurrent Writes",
                                            value: maxWrites!.toDouble(),
                                            controller: maxWritesController,
                                            min: 1,
                                            max: 50,
                                            onChanged: (v) => setState(() {
                                              maxWrites = v.toDouble();
                                              maxWritesController.text = maxWrites!.toInt().toString(); //TODO
                                            }),
                                            keyName: 'max_concurrent_writes',
                                          ),
                                        ],
                                      ),
                                    );
                                  default:
                                    return const SizedBox();
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestThree = instances.reversed.take(3).toList();

    // New local state for filters
    String searchQuery = '';
    String sortBy = 'Name';
    String groupBy = 'None';

    Future<List<Map<String, String>>> getProcessedInstances() async {
      // Filter
      var filtered = instances.where((i) {
        return i['name']!.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();

      // Sort
      filtered.sort((a, b) {
        switch (sortBy) {
          case 'Game Version':
            return a['version']!.compareTo(b['version']!);
          case 'Loader':
            return a['loader']!.compareTo(b['loader']!);
          case 'Name':
          default:
            return a['name']!.compareTo(b['name']!);
        }
      });

      // Group
      if (groupBy != 'None') {
        filtered.sort((a, b) {
          final g = groupBy == 'Loader' ? 'loader' : 'version';
          return a[g]!.compareTo(b[g]!);
        });
      }

      return filtered;
    }

    return Scaffold(
      key: _scaffoldMessengerKey,
      body: Row(
        children: [
          // Sidebar (unchanged)
          Container(
            width: 60,
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                const SizedBox(height: 16),

                //Library tab
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.library_books),
                  color: activeTab == LauncherTab.library
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  tooltip: "Library",
                  onPressed: () => setState(() => activeTab = LauncherTab.library),
                ),

                //Skins tab
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.person),
                  color: activeTab == LauncherTab.skins
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  tooltip: "Skins",
                  onPressed: () => setState(() => activeTab = LauncherTab.skins),//TODO do skins tab
                ),

                //Quick launch buttons
                if (latestThree.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(color: Colors.white24, thickness: 1),
                  ),
                ...latestThree.map(
                      (instance) => IconButton(
                    iconSize: 28,
                    icon: const Icon(Icons.play_arrow),
                    tooltip: "Launch ${instance['name']}",
                    onPressed: () => _launchInstance(instance),
                  ),
                ),
                if (latestThree.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(color: Colors.white24, thickness: 1),
                  ),

                //New instance button
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.add),
                  tooltip: "Create New Instance",
                  onPressed: _addInstance,
                ),
                const Spacer(),

                //Settings button
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.settings),
                  tooltip: "Settings",
                  onPressed: () {
                    _openSettings();
                  },
                ),

                //Login button
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.login),
                  tooltip: "Sign In",
                  onPressed: () {
                    _signIn();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF1E1E1E),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        title,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: instances.isEmpty ? Colors.red : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            instances.isEmpty
                                ? "No instances running"
                                : "${instances.length} instance(s) running",//TODO
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1, thickness: 1),

                Expanded(
                  child: Row(
                    children: [
                      Container(width: 1, color: Colors.white24),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF121212),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                          ),
                          child: activeTab == LauncherTab.library
                              ? StatefulBuilder(
                            builder: (context, setInner) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText: "Search instances...",
                                            prefixIcon: const Icon(Icons.search),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: const Color(0xFF1E1E1E),
                                          ),
                                          onChanged: (val) {
                                            setInner(() => searchQuery = val);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      DropdownButton<String>(
                                        value: sortBy,
                                        items: const [
                                          "Name",
                                          "Game Version",
                                          "Loader"
                                        ].map((e) => DropdownMenuItem(value: e, child: Text("Sort: $e"))).toList(),
                                        onChanged: (v) => setInner(() => sortBy = v!),
                                      ),
                                      const SizedBox(width: 8),
                                      DropdownButton<String>(
                                        value: groupBy,
                                        items: const [
                                          "None",
                                          "Loader",
                                          "Game Version"
                                        ].map((e) => DropdownMenuItem(value: e, child: Text("Group: $e"))).toList(),
                                        onChanged: (v) => setInner(() => groupBy = v!),
                                      ),
                                    ],
                                ),
                                const SizedBox(height: 16),

                                // Grid
                                  Expanded(
                                    child: FutureBuilder<List<Map<String, String>>>(
                                      future: getProcessedInstances(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState != ConnectionState.done) {
                                          return const Center(child: CircularProgressIndicator());
                                        }
                                        if (snapshot.hasError) {
                                          return Center(child: Text('Error: ${snapshot.error}'));
                                        }
                                        final list = snapshot.data ?? <Map<String, String>>[];

                                        if (groupBy == 'None') {
                                          // Simple grid when not grouped
                                          return GridView.builder(
                                            itemCount: list.length,
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 1.4,
                                            ),
                                            itemBuilder: (context, index) {
                                              final instance = list[index];
                                              return _buildInstanceCard(context, instance);
                                            },
                                          );
                                        }

                                        // Grouped view
                                        final grouped = <String, List<Map<String, String>>>{};
                                        for (var inst in list) {
                                          final key = groupBy == 'Loader' ? inst['loader']! : inst['version']!;
                                          grouped.putIfAbsent(key, () => []).add(inst);
                                        }

                                        return ListView(
                                          children: grouped.entries.map((entry) {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                                  child: Text(
                                                    entry.key,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                                GridView.builder(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemCount: entry.value.length,
                                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 3,
                                                    mainAxisSpacing: 12,
                                                    crossAxisSpacing: 12,
                                                    childAspectRatio: 1.4,
                                                  ),
                                                  itemBuilder: (context, index) {
                                                    final instance = entry.value[index];
                                                    return _buildInstanceCard(context, instance);
                                                  },
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                              : Center(
                            child: Text(
                              "Skins tab",
                              style:
                              Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
