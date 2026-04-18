import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'node_editor_models.dart';
import 'node_editor_viewport.dart';

const double _nodeWidth = 220;
const double _headerHeight = 34;
const double _rowHeight = 26;
const double _socketInset = 11;
const double _bodyTopSpacing = 10;
const double _bodyBottomSpacing = 8;
const EdgeInsets _nodeBodyPadding = EdgeInsets.fromLTRB(10, 10, 10, 8);
const Color _canvasColor = Color(0xFF090B11);

class NodeEditorCanvas extends StatefulWidget {
  const NodeEditorCanvas({
    super.key,
    required this.nodes,
    required this.links,
    required this.selectedNodeId,
    required this.pendingPropertyId,
    required this.onSelectNode,
    required this.onSetNodePosition,
    required this.onSocketTap,
    required this.onCancelPendingConnection,
    this.viewportController,
    this.buildNodeBody,
  });

  final List<NodeEditorNodeViewModel> nodes;
  final List<GraphLinkDocument> links;
  final String? selectedNodeId;
  final String? pendingPropertyId;
  final ValueChanged<String?> onSelectNode;
  final void Function(String nodeId, Vector2 position) onSetNodePosition;
  final void Function(String nodeId, String propertyId) onSocketTap;
  final VoidCallback onCancelPendingConnection;
  final NodeEditorViewportController? viewportController;
  final NodeEditorBodyBuilder? buildNodeBody;

  @override
  State<NodeEditorCanvas> createState() => _NodeEditorCanvasState();
}

class _NodeEditorCanvasState extends State<NodeEditorCanvas> {
  late final NodeEditorViewportController _internalViewportController;
  _NodeDragSession? _dragSession;
  double _trackpadScale = 1;

  NodeEditorViewportController get _viewportController =>
      widget.viewportController ?? _internalViewportController;

  @override
  void initState() {
    super.initState();
    _internalViewportController = NodeEditorViewportController();
  }

