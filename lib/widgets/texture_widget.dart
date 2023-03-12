import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sw_rend/software_texture.dart';

/// Parent class that contains logic for rendering to a texture widget.
class Renderer {
  SoftwareTexture? _texture;
  Uint8List? _pixels;
  int _bgColor = 0x000000ff;
  late int width, height;

  bool get ready => _pixels != null;

  /// Called by the texture widget state upon initialization.
  /// Should probably not be called outside of this context...
  void setTexture(SoftwareTexture texture, [int? bgColor]) {
    _texture = texture;
    _pixels = texture.buffer;
    _bgColor = bgColor ?? _bgColor;
    width = texture.width;
    height = texture.height;
  }

  /// Call in order to render to this renderer's texture.
  /// This internally calls the protected _render method, which
  /// if it returns true, pushes to and draws the software texture.
  Future<void> render() async {
    if (!ready) {
      return;
    }
    if (await render_impl()) {
      await _texture!.draw();
    }
  }

  /// Override this method in derived classes to control rendering logic.
  /// By default, the parent class just clears the buffer.
  /// If this method returns false, the redraw call in render is skipped.
  Future<bool> render_impl() async {
    clear(_bgColor);
    return true;
  }

  Future<void> clear([int color = 0xff]) async {
    if (!ready) {
      return;
    }
    for (int y = 0; y < _texture!.height; y++) {
      for (int x = 0; x < _texture!.width; x++) {
        _drawPoint(x, y, color);
      }
    }
  }

  void drawPoint(int x, int y, int color) {
    if (!ready ||
        x < 0 ||
        y < 0 ||
        x >= _texture!.width ||
        y >= _texture!.height) {
      return;
    }
    _drawPoint(x, y, color);
  }

  void _drawPoint(int x, int y, int color) {
    y = _texture!.height - 1 - y; // Swap y-bottom to y-top
    int index = y * _texture!.width + x;
    _pixels![index * 4 + 0] = color >> 24;
    _pixels![index * 4 + 1] = color >> 16;
    _pixels![index * 4 + 2] = color >> 8;
    _pixels![index * 4 + 3] = color;
  }

  // All coordinates in the range of [0, 1].
  void drawLine(double x0, double y0, double x1, double y1, int color) {
    if (!ready) {
      return;
    }
    int ix0 = (x0 * _texture!.width).toInt();
    int ix1 = (x1 * _texture!.width).toInt();
    int iy0 = (y0 * _texture!.height).toInt();
    int iy1 = (y1 * _texture!.height).toInt();

    int dx = ix1 - ix0;
    int dy = iy1 - iy0;

    // Vertical line
    if (dx == 0) {
      for (int y = iy0; y != iy1; y += dy.sign) {
        drawPoint(ix0, y, color);
      }
      return;
    }

    // Run >= rise
    if (dx.abs() >= dy.abs()) {
      int y = iy0;
      double error = 0;
      double step = dy / dx.abs();
      for (int x = ix0; x != ix1; x += dx.sign) {
        drawPoint(x, y, color);
        error += step;
        if (error.abs() > 0.5) {
          y += step.sign.toInt();
          error -= step.sign;
        }
      }
      return;
    }

    // Rise > run
    int x = ix0;
    double error = 0;
    double step = dx / dy.abs();
    for (int y = iy0; y != iy1; y += dy.sign) {
      drawPoint(x, y, color);
      error += step;
      if (error.abs() > 0.5) {
        x += step.sign.toInt();
        error -= step.sign;
      }
    }
    return;
  }
}

class TextureWidget extends StatefulWidget {
  final int width, height;
  final Renderer? renderer;
  final int bgColor;

  const TextureWidget(
      {required this.width,
      required this.height,
      this.renderer,
      this.bgColor = 0x000000ff,
      super.key});

  @override
  State<TextureWidget> createState() => _TextureWidgetState();
}

class _TextureWidgetState extends State<TextureWidget> {
  SoftwareTexture? _texture;
  int frames = 0;

  @override
  void initState() {
    super.initState();
    initTexture();
  }

  @override
  Future<void> didUpdateWidget(TextureWidget oldWidget) async {
    super.didUpdateWidget(oldWidget);
    print('Updating');
    //await widget.renderer?.render();
  }

  Future<void> initTexture() async {
    SoftwareTexture tex = SoftwareTexture(
        Size(widget.width.toDouble(), widget.height.toDouble()));
    await tex.generateTexture().then((void v) {
      _texture = tex;
      widget.renderer?.setTexture(tex, widget.bgColor);
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _texture == null
        ? Container(color: Colors.blue)
        : Texture(
            textureId: _texture!.textureId,
            filterQuality: FilterQuality.none,
          );
  }
}
