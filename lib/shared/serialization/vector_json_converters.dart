import 'package:json_annotation/json_annotation.dart';
import 'package:vector_math/vector_math.dart';

class Vector2JsonConverter extends JsonConverter<Vector2, Object?> {
  const Vector2JsonConverter();

  @override
  Vector2 fromJson(Object? json) {
    return Vector2(
      _elementAtOrNull(json, 0) ?? 0,
      _elementAtOrNull(json, 1) ?? 0,
    );
  }

  @override
  Object? toJson(Vector2 object) => [object.x, object.y];
}

class Vector4JsonConverter extends JsonConverter<Vector4, Object?> {
  const Vector4JsonConverter();

  @override
  Vector4 fromJson(Object? json) {
    return Vector4(
      _elementAtOrNull(json, 0) ?? 0,
      _elementAtOrNull(json, 1) ?? 0,
      _elementAtOrNull(json, 2) ?? 0,
      _elementAtOrNull(json, 3) ?? 1,
    );
  }

  @override
  Object? toJson(Vector4 object) => [object.x, object.y, object.z, object.w];
}

class Vector3JsonConverter extends JsonConverter<Vector3, Object?> {
  const Vector3JsonConverter();

  @override
  Vector3 fromJson(Object? json) {
    return Vector3(
      _elementAtOrNull(json, 0) ?? 0,
      _elementAtOrNull(json, 1) ?? 0,
      _elementAtOrNull(json, 2) ?? 0,
    );
  }

  @override
  Object? toJson(Vector3 object) => [object.x, object.y, object.z];
}

double? _elementAtOrNull(Object? json, int index) {
  if (json is! List || index < 0 || index >= json.length) {
    return null;
  }

  final value = json[index];
  if (value is! num) {
    return null;
  }

  return value.toDouble();
}
