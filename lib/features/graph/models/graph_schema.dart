import 'package:bezier/bezier.dart';
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
  float3x3,
  stringValue,
  workspaceResource,
  boolean,
  enumChoice,
  gradient,
  colorBezierCurve,
  textBlock,
}

enum GraphValueUnit { none, rotation, position, power2, color, path }

enum GraphPropertyType { input, output, descriptor }

enum GraphSocketDirection { input, output }

enum GraphSocketTransport { value, texture }

enum GraphCurveChannel { luminance, red, green, blue, alpha }

enum GraphResourceKind { image, svg, mathGraph, materialGraph }

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

  GraphBezierControlPoint clone() =>
      GraphBezierControlPoint(t1: t1.clone(), pos: pos.clone(), t2: t2.clone());

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

class GraphBezierSegment {
  const GraphBezierSegment({required this.start, required this.end});

  final GraphBezierControlPoint start;
  final GraphBezierControlPoint end;

  CubicBezier toBezier() {
    return CubicBezier([
      start.pos.clone(),
      start.t2.clone(),
      end.t1.clone(),
      end.pos.clone(),
    ]);
  }
}

class GraphBezierSpline {
  const GraphBezierSpline({required this.points});

  final List<GraphBezierControlPoint> points;
  static const double epsilon = 1e-5;

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

  bool get hasEditableInteriorPoints => points.length > 2;

  List<GraphBezierSegment> get segments {
    final normalized = validated();
    if (normalized.points.length < 2) {
      return const <GraphBezierSegment>[];
    }

    return List<GraphBezierSegment>.generate(
      normalized.points.length - 1,
      (index) => GraphBezierSegment(
        start: normalized.points[index],
        end: normalized.points[index + 1],
      ),
      growable: false,
    );
  }

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

  GraphBezierSpline sort() {
    final sortedPoints =
        points.map((point) => point.clone()).toList(growable: true)
          ..sort((left, right) => left.pos.x.compareTo(right.pos.x));
    return GraphBezierSpline(points: sortedPoints);
  }

  GraphBezierSpline validated() {
    final sorted = sort().points;
    if (sorted.length < 2) {
      return GraphBezierSpline.identity();
    }

    final normalizedPoints = List<GraphBezierControlPoint>.from(
      sorted.map((point) => point.clone()),
      growable: true,
    );

    final first = normalizedPoints.first;
    final second = normalizedPoints[1];
    final firstPos = Vector2(
      _clamp(first.pos.x, 0, second.pos.x),
      _clamp(first.pos.y, 0, 1),
    );
    normalizedPoints[0] = GraphBezierControlPoint(
      t1: firstPos.clone(),
      pos: firstPos,
      t2: Vector2(
        _clamp(first.t2.x, firstPos.x, second.pos.x),
        _clamp(first.t2.y, 0, 1),
      ),
    );

    for (var index = 1; index < normalizedPoints.length - 1; index += 1) {
      final previous = normalizedPoints[index - 1];
      final current = normalizedPoints[index];
      final next = normalizedPoints[index + 1];
      final position = Vector2(
        _clamp(current.pos.x, previous.pos.x, next.pos.x),
        _clamp(current.pos.y, 0, 1),
      );
      normalizedPoints[index] = GraphBezierControlPoint(
        t1: Vector2(
          _clamp(current.t1.x, previous.pos.x, position.x),
          _clamp(current.t1.y, 0, 1),
        ),
        pos: position,
        t2: Vector2(
          _clamp(current.t2.x, position.x, next.pos.x),
          _clamp(current.t2.y, 0, 1),
        ),
      );
    }

    final penultimate = normalizedPoints[normalizedPoints.length - 2];
    final last = normalizedPoints.last;
    final lastPos = Vector2(
      _clamp(last.pos.x, penultimate.pos.x, 1),
      _clamp(last.pos.y, 0, 1),
    );
    normalizedPoints[normalizedPoints.length - 1] = GraphBezierControlPoint(
      t1: Vector2(
        _clamp(last.t1.x, penultimate.pos.x, lastPos.x),
        _clamp(last.t1.y, 0, 1),
      ),
      pos: lastPos,
      t2: lastPos.clone(),
    );

    return GraphBezierSpline(points: normalizedPoints);
  }

