import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_doomo/world/sector.dart';
import 'package:flutter_doomo/world/space.dart';
import 'package:flutter_doomo/world/world.dart';

typedef ByteProvider = int Function();

typedef BrickList = List<Brick>;

class StringReader {
  final String source;
  int index;
  StringReader(this.source) : index = 0;

  int nextByte() {
    if (index == source.length) {
      return -1;
    }
    return source.codeUnitAt(index++);
  }
}

abstract class Tokenizer {
  double nextFloating();

  int nextInt();

  String nextString();
}

class AsciiTokenizer extends Tokenizer {
  final ByteProvider provider;

  AsciiTokenizer(this.provider);

  @override
  double nextFloating() {
    String string = nextString();
    return double.parse(string);
  }

  @override
  int nextInt() {
    String string = nextString();
    return int.parse(string);
  }

  @override
  String nextString() {
    List<int> codeUnits = [];
    int char;
    while ([10, 13, 32].contains(char = provider())) {}
    if (char != -1) {
      codeUnits.add(char);
    }
    while (![10, 13, 32, -1].contains(char = provider())) {
      codeUnits.add(char);
    }
    return utf8.decode(codeUnits);
  }
}

class BinaryTokenizer extends Tokenizer {
  final ByteProvider provider;

  BinaryTokenizer(this.provider);

  @override
  double nextFloating() {
    Uint8List buffer = Uint8List(4);
    for (int i = 0; i < 4; i++) {
      buffer[i] = provider();
    }
    return ByteData.sublistView(buffer).getFloat32(0);
  }

  @override
  int nextInt() {
    Uint8List buffer = Uint8List(4);
    for (int i = 0; i < 4; i++) {
      buffer[i] = provider();
    }
    return ByteData.sublistView(buffer).getInt32(0);
  }

  @override
  String nextString() {
    List<int> codeUnits = [];
    int char;
    while ((char = provider()) != 0) {
      codeUnits.add(char);
    }
    return utf8.decode(codeUnits);
  }
}

class WorldLoader {
  final Tokenizer tokenizer;

  final Map<String, Point> _points = {};
  final Map<String, BrickList> _brickLists = {};

  WorldLoader(this.tokenizer);

  World loadWorld() {
    String indicator;
    List<Sector> sectors = [];
    while ((indicator = tokenizer.nextString()) != '.end') {
      switch (indicator) {
        case '.pts':
          _loadPoints();
          break;
        case '.brk':
          _loadBricks();
          break;
        case '.sec':
          sectors.addAll(_loadSectors());
          break;
      }
    }
    return World()..sectors.addAll(sectors);
  }

  void _loadPoints() {
    String name;
    while ((name = tokenizer.nextString()) != '.end') {
      double x = tokenizer.nextFloating();
      double y = tokenizer.nextFloating();
      _points[name] = Point(x, y);
    }
  }

  void _loadBricks() {
    String name;
    while ((name = tokenizer.nextString()) != '.end') {
      int numBricks = tokenizer.nextInt();
      BrickList bricks = [];
      for (int b = 0; b < numBricks; b++) {
        int portalIndex = tokenizer.nextInt();
        int texIndex = tokenizer.nextInt();
        double x = tokenizer.nextFloating();
        double y = tokenizer.nextFloating();
        Point texOrigin = Point(x, y);
        x = tokenizer.nextFloating();
        y = tokenizer.nextFloating();
        Point texRange = Point(x, y);
        double height = tokenizer.nextFloating();
        int color = tokenizer.nextInt();
        Brick brick = Brick(
          height: height,
          portalIndex: portalIndex,
          texIndex: texIndex,
          texOrigin: texOrigin,
          texRange: texRange,
          color: color,
        );
        bricks.add(brick);
      }
      _brickLists[name] = bricks;
    }
  }

  List<Sector> _loadSectors() {
    int numSectors = tokenizer.nextInt();
    List<Sector> sectors = [];
    for (int i = 0; i < numSectors; i++) {
      double floor = tokenizer.nextFloating();
      double ceil = tokenizer.nextFloating();
      Sector sector = Sector(floor: floor, ceil: ceil);
      int numWalls = tokenizer.nextInt();
      for (int w = 0; w < numWalls; w++) {
        String pName0 = tokenizer.nextString();
        String pName1 = tokenizer.nextString();
        if (!_points.containsKey(pName0) || !_points.containsKey(pName1)) {
          throw Exception('$pName0 and $pName1 must both be present points');
        }
        String bName = tokenizer.nextString();
        if (!_brickLists.containsKey(bName)) {
          throw Exception('$bName must be present brick list');
        }
        Wall wall = Wall(
            line: LineSeg(_points[pName0]!, _points[pName1]!),
            bricks: _brickLists[bName]!);
        sector.walls.add(wall);
      }
      sectors.add(sector);
    }
    return sectors;
  }
}
