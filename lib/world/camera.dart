import 'dart:math';

import 'package:flutter_doomo/world/space.dart';

class Camera {
  Point position;
  double yaw; // Radians
  double cosYaw, sinYaw;
  int currentSector;
  double fov;
  double tanHalfFov;
  double focus;
  double z;
  double pitch;

  Camera({
    this.position = const Point(0, 0),
    this.yaw = 0,
    this.currentSector = 0,
    this.fov = pi / 2,
    this.focus = 1,
    this.z = 0.5,
    this.pitch = 0,
  })  : cosYaw = cos(yaw),
        sinYaw = sin(yaw),
        tanHalfFov = tan(fov / 2);

  void setYaw(double yaw) {
    this.yaw = yaw;
    cosYaw = cos(yaw);
    sinYaw = sin(yaw);
  }
}
