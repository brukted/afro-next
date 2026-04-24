import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

import '../graph/graph_value_type_colors.dart';
import '../graph/models/graph_schema.dart';

const double nodeEditorNodeWidth = 204;
const double nodeEditorHeaderHeight = 30;
const double nodeEditorRowHeight = 22;
const double nodeEditorSocketInset = 10;
const double nodeEditorBodyTopSpacing = 8;
const double nodeEditorBodyBottomSpacing = 6;
const double nodeEditorFooterSpacing = 6;
const EdgeInsets nodeEditorBodyPadding = EdgeInsets.fromLTRB(8, 8, 8, 6);

typedef NodeEditorBodyBuilder<T> =
    Widget Function(BuildContext context, NodeEditorNodeViewModel<T> node);

double estimateNodeEditorNodeHeight<T>(NodeEditorNodeViewModel<T> node) {
  return nodeEditorHeaderHeight +
      nodeEditorBodyTopSpacing +
      node.bodyHeight +
      nodeEditorBodyBottomSpacing +
      (node.sockets.length * nodeEditorRowHeight) +
      nodeEditorFooterSpacing;
}

Rect estimateNodeEditorNodeRect<T>(NodeEditorNodeViewModel<T> node) {
  return Rect.fromLTWH(
    node.position.x,
    node.position.y,
    nodeEditorNodeWidth,
    estimateNodeEditorNodeHeight(node),
  );
}

class NodeEditorSocketViewModel {
  const NodeEditorSocketViewModel({
    required this.id,
    required this.label,
    required this.direction,
    required this.valueType,
    this.valueUnit = GraphValueUnit.none,
    this.isConnected = false,
  });

  final String id;
  final String label;
  final GraphSocketDirection direction;
  final GraphValueType valueType;
  final GraphValueUnit valueUnit;
  final bool isConnected;

  Color get color =>
      graphValueTypeSocketColor(valueType, valueUnit: valueUnit);
}

class NodeEditorNodeViewModel<T> {
  const NodeEditorNodeViewModel({
    required this.id,
    required this.title,
    required this.position,
    required this.icon,
    required this.accentColor,
    required this.sockets,
    this.bodyHeight = 88,
    this.bodyData,
  });

  final String id;
  final String title;
  final Vector2 position;
  final IconData icon;
  final Color accentColor;
  final List<NodeEditorSocketViewModel> sockets;
  final double bodyHeight;
  final T? bodyData;
}
