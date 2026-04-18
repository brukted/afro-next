import 'package:vector_math/vector_math.dart';

enum GraphValueType {
  integer,
  integer2,
  integer3,
  integer4,
  float,
  float2,
  float3,
  float4,
  stringValue,
  boolean,
  enumChoice,
  colorBezierCurve,
}

enum GraphValueUnit { none, rotation, position, power2, color, path }

enum GraphPropertyType { input, output, descriptor }

enum GraphSocketDirection { input, output }

class EnumChoiceOption {
  const EnumChoiceOption({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final int value;
}

class GraphBezierControlPoint {
  const GraphBezierControlPoint({
    required this.t1,
    required this.pos,
    required this.t2,
  });

  final Vector2 t1;
  final Vector2 pos;
  final Vector2 t2;

  GraphBezierControlPoint clone() => GraphBezierControlPoint(
    t1: t1.clone(),
    pos: pos.clone(),
    t2: t2.clone(),
  );

  factory GraphBezierControlPoint.fromJson(Map<String, dynamic> json) {
    return GraphBezierControlPoint(
      t1: _vector2FromJson(json['t1']),
      pos: _vector2FromJson(json['pos']),
      t2: _vector2FromJson(json['t2']),
    );
  }

  Map<String, dynamic> toJson() => {
    't1': _vector2ToJson(t1),
    'pos': _vector2ToJson(pos),
    't2': _vector2ToJson(t2),
  };
}

class GraphBezierSpline {
  const GraphBezierSpline({required this.points});

  final List<GraphBezierControlPoint> points;

  factory GraphBezierSpline.identity() {
    return GraphBezierSpline(
      points: [
        GraphBezierControlPoint(
          t1: Vector2.zero(),
          pos: Vector2.zero(),
          t2: Vector2.zero(),
        ),
        GraphBezierControlPoint(
          t1: Vector2.all(1),
          pos: Vector2.all(1),
          t2: Vector2.all(1),
        ),
      ],
    );
  }

  GraphBezierSpline clone() => GraphBezierSpline(
    points: points.map((point) => point.clone()).toList(growable: false),
  );

  factory GraphBezierSpline.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    if (rawPoints is! List) {
      return GraphBezierSpline.identity();
    }

    return GraphBezierSpline(
      points: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(GraphBezierControlPoint.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'points': points.map((point) => point.toJson()).toList(growable: false),
  };
}

class GraphColorCurveData {
  const GraphColorCurveData({
    required this.lum,
    required this.red,
    required this.green,
    required this.blue,
    required this.alpha,
  });

  final GraphBezierSpline lum;
  final GraphBezierSpline red;
  final GraphBezierSpline green;
  final GraphBezierSpline blue;
  final GraphBezierSpline alpha;

  factory GraphColorCurveData.identity() {
    return GraphColorCurveData(
      lum: GraphBezierSpline.identity(),
      red: GraphBezierSpline.identity(),
      green: GraphBezierSpline.identity(),
      blue: GraphBezierSpline.identity(),
      alpha: GraphBezierSpline.identity(),
    );
  }

  GraphColorCurveData clone() => GraphColorCurveData(
    lum: lum.clone(),
    red: red.clone(),
    green: green.clone(),
    blue: blue.clone(),
    alpha: alpha.clone(),
  );

  factory GraphColorCurveData.fromJson(Map<String, dynamic> json) {
    return GraphColorCurveData(
      lum: _splineFromJson(json['lum']),
      red: _splineFromJson(json['red']),
      green: _splineFromJson(json['green']),
      blue: _splineFromJson(json['blue']),
      alpha: _splineFromJson(json['alpha']),
    );
  }

  Map<String, dynamic> toJson() => {
    'lum': lum.toJson(),
    'red': red.toJson(),
    'green': green.toJson(),
    'blue': blue.toJson(),
    'alpha': alpha.toJson(),
  };
}

class GraphPropertyDefinition {
  const GraphPropertyDefinition({
    required this.key,
    required this.label,
    required this.description,
    required this.propertyType,
    required this.socket,
    required this.valueType,
    required this.valueUnit,
    required this.defaultValue,
    this.isEditable = false,
    this.min,
    this.max,
    this.step,
    this.enumOptions = const <EnumChoiceOption>[],
  });

  final String key;
  final String label;
  final String description;
  final GraphPropertyType propertyType;
  final bool socket;
  final GraphValueType valueType;
  final GraphValueUnit valueUnit;
  final Object defaultValue;
  final bool isEditable;
  final num? min;
  final num? max;
  final double? step;
  final List<EnumChoiceOption> enumOptions;

  bool get isSocket => socket;

  bool get isColor =>
      valueType == GraphValueType.float4 &&
      valueUnit == GraphValueUnit.color;

  GraphSocketDirection? get socketDirection {
    if (!socket) {
      return null;
    }

    switch (propertyType) {
      case GraphPropertyType.input:
        return GraphSocketDirection.input;
      case GraphPropertyType.output:
        return GraphSocketDirection.output;
      case GraphPropertyType.descriptor:
        return null;
    }
  }
}

class GraphNodeSchema {
  const GraphNodeSchema({
    required this.id,
    required this.label,
    required this.description,
    required this.properties,
  });

  final String id;
  final String label;
  final String description;
  final List<GraphPropertyDefinition> properties;

  GraphPropertyDefinition propertyDefinition(String key) {
    return properties.firstWhere((property) => property.key == key);
  }
}

List<int> asIntVector(Object value) =>
    List<int>.unmodifiable(List<int>.from(value as List<dynamic>));

Vector2 asVector2(Object value) => (value as Vector2).clone();

Vector3 asVector3(Object value) => (value as Vector3).clone();

Vector4 asVector4(Object value) => (value as Vector4).clone();

GraphColorCurveData asColorCurve(Object value) =>
    (value as GraphColorCurveData).clone();

Map<String, dynamic> _vector2ToJson(Vector2 value) => {
  'x': value.x,
  'y': value.y,
};

Vector2 _vector2FromJson(Object? json) {
  if (json is List) {
    return Vector2(
      _numAt(json, 0),
      _numAt(json, 1),
    );
  }

  if (json is Map<String, dynamic>) {
    return Vector2(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  return Vector2.zero();
}

GraphBezierSpline _splineFromJson(Object? json) {
  if (json is Map<String, dynamic>) {
    return GraphBezierSpline.fromJson(json);
  }

  return GraphBezierSpline.identity();
}

double _numAt(List<dynamic> values, int index, {double fallback = 0}) {
  if (index < 0 || index >= values.length) {
    return fallback;
  }

  final value = values[index];
  if (value is num) {
    return value.toDouble();
  }

  return fallback;
}

