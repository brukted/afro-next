import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

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

        final resource = widget.workspaceController.activeResource;

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
        message: 'Math graph documents are part of the workspace model. The dedicated editor is the next pass.',
      );
    }

    return const _PlaceholderPanel(
      title: 'Editor',
      subtitle: 'No resource selected',
      message: 'Select a resource from the outliner to open it here.',
    );
  }

  Widget _buildInspector(WorkspaceResourceEntry? resource) {
    if (resource?.kind == WorkspaceResourceKind.materialGraph) {
      return PropertyEditorPanel(controller: widget.materialGraphController);
    }

    return const _PlaceholderPanel(
      title: 'Inspector',
      subtitle: 'Selection details',
      message: 'Material node properties will appear here when you open a material graph and select a node.',
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

    final activeMaterial = widget.workspaceController.activeMaterialGraphDocument;
    if (activeMaterial == null) {
      if (widget.materialGraphController.hasGraph) {
        widget.materialGraphController.clearGraph();
      }
      return;
    }

    if (!widget.materialGraphController.hasGraph ||
        widget.materialGraphController.graphId != activeMaterial.graph.id ||
        !identical(widget.materialGraphController.graph, activeMaterial.graph)) {
      widget.materialGraphController.bindGraph(
        graph: activeMaterial.graph,
        onChanged: widget.workspaceController.updateActiveMaterialGraph,
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
    final resource = workspaceController.activeResource;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(
              workspaceController.workspace.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
