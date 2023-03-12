import 'package:flutter_doomo/world/camera.dart';

class Point {
  static const Point origin = Point(0, 0),
      unitX = Point(1, 0),
      unitY = Point(0, 1);
  final double x, y;
  const Point(this.x, this.y);

  Point operator +(Point other) {
    return Point(x + other.x, y + other.y);
  }

  Point operator -() {
    return Point(-x, -y);
  }

  Point operator -(Point other) {
    return Point(x - other.x, y - other.y);
  }

  Point operator *(num scale) {
    return Point((x * scale).toDouble(), (y * scale).toDouble());
  }

  double dot(Point other) {
    return x * other.x + y * other.y;
  }

  Point rotated(double cosYaw, double sinYaw) {
    double rx = x * cosYaw - y * sinYaw;
    double ry = y * cosYaw + x * sinYaw;
    return Point(rx, ry);
  }

  @override
  String toString() {
    return "($x, $y)";
  }
}

class LineSeg {
  final Point p0, p1;
  const LineSeg(this.p0, this.p1);

  ParLine get parLine => ParLine(p0, p1 - p0);

  LineSeg asViewed(Camera camera) {
    // Signs of sin terms are inverted to negate camera rotation.
    Point np0 = p0.rotated(camera.cosYaw, -camera.sinYaw);
    //p0 * camera.cosYaw + p1 * camera.sinYaw;
    Point np1 = p1.rotated(camera.cosYaw,
        -camera.sinYaw); //p1 * camera.cosYaw - p0 * camera.sinYaw;
    return LineSeg(np0 - camera.position, np1 - camera.position);
  }

  @override
  String toString() {
    return "[$p0 -> $p1]";
  }
}

enum IntersectionType {
  /// All intersection parameters are valid.
  line,

  /// Only intersection parameters in [0, 1] are valid.
  segment,

  /// Non-negative intersection parameters are valid.
  ray;
}

class Intersection {
  final Point intersection;
  final double t, u;

  const Intersection(
      {required this.intersection, required this.t, required this.u});

  @override
  String toString() {
    return "{$intersection @ ($t, $u)}";
  }
}

class ParLine {
  static const double _epsilon = 1e-9;

  final Point origin, unit;
  const ParLine(this.origin, this.unit);

  LineSeg segment([double t = 1]) {
    return LineSeg(origin, origin + unit * t);
  }

  Point at(double t) {
    return origin + unit * t;
  }

  /*
  P = point of intersection
  this(t) = A0 + t*A
  other(T) = B0 + T*B
  P = this(t) = other(T)
  A0 + t*A = B0 + T*B
  t*A - T*B = B0 - A0
  Ax*t - Bx*T = Bx0 - Ax0
  Ay*t - By*T = By0 - Ay0
  [Ax -Bx  [t  = [Bx0 - Ax0
   Ay -By]  T]    By0 - Ay0]
  MX = O
  inv(M) = [-By  Bx  / (AyBx - AxBy)
            -Ay  Ax]
  X = inv(M)O
  t = (-By * (Bx0 - Ax0) + Bx * (By0 - Ay0)) / (AyBx - AxBy)
  T = (-Ay * (Bx0 - Ax0) + Ax * (By0 - Ay0)) / (AyBx - AxBy)
  */
  /// Find the intersection between this and another parametric line.
  /// Returns null if there is no valid intersection, or an intersection
  /// object containing the 2D point of intersection and both parameters.
  Intersection? intersection(ParLine other,
      {IntersectionType typeThis = IntersectionType.line,
      IntersectionType typeOther = IntersectionType.line}) {
    double determinant = unit.y * other.unit.x - unit.x * other.unit.y;
    if (determinant.abs() < _epsilon) {
      return null;
    }
    determinant = 1 / determinant;
    double t = (other.unit.x * (other.origin.y - origin.y) -
            other.unit.y * (other.origin.x - origin.x)) *
        determinant;
    if (t < -_epsilon && typeThis != IntersectionType.line) {
      return null;
    }
    if (t > 1 + _epsilon && typeThis == IntersectionType.segment) {
      return null;
    }
    double u = (-unit.y * (other.origin.x - origin.x) +
            unit.x * (other.origin.y - origin.y)) *
        determinant;
    if (u < -_epsilon && typeOther != IntersectionType.line) {
      return null;
    }
    if (u > 1 + _epsilon && typeOther == IntersectionType.segment) {
      return null;
    }
    return Intersection(intersection: at(t), t: t, u: u);
  }

  @override
  String toString() {
    return "[$origin + t * $unit]";
  }
}
