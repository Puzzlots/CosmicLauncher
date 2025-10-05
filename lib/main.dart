import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CosmicReachLauncher());
}

class CosmicReachLauncher extends StatelessWidget {
  const CosmicReachLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Cosmic Reach Launcher",
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
  List<Map<String, String>> instances = [
    {"name": "Modded Survival", "version": "alpha-0.3.2"},
    {"name": "Vanilla", "version": "alpha-0.2.9"},
  ];

  LauncherTab activeTab = LauncherTab.library; // track which tab is active

  Future<void> _addInstance() async {
    final details = await askForInstanceDetails(context);
    if (details == null) return;

    setState(() {
      instances.add(details);
    });
  }

  List<String> fetchVersions() {
    return ["latest", "alpha-0.3.2", "alpha-0.3.1", "alpha-0.2.9", "last"];
  }


  Future<Map<String, String>?> askForInstanceDetails(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    String selectedVersion = "alpha-0.3.2";
    final List<String> versions = fetchVersions();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("New Instance"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Instance Name",
                  ),
                  autofocus: true,
                  maxLength: 40,
                ),
                const SizedBox(height: 12),
                DropdownSearch<String>(
                  items: (filter, _) {
                    if (filter.isEmpty) return versions;
                    return versions
                        .where((v) => v.toLowerCase().contains(filter.toLowerCase()))
                        .toList();
                  },
                  selectedItem: selectedVersion,
                  onChanged: (v) => setState(() => selectedVersion = v ?? selectedVersion),
                  popupProps: const PopupProps.menu(showSearchBox: true),
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(labelText: "Version"),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, {
                    "name": nameController.text.trim(),
                    "version": selectedVersion,
                  });
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _launchInstance(Map<String, String> instance) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Launching ${instance['name']}...")),
    );
  }

  void _switchTab(LauncherTab tab) {
    setState(() => activeTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final latestThree = instances.reversed.take(3).toList();

    return Scaffold(
      body: Row(
        children: [
          // Left sidebar
          Container(
            width: 60,
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                const SizedBox(height: 16),
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.library_books),
                  color: activeTab == LauncherTab.library
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  tooltip: "Library",
                  onPressed: () => _switchTab(LauncherTab.library),
                ),
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.person),
                  color: activeTab == LauncherTab.skins
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  tooltip: "Skins",
                  onPressed: () => _switchTab(LauncherTab.skins),
                ),

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
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.add),
                  tooltip: "Create New Instance",
                  onPressed: _addInstance,
                ),
                const Spacer(),
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.settings),
                  tooltip: "Settings",
                  onPressed: () {},
                ),
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.login),
                  tooltip: "Sign In",
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar (no rounded corner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF1E1E1E),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Cosmic Launcher",
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

                // Thin horizontal divider below top bar
                const Divider(color: Colors.white24, height: 1, thickness: 1),

                // Content row with vertical divider
                Expanded(
                  child: Row(
                    children: [
                      // Slim vertical divider along entire height
                      Container(width: 1, color: Colors.white24),

                      // Main content container with top-left rounded corner
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF121212),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                          ),
                          child: activeTab == LauncherTab.library
                              ? ListView.builder(
                            itemCount: instances.length,
                            itemBuilder: (context, index) {
                              final instance = instances[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                                child: ListTile(
                                  title: Text(instance["name"]!),
                                  subtitle: Text("Version: ${instance['version']}"),
                                  trailing: ElevatedButton(
                                    onPressed: () => _launchInstance(instance),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text("Launch"),
                                  ),
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Text(
                              "Skins tab",
                              style: Theme.of(context).textTheme.titleMedium,
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
