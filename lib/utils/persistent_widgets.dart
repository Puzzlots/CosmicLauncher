import 'package:flutter/material.dart';
import 'package:polaris/main.dart' show title, installPath;

import '../main.dart' show title; // default app title
import 'cache_utils.dart'; // your PersistentPrefs

/// ----------------- Persistent Checkbox ----------------- ///
class PersistentCheckbox extends StatefulWidget {
  final String keyName;
  final bool? value; // default value if no persisted value
  final ValueChanged<bool?>? onChanged;
  final String appName;

  const PersistentCheckbox({
    super.key,
    required this.keyName,
    this.value,
    this.onChanged,
    this.appName = title,
  });

  @override
  State<PersistentCheckbox> createState() => _PersistentCheckboxState();
}

class _PersistentCheckboxState extends State<PersistentCheckbox> {
  late PersistentPrefs _prefs;
  bool _value = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await PersistentPrefs.open(installPath: installPath);
    final saved = _prefs.getValue(widget.keyName, defaultValue: widget.value ?? false);
    setState(() {
      _value = saved;
      _loaded = true;
    });
  }

  Future<void> _onChanged(bool? v) async {
    if (v == null) return;
    setState(() => _value = v);
    await _prefs.setValue(widget.keyName, v);
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const CircularProgressIndicator();
    return Checkbox(
      value: _value,
      onChanged: _onChanged,
    );
  }
}

/// ----------------- Persistent Switch ----------------- ///
class PersistentSwitch extends StatefulWidget {
  final String keyName;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final String appName;

  const PersistentSwitch({
    super.key,
    required this.keyName,
    this.value,
    this.onChanged,
    this.appName = title,
  });

  @override
  State<PersistentSwitch> createState() => _PersistentSwitchState();
}

class _PersistentSwitchState extends State<PersistentSwitch> {
  late PersistentPrefs _prefs;
  bool _value = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await PersistentPrefs.open(installPath: installPath);
    final saved = _prefs.getValue(widget.keyName, defaultValue: widget.value ?? false);
    setState(() {
      _value = saved;
      _loaded = true;
    });
  }

  Future<void> _onChanged(bool v) async {
    setState(() => _value = v);
    await _prefs.setValue(widget.keyName, v);
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const CircularProgressIndicator();
    return Switch(
      value: _value,
      onChanged: _onChanged,
    );
  }
}

/// ----------------- Persistent Slider (double) ----------------- ///
class PersistentSlider extends StatefulWidget {
  final String keyName;
  final double? value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final Color? activeColor;
  final String appName;

  const PersistentSlider({
    super.key,
    required this.keyName,
    this.value,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.appName = title,
  });

  @override
  State<PersistentSlider> createState() => _PersistentSliderState();
}

class _PersistentSliderState extends State<PersistentSlider> {
  late PersistentPrefs _prefs;
  double _value = 0.0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await PersistentPrefs.open(installPath: installPath);
    final saved = _prefs.getValue(widget.keyName, defaultValue: widget.value ?? widget.min);
    setState(() {
      _value = saved;
      _loaded = true;
    });
  }

  Future<void> _onChanged(double v) async {
    setState(() => _value = v);
    await _prefs.setValue(widget.keyName, v);
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const CircularProgressIndicator();
    return Slider(
      value: _value,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      activeColor: widget.activeColor,
      onChanged: _onChanged,
    );
  }
}

/// ----------------- Persistent Numeric Field (int/double) ----------------- ///
class PersistentNumericField extends StatefulWidget {
  final String keyName;
  final num? value;
  final ValueChanged<num>? onChanged;
  final bool allowDouble;
  final String appName;

  const PersistentNumericField({
    super.key,
    required this.keyName,
    this.value,
    this.onChanged,
    this.allowDouble = false,
    this.appName = title,
  });

  @override
  State<PersistentNumericField> createState() => _PersistentNumericFieldState();
}

class _PersistentNumericFieldState extends State<PersistentNumericField> {
  late PersistentPrefs _prefs;
  late TextEditingController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await PersistentPrefs.open(installPath: installPath);

    final initial = widget.allowDouble
        ? _prefs.getValue(widget.keyName, defaultValue: widget.value?.toDouble() ?? 0.0).toString()
        : _prefs.getValue(widget.keyName, defaultValue: widget.value?.toInt() ?? 0).toString();

    _controller.text = initial;

    _controller.addListener(() async {
      final text = _controller.text;
      if (text.isEmpty) return;
      try {
        if (widget.allowDouble) {
          final val = double.parse(text);
          await _prefs.setValue(widget.keyName, val);
          widget.onChanged?.call(val);
        } else {
          final val = int.parse(text);
          await _prefs.setValue(widget.keyName, val);
          widget.onChanged?.call(val);
        }
      } catch (_) {}
    });

    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const CircularProgressIndicator();
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.allowDouble),
    );
  }
}

/// ----------------- Persistent Text Field (String) ----------------- ///
class PersistentTextField extends StatefulWidget {
  final String keyName;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String appName;
  final bool? enabled;
  final InputDecoration? decoration;

  const PersistentTextField({
    super.key,
    required this.keyName,
    this.controller,
    this.onChanged,
    this.appName = title,
    this.enabled,
    this.decoration,
  });

  @override
  State<PersistentTextField> createState() => _PersistentTextFieldState();
}

class _PersistentTextFieldState extends State<PersistentTextField> {
  late PersistentPrefs _prefs;
  late TextEditingController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await PersistentPrefs.open(installPath: installPath);
    final saved = _prefs.getValue(widget.keyName, defaultValue: _controller.text);
    if (_controller.text.isEmpty) _controller.text = saved;

    _controller.addListener(() async {
      await _prefs.setValue(widget.keyName, _controller.text);
      widget.onChanged?.call(_controller.text);
    });

    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const CircularProgressIndicator();
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      decoration: widget.decoration,
    );
  }
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

OutlineInputBorder darkGreyBorder = const OutlineInputBorder(
  borderSide: BorderSide(color: Colors.grey, width: 1),
);