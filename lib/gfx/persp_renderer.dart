import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_doomo/widgets/texture_widget.dart';
import 'package:flutter_doomo/world/camera.dart';
import 'package:flutter_doomo/world/sector.dart';
import 'package:flutter_doomo/world/space.dart';
import 'package:flutter_doomo/world/world.dart';
import 'package:sw_rend/software_texture.dart';

class QueueEntry {
  final int sector;
  final int x0, x1;
  final Uint16List floor, ceil;

  const QueueEntry(
      {required this.sector,
      required this.x0,
      required this.x1,
      required this.floor,
      required this.ceil});
}

class SpanCache {
  double perpDist = 0;
  double z = 0;
  double u0 = 0, v0 = 0;
  double texDuDpix = 0, texDvDpix = 0;
  int lastX = 0;
}

class Flat {
  double z = 0;
  final int width;
  final Uint16List startY, endY;

  Flat(this.width)
      : startY = Uint16List(width),
        endY = Uint16List(width);

  void reset(double z) {
    this.z = z;
    startY.fillRange(0, width, 0);
    endY.fillRange(0, width, 0);
  }
}

class PerspRenderer extends Renderer {
  World world;
  Camera camera;
  final Queue<QueueEntry> portals = Queue();
  late final Uint16List floor, ceil;
  late final int halfWidth;
  late final List<SpanCache> spanCache;
  late final Flat floorFlat, ceilFlat;

  PerspRenderer({required this.world, required this.camera});

  @override
  void setTexture(SoftwareTexture texture, [int? bgColor]) {
    super.setTexture(texture, bgColor);
    floor = Uint16List(texture.width);
    floor.fillRange(0, texture.width, 0);
    ceil = Uint16List(texture.width);
    ceil.fillRange(0, texture.width, texture.height);
    halfWidth = width ~/ 2;
    spanCache = List<SpanCache>.generate(height, (i) => SpanCache());
    floorFlat = Flat(width);
    ceilFlat = Flat(width);
  }

  @override
  Future<bool> render_impl() async {
    if (!await super.render_impl()) {
      return false;
    }
    for (SpanCache span in spanCache) {
      span.z = double.infinity;
    }
    portals.clear();
    portals.addLast(QueueEntry(
      sector: camera.currentSector,
      x0: 0,
      x1: width,
      floor: floor,
      ceil: ceil,
    ));
    while (portals.isNotEmpty) {
      renderNextSector(portals, camera);
    }
    return true;
  }

