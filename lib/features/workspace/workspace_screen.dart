import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../../shared/widgets/panel_frame.dart';
import '../math_graph/math_graph_controller.dart';
import '../math_graph/math_graph_inspector_panel.dart';
import '../math_graph/math_graph_panel.dart';
import '../material_graph/material_graph_controller.dart';
import '../material_graph/material_graph_panel.dart';
import '../outliner/outliner_panel.dart';
import '../property_editor/property_editor_panel.dart';
import 'models/workspace_models.dart';
import 'workspace_controller.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.workspaceController,
    required this.materialGraphController,
    required this.mathGraphController,
  });

  final WorkspaceController workspaceController;
  final MaterialGraphController materialGraphController;
  final MathGraphController mathGraphController;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final MultiSplitViewController _splitViewController;

  @override
  void initState() {
    super.initState();
    final layout = widget.workspaceController.layoutPreferences;
    _splitViewController = MultiSplitViewController()
      ..areas = [
        Area(size: layout.leftPaneWidth, min: 220, data: 0),
        Area(flex: 1, data: 1),
        Area(size: layout.inspectorWidth, min: 280, data: 2),
      ]
      ..addListener(_persistLayout);
    widget.workspaceController.addListener(_syncEditorBinding);
    _syncEditorBinding();
  }

  @override
  void dispose() {
    widget.workspaceController.removeListener(_syncEditorBinding);
    _splitViewController.removeListener(_persistLayout);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.workspaceController,
        widget.materialGraphController,
        widget.mathGraphController,
      ]),
      builder: (context, _) {
        if (!widget.workspaceController.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final resource = widget.workspaceController.openedResource;

        return Scaffold(
          body: SafeArea(
            child: CallbackShortcuts(
              bindings: _workspaceMenuShortcuts(),
              child: Focus(
                autofocus: true,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _WorkspaceMenuBar(
                            workspaceController: widget.workspaceController,
                            onNewWorkspace: _newWorkspace,
                            onOpenWorkspace: _openWorkspace,
                            onOpenRecentWorkspace: _openRecentWorkspace,
                            onSaveWorkspace: _saveWorkspace,
                            onSaveWorkspaceAs: _saveWorkspaceAs,
                            onNewMaterialGraph: () =>
                                widget.workspaceController.createMaterialGraph(),
                            onNewMathGraph: () =>
                                widget.workspaceController.createMathGraph(),
                            onNewFolder: () =>
                                widget.workspaceController.createFolder(),
                            onImportImage: () =>
                                widget.workspaceController.importImage(),
                            onImportSvg: () =>
                                widget.workspaceController.importSvg(),
                            onAbout: _showAbout,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _WorkspaceToolbar(
                              workspaceController: widget.workspaceController,
                              materialGraphController:
                                  widget.materialGraphController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: MultiSplitViewTheme(
                          data: MultiSplitViewThemeData(
                            dividerPainter: DividerPainters.grooved1(),
                          ),
                          child: MultiSplitView(
                            controller: _splitViewController,
                            builder: (context, area) {
                              switch (area.data as int) {
                                case 0:
                                  return OutlinerPanel(
                                    controller: widget.workspaceController,
                                  );
                                case 1:
                                  return _buildEditor(resource);
                                case 2:
                                  return _buildInspector(resource);
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Map<ShortcutActivator, VoidCallback> _workspaceMenuShortcuts() {
    void run(Future<void> Function() action) {
      unawaited(action());
    }

    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
          run(_newWorkspace),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
          run(_newWorkspace),
      const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () =>
          run(_openWorkspace),
      const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
          run(_openWorkspace),
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
          run(_saveWorkspace),
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
          run(_saveWorkspace),
      const SingleActivator(
        LogicalKeyboardKey.keyS,
        meta: true,
        shift: true,
      ): () =>
          run(_saveWorkspaceAs),
      const SingleActivator(
        LogicalKeyboardKey.keyS,
        control: true,
        shift: true,
      ): () =>
          run(_saveWorkspaceAs),
    };
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!widget.workspaceController.isDirty) {
      return true;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Discard changes and continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return discard ?? false;
  }

  Future<void> _newWorkspace() async {
    if (!await _confirmDiscardIfDirty()) {
      return;
    }
    widget.workspaceController.newUntitledWorkspace();
  }

  Future<void> _openWorkspace() async {
    if (!await _confirmDiscardIfDirty()) {
      return;
    }
    await widget.workspaceController.openWorkspaceFile();
  }

  Future<void> _openRecentWorkspace(String path) async {
    if (!await _confirmDiscardIfDirty()) {
      return;
    }
    try {
      await widget.workspaceController.openWorkspaceFromPath(path);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open workspace: $e')));
    }
  }

  Future<void> _saveWorkspace() async {
    await widget.workspaceController.saveWorkspaceFile();
  }

  Future<void> _saveWorkspaceAs() async {
    await widget.workspaceController.saveWorkspaceAs();
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Eyecandy',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.palette_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const SizedBox(height: 12),
        Text(
          'A desktop-first material graph editor foundation.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildEditor(WorkspaceResourceEntry? resource) {
    if (resource?.kind == WorkspaceResourceKind.materialGraph) {
      return MaterialGraphPanel(controller: widget.materialGraphController);
    }

    if (resource?.kind == WorkspaceResourceKind.mathGraph) {
      return MathGraphPanel(controller: widget.mathGraphController);
    }

    if (resource?.kind == WorkspaceResourceKind.image) {
      final document = widget.workspaceController.openedImageDocument;
      if (document != null) {
        return _AssetPreviewPanel(
          title: 'Image Resource',
          subtitle: document.sourceName,
          child: Image.memory(
            base64Decode(document.encodedBytesBase64),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text('Unable to decode image resource.'),
              );
            },
          ),
        );
      }
    }

    if (resource?.kind == WorkspaceResourceKind.svg) {
      final document = widget.workspaceController.openedSvgDocument;
      if (document != null) {
        return _AssetPreviewPanel(
          title: 'SVG Resource',
          subtitle: document.sourceName,
          child: SvgPicture.string(
            document.svgText,
            fit: BoxFit.contain,
            placeholderBuilder: (context) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      }
    }

    return const _PlaceholderPanel(
      title: 'Editor',
      subtitle: 'No resource open',
      message:
          'Select a resource in the outliner, then use Open from the context menu to load it here.',
    );
  }

  Widget _buildInspector(WorkspaceResourceEntry? resource) {
    if (resource?.kind == WorkspaceResourceKind.materialGraph) {
      return PropertyEditorPanel(
        controller: widget.materialGraphController,
        workspaceController: widget.workspaceController,
      );
    }

    if (resource?.kind == WorkspaceResourceKind.mathGraph) {
      return MathGraphInspectorPanel(controller: widget.mathGraphController);
    }

    if (resource?.kind == WorkspaceResourceKind.image) {
      final document = widget.workspaceController.openedImageDocument;
      if (document != null) {
        return _AssetInfoPanel(
          title: 'Image Inspector',
          subtitle: resource!.name,
          entries: [
            ('Source', document.sourceName),
            ('Bytes', '${base64Decode(document.encodedBytesBase64).length}'),
            ('Mime', document.mimeType ?? 'Unknown'),
          ],
        );
      }
    }

    if (resource?.kind == WorkspaceResourceKind.svg) {
      final document = widget.workspaceController.openedSvgDocument;
      if (document != null) {
        return _AssetInfoPanel(
          title: 'SVG Inspector',
          subtitle: resource!.name,
          entries: [
            ('Source', document.sourceName),
            ('Characters', '${document.svgText.length}'),
          ],
        );
      }
    }

    return const _PlaceholderPanel(
      title: 'Inspector',
      subtitle: 'Selection details',
      message:
          'Material node properties will appear here when you open a material graph and select a node.',
    );
  }

  void _persistLayout() {
    if (_splitViewController.areasCount < 3) {
      return;
    }

    final leftPaneWidth = _splitViewController.areas[0].size ?? 260;
    final inspectorWidth = _splitViewController.areas[2].size ?? 320;

    widget.workspaceController.saveLayout(
      leftPaneWidth: leftPaneWidth,
      inspectorWidth: inspectorWidth,
    );
  }

  void _syncEditorBinding() {
    if (!widget.workspaceController.isInitialized) {
      return;
    }

    final activeMaterial =
        widget.workspaceController.openedMaterialGraphDocument;
    if (activeMaterial == null) {
      if (widget.materialGraphController.hasGraph) {
        widget.materialGraphController.clearGraph();
      }
    } else if (!widget.materialGraphController.hasGraph ||
        widget.materialGraphController.graphId != activeMaterial.graph.id ||
        !identical(
          widget.materialGraphController.graph,
          activeMaterial.graph,
        )) {
      widget.materialGraphController.bindGraph(
        graph: activeMaterial.graph,
        graphOutputSizeSettings: activeMaterial.outputSizeSettings,
        onChanged: widget.workspaceController.updateActiveMaterialGraph,
        onGraphOutputSizeSettingsChanged: widget
            .workspaceController
            .updateActiveMaterialGraphOutputSizeSettings,
      );
    }

    final activeMath = widget.workspaceController.openedMathGraphDocument;
    if (activeMath == null) {
      if (widget.mathGraphController.hasGraph) {
        widget.mathGraphController.clearGraph();
      }
      return;
    }

    if (!widget.mathGraphController.hasGraph ||
        widget.mathGraphController.graphId != activeMath.graph.id ||
        !identical(widget.mathGraphController.graph, activeMath.graph)) {
      widget.mathGraphController.bindGraph(
        graph: activeMath.graph,
        onChanged: widget.workspaceController.updateActiveMathGraph,
      );
    }
  }
}

class _WorkspaceMenuBar extends StatelessWidget {
  const _WorkspaceMenuBar({
    required this.workspaceController,
    required this.onNewWorkspace,
    required this.onOpenWorkspace,
    required this.onOpenRecentWorkspace,
    required this.onSaveWorkspace,
    required this.onSaveWorkspaceAs,
    required this.onNewMaterialGraph,
    required this.onNewMathGraph,
    required this.onNewFolder,
    required this.onImportImage,
    required this.onImportSvg,
    required this.onAbout,
  });

  final WorkspaceController workspaceController;
  final Future<void> Function() onNewWorkspace;
  final Future<void> Function() onOpenWorkspace;
  final Future<void> Function(String path) onOpenRecentWorkspace;
  final Future<void> Function() onSaveWorkspace;
  final Future<void> Function() onSaveWorkspaceAs;
  final VoidCallback onNewMaterialGraph;
  final VoidCallback onNewMathGraph;
  final VoidCallback onNewFolder;
  final Future<void> Function() onImportImage;
  final Future<void> Function() onImportSvg;
  final VoidCallback onAbout;

  static Widget _sectionDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = workspaceController.recentFiles;

    return MenuBar(
      style: const MenuStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 2)),
      ),
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: () => unawaited(onNewWorkspace()),
              child: const Text('New workspace'),
            ),
            MenuItemButton(
              onPressed: () => unawaited(onOpenWorkspace()),
              child: const Text('Open…'),
            ),
            if (recent.isNotEmpty)
              SubmenuButton(
                menuChildren: [
                  for (final filePath in recent.take(12))
                    MenuItemButton(
                      onPressed: () =>
                          unawaited(onOpenRecentWorkspace(filePath)),
                      child: Tooltip(
                        message: filePath,
                        child: Text(
                          p.basename(filePath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
                child: const Text('Open recent'),
              ),
            _sectionDivider(context),
            MenuItemButton(
              onPressed: () => unawaited(onSaveWorkspace()),
              child: const Text('Save'),
            ),
            MenuItemButton(
              onPressed: () => unawaited(onSaveWorkspaceAs()),
              child: const Text('Save as…'),
            ),
            _sectionDivider(context),
            MenuItemButton(
              onPressed: onNewMaterialGraph,
              child: const Text('New material graph'),
            ),
            MenuItemButton(
              onPressed: onNewMathGraph,
              child: const Text('New math graph'),
            ),
            MenuItemButton(
              onPressed: onNewFolder,
              child: const Text('New folder'),
            ),
            _sectionDivider(context),
            MenuItemButton(
              onPressed: () => unawaited(onImportImage()),
              child: const Text('Import image…'),
            ),
            MenuItemButton(
              onPressed: () => unawaited(onImportSvg()),
              child: const Text('Import SVG…'),
            ),
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: onAbout,
              child: const Text('About Eyecandy'),
            ),
          ],
          child: const Text('Help'),
        ),
      ],
    );
  }
}

class _WorkspaceToolbar extends StatelessWidget {
  const _WorkspaceToolbar({
    required this.workspaceController,
    required this.materialGraphController,
  });

  final WorkspaceController workspaceController;
  final MaterialGraphController materialGraphController;

  @override
  Widget build(BuildContext context) {
    final resource = workspaceController.openedResource;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final primaryLabel = resource?.name ?? workspaceController.workspace.name;

    final secondaryParts = <String>[];
    if (resource?.kind == WorkspaceResourceKind.materialGraph) {
      secondaryParts.add(materialGraphController.rendererState.backendLabel);
      final size = materialGraphController.resolvedGraphOutputSize;
      if (size != null) {
        secondaryParts.add('${size.width}×${size.height}');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              primaryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (secondaryParts.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              secondaryParts.join(' · '),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (workspaceController.isDirty) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Unsaved changes',
              child: Icon(Icons.circle, size: 8, color: colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({
    required this.title,
    required this.subtitle,
    required this.message,
  });

  final String title;
  final String subtitle;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: title,
      subtitle: subtitle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _AssetPreviewPanel extends StatelessWidget {
  const _AssetPreviewPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: title,
      subtitle: subtitle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _AssetInfoPanel extends StatelessWidget {
  const _AssetInfoPanel({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: title,
      subtitle: subtitle,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: entries
            .map(
              (entry) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(entry.$1),
                subtitle: Text(entry.$2),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
