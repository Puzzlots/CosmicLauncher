import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../main.dart';

class CustomTitleBar extends StatelessWidget {
  final String version;
  final ValueNotifier<int> runningInstances;

  const CustomTitleBar(this.version, this.runningInstances, {super.key});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
        child: SizedBox(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DragToMoveArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF1E1E1E),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Center(
                          child: Row(
                              children:[
                                Text(
                                  'Version $version',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: Colors.grey),
                                ),
                                // TODO: make this function
                                // SizedBox(width: 5),
                                // Tooltip(
                                //     message: "A new version is available",
                                //     child: Icon(
                                //       Icons.download_sharp,
                                //       color: Theme.of(context).colorScheme.primary,
                                //     )
                                // )
                              ]
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: runningInstances,
                          builder: (context, value, child) {
                            return Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: value == 0 ? Colors.red : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  value == 0 ? "No instances running" : "$value instance${value == 1 ? '' : 's'} running",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            );
                          },
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                color: const Color(0xFF1E1E1E),
                child: Row(children: [
                  _WindowButton(
                    icon: Icons.remove,
                    onPressed: () => windowManager.minimize(),
                  ),
                  _WindowButton(
                    icon: Icons.crop_square,
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  _WindowButton(
                    icon: Icons.close,
                    hoverColor: Colors.red,
                    onPressed: () => windowManager.close(),
                  ),
                ],)
              )

            ],
          ),
        )
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      color: const Color(0xFF1E1E1E),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: hoverColor ?? Colors.white10,
          child: Center(
            child: Icon(icon, size: 20, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}