  List<Vector2> samplePoints({int samplesPerSegment = 24}) {
    final normalized = validated();
    final segments = normalized.segments;
    if (segments.isEmpty) {
      return [Vector2.zero(), Vector2.all(1)];
    }

    final points = <Vector2>[];
    for (
      var segmentIndex = 0;
      segmentIndex < segments.length;
      segmentIndex += 1
    ) {
      final curve = segments[segmentIndex].toBezier();
      for (
        var sampleIndex = 0;
        sampleIndex <= samplesPerSegment;
        sampleIndex += 1
      ) {
        if (segmentIndex > 0 && sampleIndex == 0) {
          continue;
        }

        final point = curve.pointAt(sampleIndex / samplesPerSegment);
        points.add(Vector2(point.x, point.y));
      }
    }

    return List<Vector2>.unmodifiable(points);
  }

  double valueAt(double x) {
    final normalized = validated();
    if (normalized.points.length < 2) {
      return x.clamp(0, 1).toDouble();
    }

    final clampedX = _clamp(
      x,
      normalized.points.first.pos.x,
      normalized.points.last.pos.x,
    );
    final segmentIndex = normalized._segmentIndexForX(clampedX);
    if (segmentIndex == null) {
      return normalized.points.last.pos.y;
    }

    final curve = normalized.segments[segmentIndex].toBezier();
    final t = normalized._solveTForX(curve, clampedX);
    return curve.pointAt(t).y.clamp(0, 1).toDouble();
  }

  GraphBezierSpline splitAt(double x) {
    final normalized = validated();
    if (normalized.points.length < 2) {
      return GraphBezierSpline.identity();
    }

    final minX = normalized.points.first.pos.x;
    final maxX = normalized.points.last.pos.x;
    final clampedX = _clamp(x, minX, maxX);
    if (normalized.points.any(
      (point) => (point.pos.x - clampedX).abs() <= epsilon,
    )) {
      return normalized;
    }

    final segmentIndex = normalized._segmentIndexForX(clampedX);
    if (segmentIndex == null) {
      return normalized;
    }

    final curve = normalized.segments[segmentIndex].toBezier();
    final t = normalized._solveTForX(curve, clampedX);
    if (t <= epsilon || t >= 1 - epsilon) {
      return normalized;
    }

    final leftCurve = curve.leftSubcurveAt(t) as CubicBezier;
    final rightCurve = curve.rightSubcurveAt(t) as CubicBezier;
    final updatedPoints = List<GraphBezierControlPoint>.from(
      normalized.points.map((point) => point.clone()),
      growable: true,
    );
    final originalLeft = updatedPoints[segmentIndex];
    final originalRight = updatedPoints[segmentIndex + 1];

    updatedPoints[segmentIndex] = GraphBezierControlPoint(
      t1: originalLeft.t1.clone(),
      pos: originalLeft.pos.clone(),
      t2: leftCurve.points[1].clone(),
    );
    updatedPoints[segmentIndex + 1] = GraphBezierControlPoint(
      t1: rightCurve.points[2].clone(),
      pos: originalRight.pos.clone(),
      t2: originalRight.t2.clone(),
    );
    updatedPoints.insert(
      segmentIndex + 1,
      GraphBezierControlPoint(
        t1: leftCurve.points[2].clone(),
        pos: leftCurve.points[3].clone(),
        t2: rightCurve.points[1].clone(),
      ),
    );

    return GraphBezierSpline(points: updatedPoints).validated();
  }

  GraphBezierSpline moveAnchor(int index, Vector2 nextPosition) {
    if (index <= 0 || index >= points.length - 1) {
      return validated();
    }

    final updatedPoints = List<GraphBezierControlPoint>.from(
      validated().points.map((point) => point.clone()),
      growable: true,
    );
    final current = updatedPoints[index];
    final delta = nextPosition - current.pos;
    updatedPoints[index] = GraphBezierControlPoint(
      t1: current.t1 + delta,
      pos: nextPosition.clone(),
      t2: current.t2 + delta,
    );

    return GraphBezierSpline(points: updatedPoints).validated();
  }

  GraphBezierSpline moveIncomingTangent(int index, Vector2 nextPosition) {
    if (index <= 0 || index >= points.length) {
      return validated();
    }

    final updatedPoints = List<GraphBezierControlPoint>.from(
      validated().points.map((point) => point.clone()),
      growable: true,
    );
    final current = updatedPoints[index];
    updatedPoints[index] = GraphBezierControlPoint(
      t1: nextPosition.clone(),
      pos: current.pos.clone(),
      t2: current.t2.clone(),
    );
    return GraphBezierSpline(points: updatedPoints).validated();
  }

