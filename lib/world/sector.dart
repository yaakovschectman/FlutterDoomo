
import 'dart:typed_data';

import 'package:flutter_doomo/world/space.dart';

/// Essentially a room with a floor height, ceiling height, and list of walls.
class Sector {
  final double floor, ceil;

  Sector({this.floor = 0, this.ceil = 1});

  /// 0-indices to the walls that confine this sector.
  Uint16List walls = Uint16List(0);
}

class Wall {
  /// Parametric representation of the line segment of this wall.
  /// Its endpoints are at t = 0 and t = 1.
  final ParLine line;
  final double floor, ceil;

  Wall({required LineSeg lineSeg, this.floor = 0, this.ceil = 1}) : line = lineSeg.parLine;

  /// 0-index of the sector on the opposite side of the wall, or -1 for none.
  int portalIndex = -1;
}