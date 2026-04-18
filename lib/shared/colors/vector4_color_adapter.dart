import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

class Vector4ColorAdapter {
  const Vector4ColorAdapter._();

  static Color toFlutterColor(Vector4 value) {
    return Color.from(
      alpha: value.w.clamp(0, 1).toDouble(),
      red: value.x.clamp(0, 1).toDouble(),
      green: value.y.clamp(0, 1).toDouble(),
      blue: value.z.clamp(0, 1).toDouble(),
    );
  }

  static Vector4 fromFlutterColor(Color color) {
    return Vector4(color.r, color.g, color.b, color.a);
  }

  static Vector4 withChannel(
    Vector4 value, {
    double? red,
    double? green,
    double? blue,
    double? alpha,
  }) {
    return Vector4(
      red ?? value.x,
      green ?? value.y,
      blue ?? value.z,
      alpha ?? value.w,
    );
  }
}
