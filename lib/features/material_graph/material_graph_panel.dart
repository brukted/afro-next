import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/widgets/panel_frame.dart';
import '../../vulkan/resources/preview_render_target.dart';
import '../graph/models/graph_schema.dart';
import '../node_editor/node_editor_canvas.dart';
import '../node_editor/node_editor_models.dart';
import '../node_editor/node_editor_viewport.dart';
import 'material_graph_controller.dart';
import 'material_node_definition.dart';

class MaterialGraphPanel extends StatefulWidget {
  const MaterialGraphPanel({
    super.key,
    required this.controller,
  });

  final MaterialGraphController controller;

  @override
  State<MaterialGraphPanel> createState() => _MaterialGraphPanelState();
}

class _MaterialGraphPanelState extends State<MaterialGraphPanel> {
  late final NodeEditorViewportController _viewportController;

  @override
  void initState() {
    super.initState();
    _viewportController = NodeEditorViewportController();
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  MaterialGraphController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    if (!_controller.hasGraph) {
      return const PanelFrame(
        title: 'Material Editor',
        subtitle: 'Select a material graph',
        child: Center(child: Text('No material graph selected.')),
      );
    }

    final graph = _controller.graph;
    final rendererState = _controller.rendererState;
    final pendingConnection = _controller.pendingConnection;

    return PanelFrame(
      title: 'Material Editor',
      subtitle: graph.name,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Add node',
          onSelected: _controller.addNode,
          itemBuilder: (context) => _controller.nodeDefinitions
              .map((definition) => PopupMenuItem<String>(
                    value: definition.id,
                    child: _NodeDefinitionLabel(definition: definition),
                  ))
              .toList(growable: false),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.add_circle_outline, size: 16),
          ),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.28),
                ),
              ),
            ),
            child: Row(
              children: [
                Chip(
                  label: Text(rendererState.backendLabel),
                  avatar: const Icon(Icons.memory_outlined, size: 13),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pendingConnection == null
                        ? rendererState.summary
                        : 'Tap an input socket to finish the link.',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pendingConnection != null)
                  TextButton(
                    onPressed: _controller.cancelPendingConnection,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final nodes = _buildNodeViewModels();
                return NodeEditorCanvas(
                  viewportController: _viewportController,
                  nodes: nodes,
                  links: graph.links,
                  selectedNodeId: _controller.selectedNodeId,
                  pendingPropertyId: _controller.pendingConnection?.propertyId,
                  onSelectNode: _controller.selectNode,
                  onSetNodePosition: _controller.setNodePosition,
                  onSocketTap: (nodeId, propertyId) {
                    _controller.handleSocketTap(
                      nodeId: nodeId,
                      propertyId: propertyId,
                    );
                  },
                  onCancelPendingConnection: _controller.cancelPendingConnection,
                  onRequestCanvasMenu: (globalPosition, scenePosition) {
                    return _showCanvasMenu(
                      context: context,
                      globalPosition: globalPosition,
                      scenePosition: scenePosition,
                      canvasSize: canvasSize,
                    );
                  },
                  onRequestNodeMenu: (node, globalPosition) {
                    return _showNodeMenu(
                      context: context,
                      node: node,
                      globalPosition: globalPosition,
                      canvasSize: canvasSize,
                    );
                  },
                  buildNodeBody: (context, nodeViewModel) {
                    final preview =
                        nodeViewModel.bodyData as PreviewRenderTarget?;
                    return _MaterialNodeBody(
                      accentColor: nodeViewModel.accentColor,
                      title: nodeViewModel.title,
                      preview: preview,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<NodeEditorNodeViewModel> _buildNodeViewModels() {
    return _controller.graph.nodes.map((node) {
      final definition = _controller.definitionForNode(node);
      final accentColor = Vector4ColorAdapter.toFlutterColor(
        definition.accentColor,
      );
      final bindings = _controller.boundPropertiesForNode(node);

      return NodeEditorNodeViewModel(
        id: node.id,
        title: node.name,
        position: node.position,
        icon: definition.icon,
        accentColor: accentColor,
        bodyHeight: 84,
        bodyData: _controller.previewForNode(node.id),
        sockets: bindings
            .where((binding) => binding.definition.isSocket)
            .map(
              (binding) => NodeEditorSocketViewModel(
                id: binding.id,
                label: binding.label,
                direction: binding.definition.socketDirection!,
                isConnected:
                    binding.definition.socketDirection ==
                            GraphSocketDirection.input
                        ? _controller.hasIncomingLink(binding.id)
                        : _controller.hasOutgoingLink(binding.id),
              ),
            )
            .toList(growable: false),
      );
    }).toList(growable: false);
  }

  Future<void> _showCanvasMenu({
    required BuildContext context,
    required Offset globalPosition,
    required Offset scenePosition,
    required Size canvasSize,
  }) async {
    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: [
        _sectionHeader(context, 'Add node'),
        ..._controller.nodeDefinitions.map(
          (definition) => PopupMenuItem<String>(
            value: 'add:${definition.id}',
            height: 30,
            child: _NodeDefinitionLabel(definition: definition),
          ),
        ),
        const PopupMenuDivider(height: 10),
        PopupMenuItem<String>(
          value: 'focusCenter',
          enabled: _controller.graph.nodes.isNotEmpty,
          height: 30,
          child: const Text('Focus to center'),
        ),
      ],
    );
    if (!context.mounted || action == null) {
      return;
    }

    if (action == 'focusCenter') {
      _focusToCenter(canvasSize);
      return;
    }

    if (action.startsWith('add:')) {
      final definitionId = action.substring(4);
      _controller.addNodeAt(
        definitionId,
        Vector2(scenePosition.dx, scenePosition.dy),
      );
    }
  }

  Future<void> _showNodeMenu({
    required BuildContext context,
    required NodeEditorNodeViewModel node,
    required Offset globalPosition,
    required Size canvasSize,
  }) async {
    final hasLinks = _controller.graph.links.any(
      (link) => link.fromNodeId == node.id || link.toNodeId == node.id,
    );
    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: [
        const PopupMenuItem<String>(
          value: 'focus',
          height: 30,
          child: Text('Focus'),
        ),
        const PopupMenuItem<String>(
          value: 'duplicate',
          height: 30,
          child: Text('Duplicate node'),
        ),
        PopupMenuItem<String>(
          value: 'disconnect',
          enabled: hasLinks,
          height: 30,
          child: const Text('Disconnect'),
        ),
        const PopupMenuDivider(height: 10),
        const PopupMenuItem<String>(
          value: 'delete',
          height: 30,
          child: Text('Delete node'),
        ),
      ],
    );
    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case 'focus':
        _viewportController.focusSceneRect(
          sceneRect: estimateNodeEditorNodeRect(node),
          viewportSize: canvasSize,
        );
        return;
      case 'duplicate':
        _controller.duplicateNode(node.id);
        return;
      case 'disconnect':
        _controller.disconnectNode(node.id);
        return;
      case 'delete':
        _controller.deleteNode(node.id);
        return;
      default:
        return;
    }
  }

  void _focusToCenter(Size canvasSize) {
    final nodes = _buildNodeViewModels();
    if (nodes.isEmpty) {
      return;
    }

    var sumX = 0.0;
    var sumY = 0.0;
    for (final node in nodes) {
      final center = estimateNodeEditorNodeRect(node).center;
      sumX += center.dx;
      sumY += center.dy;
    }

    _viewportController.centerScenePoint(
      scenePoint: Offset(sumX / nodes.length, sumY / nodes.length),
      viewportSize: canvasSize,
    );
  }

  RelativeRect _menuPosition(BuildContext context, Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
  }

  PopupMenuEntry<String> _sectionHeader(BuildContext context, String label) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 26,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NodeDefinitionLabel extends StatelessWidget {
  const _NodeDefinitionLabel({required this.definition});

  final MaterialNodeDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          definition.icon,
          size: 16,
          color: Vector4ColorAdapter.toFlutterColor(definition.accentColor),
        ),
        const SizedBox(width: 8),
        Text(definition.label),
      ],
    );
  }
}

class _MaterialNodeBody extends StatelessWidget {
  const _MaterialNodeBody({
    required this.accentColor,
    required this.title,
    required this.preview,
  });

  final Color accentColor;
  final String title;
  final PreviewRenderTarget? preview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (preview?.accentColor ?? accentColor).withValues(alpha: 0.78),
            const Color(0xFF10131B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview?.label ?? 'Preview',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              preview?.diagnostics.firstOrNull ?? title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
