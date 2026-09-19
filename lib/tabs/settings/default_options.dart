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
                await LauncherHomeState.instanceManager.loadInstances(context);
              }, child: const Text("Purge Instances")),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
