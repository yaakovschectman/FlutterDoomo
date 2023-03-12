import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_doomo/gfx/persp_renderer.dart';
import 'package:flutter_doomo/widgets/texture_widget.dart';
import 'package:flutter_doomo/world/camera.dart';
import 'package:flutter_doomo/world/sector.dart';
import 'package:flutter_doomo/world/space.dart';
import 'package:flutter_doomo/world/world.dart';

double _kTargetFps = 30;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  double _fps = 0;
  late TextureWidget view;
  final World world = World();
  Camera camera = Camera();
  late PerspRenderer renderer;

  @override
  void initState() {
    super.initState();

    // Test world
    List<Sector> sectors = world.sectors;
    // Square walls in [-1, 1]
    Sector sector = Sector(ceil: 0.75, floor: 0.25);
    Point p0 = Point(-1, -1),
        p1 = Point(1, -1),
        p2 = Point(2, 0),
        p3 = Point(1, 1),
        p4 = Point(-1, 1),
        p5 = Point(-2, 0);
    sector.walls.add(Wall(line: LineSeg(p1, p0)));
    sector.walls.add(Wall(line: LineSeg(p2, p1)));
    sector.walls.add(Wall(line: LineSeg(p3, p2)));
    sector.walls.add(Wall(line: LineSeg(p4, p3)));
    sector.walls.add(Wall(line: LineSeg(p5, p4)));
    sector.walls.add(Wall(line: LineSeg(p0, p5)));
    sectors.add(sector);

    renderer = PerspRenderer(world: world, camera: camera);
    view = TextureWidget(
        width: 300, height: 300, renderer: renderer, bgColor: 0xa08010ff);
    loop();
  }

  Future<void> loop() async {
    DateTime start = DateTime.now();
    while (true) {
      DateTime lastCall = DateTime.now();
      camera.setYaw(camera.yaw + 0.1);
      camera.pitch = 0.5 * sin(_counter / 40);
      renderer.camera = camera;
      await view.renderer?.render();
      setState(() {});
      Duration passed = DateTime.now().difference(lastCall);
      await Future.delayed(
          Duration(microseconds: 1000000 ~/ _kTargetFps) - passed);
      _counter++;
      _fps = min(_counter / (DateTime.now().difference(start).inSeconds), 1000);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'FPS: ${_fps.toInt()} Yaw: ${camera.yaw}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Container(width: 500, height: 500, child: view),
          ],
        ),
      ),
    );
  }
}