  @override
  void dispose() {
    if (widget.viewportController == null) {
      _internalViewportController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        return AnimatedBuilder(
          animation: _viewportController,
          builder: (context, _) {
            final viewport = _viewportController.viewport;
            final anchors = _buildSocketAnchors();

            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: (event) {
                _handlePointerSignal(event, viewportSize);
              },
              onPointerPanZoomStart: (_) {
                _trackpadScale = 1;
              },
              onPointerPanZoomUpdate: (event) {
                _handleTrackpadPanZoom(event);
              },
              onPointerPanZoomEnd: (_) {
                _trackpadScale = 1;
              },
              child: ClipRect(
                child: ColoredBox(
                  color: _canvasColor,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            widget.onSelectNode(null);
                            widget.onCancelPendingConnection();
                          },
                          onPanUpdate: (details) {
                            _viewportController.panBy(details.delta);
                          },
                          child: CustomPaint(
                            painter: _NodeEditorPainter(
                              links: widget.links,
                              anchors: anchors,
                              selectedNodeId: widget.selectedNodeId,
                              viewport: viewport,
                              viewportSize: viewportSize,
                            ),
                          ),
                        ),
                      ),
                      ...widget.nodes.map((node) {
                        final screenPosition = viewport.sceneToScreen(
                          node.position.toOffset(),
                        );
                        return Positioned(
                          left: screenPosition.dx,
                          top: screenPosition.dy,
                          child: Transform.scale(
                            scale: viewport.scale,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: _nodeWidth,
                              child: _NodeCard(
                                node: node,
                                isSelected: widget.selectedNodeId == node.id,
                                pendingPropertyId: widget.pendingPropertyId,
                                bodyBuilder: widget.buildNodeBody,
                                onSelect: () => widget.onSelectNode(node.id),
                                onDragStart: (globalPosition) {
                                  widget.onSelectNode(node.id);
                                  _startNodeDrag(
                                    node: node,
                                    globalPosition: globalPosition,
                                  );
                                },
                                onDragUpdate: (globalPosition) {
                                  _updateNodeDrag(
                                    node: node,
                                    globalPosition: globalPosition,
                                  );
                                },
                                onDragEnd: () {
                                  _dragSession = null;
                                },
                                onSocketTap: (propertyId) {
                                  widget.onSocketTap(node.id, propertyId);
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, Offset> _buildSocketAnchors() {
    final anchors = <String, Offset>{};

    for (final node in widget.nodes) {
      for (final entry in node.sockets.indexed) {
        final index = entry.$1;
        final socket = entry.$2;
        final y =
            node.position.y +
            _headerHeight +
            _bodyTopSpacing +
            node.bodyHeight +
            _bodyBottomSpacing +
            (index * _rowHeight) +
            (_rowHeight / 2);
        final x = node.position.x +
            (socket.direction == GraphSocketDirection.input
                ? _socketInset
                : _nodeWidth - _socketInset);
        anchors[socket.id] = Offset(x, y);
      }
    }

    return anchors;
  }

  void _startNodeDrag({
    required NodeEditorNodeViewModel node,
    required Offset globalPosition,
  }) {
    final pointerScene = _scenePositionForGlobal(globalPosition);
    _dragSession = _NodeDragSession(
      nodeId: node.id,
      pointerOffsetFromNodeOrigin: Offset(
        pointerScene.dx - node.position.x,
        pointerScene.dy - node.position.y,
      ),
    );
  }

  void _updateNodeDrag({
    required NodeEditorNodeViewModel node,
    required Offset globalPosition,
  }) {
    final dragSession = _dragSession;
    if (dragSession == null || dragSession.nodeId != node.id) {
      return;
    }

    final pointerScene = _scenePositionForGlobal(globalPosition);
    final nextPosition = Offset(
      pointerScene.dx - dragSession.pointerOffsetFromNodeOrigin.dx,
      pointerScene.dy - dragSession.pointerOffsetFromNodeOrigin.dy,
    );
    widget.onSetNodePosition(node.id, nextPosition.toVector2());
  }

  Offset _scenePositionForGlobal(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return Offset.zero;
    }

    final localPosition = renderObject.globalToLocal(globalPosition);
    return _viewportController.screenToScene(localPosition);
  }

  void _handleTrackpadPanZoom(PointerPanZoomUpdateEvent event) {
    _viewportController.panBy(event.localPanDelta);

    final scaleDelta = event.scale / _trackpadScale;
    _trackpadScale = event.scale;
    if ((scaleDelta - 1).abs() < 0.0001) {
      return;
    }

    _viewportController.zoomAtScreenPoint(
      focalPoint: event.localPosition,
      scaleDelta: scaleDelta,
    );
  }

  void _handlePointerSignal(PointerSignalEvent event, Size viewportSize) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final localPosition = _localPositionForScroll(event, viewportSize);
    final keyboard = HardwareKeyboard.instance;
    final shouldZoom = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (shouldZoom) {
      final scaleDelta = math.exp(-event.scrollDelta.dy / 240);
      _viewportController.zoomAtScreenPoint(
        focalPoint: localPosition,
        scaleDelta: scaleDelta,
      );
      return;
    }

    _viewportController.panBy(
      Offset(-event.scrollDelta.dx, -event.scrollDelta.dy),
    );
  }

  Offset _localPositionForScroll(
    PointerScrollEvent event,
    Size viewportSize,
  ) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return Offset(viewportSize.width / 2, viewportSize.height / 2);
    }

    return renderObject.globalToLocal(event.position);
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.isSelected,
    required this.pendingPropertyId,
    required this.onSelect,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onSocketTap,
    required this.bodyBuilder,
  });

  final NodeEditorNodeViewModel node;
  final bool isSelected;
  final String? pendingPropertyId;
  final VoidCallback onSelect;
  final ValueChanged<Offset> onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onSocketTap;
  final NodeEditorBodyBuilder? bodyBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? node.accentColor
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onSelect,
            onPanStart: (details) => onDragStart(details.globalPosition),
            onPanUpdate: (details) => onDragUpdate(details.globalPosition),
            onPanEnd: (_) => onDragEnd(),
            onPanCancel: onDragEnd,
            child: Container(
              height: _headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: node.accentColor.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  Icon(node.icon, size: 15, color: node.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.drag_indicator,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: _nodeBodyPadding,
            child: SizedBox(
              height: node.bodyHeight,
              width: double.infinity,
              child: bodyBuilder?.call(context, node) ?? _DefaultNodeBody(node: node),
            ),
          ),
          ...node.sockets.map((socket) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  onSelect();
                  onSocketTap(socket.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: _rowHeight,
                    child: Row(
                      children: [
                        if (socket.direction == GraphSocketDirection.input)
                          _SocketDot(
                            isActive: pendingPropertyId == socket.id,
                            isConnected: socket.isConnected,
                            color: node.accentColor,
                          )
                        else
                          const SizedBox(width: 12),
                        if (socket.direction == GraphSocketDirection.input)
                          const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            socket.label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (socket.direction == GraphSocketDirection.output) ...[
                          const SizedBox(width: 8),
                          _SocketDot(
                            isActive: pendingPropertyId == socket.id,
                            isConnected: socket.isConnected,
                            color: node.accentColor,
                          ),
                        ] else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DefaultNodeBody extends StatelessWidget {
  const _DefaultNodeBody({required this.node});

  final NodeEditorNodeViewModel node;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: node.accentColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          node.title,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SocketDot extends StatelessWidget {
  const _SocketDot({
    required this.isActive,
    required this.isConnected,
    required this.color,
  });

  final bool isActive;
  final bool isConnected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(
          alpha: isActive
              ? 1
              : isConnected
              ? 0.8
              : 0.48,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.22),
          width: isActive ? 1.4 : 1,
        ),
      ),
    );
  }
}

class _NodeEditorPainter extends CustomPainter {
  const _NodeEditorPainter({
    required this.links,
    required this.anchors,
    required this.selectedNodeId,
    required this.viewport,
    required this.viewportSize,
  });

  final List<GraphLinkDocument> links;
  final Map<String, Offset> anchors;
  final String? selectedNodeId;
  final NodeEditorViewport viewport;
  final Size viewportSize;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (final link in links) {
      final fromScene = anchors[link.fromPropertyId];
      final toScene = anchors[link.toPropertyId];
      if (fromScene == null || toScene == null) {
        continue;
      }

      final from = viewport.sceneToScreen(fromScene);
      final to = viewport.sceneToScreen(toScene);
      final isSelected =
          selectedNodeId == link.fromNodeId || selectedNodeId == link.toNodeId;
      basePaint.color = isSelected
          ? const Color(0xFFAAB7FF)
          : const Color(0xFF5B6283);

      final dx = math.max(90, (to.dx - from.dx).abs() * 0.5);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx + dx, from.dy, to.dx - dx, to.dy, to.dx, to.dy);

      canvas.drawPath(path, basePaint);
    }
  }

  void _paintGrid(Canvas canvas) {
    const minorSpacing = 32.0;
    const majorSpacing = 128.0;
    final minorPaint = Paint()..color = const Color(0xFF10141E);
    final majorPaint = Paint()..color = const Color(0xFF181D2B);
    final sceneRect = viewport.visibleSceneRect(viewportSize).inflate(majorSpacing);

    final startX = (sceneRect.left / minorSpacing).floor() * minorSpacing;
    final endX = (sceneRect.right / minorSpacing).ceil() * minorSpacing;
    for (double x = startX; x <= endX; x += minorSpacing) {
      final screenX = viewport.sceneToScreen(Offset(x, 0)).dx;
      canvas.drawLine(
        Offset(screenX, 0),
        Offset(screenX, viewportSize.height),
        x % majorSpacing == 0 ? majorPaint : minorPaint,
      );
    }

    final startY = (sceneRect.top / minorSpacing).floor() * minorSpacing;
    final endY = (sceneRect.bottom / minorSpacing).ceil() * minorSpacing;
    for (double y = startY; y <= endY; y += minorSpacing) {
      final screenY = viewport.sceneToScreen(Offset(0, y)).dy;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(viewportSize.width, screenY),
        y % majorSpacing == 0 ? majorPaint : minorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NodeEditorPainter oldDelegate) {
    return oldDelegate.links != links ||
        oldDelegate.anchors != anchors ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.viewport != viewport ||
        oldDelegate.viewportSize != viewportSize;
  }
}

class _NodeDragSession {
  const _NodeDragSession({
    required this.nodeId,
    required this.pointerOffsetFromNodeOrigin,
  });

  final String nodeId;
  final Offset pointerOffsetFromNodeOrigin;
}

extension on Vector2 {
  Offset toOffset() => Offset(x, y);
}

extension on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}
