import 'package:flutter/material.dart';

import '../../shared/widgets/panel_frame.dart';
import '../workspace/models/workspace_models.dart';
import '../workspace/workspace_controller.dart';

class OutlinerPanel extends StatefulWidget {
  const OutlinerPanel({
    super.key,
    required this.controller,
  });

  final WorkspaceController controller;

  @override
  State<OutlinerPanel> createState() => _OutlinerPanelState();
}

class _OutlinerPanelState extends State<OutlinerPanel> {
  final Set<String> _expandedFolderIds = <String>{};
  String? _lastSyncedSelectionId;

  @override
  Widget build(BuildContext context) {
    _syncExpandedFoldersToSelection();

    final workspace = widget.controller.workspace;
    final theme = Theme.of(context);

    return PanelFrame(
      title: 'Outliner',
      subtitle: workspace.name,
      actions: [
        IconButton(
          tooltip: 'Open workspace',
          onPressed: widget.controller.openWorkspaceFile,
          icon: const Icon(Icons.folder_open_outlined, size: 16),
        ),
        IconButton(
          tooltip: 'Save workspace',
          onPressed: widget.controller.saveWorkspaceFile,
          icon: const Icon(Icons.save_outlined, size: 16),
        ),
      ],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          _showBackgroundMenu(
            context,
            globalPosition: details.globalPosition,
          );
        },
        onLongPressStart: (details) {
          _showBackgroundMenu(
            context,
            globalPosition: details.globalPosition,
          );
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          children: [
            _WorkspaceStatusRow(controller: widget.controller),
            const SizedBox(height: 10),
            ..._buildTreeEntries(
              context,
              parentId: workspace.rootFolderId,
              depth: 0,
            ),
            const SizedBox(height: 14),
            Text(
              'Recent Files',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            if (widget.controller.recentFiles.isEmpty)
              Text(
                'No recent files yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...widget.controller.recentFiles.map(
                (path) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
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
      ),
    );
  }

  List<Widget> _buildTreeEntries(
    BuildContext context, {
    required String? parentId,
    required int depth,
  }) {
    return widget.controller.childrenOf(parentId).expand((resource) {
      final children = resource.kind == WorkspaceResourceKind.folder &&
              _expandedFolderIds.contains(resource.id)
          ? _buildTreeEntries(
              context,
              parentId: resource.id,
              depth: depth + 1,
            )
          : const <Widget>[];

      return [
        _OutlinerRow(
          resource: resource,
          depth: depth,
          isExpanded: _expandedFolderIds.contains(resource.id),
          isSelected: widget.controller.selectedResourceId == resource.id,
          onTap: () {
            widget.controller.selectResource(resource.id);
            if (resource.kind == WorkspaceResourceKind.folder) {
              _toggleFolder(resource.id);
            }
          },
          onToggleExpanded: resource.kind == WorkspaceResourceKind.folder
              ? () => _toggleFolder(resource.id)
              : null,
          onContextMenuRequested: (globalPosition) {
            widget.controller.selectResource(resource.id);
            _showItemMenu(
              context,
              resource: resource,
              globalPosition: globalPosition,
            );
          },
        ),
        ...children,
      ];
    }).toList(growable: false);
  }

  Future<void> _showBackgroundMenu(
    BuildContext context, {
    required Offset globalPosition,
  }) async {
    final action = await showMenu<_OutlinerMenuAction>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: [
        _sectionHeader('New'),
        _menuAction(_OutlinerMenuAction.newFolder, 'Folder'),
        _menuAction(_OutlinerMenuAction.newMaterialGraph, 'Material Graph'),
        _menuAction(_OutlinerMenuAction.newMathGraph, 'Math Graph'),
        const PopupMenuDivider(height: 10),
        _disabledMenuItem('Import'),
        const PopupMenuDivider(height: 10),
        _disabledMenuItem('Paste'),
      ],
    );

    switch (action) {
      case _OutlinerMenuAction.newFolder:
        widget.controller.createFolderAt(widget.controller.workspace.rootFolderId);
        return;
      case _OutlinerMenuAction.newMaterialGraph:
        widget.controller.createMaterialGraphAt(
          widget.controller.workspace.rootFolderId,
        );
        return;
      case _OutlinerMenuAction.newMathGraph:
        widget.controller.createMathGraphAt(widget.controller.workspace.rootFolderId);
        return;
      case null:
      case _OutlinerMenuAction.rename:
      case _OutlinerMenuAction.delete:
      case _OutlinerMenuAction.open:
        return;
    }
  }

  Future<void> _showItemMenu(
    BuildContext context, {
    required WorkspaceResourceEntry resource,
    required Offset globalPosition,
  }) async {
    final action = await showMenu<_OutlinerMenuAction>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: resource.kind == WorkspaceResourceKind.folder
          ? _folderMenuEntries(resource)
          : _resourceMenuEntries(resource),
    );
    if (!context.mounted) {
      return;
    }

    switch (action) {
      case _OutlinerMenuAction.open:
        widget.controller.openResource(resource.id);
        return;
      case _OutlinerMenuAction.newFolder:
        _expandedFolderIds.add(resource.id);
        widget.controller.createFolderAt(resource.id);
        return;
      case _OutlinerMenuAction.newMaterialGraph:
        _expandedFolderIds.add(resource.id);
        widget.controller.createMaterialGraphAt(resource.id);
        return;
      case _OutlinerMenuAction.newMathGraph:
        _expandedFolderIds.add(resource.id);
        widget.controller.createMathGraphAt(resource.id);
        return;
      case _OutlinerMenuAction.rename:
        await _showRenameDialog(context, resource: resource);
        return;
      case _OutlinerMenuAction.delete:
        await _showDeleteDialog(context, resource: resource);
        return;
      case null:
        return;
    }
  }

