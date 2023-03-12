import 'dart:typed_data';

import 'package:flutter_doomo/world/space.dart';

/// Essentially a room with a floor height, ceiling height, and list of walls.
class Sector {
  final double floor, ceil;
  final List<Wall> walls = <Wall>[];

  Sector({this.floor = 0, this.ceil = 1});
}

class Wall {
  /// Parametric representation of the line segment of this wall.
  /// Its endpoints are at t = 0 and t = 1.
  final LineSeg line;
  final List<Brick> bricks = <Brick>[];

  Wall({required this.line});
}

class Brick {
  /// 0-index of the sector on the opposite side of the wall, or -1 for none.
  final int portalIndex;

  /// Index of texture, -1 for none.
  final int texIndex;
  final Point texOrigin;
  final Point texRange;

  final double height;

  final int color;

  const Brick(
      {required this.height,
      this.portalIndex = -1,
      this.texIndex = -1,
      this.texOrigin = const Point(0, 0),
      this.texRange = const Point(1, 1),
      this.color = 0xffffffff});
}
