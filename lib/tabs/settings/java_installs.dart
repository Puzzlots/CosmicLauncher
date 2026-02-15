import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../utils/cache_utils.dart';
import '../../utils/downloaders/temurin_downloader.dart';
import '../../utils/general_utils.dart';
import '../../utils/java_utils.dart';

class JavaInstallsPage extends StatefulWidget {

  const JavaInstallsPage({
    super.key,
  });

  @override
  State<JavaInstallsPage> createState() => _JavaInstallsPageState();
}

class _JavaInstallsPageState extends State<JavaInstallsPage> {
  @override
  Widget build(BuildContext context) {
    final TextEditingController javaVersionController = TextEditingController(text: '17');
    final TextEditingController downloadDirController = TextEditingController();
    downloadDirController.text = p.join(getPersistentCacheDir().path, "java");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Downloader UI
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Java Version: ',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: javaVersionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final versionText = javaVersionController.text;
                      final version = int.tryParse(versionText);
                      if (version == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid Java version number')),
                        );
                        return;
                      }

                      final outDir = downloadDirController.text;
                      final path = await TemurinDownloader.download(
                        version: version,
                        outDir: outDir,
                      );

                      if (path != null && mounted) {
                        if (kDebugMode) {print('[Info] Downloaded Java $version to $path');}
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloaded Java $version to $path')),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Download Directory: ',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: downloadDirController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      final folder = downloadDirController.text;
                      await folder.browseFolder();
                      if (mounted) {
                        setState(() {
                          downloadDirController.text = folder;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.grey),
        // Existing Java installations list
        Expanded(
          child: FutureBuilder<List<Map<String, String>>>(
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
              return ListView.builder(
                itemCount: javaInstallations.length,
                itemBuilder: (context, index) {
                  final java = javaInstallations[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                              onPressed: () => java['path']?.browseFolder(),
                              icon: const Icon(Icons.folder_open),
                              label: const Text("Browse"),
                            ),
                            const SizedBox(width: 4),
                            JavaTesterButton(java: java),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