  GraphBezierSpline moveOutgoingTangent(int index, Vector2 nextPosition) {
    if (index < 0 || index >= points.length - 1) {
      return validated();
    }

    final updatedPoints = List<GraphBezierControlPoint>.from(
      validated().points.map((point) => point.clone()),
      growable: true,
    );
    final current = updatedPoints[index];
    updatedPoints[index] = GraphBezierControlPoint(
      t1: current.t1.clone(),
      pos: current.pos.clone(),
      t2: nextPosition.clone(),
    );
    return GraphBezierSpline(points: updatedPoints).validated();
  }

  GraphBezierSpline removePoint(int index) {
    if (index <= 0 || index >= points.length - 1) {
      return validated();
    }

    final updatedPoints = List<GraphBezierControlPoint>.from(
      validated().points.map((point) => point.clone()),
      growable: true,
    )..removeAt(index);
    return GraphBezierSpline(points: updatedPoints).validated();
  }

  int? _segmentIndexForX(double x) {
    final normalizedPoints = points;
    for (var index = 0; index < normalizedPoints.length - 1; index += 1) {
      final left = normalizedPoints[index].pos.x;
      final right = normalizedPoints[index + 1].pos.x;
      if (x >= left && x <= right) {
        return index;
      }
    }
    return null;
  }

  double _solveTForX(CubicBezier curve, double x) {
    var low = 0.0;
    var high = 1.0;
    for (var iteration = 0; iteration < 32; iteration += 1) {
      final mid = (low + high) * 0.5;
      final point = curve.pointAt(mid);
      if (point.x < x) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) * 0.5;
  }
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

  GraphBezierSpline splineFor(GraphCurveChannel channel) {
    return switch (channel) {
      GraphCurveChannel.luminance => lum,
      GraphCurveChannel.red => red,
      GraphCurveChannel.green => green,
      GraphCurveChannel.blue => blue,
      GraphCurveChannel.alpha => alpha,
    };
  }

  GraphColorCurveData copyWithSpline(
    GraphCurveChannel channel,
    GraphBezierSpline spline,
  ) {
    return GraphColorCurveData(
      lum: channel == GraphCurveChannel.luminance ? spline : lum.clone(),
      red: channel == GraphCurveChannel.red ? spline : red.clone(),
      green: channel == GraphCurveChannel.green ? spline : green.clone(),
      blue: channel == GraphCurveChannel.blue ? spline : blue.clone(),
      alpha: channel == GraphCurveChannel.alpha ? spline : alpha.clone(),
    );
  }
}

class GraphGradientStopData {
  const GraphGradientStopData({required this.position, required this.color});

  final double position;
  final Vector4 color;

  GraphGradientStopData copyWith({double? position, Vector4? color}) {
    return GraphGradientStopData(
      position: position ?? this.position,
      color: color ?? this.color,
    );
  }

  GraphGradientStopData clone() =>
      GraphGradientStopData(position: position, color: color.clone());

  factory GraphGradientStopData.fromJson(Map<String, dynamic> json) {
    return GraphGradientStopData(
      position: (json['position'] as num?)?.toDouble() ?? 0,
      color: _vector4FromJson(json['color']),
    );
  }

  Map<String, dynamic> toJson() => {
    'position': position,
    'color': _vector4ToJson(color),
  };
}

class GraphGradientData {
  const GraphGradientData({required this.stops});

  final List<GraphGradientStopData> stops;

  factory GraphGradientData.identity() {
    return GraphGradientData(
      stops: [
        GraphGradientStopData(position: 0, color: Vector4.zero()),
        GraphGradientStopData(position: 1, color: Vector4.all(1)),
      ],
    );
  }

  GraphGradientData clone() => GraphGradientData(
    stops: stops.map((entry) => entry.clone()).toList(growable: false),
  );

  GraphGradientData copyWith({List<GraphGradientStopData>? stops}) {
    return GraphGradientData(stops: stops ?? this.stops);
  }

