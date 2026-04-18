import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

import '../graph/models/graph_schema.dart';

class MaterialNodeDefinition {
  const MaterialNodeDefinition({
    required this.schema,
    required this.icon,
    required this.accentColor,
  });

  final GraphNodeSchema schema;
  final IconData icon;
  final Vector4 accentColor;

  String get id => schema.id;

  String get label => schema.label;

  String get description => schema.description;

  List<GraphPropertyDefinition> get properties => schema.properties;

  GraphPropertyDefinition propertyDefinition(String key) {
    return schema.propertyDefinition(key);
  }
}
