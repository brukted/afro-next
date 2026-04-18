import 'package:json_annotation/json_annotation.dart';
import 'package:vector_math/vector_math.dart';

import '../../../shared/serialization/vector_json_converters.dart';
import 'graph_schema.dart';

part 'graph_models.g.dart';

class GraphValueData {
  const GraphValueData({
    required this.valueType,
    this.integerValue,
    this.integerValues,
    this.floatValue,
    this.floatValues,
    this.stringValue,
    this.boolValue,
    this.enumValue,
    this.curveValue,
  });

  const GraphValueData.integer(int value)
    : this(valueType: GraphValueType.integer, integerValue: value);

  GraphValueData.integer2(List<int> value)
    : this(
        valueType: GraphValueType.integer2,
        integerValues: List<int>.unmodifiable(List<int>.from(value)),
      );

  GraphValueData.integer3(List<int> value)
    : this(
        valueType: GraphValueType.integer3,
        integerValues: List<int>.unmodifiable(List<int>.from(value)),
      );

  GraphValueData.integer4(List<int> value)
    : this(
        valueType: GraphValueType.integer4,
        integerValues: List<int>.unmodifiable(List<int>.from(value)),
      );

  const GraphValueData.float(double value)
    : this(valueType: GraphValueType.float, floatValue: value);

  GraphValueData.float2(Vector2 value)
    : this(
        valueType: GraphValueType.float2,
        floatValues: List<double>.unmodifiable([value.x, value.y]),
      );

  GraphValueData.float3(Vector3 value)
    : this(
        valueType: GraphValueType.float3,
        floatValues: List<double>.unmodifiable([value.x, value.y, value.z]),
      );

  GraphValueData.float4(Vector4 value)
    : this(
        valueType: GraphValueType.float4,
        floatValues: List<double>.unmodifiable([
          value.x,
          value.y,
          value.z,
          value.w,
        ]),
      );

  const GraphValueData.stringValue(String value)
    : this(valueType: GraphValueType.stringValue, stringValue: value);

  const GraphValueData.boolean(bool value)
    : this(valueType: GraphValueType.boolean, boolValue: value);

  const GraphValueData.enumChoice(int value)
    : this(valueType: GraphValueType.enumChoice, enumValue: value);

  GraphValueData.colorCurve(GraphColorCurveData value)
    : this(
        valueType: GraphValueType.colorBezierCurve,
        curveValue: value.clone(),
      );

  final GraphValueType valueType;
  final int? integerValue;
  final List<int>? integerValues;
  final double? floatValue;
  final List<double>? floatValues;
  final String? stringValue;
  final bool? boolValue;
  final int? enumValue;
  final GraphColorCurveData? curveValue;

  factory GraphValueData.fromJson(Map<String, dynamic> json) {
    final rawType = json['valueType'] as String?;
    switch (rawType) {
      case 'scalar':
        return GraphValueData.float(
          (json['scalarValue'] as num?)?.toDouble() ?? 0,
        );
      case 'color':
        return GraphValueData.float4(_vector4FromJson(json['colorValue']));
      case 'enumChoice':
        return GraphValueData.enumChoice(
          (json['enumValue'] as num?)?.toInt() ?? 0,
        );
      case 'integer':
        return GraphValueData.integer(
          (json['integerValue'] as num?)?.toInt() ?? 0,
        );
      case 'integer2':
        return GraphValueData.integer2(
          _intListFromJson(json['integerValues'], 2),
        );
      case 'integer3':
        return GraphValueData.integer3(
          _intListFromJson(json['integerValues'], 3),
        );
      case 'integer4':
        return GraphValueData.integer4(
          _intListFromJson(json['integerValues'], 4),
        );
      case 'float':
        return GraphValueData.float(
          (json['floatValue'] as num?)?.toDouble() ?? 0,
        );
      case 'float2':
        return GraphValueData.float2(_vector2FromJson(json['floatValues']));
      case 'float3':
        return GraphValueData.float3(_vector3FromJson(json['floatValues']));
      case 'float4':
        return GraphValueData.float4(_vector4FromJson(json['floatValues']));
      case 'stringValue':
        return GraphValueData.stringValue(json['stringValue'] as String? ?? '');
      case 'boolean':
        return GraphValueData.boolean(json['boolValue'] as bool? ?? false);
      case 'colorBezierCurve':
        final rawCurve = json['curveValue'];
        return GraphValueData.colorCurve(
          rawCurve is Map<String, dynamic>
              ? GraphColorCurveData.fromJson(rawCurve)
              : GraphColorCurveData.identity(),
        );
      default:
        return GraphValueData.float(0);
    }
  }

