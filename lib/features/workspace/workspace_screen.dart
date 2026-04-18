import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

import '../material_graph/material_graph_panel.dart';
import '../outliner/outliner_panel.dart';
import '../property_editor/property_editor_panel.dart';
import 'workspace_controller.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.controller,
  });

  final WorkspaceController controller;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final MultiSplitViewController _splitViewController;

  @override
  void initState() {
    super.initState();
    final layout = widget.controller.layoutPreferences;
    _splitViewController = MultiSplitViewController()
      ..areas = [
        Area(size: layout.leftPaneWidth, min: 220, data: 0),
        Area(flex: 1, data: 1),
        Area(size: layout.inspectorWidth, min: 280, data: 2),
      ]
      ..addListener(_persistLayout);
  }

  @override
  void dispose() {
    _splitViewController.removeListener(_persistLayout);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final activeGraph = widget.controller.activeGraph;
        final rendererState = widget.controller.rendererState;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Eyecandy'),
            actions: [
              Chip(
                label: Text(activeGraph.name),
                avatar: const Icon(Icons.account_tree_outlined, size: 18),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(rendererState.backendLabel),
                avatar: const Icon(Icons.memory_outlined, size: 18),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: MultiSplitViewTheme(
              data: MultiSplitViewThemeData(
                dividerPainter: DividerPainters.grooved1(),
              ),
              child: MultiSplitView(
                controller: _splitViewController,
                builder: (context, area) {
                  switch (area.data as int) {
                    case 0:
                      return OutlinerPanel(controller: widget.controller);
                    case 1:
                      return MaterialGraphPanel(controller: widget.controller);
                    case 2:
                      return PropertyEditorPanel(controller: widget.controller);
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _persistLayout() {
    if (_splitViewController.areasCount < 3) {
      return;
    }

    final leftPaneWidth = _splitViewController.areas[0].size ?? 260;
    final inspectorWidth = _splitViewController.areas[2].size ?? 320;

    widget.controller.saveLayout(
      leftPaneWidth: leftPaneWidth,
      inspectorWidth: inspectorWidth,
    );
  }
}
