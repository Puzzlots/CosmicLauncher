import 'package:flutter/material.dart';

import '../../utils/cache_utils.dart';
import '../../utils/persistent_widgets.dart';

class ResourceManagementPage extends StatefulWidget {
  final PersistentPrefs prefs;

  const ResourceManagementPage({
    super.key, required this.prefs,
  });

  @override
  State<ResourceManagementPage> createState() => _ResourceManagementPageState();

}

class _ResourceManagementPageState extends State<ResourceManagementPage> {
  @override
  Widget build(BuildContext context) {
    final TextEditingController minMemoryController = TextEditingController(text: widget.prefs.getValue('defaults_instance_memory_min', defaultValue: 1024).toString());
    double? minMemory = double.tryParse(minMemoryController.text);

    final TextEditingController maxMemoryController = TextEditingController(text: widget.prefs.getValue('defaults_instance_memory_max', defaultValue: 4096).toString());
    double? maxMemory = double.tryParse(maxMemoryController.text);

    bool fullscreen = widget.prefs.getValue("defaults_instance_fullscreen", defaultValue: false);
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
              minMemoryController.text = v.toInt().toString();
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
              maxMemoryController.text = v.toInt().toString();
            }),
            entryWidth: 100,
            keyName: 'defaults_instance_memory_max',
          ),
          const SizedBox(height: 16),
          PersistentTextField(
            decoration: InputDecoration(
              labelText: "Java Arguments",
              hintText: "Comma to separate",
              border: darkGreyBorder,
            ), keyName: 'defaults_instance_args',
          ),
          const SizedBox(height: 8),
          PersistentTextField(
            decoration: InputDecoration(
              labelText: "Environment Variables",
              hintText: "Comma to separate",
              border: darkGreyBorder,
            ), keyName: 'defaults_instance_vars',
          ),
        ],
      ),
    );
  }
}