  Map<String, dynamic> toJson() {
    return switch (valueType) {
      GraphValueType.integer => {
        'valueType': 'integer',
        'integerValue': integerValue ?? 0,
      },
      GraphValueType.integer2 => {
        'valueType': 'integer2',
        'integerValues': _trimOrPadInts(integerValues, 2),
      },
      GraphValueType.integer3 => {
        'valueType': 'integer3',
        'integerValues': _trimOrPadInts(integerValues, 3),
      },
      GraphValueType.integer4 => {
        'valueType': 'integer4',
        'integerValues': _trimOrPadInts(integerValues, 4),
      },
      GraphValueType.float => {
        'valueType': 'float',
        'floatValue': floatValue ?? 0,
      },
      GraphValueType.float2 => {
        'valueType': 'float2',
        'floatValues': _trimOrPadDoubles(floatValues, 2),
      },
      GraphValueType.float3 => {
        'valueType': 'float3',
        'floatValues': _trimOrPadDoubles(floatValues, 3),
      },
      GraphValueType.float4 => {
        'valueType': 'float4',
        'floatValues': _trimOrPadDoubles(floatValues, 4, fallback: 1),
      },
      GraphValueType.stringValue => {
        'valueType': 'stringValue',
        'stringValue': stringValue ?? '',
      },
      GraphValueType.boolean => {
        'valueType': 'boolean',
        'boolValue': boolValue ?? false,
      },
      GraphValueType.enumChoice => {
        'valueType': 'enumChoice',
        'enumValue': enumValue ?? 0,
      },
      GraphValueType.colorBezierCurve => {
        'valueType': 'colorBezierCurve',
        'curveValue': (curveValue ?? GraphColorCurveData.identity()).toJson(),
      },
    };
  }

  GraphValueData deepCopy() {
    switch (valueType) {
      case GraphValueType.integer:
        return GraphValueData.integer(integerValue ?? 0);
      case GraphValueType.integer2:
        return GraphValueData.integer2(integerValues ?? const <int>[0, 0]);
      case GraphValueType.integer3:
        return GraphValueData.integer3(integerValues ?? const <int>[0, 0, 0]);
      case GraphValueType.integer4:
        return GraphValueData.integer4(
          integerValues ?? const <int>[0, 0, 0, 0],
        );
      case GraphValueType.float:
        return GraphValueData.float(floatValue ?? 0);
      case GraphValueType.float2:
        return GraphValueData.float2(asFloat2());
      case GraphValueType.float3:
        return GraphValueData.float3(asFloat3());
      case GraphValueType.float4:
        return GraphValueData.float4(asFloat4());
      case GraphValueType.stringValue:
        return GraphValueData.stringValue(stringValue ?? '');
      case GraphValueType.boolean:
        return GraphValueData.boolean(boolValue ?? false);
      case GraphValueType.enumChoice:
        return GraphValueData.enumChoice(enumValue ?? 0);
      case GraphValueType.colorBezierCurve:
        return GraphValueData.colorCurve(
          (curveValue ?? GraphColorCurveData.identity()).clone(),
        );
    }
  }

  Object unwrap() {
    switch (valueType) {
      case GraphValueType.integer:
        return integerValue ?? 0;
      case GraphValueType.integer2:
      case GraphValueType.integer3:
      case GraphValueType.integer4:
        return List<int>.unmodifiable(integerValues ?? const <int>[]);
      case GraphValueType.float:
        return floatValue ?? 0;
      case GraphValueType.float2:
        return asFloat2();
      case GraphValueType.float3:
        return asFloat3();
      case GraphValueType.float4:
        return asFloat4();
      case GraphValueType.stringValue:
        return stringValue ?? '';
      case GraphValueType.boolean:
        return boolValue ?? false;
      case GraphValueType.enumChoice:
        return enumValue ?? 0;
      case GraphValueType.colorBezierCurve:
        return (curveValue ?? GraphColorCurveData.identity()).clone();
    }
  }

  Vector2 asFloat2() => _vector2FromJson(floatValues);

  Vector3 asFloat3() => _vector3FromJson(floatValues);

  Vector4 asFloat4() => _vector4FromJson(floatValues);
}

Vector2 _vector2FromJson(Object? json) {
  final values = _doubleListFromJson(json, 2);
  return Vector2(values[0], values[1]);
}

Vector3 _vector3FromJson(Object? json) {
  final values = _doubleListFromJson(json, 3);
  return Vector3(values[0], values[1], values[2]);
}

Vector4 _vector4FromJson(Object? json) {
  final values = _doubleListFromJson(json, 4, fallback: 1);
  return Vector4(values[0], values[1], values[2], values[3]);
}

List<int> _intListFromJson(Object? json, int expectedLength) {
  final source = json is List ? json : const <dynamic>[];
  return List<int>.unmodifiable(
    List<int>.generate(expectedLength, (index) {
      if (index >= source.length) {
        return 0;
      }

      final value = source[index];
      return value is num ? value.toInt() : 0;
    }),
  );
}

