import 'package:flutter/material.dart';

import '../../shared/widgets/panel_frame.dart';
import '../workspace/models/workspace_models.dart';
import '../workspace/workspace_controller.dart';

class OutlinerPanel extends StatelessWidget {
  const OutlinerPanel({
    super.key,
    required this.controller,
  });

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
          icon: const Icon(Icons.folder_open_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Save workspace',
          onPressed: controller.saveWorkspaceFile,
          icon: const Icon(Icons.save_outlined, size: 18),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ToolbarButton(
                icon: Icons.create_new_folder_outlined,
                label: 'Folder',
                onPressed: controller.createFolder,
              ),
              _ToolbarButton(
                icon: Icons.account_tree_outlined,
                label: 'Material',
                onPressed: controller.createMaterialGraph,
              ),
              _ToolbarButton(
                icon: Icons.functions_outlined,
                label: 'Math',
                onPressed: controller.createMathGraph,
              ),
              _ToolbarButton(
                icon: Icons.save_as_outlined,
                label: 'Save As',
                onPressed: controller.saveWorkspaceAs,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  controller.isDirty ? Icons.circle : Icons.check_circle_outline,
                  size: 14,
                  color: controller.isDirty
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.currentFilePath ?? 'Unsaved workspace',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._buildEntries(
            context,
            parentId: workspace.rootFolderId,
            depth: 0,
          ),
          const SizedBox(height: 14),
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

  List<Widget> _buildEntries(
    BuildContext context, {
    required String? parentId,
    required int depth,
  }) {
    final theme = Theme.of(context);
    return controller.childrenOf(parentId).expand((resource) {
      final isSelected = controller.activeResourceId == resource.id;
      final tile = Padding(
        padding: EdgeInsets.only(
          left: depth * 14,
          bottom: 6,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.selectResource(resource.id),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _iconForResource(resource.kind),
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resource.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (resource.kind != WorkspaceResourceKind.folder) {
        return [tile];
      }

      return [
        tile,
        ..._buildEntries(
          context,
          parentId: resource.id,
          depth: depth + 1,
        ),
      ];
    }).toList(growable: false);
  }

  IconData _iconForResource(WorkspaceResourceKind kind) {
    switch (kind) {
      case WorkspaceResourceKind.folder:
        return Icons.folder_outlined;
      case WorkspaceResourceKind.materialGraph:
        return Icons.account_tree_outlined;
      case WorkspaceResourceKind.mathGraph:
        return Icons.functions_outlined;
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
