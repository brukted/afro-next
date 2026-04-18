import 'package:flutter/material.dart';

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/widgets/panel_frame.dart';
import '../graph/models/graph_schema.dart';
import '../node_editor/node_editor_canvas.dart';
import '../node_editor/node_editor_models.dart';
import '../../vulkan/resources/preview_render_target.dart';
import 'material_graph_controller.dart';

class MaterialGraphPanel extends StatelessWidget {
  const MaterialGraphPanel({
    super.key,
    required this.controller,
  });

  final MaterialGraphController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasGraph) {
      return const PanelFrame(
        title: 'Material Editor',
        subtitle: 'Select a material graph',
        child: Center(child: Text('No material graph selected.')),
      );
    }

    final graph = controller.graph;
    final rendererState = controller.rendererState;
    final pendingConnection = controller.pendingConnection;

    return PanelFrame(
      title: 'Material Editor',
      subtitle: graph.name,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Add node',
          onSelected: controller.addNode,
          itemBuilder: (context) {
            return controller.nodeDefinitions.map((definition) {
              return PopupMenuItem<String>(
                value: definition.id,
                child: Row(
                  children: [
                    Icon(
                      definition.icon,
                      color: Vector4ColorAdapter.toFlutterColor(
                        definition.accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(definition.label),
                  ],
                ),
              );
            }).toList(growable: false);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.add_circle_outline, size: 18),
          ),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.32),
                ),
              ),
            ),
            child: Row(
              children: [
                Chip(
                  label: Text(rendererState.backendLabel),
                  avatar: const Icon(Icons.memory_outlined, size: 14),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
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
                    onPressed: controller.cancelPendingConnection,
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: NodeEditorCanvas(
              nodes: graph.nodes.map((node) {
                final definition = controller.definitionForNode(node);
                final accentColor = Vector4ColorAdapter.toFlutterColor(
                  definition.accentColor,
                );
                final bindings = controller.boundPropertiesForNode(node);

                return NodeEditorNodeViewModel(
                  id: node.id,
                  title: node.name,
                  position: node.position,
                  icon: definition.icon,
                  accentColor: accentColor,
                  bodyHeight: 96,
                  bodyData: controller.previewForNode(node.id),
                  sockets: bindings
                      .where((binding) => binding.definition.isSocket)
                      .map(
                        (binding) => NodeEditorSocketViewModel(
                          id: binding.id,
                          label: binding.label,
                          direction: binding.definition.socketDirection!,
                          isConnected: binding.definition.socketDirection ==
                                  GraphSocketDirection.input
                              ? controller.hasIncomingLink(binding.id)
                              : controller.hasOutgoingLink(binding.id),
                        ),
                      )
                      .toList(growable: false),
                );
              }).toList(growable: false),
              links: graph.links,
              selectedNodeId: controller.selectedNodeId,
              pendingPropertyId: controller.pendingConnection?.propertyId,
              onSelectNode: controller.selectNode,
              onSetNodePosition: controller.setNodePosition,
              onSocketTap: (nodeId, propertyId) {
                controller.handleSocketTap(
                  nodeId: nodeId,
                  propertyId: propertyId,
                );
              },
              onCancelPendingConnection: controller.cancelPendingConnection,
              buildNodeBody: (context, nodeViewModel) {
                final preview = nodeViewModel.bodyData as PreviewRenderTarget?;
                return _MaterialNodeBody(
                  accentColor: nodeViewModel.accentColor,
                  title: nodeViewModel.title,
                  preview: preview,
                );
              },
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview?.label ?? 'Preview',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