  List<PopupMenuEntry<_OutlinerMenuAction>> _folderMenuEntries(
    WorkspaceResourceEntry resource,
  ) {
    return [
      _sectionHeader('New'),
      _menuAction(_OutlinerMenuAction.newFolder, 'Folder'),
      _menuAction(_OutlinerMenuAction.newMaterialGraph, 'Material Graph'),
      _menuAction(_OutlinerMenuAction.newMathGraph, 'Math Graph'),
      const PopupMenuDivider(height: 10),
      _menuAction(
        _OutlinerMenuAction.rename,
        'Rename',
        enabled: widget.controller.canRenameResource(resource.id),
      ),
      _menuAction(
        _OutlinerMenuAction.delete,
        'Delete',
        enabled: widget.controller.canDeleteResource(resource.id),
      ),
    ];
  }

  List<PopupMenuEntry<_OutlinerMenuAction>> _resourceMenuEntries(
    WorkspaceResourceEntry resource,
  ) {
    return [
      _menuAction(_OutlinerMenuAction.open, 'Open'),
      const PopupMenuDivider(height: 10),
      _menuAction(
        _OutlinerMenuAction.rename,
        'Rename',
        enabled: widget.controller.canRenameResource(resource.id),
      ),
      _menuAction(
        _OutlinerMenuAction.delete,
        'Delete',
        enabled: widget.controller.canDeleteResource(resource.id),
      ),
    ];
  }

  Future<void> _showRenameDialog(
    BuildContext context, {
    required WorkspaceResourceEntry resource,
  }) async {
    final textController = TextEditingController(text: resource.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              isDense: true,
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                textController.text,
              ),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (nextName == null) {
      return;
    }

    widget.controller.renameResource(
      resourceId: resource.id,
      nextName: nextName,
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context, {
    required WorkspaceResourceEntry resource,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final label = resource.kind == WorkspaceResourceKind.folder
            ? 'Delete folder'
            : 'Delete resource';
        final description = resource.kind == WorkspaceResourceKind.folder
            ? 'Delete "${resource.name}" and all nested resources?'
            : 'Delete "${resource.name}"?';
        return AlertDialog(
          title: Text(label),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _expandedFolderIds.remove(resource.id);
    });
    widget.controller.deleteResource(resource.id);
  }

  RelativeRect _menuPosition(BuildContext context, Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
  }

  PopupMenuEntry<_OutlinerMenuAction> _sectionHeader(String label) {
    return PopupMenuItem<_OutlinerMenuAction>(
      enabled: false,
      height: 26,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  PopupMenuEntry<_OutlinerMenuAction> _menuAction(
    _OutlinerMenuAction action,
    String label, {
    bool enabled = true,
  }) {
    return PopupMenuItem<_OutlinerMenuAction>(
      value: action,
      enabled: enabled,
      height: 30,
      child: Text(label),
    );
  }

  PopupMenuEntry<_OutlinerMenuAction> _disabledMenuItem(String label) {
    return PopupMenuItem<_OutlinerMenuAction>(
      enabled: false,
      height: 30,
      child: Text(label),
    );
  }

  void _toggleFolder(String resourceId) {
    setState(() {
      if (!_expandedFolderIds.add(resourceId)) {
        _expandedFolderIds.remove(resourceId);
      }
    });
  }

  void _syncExpandedFoldersToSelection() {
    final selectionId = widget.controller.selectedResourceId;
    if (selectionId == null || selectionId == _lastSyncedSelectionId) {
      return;
    }

    _lastSyncedSelectionId = selectionId;
    _expandedFolderIds.addAll(widget.controller.ancestorIdsOf(selectionId));
  }
}

class _WorkspaceStatusRow extends StatelessWidget {
  const _WorkspaceStatusRow({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            controller.isDirty ? Icons.circle : Icons.check_circle_outline,
            size: 11,
            color: controller.isDirty
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              controller.currentFilePath ?? 'Unsaved workspace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinerRow extends StatelessWidget {
  const _OutlinerRow({
    required this.resource,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.onTap,
    required this.onContextMenuRequested,
    this.onToggleExpanded,
  });

  final WorkspaceResourceEntry resource;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<Offset> onContextMenuRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canExpand = resource.kind == WorkspaceResourceKind.folder;

    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          onSecondaryTapDown: (details) {
            onContextMenuRequested(details.globalPosition);
          },
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: canExpand
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onToggleExpanded,
                          child: Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                Icon(
                  _iconForResource(resource.kind),
                  size: 14,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resource.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

enum _OutlinerMenuAction {
  open,
  newFolder,
  newMaterialGraph,
  newMathGraph,
  rename,
  delete,
}