  void renderNextSector(Queue<QueueEntry> portals, Camera camera) {
    double xAdjust = camera.focus / camera.tanHalfFov * halfWidth;
    double xAdjustRecip = 1 / xAdjust;
    QueueEntry portal = portals.removeFirst();
    Sector currentSector = world.sectors[portal.sector];
    floorFlat.reset(currentSector.floor);
    ceilFlat.reset(currentSector.ceil);
    int wallnum = 0;
    for (Wall wall in currentSector.walls) {
      wallnum++;
      // Transform wall positions relative to camera
      LineSeg transformed = wall.line.asViewed(camera);

      // Ignore walls behind the camera
      if (transformed.p0.y <= 0 && transformed.p1.y <= 0) {
        continue;
      }

      // Clip to front space
      Point p0 = transformed.p0, p1 = transformed.p1;
      double startX = 0, endX = 1;
      if (p0.y < 0) {
        startX = (0 - p0.y) / (p1.y - p0.y);
        p0 = Point(p0.x + startX * (p1.x - p0.x), 0);
      }
      if (p1.y < 0) {
        endX = (0 - p0.y) / (p1.y - p0.y);
        p1 = Point(p0.x + endX * (p1.x - p0.x), 0);
      }

      double x0 = p0.y.abs() <= 1e-9
          ? p0.x.abs() <= 1e-9
              ? 0
              : double.infinity * p0.x.sign
          : p0.x / p0.y;
      double x1 = p1.y.abs() <= 1e-9
          ? p1.x.abs() <= 1e-9
              ? 0
              : double.infinity * p1.x.sign
          : p1.x / p1.y;
      // Backwards face
      if (x0 > x1) {
        continue;
      }
      // Outside of frustum
      double portalWorldX0 = (portal.x0 - halfWidth) * xAdjustRecip;
      double portalWorldX1 = (portal.x1 - halfWidth - 1) * xAdjustRecip;
      if (x1 <= portalWorldX0 || x0 >= portalWorldX1) {
        continue;
      }

      ParLine clipped = ParLine(p0, p1 - p0);
      // Left side outside of frustum, clip it
      if (x0 < portalWorldX0) {
        ParLine left = ParLine(Point.origin, Point(portalWorldX0, 1));
        Intersection? intersection = left.intersection(clipped,
            typeThis: IntersectionType.ray,
            typeOther: IntersectionType.segment);
        assert(intersection != null,
            "Intersection of left frustum end not found when the coordinates should have, ${wall.line} $transformed $p0 $p1 $x0 $x1 ${portal.x0} ${p1.x.sign}");
        startX = startX + (endX - startX) * intersection!.u;
        p0 = clipped.at(intersection.u);
        clipped = ParLine(p0, p1 - p0);
        x0 = portalWorldX0;
      }
      // Right side outside of frustum, clip it
      if (x1 > portalWorldX1) {
        ParLine right = ParLine(Point.origin, Point(portalWorldX1, 1));
        Intersection? intersection = right.intersection(clipped,
            typeThis: IntersectionType.ray,
            typeOther: IntersectionType.segment);
        assert(intersection != null,
            "Intersection of right frustum end not found when the coordinates should have, ${wall.line} $transformed $p0 $p1 $x0 $x1 ${portal.x0} ${portal.x1}");
        endX = startX + (endX - startX) * intersection!.u;
        p1 = clipped.at(intersection.u);
        clipped = ParLine(p0, p1 - p0);
        x1 = portalWorldX1;
      }
      int screenX0 = (x0 * xAdjust).toInt() + halfWidth;
      int screenX1 = (x1 * xAdjust).toInt() + halfWidth + 1;

      int fy0 = (height *
              (camera.pitch / 2 +
                  camera.z +
                  (currentSector.floor - camera.z) / p0.y))
          .toInt();
      int cy0 = (height *
              (camera.pitch / 2 +
                  camera.z +
                  (currentSector.ceil - camera.z) / p0.y))
          .toInt();
      int fy1 = (height *
              (camera.pitch / 2 +
                  camera.z +
                  (currentSector.floor - camera.z) / p1.y))
          .toInt();
      int cy1 = (height *
              (camera.pitch / 2 +
                  camera.z +
                  (currentSector.ceil - camera.z) / p1.y))
          .toInt();

      List<QueueEntry?> portals = List.filled(wall.bricks.length, null);
      for (int i = 0; i < wall.bricks.length; i++) {
        Brick brick = wall.bricks[i];
        if (brick.portalIndex != -1) {
          portals[i] = QueueEntry(
              sector: brick.portalIndex,
              x0: screenX0,
              x1: screenX1,
              floor: Uint16List(screenX1 - screenX0),
              ceil: Uint16List(screenX1 - screenX0));
        }
      }

      for (int x = screenX0; x < screenX1; x++) {
        if (x - screenX0 < 0 || x - screenX0 >= width) continue;
        int fy = (fy0 + (fy1 - fy0) * (x - screenX0) / (screenX1 - screenX0))
            .toInt();
        int cy = (cy0 + (cy1 - cy0) * (x - screenX0) / (screenX1 - screenX0))
            .toInt();
        double perpDist = (currentSector.floor - camera.z) /
            (fy / height - camera.z - camera.pitch / 2);
        double worldX = (x - halfWidth) * xAdjustRecip;
        Point worldSpace = Point(worldX, 1) * perpDist;
        worldSpace = worldSpace.rotated(camera.cosYaw, camera.sinYaw);
        int r = (worldSpace.x * 0xff ~/ 2) & 0xff;
        int g = (worldSpace.y * 0xff ~/ 3) & 0xff;
        double b = currentSector.floor;
        double stepB = (currentSector.ceil - b) / (cy - fy);
        int oldFy = portal.floor[x - screenX0];
        int oldCy = portal.ceil[x - screenX0];
        floorFlat.startY[x] = max(0, min(height, oldFy));
        floorFlat.endY[x] = max(0, min(height, fy));

        // Iterate over every brick
        int ySoFar = fy;
        for (int i = 0; i < wall.bricks.length && ySoFar < cy; i++) {
          Brick brick = wall.bricks[i];
          int nextY = (ySoFar + (cy - fy) * brick.height).toInt();

          int startY = max(ySoFar, max(fy, oldFy));
          int endY = min(nextY, min(cy, oldCy));

          // Render wall
          if (brick.texIndex != -1) {
            for (int y = startY; y < endY; y++) {
              drawPoint(x, y, brick.texIndex);
            }
          }

          // Queue portal
          if (portals[i] != null) {
            portals[i]!.floor[x - screenX0] = startY;
            portals[i]!.ceil[x - screenX0] = endY;
          }

          ySoFar = max(ySoFar, nextY);
        }
        /*for (int y = fy; y < cy; y++) {
          int blue = (b * 0xff).toInt() & 0xff;
          int color = (r << 24) | (g << 16) | (blue << 8) | 0xff;
          if (y >= oldFy && y < oldCy) {
            drawPoint(x, y, color);
          }
          b += stepB;
        }*/
        ceilFlat.startY[x] = max(0, min(height, cy));
        ceilFlat.endY[x] = max(0, min(height, oldCy));
      }
    }
    drawSpans(floorFlat, camera, xAdjustRecip);
    drawSpans(ceilFlat, camera, xAdjustRecip);
  }

