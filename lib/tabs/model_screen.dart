import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart';

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key});
  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  late three.ThreeJS threeJs;
  three.Object3D? character;
  three.AnimationMixer? _mixer;
  double _rotationY = math.pi;

  @override
  void initState() {
    super.initState();
    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setup,
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
      25,
      threeJs.width / threeJs.height,
      0.1,
      1000,
    );

    threeJs.initRenderer();

    threeJs.camera.position.setValues(0, 1, 5);

    threeJs.scene.add(three.AmbientLight(0xffffff, 3));

    final loader = GLTFLoader();
    final gltf = await loader.fromAsset('assets/models/model.glb');

    character = gltf?.scene;

    if (character != null) {
      threeJs.scene.add(character!);

      if (gltf!.animations!.isNotEmpty) {
        _mixer = three.AnimationMixer(character!);
        _mixer!.clipAction(gltf.animations![0] as three.AnimationClip)?.play();
      }
    }

    threeJs.addAnimationEvent((dt) {
      _mixer?.update(dt);
      character?.rotation.y = _rotationY;

      final currentAspect = threeJs.width / (threeJs.height / 0.35);
      if ((threeJs.camera.aspect - currentAspect).abs() > 0.001) {
        threeJs.camera.aspect = currentAspect;
        threeJs.camera.updateProjectionMatrix();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skin Selector',
        style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20
        ),)),
      body: Row(
        children: [
          Expanded(
              flex: 1,
              child:
              Column(
                  children:[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Skin Selector',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Listener(
                        onPointerMove: (event) {
                          setState(() => _rotationY += event.delta.dx * 0.01);
                        },
                        child: threeJs.build(),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.rotate_left_sharp,
                          size: 20,
                        ),
                        const SizedBox(width: 8), // spacing between icon and text
                        const Text(
                          'Drag to rotate',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 23,
                          ),
                        ),
                      ],
                    )
                  ]
              )
          ),
          const Expanded(
            flex: 3,
            child: Center(child: Text('Other content here')),
          ),
        ],
      ),
    );
  }
}