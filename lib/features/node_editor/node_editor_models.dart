import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

import '../graph/models/graph_schema.dart';

typedef NodeEditorBodyBuilder =
    Widget Function(BuildContext context, NodeEditorNodeViewModel node);

class NodeEditorSocketViewModel {
  const NodeEditorSocketViewModel({
    required this.id,
    required this.label,
    required this.direction,
    this.isConnected = false,
  });

  final String id;
  final String label;
  final GraphSocketDirection direction;
  final bool isConnected;
}

class NodeEditorNodeViewModel {
  const NodeEditorNodeViewModel({
    required this.id,
    required this.title,
    required this.position,
    required this.icon,
    required this.accentColor,
    required this.sockets,
    this.bodyHeight = 96,
    this.bodyData,
  });

  final String id;
  final String title;
  final Vector2 position;
  final IconData icon;
  final Color accentColor;
  final List<NodeEditorSocketViewModel> sockets;
  final double bodyHeight;
  final Object? bodyData;
}