  factory GraphGradientData.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];
    if (rawStops is! List) {
      return GraphGradientData.identity();
    }
    final stops = rawStops
        .whereType<Map<String, dynamic>>()
        .map(GraphGradientStopData.fromJson)
        .toList(growable: false);
    if (stops.length < 2) {
      return GraphGradientData.identity();
    }
    return GraphGradientData(stops: stops).normalized();
  }

  Map<String, dynamic> toJson() => {
    'stops': normalized().stops
        .map((entry) => entry.toJson())
        .toList(growable: false),
  };

  GraphGradientData normalized() {
    if (stops.isEmpty) {
      return GraphGradientData.identity();
    }
    final normalizedStops =
        stops
            .map(
              (stop) => GraphGradientStopData(
                position: stop.position.clamp(0, 1).toDouble(),
                color: Vector4(
                  stop.color.x.clamp(0, 1).toDouble(),
                  stop.color.y.clamp(0, 1).toDouble(),
                  stop.color.z.clamp(0, 1).toDouble(),
                  stop.color.w.clamp(0, 1).toDouble(),
                ),
              ),
            )
            .toList(growable: true)
          ..sort((left, right) => left.position.compareTo(right.position));
    if (normalizedStops.length == 1) {
      normalizedStops.add(
        GraphGradientStopData(
          position: 1,
          color: normalizedStops.first.color.clone(),
        ),
      );
    }
    return GraphGradientData(
      stops: List<GraphGradientStopData>.unmodifiable(normalizedStops),
    );
  }
}

class GraphTextData {
  const GraphTextData({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final Vector4 backgroundColor;
  final Vector4 textColor;

  factory GraphTextData.defaults() {
    return GraphTextData(
      text: 'Text',
      fontFamily: 'Helvetica',
      fontSize: 36,
      backgroundColor: Vector4.zero(),
      textColor: Vector4.all(1),
    );
  }

  GraphTextData clone() => GraphTextData(
    text: text,
    fontFamily: fontFamily,
    fontSize: fontSize,
    backgroundColor: backgroundColor.clone(),
    textColor: textColor.clone(),
  );

  GraphTextData copyWith({
    String? text,
    String? fontFamily,
    double? fontSize,
    Vector4? backgroundColor,
    Vector4? textColor,
  }) {
    return GraphTextData(
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
    );
  }

  factory GraphTextData.fromJson(Map<String, dynamic> json) {
    return GraphTextData(
      text: json['text'] as String? ?? 'Text',
      fontFamily: json['fontFamily'] as String? ?? 'Helvetica',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 36,
      backgroundColor: _vector4FromJson(json['backgroundColor']),
      textColor: _vector4FromJson(json['textColor']),
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'backgroundColor': _vector4ToJson(backgroundColor),
    'textColor': _vector4ToJson(textColor),
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
    this.runtimeTextureBindingKey,
    this.resourceKinds = const <GraphResourceKind>[],
    this.socketTransport = GraphSocketTransport.value,
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
  final String? runtimeTextureBindingKey;
  final List<GraphResourceKind> resourceKinds;
  final GraphSocketTransport socketTransport;

  bool get isSocket => socket;

  bool get isColor =>
      valueUnit == GraphValueUnit.color &&
      (valueType == GraphValueType.float3 ||
          valueType == GraphValueType.float4);

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

List<double> asFloat3x3(Object value) => List<double>.unmodifiable(
  List<double>.generate(9, (index) {
    final source = value is List ? value : const <dynamic>[];
    if (index >= source.length) {
      return index % 4 == 0 ? 1.0 : 0.0;
    }
    final entry = source[index];
    return entry is num ? entry.toDouble() : 0.0;
  }),
);

GraphColorCurveData asColorCurve(Object value) =>
    (value as GraphColorCurveData).clone();

String asResourceId(Object value) => value as String;

GraphGradientData asGradient(Object value) =>
    (value as GraphGradientData).clone();

GraphTextData asTextData(Object value) => (value as GraphTextData).clone();

Map<String, dynamic> _vector2ToJson(Vector2 value) => {
  'x': value.x,
  'y': value.y,
};

Map<String, dynamic> _vector4ToJson(Vector4 value) => {
  'x': value.x,
  'y': value.y,
  'z': value.z,
  'w': value.w,
};

Vector2 _vector2FromJson(Object? json) {
  if (json is List) {
    return Vector2(_numAt(json, 0), _numAt(json, 1));
  }

  if (json is Map<String, dynamic>) {
    return Vector2(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  return Vector2.zero();
}

Vector4 _vector4FromJson(Object? json) {
  if (json is List) {
    return Vector4(
      _numAt(json, 0),
      _numAt(json, 1),
      _numAt(json, 2, fallback: 0),
      _numAt(json, 3, fallback: 1),
    );
  }

  if (json is Map<String, dynamic>) {
    return Vector4(
      (json['x'] as num?)?.toDouble() ?? 0,
      (json['y'] as num?)?.toDouble() ?? 0,
      (json['z'] as num?)?.toDouble() ?? 0,
      (json['w'] as num?)?.toDouble() ?? 1,
    );
  }

  return Vector4(0, 0, 0, 1);
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

double _clamp(num value, num min, num max) {
  return value.clamp(min, max).toDouble();
}
