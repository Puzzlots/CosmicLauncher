import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as p;
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';

import '../utils/cache_utils.dart' as cache_utils;
import '../utils/credentials.dart';
import '../utils/general_utils.dart';
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
  final skinDir = Directory(p.join(cache_utils.getCosmicReachDir().path, "skins"));
  final currentSkinJSONFile = File(p.join(cache_utils.getCosmicReachDir().path, "skins", "current.json"));
  final Map<three.Material, three.Texture?> _defaultMaterialMaps = {};
  three.Texture? _activeSkinTexture;

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
    _activeSkinTexture?.dispose();
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
          final material = object.material;
          if (material != null) {
            _defaultMaterialMaps[material] = material.map;
          }
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
                itemCount: _skins.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 3/4,
                ),
                itemBuilder: (context, index) {
                  if (index == 0) return _buildAddSkinCard(context);
                  final skin = _skins[index - 1];
                  return _buildSkinCard(context, skin);
                },
              )
          ),
        ],
      ),
    );
  }

  Widget _buildAddSkinCard(BuildContext context) {
    bool hovering = false;

    return KeyedSubtree(
      child: StatefulBuilder(
        builder: (context, setHover) {
          return MouseRegion(
            onEnter: (_) => setHover(() => hovering = true),
            onExit: (_) => setHover(() => hovering = false),
            child: GestureDetector(
              onTapDown: (details) async => await _importSkin(),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: hovering ? Theme.of(context).colorScheme.outline.withAlpha(50) : Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:  hovering ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.outlineVariant.withAlpha(40)
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, size: 50),
                      SizedBox(height: 8),
                      Text(
                        "Add skin",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              ),
            ),
          );
        },
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

  Future<void> _importSkin() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: "Select skin file",
      lockParentWindow: true,
      type: FileType.custom,
      allowedExtensions: ["png"],
      allowMultiple: true,
    );

    if (result == null) return;

    for (final path in result.paths.whereType<String>()) {
      final file = File(path);
      final fileName = p.basename(file.path);
      var destination = File(p.join(skinDir.path, fileName));

      while (await destination.exists()) {destination = File(p.joinAll(skinDir.uri.pathSegments.append("${nanoid(5)}.png").whereType()));}
      await file.copy(destination.path);
    }
    setState(() {
      _skins = _getAllSkins();
    });
  }

  Future<void> _setSkinToCurrent() async {
    if (_skins.isEmpty) return;
    final selectedSkins = _skins.firstWhere(
          (s) => s.selected,
      orElse: () => _skins.last,
    );
    unawaited(_updateSkin(selectedSkins.file));
  }

  Future<void> _updateSkin(File file) async {
    for (final skin in _skins) {
      skin.selected = false;
    }
    _skins.firstWhere((skin) => skin.file.path == file.path).selected = true;
    setState(() {});

    final isDefaultSkin = file.path == _defaultSkinFile.path;
    final newTexture = isDefaultSkin ? null : await textureLoader.fromFile(file);
    if (!isDefaultSkin && newTexture == null) {
      logger.log("Failed to load skin texture: ${file.path}");
      return;
    }

    if (newTexture != null) {
      final defaultTexture = _defaultMaterialMaps.values.whereType<three.Texture>().firstOrNull;
      _copyTextureSettings(defaultTexture, newTexture);
      newTexture.needsUpdate = true;
    }

    character?.traverse((object) {
      if (object is three.Mesh) {
        final material = object.material;
        if (material != null) {
          material.map = isDefaultSkin ? _defaultMaterialMaps[material] : newTexture;
          material.map?.needsUpdate = true;
          material.needsUpdate = true;
        }
      }
    });

    final previousSkinTexture = _activeSkinTexture;
    _activeSkinTexture = newTexture;
    if (previousSkinTexture != null && previousSkinTexture != newTexture) {
      previousSkinTexture.dispose();
    }

    await currentSkinJSONFile.writeAsString(
      jsonEncode({"currentSkin": file.uri.pathSegments.last}),
    );
  }

  File get _defaultSkinFile => File(p.join(skinDir.path, "default"));

  void _copyTextureSettings(three.Texture? source, three.Texture target) {
    if (source == null) return;

    target.mapping = source.mapping;
    target.wrapS = source.wrapS;
    target.wrapT = source.wrapT;
    target.magFilter = source.magFilter;
    target.minFilter = source.minFilter;
    target.anisotropy = source.anisotropy;
    target.format = source.format;
    target.internalFormat = source.internalFormat;
    target.type = source.type;
    target.colorSpace = source.colorSpace;
    target.generateMipmaps = source.generateMipmaps;
    target.premultiplyAlpha = source.premultiplyAlpha;
    target.flipY = source.flipY;
    target.unpackAlignment = source.unpackAlignment;
    target.offset.setFrom(source.offset);
    target.repeat.setFrom(source.repeat);
    target.center.setFrom(source.center);
    target.rotation = source.rotation;
    target.matrixAutoUpdate = source.matrixAutoUpdate;
    target.matrix.setFrom(source.matrix);
  }

  List<Skin> _getAllSkins() {
    if (!skinDir.existsSync()) {
      skinDir.createSync(recursive: true);
    }

    final files = skinDir
        .listSync()
        .whereType<File>()
        .where(
          (element) => element.path.endsWith(".png"),
    )
        .toList();
    files.add(_defaultSkinFile);

    var currentSkinName = "default";
    if (currentSkinJSONFile.existsSync()) {
      try {
        final currentSkinData = jsonDecode(currentSkinJSONFile.readAsStringSync(),);
        currentSkinName = (currentSkinData["currentSkin"] as String?) ?? currentSkinName;
      } catch (e) {
        logger.log("Failed to read current skin: $e");
      }
    }
    final currentSkinFile = File(p.join(skinDir.path, currentSkinName));
    List<Skin> skinList = [];

    for (File file in files) {
      skinList.add(Skin(file, file.path == currentSkinFile.path));
    }

    if (!skinList.any((skin) => skin.selected) && skinList.isNotEmpty) {
      skinList.last.selected = true;
    }

    return skinList;
  }
}

enum SkinVisualState {
  idle,
  hover,
  selected,
}
