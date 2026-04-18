import 'package:flutter/material.dart';

enum GraphValueType { scalar, color, enumChoice }

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

class NodePropertyDefinition {
  const NodePropertyDefinition({
    required this.key,
    required this.label,
    required this.valueType,
    required this.defaultValue,
    this.socketDirection,
    this.min,
    this.max,
    this.enumOptions = const <EnumChoiceOption>[],
  });

  final String key;
  final String label;
  final GraphValueType valueType;
  final GraphSocketDirection? socketDirection;
  final Object defaultValue;
  final double? min;
  final double? max;
  final List<EnumChoiceOption> enumOptions;

  bool get isSocket => socketDirection != null;
}

class GraphNodeDefinition {
  const GraphNodeDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.properties,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<NodePropertyDefinition> properties;

  NodePropertyDefinition propertyDefinition(String key) {
    return properties.firstWhere((property) => property.key == key);
  }
}

class GraphNodeProperty {
  const GraphNodeProperty({
    required this.id,
    required this.definitionKey,
    required this.value,
  });

  final String id;
  final String definitionKey;
  final Object value;

  GraphNodeProperty copyWith({
    String? id,
    String? definitionKey,
    Object? value,
  }) {
    return GraphNodeProperty(
      id: id ?? this.id,
      definitionKey: definitionKey ?? this.definitionKey,
      value: value ?? this.value,
    );
  }
}

class GraphNodePropertyView {
  const GraphNodePropertyView({
    required this.property,
    required this.definition,
  });

  final GraphNodeProperty property;
  final NodePropertyDefinition definition;

  String get id => property.id;

  String get label => definition.label;

  Object get value => property.value;

  bool get isEditable => !definition.isSocket;
}

class GraphNodeInstance {
  const GraphNodeInstance({
    required this.id,
    required this.definitionId,
    required this.name,
    required this.position,
    required this.properties,
    this.isDirty = true,
  });

  final String id;
  final String definitionId;
  final String name;
  final Offset position;
  final List<GraphNodeProperty> properties;
  final bool isDirty;

  GraphNodeInstance copyWith({
    String? id,
    String? definitionId,
    String? name,
    Offset? position,
    List<GraphNodeProperty>? properties,
    bool? isDirty,
  }) {
    return GraphNodeInstance(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      name: name ?? this.name,
      position: position ?? this.position,
      properties: properties ?? this.properties,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  GraphNodeProperty? propertyById(String propertyId) {
    for (final property in properties) {
      if (property.id == propertyId) {
        return property;
      }
    }

    return null;
  }

  GraphNodeProperty? propertyByDefinitionKey(String key) {
    for (final property in properties) {
      if (property.definitionKey == key) {
        return property;
      }
    }

    return null;
  }

  List<GraphNodePropertyView> bindProperties(GraphNodeDefinition definition) {
    return definition.properties
        .map((propertyDefinition) {
          final property = properties.firstWhere(
            (entry) => entry.definitionKey == propertyDefinition.key,
          );
          return GraphNodePropertyView(
            property: property,
            definition: propertyDefinition,
          );
        })
        .toList(growable: false);
  }
}

class GraphItem {
  const GraphItem({
    required this.id,
    required this.position,
    this.isVisible = true,
  });

  final String id;
  final Offset position;
  final bool isVisible;
}

class MaterialGraphLink {
  const MaterialGraphLink({
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
}

class MaterialGraphDocument {
  const MaterialGraphDocument({
    required this.id,
    required this.name,
    required this.nodes,
    required this.links,
    this.graphItems = const <GraphItem>[],
  });

  final String id;
  final String name;
  final List<GraphNodeInstance> nodes;
  final List<MaterialGraphLink> links;
  final List<GraphItem> graphItems;

  MaterialGraphDocument copyWith({
    String? id,
    String? name,
    List<GraphNodeInstance>? nodes,
    List<MaterialGraphLink>? links,
    List<GraphItem>? graphItems,
  }) {
    return MaterialGraphDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      nodes: nodes ?? this.nodes,
      links: links ?? this.links,
      graphItems: graphItems ?? this.graphItems,
    );
  }
}

class WorkspaceDocument {
  const WorkspaceDocument({
    required this.id,
    required this.name,
    required this.graphs,
  });

  final String id;
  final String name;
  final List<MaterialGraphDocument> graphs;

  WorkspaceDocument copyWith({
    String? id,
    String? name,
    List<MaterialGraphDocument>? graphs,
  }) {
    return WorkspaceDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      graphs: graphs ?? this.graphs,
    );
  }
}
