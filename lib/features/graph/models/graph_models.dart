import 'package:json_annotation/json_annotation.dart';
import 'package:vector_math/vector_math.dart';

import '../../../shared/serialization/vector_json_converters.dart';
import 'graph_schema.dart';

part 'graph_models.g.dart';

@JsonSerializable()
class GraphValueData {
  const GraphValueData({
    required this.valueType,
    this.scalarValue,
    this.enumValue,
    this.colorValue,
  });

  const GraphValueData.scalar(double value)
    : this(valueType: GraphValueType.scalar, scalarValue: value);

  const GraphValueData.enumChoice(int value)
    : this(valueType: GraphValueType.enumChoice, enumValue: value);

  @Vector4JsonConverter()
  const GraphValueData.color(Vector4 value)
    : this(valueType: GraphValueType.color, colorValue: value);

  final GraphValueType valueType;
  final double? scalarValue;
  final int? enumValue;

  @Vector4JsonConverter()
  final Vector4? colorValue;

  factory GraphValueData.fromJson(Map<String, dynamic> json) =>
      _$GraphValueDataFromJson(json);

  Map<String, dynamic> toJson() => _$GraphValueDataToJson(this);

  Object unwrap() {
    switch (valueType) {
      case GraphValueType.scalar:
        return scalarValue ?? 0;
      case GraphValueType.enumChoice:
        return enumValue ?? 0;
      case GraphValueType.color:
        return (colorValue ?? Vector4.zero()).clone();
    }
  }
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

  factory GraphDocument.empty({
    required String id,
    required String name,
  }) {
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
