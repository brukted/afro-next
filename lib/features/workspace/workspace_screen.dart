import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/widgets/panel_frame.dart';
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
  });

  final WorkspaceController workspaceController;
  final MaterialGraphController materialGraphController;

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
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _WorkspaceToolbar(
                    workspaceController: widget.workspaceController,
                    materialGraphController: widget.materialGraphController,
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
        );
      },
    );
  }

  Widget _buildEditor(WorkspaceResourceEntry? resource) {
    if (resource?.kind == WorkspaceResourceKind.materialGraph) {
      return MaterialGraphPanel(controller: widget.materialGraphController);
    }

    if (resource?.kind == WorkspaceResourceKind.mathGraph) {
      return const _PlaceholderPanel(
        title: 'Math Editor',
        subtitle: 'Math graph resource selected',
        message:
            'Math graph documents are part of the workspace model. The dedicated editor is the next pass.',
      );
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
      return;
    }

    if (!widget.materialGraphController.hasGraph ||
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(
              workspaceController.workspace.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            if (resource != null)
              Chip(
                label: Text(resource.name),
                visualDensity: VisualDensity.compact,
              ),
            const Spacer(),
            if (resource?.kind == WorkspaceResourceKind.materialGraph)
              Chip(
                label: Text(materialGraphController.rendererState.backendLabel),
                avatar: const Icon(Icons.memory_outlined, size: 14),
                visualDensity: VisualDensity.compact,
              ),
            if (resource?.kind == WorkspaceResourceKind.materialGraph &&
                materialGraphController.resolvedGraphOutputSize != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  '${materialGraphController.resolvedGraphOutputSize!.width}x${materialGraphController.resolvedGraphOutputSize!.height}',
                ),
                avatar: const Icon(Icons.aspect_ratio_outlined, size: 14),
                visualDensity: VisualDensity.compact,
              ),
            ],
            const SizedBox(width: 8),
            Text(
              workspaceController.isDirty ? 'Unsaved changes' : 'Saved',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
