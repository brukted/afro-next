import 'package:flutter/material.dart';

import '../../shared/widgets/panel_frame.dart';
import '../workspace/workspace_controller.dart';

class OutlinerPanel extends StatelessWidget {
  const OutlinerPanel({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final workspace = controller.workspace;
    final theme = Theme.of(context);

    return PanelFrame(
      title: 'Outliner',
      subtitle: workspace.name,
      actions: [
        IconButton(
          tooltip: 'Open workspace',
          onPressed: controller.openWorkspaceFile,
          icon: const Icon(Icons.folder_open_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Graphs',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...workspace.graphs.map((graph) {
            final isSelected = controller.activeGraphId == graph.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => controller.selectGraph(graph.id),
                child: Ink(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.35,
                          )
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.25,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.8)
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(graph.name, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${graph.nodes.length} nodes, ${graph.links.length} links',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Recent Files',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (controller.recentFiles.isEmpty)
            Text(
              'No recent files yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...controller.recentFiles.map(
              (path) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
