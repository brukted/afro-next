import 'package:flutter/material.dart';

import '../../shared/widgets/panel_frame.dart';
import '../workspace/workspace_controller.dart';
import 'material_graph_canvas.dart';

class MaterialGraphPanel extends StatelessWidget {
  const MaterialGraphPanel({
    super.key,
    required this.controller,
  });

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final graph = controller.activeGraph;
    final rendererState = controller.rendererState;
    final pendingConnection = controller.pendingConnection;

    return PanelFrame(
      title: 'Material Editor',
      subtitle: graph.name,
      actions: [
        IconButton(
          tooltip: 'Open workspace',
          onPressed: controller.openWorkspaceFile,
          icon: const Icon(Icons.folder_open_outlined),
        ),
        IconButton(
          tooltip: 'Save workspace',
          onPressed: controller.saveWorkspaceFile,
          icon: const Icon(Icons.save_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: 'Add node',
          onSelected: controller.addNode,
          itemBuilder: (context) {
            return controller.nodeDefinitions.map((definition) {
              return PopupMenuItem<String>(
                value: definition.id,
                child: Row(
                  children: [
                    Icon(definition.icon, color: definition.accentColor),
                    const SizedBox(width: 10),
                    Text(definition.label),
                  ],
                ),
              );
            }).toList(growable: false);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.add_circle_outline),
          ),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Row(
              children: [
                Chip(
                  label: Text(rendererState.backendLabel),
                  avatar: const Icon(Icons.memory_outlined, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pendingConnection == null
                        ? rendererState.summary
                        : 'Tap an input socket to connect the pending output.',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pendingConnection != null)
                  TextButton.icon(
                    onPressed: controller.cancelPendingConnection,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel link'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: MaterialGraphCanvas(controller: controller),
          ),
        ],
      ),
    );
  }
}
