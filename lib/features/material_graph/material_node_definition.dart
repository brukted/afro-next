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

  MaterialNodeDefinition copyWith({
    GraphNodeSchema? schema,
    IconData? icon,
    Vector4? accentColor,
    MaterialNodeRuntimeDefinition? runtime,
    MaterialNodeKind? kind,
    Object? primaryInputPropertyKey = _materialNodeDefinitionUndefined,
    Object? inputValuePropertyKey = _materialNodeDefinitionUndefined,
    Object? inputResourcePropertyKey = _materialNodeDefinitionUndefined,
  }) {
    return MaterialNodeDefinition(
      schema: schema ?? this.schema,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      runtime: runtime ?? this.runtime,
      kind: kind ?? this.kind,
      primaryInputPropertyKey:
          identical(primaryInputPropertyKey, _materialNodeDefinitionUndefined)
          ? this.primaryInputPropertyKey
          : primaryInputPropertyKey as String?,
      inputValuePropertyKey:
          identical(inputValuePropertyKey, _materialNodeDefinitionUndefined)
          ? this.inputValuePropertyKey
          : inputValuePropertyKey as String?,
      inputResourcePropertyKey:
          identical(inputResourcePropertyKey, _materialNodeDefinitionUndefined)
          ? this.inputResourcePropertyKey
          : inputResourcePropertyKey as String?,
    );
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

const Object _materialNodeDefinitionUndefined = Object();