List<double> _doubleListFromJson(
  Object? json,
  int expectedLength, {
  double fallback = 0,
}) {
  final source = json is List ? json : const <dynamic>[];
  return List<double>.unmodifiable(
    List<double>.generate(expectedLength, (index) {
      if (index >= source.length) {
        return fallback;
      }

      final value = source[index];
      return value is num ? value.toDouble() : fallback;
    }),
  );
}

List<int> _trimOrPadInts(List<int>? values, int expectedLength) {
  return _intListFromJson(values, expectedLength);
}

List<double> _trimOrPadDoubles(
  List<double>? values,
  int expectedLength, {
  double fallback = 0,
}) {
  return _doubleListFromJson(values, expectedLength, fallback: fallback);
}

@JsonSerializable(explicitToJson: true)
class GraphNodePropertyData {
  const GraphNodePropertyData({
    required this.id,
    required this.definitionKey,
    required this.value,
  });

  final String id;
  final String definitionKey;
  final GraphValueData value;

  GraphNodePropertyData copyWith({
    String? id,
    String? definitionKey,
    GraphValueData? value,
  }) {
    return GraphNodePropertyData(
      id: id ?? this.id,
      definitionKey: definitionKey ?? this.definitionKey,
      value: value ?? this.value,
    );
  }

  factory GraphNodePropertyData.fromJson(Map<String, dynamic> json) =>
      _$GraphNodePropertyDataFromJson(json);

  Map<String, dynamic> toJson() => _$GraphNodePropertyDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GraphNodeDocument {
  const GraphNodeDocument({
    required this.id,
    required this.definitionId,
    required this.name,
    required this.position,
    required this.properties,
  });

  final String id;
  final String definitionId;
  final String name;

  @Vector2JsonConverter()
  final Vector2 position;

  final List<GraphNodePropertyData> properties;

  GraphNodeDocument copyWith({
    String? id,
    String? definitionId,
    String? name,
    Vector2? position,
    List<GraphNodePropertyData>? properties,
  }) {
    return GraphNodeDocument(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      name: name ?? this.name,
      position: position ?? this.position,
      properties: properties ?? this.properties,
    );
  }

  GraphNodePropertyData? propertyById(String propertyId) {
    for (final property in properties) {
      if (property.id == propertyId) {
        return property;
      }
    }

    return null;
  }

  GraphNodePropertyData? propertyByDefinitionKey(String key) {
    for (final property in properties) {
      if (property.definitionKey == key) {
        return property;
      }
    }

    return null;
  }

  factory GraphNodeDocument.fromJson(Map<String, dynamic> json) =>
      _$GraphNodeDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$GraphNodeDocumentToJson(this);
}

@JsonSerializable()
class GraphLinkDocument {
  const GraphLinkDocument({
    required this.id,
    required this.fromNodeId,
    required this.fromPropertyId,
    required this.toNodeId,
    required this.toPropertyId,
  });

  final String id;
  final String fromNodeId;
  final String fromPropertyId;
  final String toNodeId;
  final String toPropertyId;

  factory GraphLinkDocument.fromJson(Map<String, dynamic> json) =>
      _$GraphLinkDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$GraphLinkDocumentToJson(this);
}

@JsonSerializable()
class GraphItemDocument {
  const GraphItemDocument({
    required this.id,
    required this.position,
    this.isVisible = true,
  });

  final String id;

  @Vector2JsonConverter()
  final Vector2 position;

  final bool isVisible;

  factory GraphItemDocument.fromJson(Map<String, dynamic> json) =>
      _$GraphItemDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$GraphItemDocumentToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GraphDocument {
  const GraphDocument({
    required this.id,
    required this.name,
    required this.nodes,
    required this.links,
    this.graphItems = const <GraphItemDocument>[],
  });

  factory GraphDocument.empty({required String id, required String name}) {
    return GraphDocument(id: id, name: name, nodes: const [], links: const []);
  }

  final String id;
  final String name;
  final List<GraphNodeDocument> nodes;
  final List<GraphLinkDocument> links;
  final List<GraphItemDocument> graphItems;

  GraphDocument copyWith({
    String? id,
    String? name,
    List<GraphNodeDocument>? nodes,
    List<GraphLinkDocument>? links,
    List<GraphItemDocument>? graphItems,
  }) {
    return GraphDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      nodes: nodes ?? this.nodes,
      links: links ?? this.links,
      graphItems: graphItems ?? this.graphItems,
    );
  }

  factory GraphDocument.fromJson(Map<String, dynamic> json) =>
      _$GraphDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$GraphDocumentToJson(this);
}
