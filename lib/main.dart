import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'utils/version_cache.dart';

const String title = "Polaris Launcher";

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

  List<Map<String, String>> instances = [
    {"name": "Modded Survival", "version": "alpha-0.3.2", "loader": "Puzzle"}, //TODO load and track
    {"name": "Vanicream", "version": "alpha-0.2.9", "loader": "Vanilla"},
  ];

  LauncherTab activeTab = LauncherTab.library; // track which tab is active

  Future<void> _addInstance() async {
    final details = await askForInstanceDetails(context);
    if (details == null) return;

    setState(() {
      instances.add(details);
    });
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

  Future<Map<String, Map<String, List<Map<String, String>>>>> fetchVersions() async {
    final aggregated = await VersionCache.fetchAllLoaders(
      loaderRepos: loaderRepos,
      cacheDirPath: "caches/versions",
      forceRefresh: false,
    );

    // Return in the exact format your UI expects
    return aggregated;
  }


  List<Map<String, String>> fetchJavaInstallations() { //TODO
    return [
      {"name": "Java 17", "path": "/usr/lib/jvm/java-17"},
      {"name": "Java 20", "path": "/usr/lib/jvm/java-20"},
    ];
  }

  Future<Map<String, String>?> askForInstanceDetails(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    String selectedVersion = "latest";

    final loaders = loaderRepos.keys.toList();
    String selectedLoader = loaders.first;

    Future<Map<String, Map<String, List<Map<String, String>>>>> versionsFuture = fetchVersions();
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

        return StatefulBuilder(
          builder: (context, setState) {
            void goToSubVersionPage() => setState(() => onSubVersionPage = true);
            void goBack() => setState(() => onSubVersionPage = false);

            return AlertDialog(
              title: Text(onSubVersionPage ? "$selectedLoader Versions" : "New Instance"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: dialogMaxHeight,
                ),
                child: SingleChildScrollView(
                  child: FutureBuilder<Map<String, Map<String, List<Map<String, String>>>>>(
                    future: versionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                      }
                      if (!snapshot.hasData) {
                        return const Text('No data found.');
                      }
                      final data = snapshot.data!;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: onSubVersionPage
                            ? [
                          for (final modType in data[selectedLoader]?.keys ?? [])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: buildDropdown(
                                label: "$modType Version",
                                items: (data[selectedLoader]?[modType] ?? [])
                                    .map((versionMap) => versionMap.keys.first)
                                    .toList(),
                                selected: selectedSubVersions[modType] ??
                                    (((data[selectedLoader]?[modType] ?? []).isNotEmpty)
                                        ? (data[selectedLoader]![modType]!.first.keys.first)
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
                            items: (data['Vanilla']?['Client'] as List<dynamic>?)
                                ?.map((v) => v.keys.first as String)
                                .toList() ?? [],
                            selected: selectedVersion,
                            onChanged: (v) => setState(() => selectedVersion = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedLoader,
                            items: loaders
                                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => selectedLoader = value);
                            },
                            decoration: const InputDecoration(labelText: "Loader"),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                if (onSubVersionPage)
                  TextButton(onPressed: goBack, child: const Text("Back"))
                else
                  TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    if (!onSubVersionPage && selectedLoader != "Vanilla") {
                      goToSubVersionPage();
                      return;
                    }

                    String versionInfo = selectedVersion;
                    if (selectedSubVersions.isNotEmpty) {
                      final mods = selectedSubVersions.entries
                          .map((e) => "${e.key}:${e.value}")
                          .join(", ");
                      versionInfo = "$versionInfo | $mods";
                    }

                    Navigator.pop(ctx, {
                      "name": nameController.text.trim(),
                      "version": versionInfo,
                      "loader": selectedLoader,
                    });
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


  void _launchInstance(Map<String, String> instance) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Launching ${instance['name']}...")), //TODO
    );
  }


  Widget _buildInstanceCard(BuildContext context, Map<String, String> instance) {
    bool hovering = false;
    OverlayEntry? overlayEntry;
    final overlay = Overlay.of(context);

    void showContextMenu(Offset position) {
      overlayEntry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => overlayEntry?.remove(),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
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
                        hoverColor: Colors.green.withOpacity(0.15),
                        highlightColor: Colors.green,
                        onTap: () {
                          overlayEntry?.remove();
                          _launchInstance(instance);
                        },
                      ),
                      _contextItem(
                        context,
                        icon: Icons.add_circle_outline,
                        label: "Add Content",
                        onTap: () => overlayEntry?.remove(), //TODO
                      ),
                      _contextDivider(),
                      _contextItem(
                        context,
                        icon: Icons.copy,
                        label: "Duplicate Instance",
                        onTap: () {
                          overlayEntry?.remove();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Duplicated instance")), //TODO
                          );
                        },
                      ),
                      _contextItem(
                        context,
                        icon: Icons.folder_open,
                        label: "Open Folder",
                        onTap: () => overlayEntry?.remove(), //TODO
                      ),
                      _contextItem(
                        context,
                        icon: Icons.content_copy,
                        label: "Copy Path",
                        onTap: () { //TODO
                          overlayEntry?.remove();
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
                        hoverColor: Colors.red.withOpacity(0.15),
                        highlightColor: Colors.red,
                        onTap: () {
                          overlayEntry?.remove();
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
      overlay.insert(overlayEntry!);
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
    showDialog(
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
                instances.remove(instance); //TODO remove from json
              });
              Navigator.pop(ctx);

              // Safe: use scaffold key
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

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        int activeTab = 0;

        final javaInstallations = fetchJavaInstallations();

        // Controllers & values
        final TextEditingController appDirController = TextEditingController(text: "/path/to/app"); //TODO
        final TextEditingController maxDownloadsController = TextEditingController(text: "3");
        int maxDownloads = 3;

        final TextEditingController maxWritesController = TextEditingController(text: "10");
        int maxWrites = 10;

        final TextEditingController minMemoryController = TextEditingController(text: "1024");
        double minMemory = 1024;
        final TextEditingController maxMemoryController = TextEditingController(text: "4096");
        double maxMemory = 4096;
        bool fullscreen = false;
        final TextEditingController widthController = TextEditingController(text: "1280");
        final TextEditingController heightController = TextEditingController(text: "720");

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
                    color: Colors.green.withOpacity(0.2),
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
                                                    Text(java['name']!, style: const TextStyle(color: Colors.white)),
                                                    const SizedBox(height: 4),
                                                    TextField(
                                                      readOnly: false,
                                                      controller: TextEditingController(text: java['path']),
                                                      decoration: const InputDecoration(
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        ElevatedButton(onPressed: () {
                                                          _installJavaVersion(java);
                                                        }, child: const Text("Install")),
                                                        const SizedBox(width: 4),
                                                        ElevatedButton(onPressed: () {
                                                          _findJavaVersion(java);
                                                        }, child: const Text("Detect")),
                                                        const SizedBox(width: 4),
                                                        ElevatedButton(onPressed: () {
                                                          _browseFolder(java['path']);
                                                        }, child: const Text("Browse")),
                                                        const SizedBox(width: 4),
                                                        ElevatedButton(onPressed: () {
                                                          _testJar(java);
                                                        }, child: const Text("Test")),
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
                                  case 1:
                                  // Default Instance Options
                                    return SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Window Size", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Row(
                                            children: [
                                              Checkbox(value: fullscreen, onChanged: (v) => setState(() => fullscreen = v!)), //TODO implement
                                              const Text("Fullscreen", style: TextStyle(color: Colors.white)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Flex(
                                            direction: Axis.horizontal,
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: widthController,
                                                  enabled: !fullscreen,
                                                  decoration: InputDecoration(labelText: "Width", border: darkGreyBorder), //TODO
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: heightController,
                                                  enabled: !fullscreen,
                                                  decoration: InputDecoration(labelText: "Height", border: darkGreyBorder), //TODO
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          buildSliderWithController(
                                            label: "Min Memory (MB)",
                                            value: minMemory,
                                            controller: minMemoryController,
                                            min: 256,
                                            max: 16384,
                                            onChanged: (v) => setState(() {
                                              minMemory = v;
                                              minMemoryController.text = v.toInt().toString(); //TODO
                                            }),
                                            entryWidth: 100,
                                          ),
                                          const SizedBox(height: 8),
                                          buildSliderWithController(
                                            label: "Max Memory (MB)",
                                            value: maxMemory,
                                            controller: maxMemoryController,
                                            min: 256,
                                            max: 16384,
                                            onChanged: (v) => setState(() {
                                              maxMemory = v;
                                              maxMemoryController.text = v.toInt().toString(); //TODO
                                            }),
                                            entryWidth: 100,
                                          ),
                                          const SizedBox(height: 16),
                                          TextField(
                                            decoration: InputDecoration(
                                              labelText: "Java Arguments", //TODO
                                              border: darkGreyBorder,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            decoration: InputDecoration(
                                              labelText: "Environment Variables", //TODO
                                              border: darkGreyBorder,
                                            ),
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
                                                    labelText: "App Directory", //TODO
                                                    border: darkGreyBorder,
                                                  ),
                                                ),
                                              ),
                                              IconButton(icon: const Icon(Icons.folder_open), onPressed: () {
                                                //TODO
                                                }),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              ElevatedButton(onPressed: () {
                                                _purgeCache();
                                              }, child: const Text("Purge Cache")),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          buildSliderWithController(
                                            label: "Max Concurrent Downloads",
                                            value: maxDownloads.toDouble(),
                                            controller: maxDownloadsController,
                                            min: 1,
                                            max: 10,
                                            onChanged: (v) => setState(() {
                                              maxDownloads = v.toInt();
                                              maxDownloadsController.text = maxDownloads.toString(); //TODO
                                            }),
                                          ),
                                          const SizedBox(height: 8),
                                          buildSliderWithController(
                                            label: "Max Concurrent Writes",
                                            value: maxWrites.toDouble(),
                                            controller: maxWritesController,
                                            min: 1,
                                            max: 50,
                                            onChanged: (v) => setState(() {
                                              maxWrites = v.toInt();
                                              maxWritesController.text = maxWrites.toString(); //TODO
                                            }),
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
                                : "${instances.length} instance(s) running",
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

  void _installJavaVersion(Map<String, String> java) {//TODO
    return;
  }

  void _findJavaVersion(Map<String, String> java) {//TODO
    return;
  }

  void _browseFolder(String? java) {//TODO
    return;
  }

  void _testJar(Map<String, String> java) {//TODO
    return;
  }

  void _purgeCache() {//TODO
    return;
  }
}