  void drawSpans(Flat flat, Camera camera, double xAdjustRecip) {
    int lastStartY = flat.startY[0], lastEndY = flat.endY[0];
    // Initialize spans
    double worldX = -halfWidth * xAdjustRecip;
    for (int y = lastStartY; y < lastEndY; y++) {
      SpanCache newSpan = spanCache[y];
      double perpDist =
          (flat.z - camera.z) / (y / height - camera.pitch / 2 - camera.z);
      newSpan.perpDist = perpDist;
      newSpan.lastX = 0;
      Point uv = Point(worldX * perpDist, perpDist) + camera.position;
      uv = uv.rotated(camera.cosYaw, camera.sinYaw);
      newSpan.u0 = uv.x;
      newSpan.v0 = uv.y;
    }
    for (int x = 1; x < width; x++) {
      worldX += xAdjustRecip;
      if (flat.startY[x] < lastStartY) {
        for (int y = flat.startY[x]; y < lastStartY; y++) {
          SpanCache newSpan = spanCache[y];
          double perpDist =
              (flat.z - camera.z) / (y / height - camera.pitch / 2 - camera.z);
          newSpan.perpDist = perpDist;
          newSpan.lastX = x;
          Point uv = Point(worldX * perpDist, perpDist) + camera.position;
          uv = uv.rotated(camera.cosYaw, camera.sinYaw);
          newSpan.u0 = uv.x;
          newSpan.v0 = uv.y;
        }
      }
      if (flat.endY[x] > lastEndY) {
        for (int y = lastEndY; y < flat.endY[x]; y++) {
          SpanCache newSpan = spanCache[y];
          double perpDist =
              (flat.z - camera.z) / (y / height - camera.pitch / 2 - camera.z);
          newSpan.perpDist = perpDist;
          newSpan.lastX = x;
          Point uv = Point(worldX * perpDist, perpDist) + camera.position;
          uv = uv.rotated(camera.cosYaw, camera.sinYaw);
          newSpan.u0 = uv.x;
          newSpan.v0 = uv.y;
        }
      }
      if (flat.startY[x] > lastStartY) {
        for (int y = lastStartY; y < flat.startY[x]; y++) {
          SpanCache span = spanCache[y];
          double perpDist = span.perpDist;
          Point uv = Point(worldX * perpDist, perpDist) + camera.position;
          uv = uv.rotated(camera.cosYaw, camera.sinYaw);
          double u1 = uv.x;
          double v1 = uv.y;
          double uStep = (u1 - span.u0) / (x - span.lastX);
          double vStep = (v1 - span.v0) / (x - span.lastX);
          double u = span.u0, v = span.v0;
          int red = (exp(-span.perpDist) * 0xff).toInt();
          for (int ix = span.lastX; ix < x; ix++) {
            int green = (u * 0xff).toInt() & 0xff;
            int blue = (v * 0xff).toInt() & 0xff;
            int rgba = (red * 0x01000000) +
                (green * 0x00010000) +
                (blue * 0x00000100) +
                0xff;
            drawPoint(ix, y, rgba);
            u += uStep;
            v += vStep;
          }
        }
      }
      if (flat.endY[x] < lastEndY) {
        for (int y = flat.endY[x]; y < lastEndY; y++) {
          SpanCache span = spanCache[y];
          double perpDist = span.perpDist;
          Point uv = Point(worldX * perpDist, perpDist) + camera.position;
          uv = uv.rotated(camera.cosYaw, camera.sinYaw);
          double u1 = uv.x;
          double v1 = uv.y;
          double uStep = (u1 - span.u0) / (x - span.lastX);
          double vStep = (v1 - span.v0) / (x - span.lastX);
          double u = span.u0, v = span.v0;
          int red = (exp(-span.perpDist) * 0xff).toInt();
          for (int ix = span.lastX; ix < x; ix++) {
            int green = (u * 0xff).toInt() & 0xff;
            int blue = (v * 0xff).toInt() & 0xff;
            int rgba = (red * 0x01000000) +
                (green * 0x00010000) +
                (blue * 0x00000100) +
                0xff;
            drawPoint(ix, y, rgba);
            u += uStep;
            v += vStep;
          }
        }
      }
      lastStartY = flat.startY[x];
      lastEndY = flat.endY[x];
    }
    // Terminate remaining spans
    worldX += xAdjustRecip;
    for (int y = lastStartY; y < lastEndY; y++) {
      SpanCache span = spanCache[y];
      double perpDist = span.perpDist;
      Point uv = Point(worldX * perpDist, perpDist) + camera.position;
      uv = uv.rotated(camera.cosYaw, camera.sinYaw);
      double u1 = uv.x;
      double v1 = uv.y;
      double uStep = (u1 - span.u0) / (width - span.lastX);
      double vStep = (v1 - span.v0) / (width - span.lastX);
      double u = span.u0, v = span.v0;
      int red = (exp(-span.perpDist) * 0xff).toInt();
      for (int x = span.lastX; x < width; x++) {
        int green = (u * 0xff).toInt() & 0xff;
        int blue = (v * 0xff).toInt() & 0xff;
        int rgba = (red * 0x01000000) +
            (green * 0x00010000) +
            (blue * 0x00000100) +
            0xff;
        drawPoint(x, y, rgba);
        u += uStep;
        v += vStep;
      }
    }
  }
}
