import 'package:flutter/material.dart';

import '../../main.dart';
import '../../utils/cache_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/persistent_widgets.dart';


class DefaultOptionsPage extends StatefulWidget {
  final PersistentPrefs prefs;

  const DefaultOptionsPage({
    super.key, required this.prefs,
  });

  @override
  State<DefaultOptionsPage> createState() => _DefaultOptionsPageState();
}

class _DefaultOptionsPageState extends State<DefaultOptionsPage> {
  @override
  Widget build(BuildContext context) {
    final TextEditingController appDirController = TextEditingController(text: getPersistentCacheDir().path);
    final TextEditingController  maxDownloadsController = TextEditingController(text: widget.prefs.getValue('max_concurrent_downloads', defaultValue: 3).toString());
    double? maxDownloads = double.tryParse(maxDownloadsController.text);

    final TextEditingController maxWritesController = TextEditingController(text: widget.prefs.getValue('max_concurrent_writes', defaultValue: 10).toString());
    double? maxWrites = double.tryParse(maxWritesController.text);

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
                appDirController.text.browseFolder();
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(onPressed: () {
                deleteCaches();
              }, child: const Text("Purge Cache")),
              ElevatedButton(onPressed: () async {
                await deleteCaches(folder: 'instances');
                await Future<dynamic>.delayed(const Duration(milliseconds: 50)); // release handles
                await CosmicReachLauncher.launcherHomeKey.currentState?.loadInstances();
              }, child: const Text("Purge Instances")),
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
  }
}
