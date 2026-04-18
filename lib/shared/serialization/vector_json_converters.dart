import 'package:json_annotation/json_annotation.dart';
import 'package:vector_math/vector_math.dart';

class Vector2JsonConverter extends JsonConverter<Vector2, List<double>> {
  const Vector2JsonConverter();

  @override
  Vector2 fromJson(List<double> json) {
    return Vector2(
      json.elementAtOrNull(0) ?? 0,
      json.elementAtOrNull(1) ?? 0,
    );
  }

  @override
  List<double> toJson(Vector2 object) => [object.x, object.y];
}

class Vector4JsonConverter extends JsonConverter<Vector4, List<double>> {
  const Vector4JsonConverter();

  @override
  Vector4 fromJson(List<double> json) {
    return Vector4(
      json.elementAtOrNull(0) ?? 0,
      json.elementAtOrNull(1) ?? 0,
      json.elementAtOrNull(2) ?? 0,
      json.elementAtOrNull(3) ?? 1,
    );
  }

  @override
  List<double> toJson(Vector4 object) => [object.x, object.y, object.z, object.w];
}

extension on List<double> {
  double? elementAtOrNull(int index) {
    if (index < 0 || index >= length) {
      return null;
    }

    return this[index];
  }
}
