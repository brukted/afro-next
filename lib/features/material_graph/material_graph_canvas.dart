import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../vulkan/resources/preview_render_target.dart';
import '../workspace/workspace_controller.dart';
import 'models/material_graph_models.dart';

const double _nodeWidth = 280;
const double _headerHeight = 48;
const double _previewHeight = 118;
const double _rowHeight = 34;
const double _socketInset = 14;

class MaterialGraphCanvas extends StatefulWidget {
  const MaterialGraphCanvas({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<MaterialGraphCanvas> createState() => _MaterialGraphCanvasState();
}

class _MaterialGraphCanvasState extends State<MaterialGraphCanvas> {
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.controller.activeGraph;
    final anchors = _buildSocketAnchors(graph);

    return ClipRect(
      child: ColoredBox(
        color: const Color(0xFF0A0C11),
        child: InteractiveViewer(
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(600),
          minScale: 0.35,
          maxScale: 1.75,
          child: SizedBox(
            width: 2200,
            height: 1600,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.controller.selectNode(null);
                widget.controller.cancelPendingConnection();
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GraphCanvasPainter(
                        links: graph.links,
                        anchors: anchors,
                        selectedNodeId: widget.controller.selectedNodeId,
                      ),
                    ),
                  ),
                  ...graph.nodes.map((node) {
                    final definition = widget.controller.definitionForNode(
                      node,
                    );
                    return Positioned(
                      left: node.position.dx,
                      top: node.position.dy,
                      width: _nodeWidth,
                      child: _GraphNodeCard(
                        node: node,
                        definition: definition,
                        properties: widget.controller.boundPropertiesForNode(
                          node,
                        ),
                        preview: widget.controller.previewForNode(node.id),
                        isSelected: widget.controller.selectedNodeId == node.id,
                        pendingPropertyId:
                            widget.controller.pendingConnection?.propertyId,
                        onSelect: () => widget.controller.selectNode(node.id),
                        onMove: (delta) {
                          widget.controller.moveNode(
                            node.id,
                            Offset(
                              delta.dx / _sceneScale(),
                              delta.dy / _sceneScale(),
                            ),
                          );
                        },
                        onSocketTap: (propertyId) {
                          widget.controller.handleSocketTap(
                            nodeId: node.id,
                            propertyId: propertyId,
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _sceneScale() {
    return _transformationController.value.getMaxScaleOnAxis();
  }

  Map<String, Offset> _buildSocketAnchors(MaterialGraphDocument graph) {
    final anchors = <String, Offset>{};

    for (final node in graph.nodes) {
      final definition = widget.controller.definitionForNode(node);
      final boundProperties = node.bindProperties(definition);

      for (final entry in boundProperties.indexed) {
        final index = entry.$1;
        final property = entry.$2;
        final direction = property.definition.socketDirection;
        if (direction == null) {
          continue;
        }

        final y =
            node.position.dy +
            _headerHeight +
            _previewHeight +
            (index * _rowHeight) +
            (_rowHeight / 2);
        final x =
            node.position.dx +
            (direction == GraphSocketDirection.input
                ? _socketInset
                : _nodeWidth - _socketInset);
        anchors[property.id] = Offset(x, y);
      }
    }

    return anchors;
  }
}

class _GraphNodeCard extends StatelessWidget {
  const _GraphNodeCard({
    required this.node,
    required this.definition,
    required this.properties,
    required this.preview,
    required this.isSelected,
    required this.pendingPropertyId,
    required this.onSelect,
    required this.onMove,
    required this.onSocketTap,
  });

  final GraphNodeInstance node;
  final GraphNodeDefinition definition;
  final List<GraphNodePropertyView> properties;
  final PreviewRenderTarget? preview;
  final bool isSelected;
  final String? pendingPropertyId;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onMove;
  final ValueChanged<String> onSocketTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171922),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? definition.accentColor
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: isSelected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onSelect,
            onPanUpdate: (details) => onMove(details.delta),
            child: Container(
              height: _headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: definition.accentColor.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    definition.icon,
                    size: 18,
                    color: definition.accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      node.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: onSelect,
            child: Container(
              height: _previewHeight,
              width: double.infinity,
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (preview?.accentColor ?? definition.accentColor)
                        .withValues(alpha: 0.75),
                    const Color(0xFF11131A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview?.label ?? 'Preview',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      definition.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...properties.map((property) {
            final direction = property.definition.socketDirection;
            final isSocket = direction != null;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  onSelect();
                  if (isSocket) {
                    onSocketTap(property.id);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: SizedBox(
                    height: _rowHeight,
                    child: Row(
                      children: [
                        if (direction == GraphSocketDirection.input)
                          _SocketDot(
                            isActive: pendingPropertyId == property.id,
                            color: definition.accentColor,
                          )
                        else
                          const SizedBox(width: 14),
                        if (direction == GraphSocketDirection.input)
                          const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            property.label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: property.isEditable
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          _propertyValueLabel(property),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (direction == GraphSocketDirection.output) ...[
                          const SizedBox(width: 8),
                          _SocketDot(
                            isActive: pendingPropertyId == property.id,
                            color: definition.accentColor,
                          ),
                        ] else
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _propertyValueLabel(GraphNodePropertyView property) {
    if (property.definition.isSocket) {
      return property.definition.socketDirection == GraphSocketDirection.input
          ? 'input'
          : 'output';
    }

    switch (property.definition.valueType) {
      case GraphValueType.scalar:
        return (property.value as double).toStringAsFixed(2);
      case GraphValueType.enumChoice:
        final value = property.value as int;
        return property.definition.enumOptions
                .firstWhereOrNull((option) => option.value == value)
                ?.label ??
            value.toString();
      case GraphValueType.color:
        final color = property.value as Color;
        return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
  }
}

class _SocketDot extends StatelessWidget {
  const _SocketDot({required this.isActive, required this.color});

  final bool isActive;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isActive ? 0.95 : 0.65),
        border: Border.all(
          color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.22),
          width: isActive ? 1.5 : 1,
        ),
      ),
    );
  }
}

class _GraphCanvasPainter extends CustomPainter {
  const _GraphCanvasPainter({
    required this.links,
    required this.anchors,
    required this.selectedNodeId,
  });

  final List<MaterialGraphLink> links;
  final Map<String, Offset> anchors;
  final String? selectedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (final link in links) {
      final start = anchors[link.fromPropertyId];
      final end = anchors[link.toPropertyId];
      if (start == null || end == null) {
        continue;
      }

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + 140,
          start.dy,
          end.dx - 140,
          end.dy,
          end.dx,
          end.dy,
        );

      final highlight =
          link.fromNodeId == selectedNodeId || link.toNodeId == selectedNodeId;
      basePaint.color = highlight
          ? const Color(0xFF8E7DFF)
          : const Color(0xFF6B7187);
      basePaint.strokeWidth = highlight ? 3.0 : 2.4;
      canvas.drawPath(path, basePaint);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = const Color(0xFF1A1E27)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = const Color(0xFF252A35)
      ..strokeWidth = 1.2;

    for (double x = 0; x <= size.width; x += 32) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x % 128 == 0 ? majorPaint : minorPaint,
      );
    }

    for (double y = 0; y <= size.height; y += 32) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y % 128 == 0 ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GraphCanvasPainter oldDelegate) {
    return oldDelegate.links != links ||
        oldDelegate.anchors != anchors ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}
