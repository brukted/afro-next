import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

import '../graph/models/graph_schema.dart';

enum MaterialNodeExecutionKind { fragment, compute }

class MaterialNodeRuntimeDefinition {
  const MaterialNodeRuntimeDefinition({
    required this.executionKind,
    required this.shaderAssetId,
  });

  const MaterialNodeRuntimeDefinition.fragment({required String? shaderAssetId})
    : this(
        executionKind: MaterialNodeExecutionKind.fragment,
        shaderAssetId: shaderAssetId,
      );

  final MaterialNodeExecutionKind executionKind;
  final String? shaderAssetId;
}

class MaterialNodeDefinition {
  const MaterialNodeDefinition({
    required this.schema,
    required this.icon,
    required this.accentColor,
    required this.runtime,
    this.primaryInputPropertyKey,
  });

  final GraphNodeSchema schema;
  final IconData icon;
  final Vector4 accentColor;
  final MaterialNodeRuntimeDefinition runtime;
  final String? primaryInputPropertyKey;

  String get id => schema.id;

  String get label => schema.label;

  String get description => schema.description;

  List<GraphPropertyDefinition> get properties => schema.properties;

  GraphPropertyDefinition propertyDefinition(String key) {
    return schema.propertyDefinition(key);
  }

  String? get resolvedPrimaryInputPropertyKey {
    return primaryInputPropertyKey ??
        properties
            .where(
              (property) =>
                  property.propertyType == GraphPropertyType.input &&
                  property.isSocket,
            )
            .map((property) => property.key)
            .firstOrNull;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
