// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'graph_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GraphNodePropertyData _$GraphNodePropertyDataFromJson(
  Map<String, dynamic> json,
) => GraphNodePropertyData(
  id: json['id'] as String,
  definitionKey: json['definitionKey'] as String,
  value: GraphValueData.fromJson(json['value'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GraphNodePropertyDataToJson(
  GraphNodePropertyData instance,
) => <String, dynamic>{
  'id': instance.id,
  'definitionKey': instance.definitionKey,
  'value': instance.value.toJson(),
};

GraphNodeDocument _$GraphNodeDocumentFromJson(Map<String, dynamic> json) =>
    GraphNodeDocument(
      id: json['id'] as String,
      definitionId: json['definitionId'] as String,
      name: json['name'] as String,
      position: const Vector2JsonConverter().fromJson(json['position']),
      properties: (json['properties'] as List<dynamic>)
          .map((e) => GraphNodePropertyData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GraphNodeDocumentToJson(GraphNodeDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'definitionId': instance.definitionId,
      'name': instance.name,
      'position': const Vector2JsonConverter().toJson(instance.position),
      'properties': instance.properties.map((e) => e.toJson()).toList(),
    };

GraphLinkDocument _$GraphLinkDocumentFromJson(Map<String, dynamic> json) =>
    GraphLinkDocument(
      id: json['id'] as String,
      fromNodeId: json['fromNodeId'] as String,
      fromPropertyId: json['fromPropertyId'] as String,
      toNodeId: json['toNodeId'] as String,
      toPropertyId: json['toPropertyId'] as String,
    );

Map<String, dynamic> _$GraphLinkDocumentToJson(GraphLinkDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromNodeId': instance.fromNodeId,
      'fromPropertyId': instance.fromPropertyId,
      'toNodeId': instance.toNodeId,
      'toPropertyId': instance.toPropertyId,
    };

GraphItemDocument _$GraphItemDocumentFromJson(Map<String, dynamic> json) =>
    GraphItemDocument(
      id: json['id'] as String,
      position: const Vector2JsonConverter().fromJson(json['position']),
      isVisible: json['isVisible'] as bool? ?? true,
    );

Map<String, dynamic> _$GraphItemDocumentToJson(GraphItemDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'position': const Vector2JsonConverter().toJson(instance.position),
      'isVisible': instance.isVisible,
    };

GraphDocument _$GraphDocumentFromJson(Map<String, dynamic> json) =>
    GraphDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => GraphNodeDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      links: (json['links'] as List<dynamic>)
          .map((e) => GraphLinkDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      graphItems:
          (json['graphItems'] as List<dynamic>?)
              ?.map(
                (e) => GraphItemDocument.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <GraphItemDocument>[],
    );

Map<String, dynamic> _$GraphDocumentToJson(GraphDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
      'links': instance.links.map((e) => e.toJson()).toList(),
      'graphItems': instance.graphItems.map((e) => e.toJson()).toList(),
    };
