import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';

import '../utils/cache_utils.dart' as cache_utils;
import '../utils/credentials.dart';
import '../utils/logger.dart';

class Skin {
  File file;
  bool selected;

  Skin(this.file, this.selected);
}

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key});
  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

Logger logger = Logger.logger("ThreeJS");

class _ModelScreenState extends State<ModelScreen> {
  late three.ThreeJS threeJs;
  three.Object3D? character;
  three.AnimationMixer? _mixer;
  double _rotationY = math.pi;
  List<three.AnimationAction> _actions = [];
  three.AnimationAction? _currentAction;
  final textureLoader = three.TextureLoader();

  late double width;
  late double height;

  late List<Skin> _skins;

  @override
  void initState() {
    super.initState();
    _skins = _getAllSkins();
    threeJs = three.ThreeJS(
      setup: _setup,
      onSetupComplete: () => setState(() {
        _setSkinToCurrent();
      }),
    );
  }

  @override
  void dispose() {
    threeJs.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    threeJs.scene = three.Scene();

    threeJs.scene.background = three.Color.fromHex32(0x121212);

    threeJs.camera = three.PerspectiveCamera(
      35,
      threeJs.width / threeJs.height,
      0.01,
      100,
    );

    threeJs.initRenderer();

    threeJs.camera.position.setValues(0, 1, 5);

    threeJs.scene.add(three.AmbientLight(0xffffff, 3));

    final loader = GLTFLoader();
    final gltf = await loader.fromAsset('assets/models/model.glb');

    character = gltf?.scene;

    if (character != null) {
      threeJs.scene.add(character!);

      character!.frustumCulled = false;
      character?.traverse((object) {
        if (object is three.Mesh) {
          object.frustumCulled = false;
        }
      });

      if (gltf!.animations!.isNotEmpty) {
        for (final dynamic rawClip in gltf.animations!) {
          final clip = rawClip as three.AnimationClip;
          if (clip.duration <= 0) {
            clip.duration = 0.1;
          }
        }

        _mixer = three.AnimationMixer(character!);

        _actions = gltf.animations
        !.map((clip) => _mixer!.clipAction(clip as three.AnimationClip))
            .whereType<three.AnimationAction>()
            .toList();

        _currentAction = _actions.first;
        _currentAction!.play();

        Timer.periodic(
          const Duration(seconds: 8),
              (_) => _switchToRandomAnimation(),
        );
      }
    }

    threeJs.addAnimationEvent((dt) {
      final clampedDt = dt.clamp(0.0, 1 / 30);
      _mixer?.update(clampedDt);
      character?.rotation.y = _rotationY;

      final renderAspect =  width / height;
      if ((threeJs.camera.aspect - renderAspect).abs() > 0.001) {
        threeJs.camera.aspect = renderAspect;
        threeJs.camera.updateProjectionMatrix();
      }
    });
  }

  void _switchToRandomAnimation() {
    if (_actions.length < 2 || _currentAction == null) return;

    final random = math.Random();
    three.AnimationAction next;
    do {
      next = _actions[random.nextInt(_actions.length)];
    } while (next == _currentAction);

    next.reset();
    next.play();
    _currentAction!.crossFadeTo(next, 0.5, true);

    _currentAction = next;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:
      Row(
          children: [
            const Text('Skin Selector',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 20
              ),
            ),
            SizedBox.fromSize(size: Size(10, 10)),
            Tooltip(
                message: "Player flickering? Set the app to use a dedicated GPU",
                child:
                Icon(
                    color: Colors.white54,
                    Icons.info
                )
            )
          ]
      )
      ),
      body: Row(
        children: [
          Expanded(
              flex: 1,
              child:
              Column(
                  children:[
                    SizedBox.fromSize(size: Size(0, 30)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ItchSecureStore.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Listener(
                          onPointerMove: (event) {
                            _rotationY += event.delta.dx * 0.01;
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              width = constraints.maxWidth;
                              height = constraints.maxHeight;
                              return threeJs.build();
                            },
                          )
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.rotate_left_sharp,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Drag to rotate',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 23,
                          ),
                        ),
                      ],
                    ),
                    SizedBox.fromSize(size: Size(0, 30)),
                  ]
              )
          ),
          Expanded(
              flex: 3,
              child: GridView.builder(
                itemCount: _skins.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.4,
                ),
                itemBuilder: (context, index) {
                  final skin = _skins[index];
                  return _buildSkinCard(context, skin);
                },
              )
          ),
        ],
      ),
    );
  }

  Widget _buildSkinCard(BuildContext context, Skin skin) {
    bool hovering = false;

    return KeyedSubtree(
      child: StatefulBuilder(
        builder: (context, setHover) {
          final visualState = hovering
              ? SkinVisualState.hover : skin.selected
              ? SkinVisualState.selected
              : SkinVisualState.idle;

          return MouseRegion(
            onEnter: (_) => setHover(() => hovering = true),
            onExit: (_) => setHover(() => hovering = false),
            child: GestureDetector(
              onTapDown: (details) async => await _updateSkin(skin.file),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: switch (visualState) {
                    SkinVisualState.idle => Color(0xFF1E1E1E),
                    SkinVisualState.hover => Theme.of(context).colorScheme.secondary.withAlpha(50),
                    SkinVisualState.selected => Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                  },
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: switch (visualState) {
                      SkinVisualState.idle => Colors.transparent,
                      SkinVisualState.hover => Theme.of(context).colorScheme.secondary,
                      SkinVisualState.selected => Theme.of(context).colorScheme.primary,
                    }
                  ),
                ),
                padding: const EdgeInsets.all(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _setSkinToCurrent() async {
    Future.delayed(Duration(milliseconds: 100), () { // because why would it work if you didnt!!
      final selectedSkins = _skins.where((s) => s.selected).toList();
      if (selectedSkins.isNotEmpty) {
        unawaited(_updateSkin(selectedSkins.first.file));
      }
    });
  }

  Future<void> _updateSkin(File file) async {
    final newTexture = await textureLoader.fromFile(file);

    character?.traverse((object) {
      if (object is three.Mesh) {
        final material = object.material;
        if (material != null) {
          final oldTexture = material.map;
          newTexture?.magFilter = oldTexture!.magFilter;
          newTexture?.minFilter = oldTexture!.minFilter;
          newTexture?.colorSpace = oldTexture!.colorSpace;
          material.map = newTexture;
          material.needsUpdate = true;
          oldTexture?.dispose();
          return;
        }
      }
    });
    newTexture?.dispose();
  }

  List<Skin> _getAllSkins() {
    final dir = Directory("${cache_utils.getCosmicReachDir().path}\\skins");
    final files = dir.listSync().whereType<File>().where((element) => element.path.endsWith(".png"),).toList();
    final currentSkinJSONFile = File("${dir.path}\\current.json");

    final currentSkinData = jsonDecode(currentSkinJSONFile.readAsStringSync());
    final currentSkinFile = File("${dir.path}\\${currentSkinData["currentSkin"]}");
    List<Skin> skinList = [];

    for (File file in files) {
      skinList.add(Skin(file, file.path == currentSkinFile.path));
    }

    return skinList;
  }
}

enum SkinVisualState {
  idle,
  hover,
  selected,
}