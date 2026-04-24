import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

import '../graph/models/graph_schema.dart';

enum MaterialNodeExecutionKind { fragment, compute }

enum MaterialNodeKind { effect, input }

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
    this.kind = MaterialNodeKind.effect,
    this.primaryInputPropertyKey,
    this.inputValuePropertyKey,
    this.inputResourcePropertyKey,
  });

  final GraphNodeSchema schema;
  final IconData icon;
  final Vector4 accentColor;
  final MaterialNodeRuntimeDefinition runtime;
  final MaterialNodeKind kind;
  final String? primaryInputPropertyKey;
  final String? inputValuePropertyKey;
  final String? inputResourcePropertyKey;

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

  bool get isGraphInput => kind == MaterialNodeKind.input;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
