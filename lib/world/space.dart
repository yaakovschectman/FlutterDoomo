class Point {
  final double x, y;
  const Point(this.x, this.y);

  Point operator+(Point other) {
    return Point(x + other.x, y + other.y);
  }

  Point operator-() {
    return Point(-x, -y);
  }

  Point operator-(Point other) {
    return Point(x - other.x, y - other.y);
  }

  Point operator*(num scale) {
    return Point((x * scale).toDouble(), (y * scale).toDouble());
  }
}

class LineSeg {
  final Point p0, p1;
  const LineSeg(this.p0, this.p1);

  ParLine get parLine => ParLine(p0, p1 - p0);
}

class ParLine {
  final Point origin, unit;
  const ParLine(this.origin, this.unit);

  LineSeg segment([double t = 1]) {
    return LineSeg(origin, origin + unit * t);
  }

  Point at(double t) {
    return origin + unit * t;
  }
}