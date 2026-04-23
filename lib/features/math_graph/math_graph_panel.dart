import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../shared/widgets/panel_frame.dart';
import '../graph/models/graph_schema.dart';
import '../node_editor/node_editor_canvas.dart';
import '../node_editor/node_editor_models.dart';
import '../node_editor/node_editor_viewport.dart';
import 'math_graph_controller.dart';
import 'math_node_definition.dart';

class MathGraphPanel extends StatefulWidget {
  const MathGraphPanel({super.key, required this.controller});

  final MathGraphController controller;

  @override
  State<MathGraphPanel> createState() => _MathGraphPanelState();
}

const double _mathNodeBodyHeight = 68;

class _MathGraphPanelState extends State<MathGraphPanel> {
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

  MathGraphController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    if (!_controller.hasGraph) {
      return const PanelFrame(
        title: 'Math Editor',
        subtitle: 'Select a math graph',
        child: Center(child: Text('No math graph selected.')),
      );
    }

    final graph = _controller.graph;
    final pendingConnection = _controller.pendingConnection;
    final diagnostics = _controller.diagnostics;
    final compiledFunction = _controller.compiledFunction;
    final nodes = _buildNodeViewModels();

    return PanelFrame(
      title: 'Math Editor',
      subtitle: graph.name,
      actions: [
        Builder(
          builder: (buttonContext) {
            return IconButton(
              tooltip: 'Add node',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              onPressed: () async {
                final renderBox =
                    buttonContext.findRenderObject() as RenderBox?;
                final globalPosition = renderBox?.localToGlobal(
                  Offset(0, renderBox.size.height),
                );
                if (globalPosition == null) {
                  return;
                }
                final action = await _showAddNodeMenu(
                  context: buttonContext,
                  globalPosition: globalPosition,
                );
                if (!buttonContext.mounted || action == null) {
                  return;
                }
                _controller.addNode(action.substring(4));
              },
              icon: const Icon(Icons.add_circle_outline, size: 16),
            );
          },
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
              ),
            ),
            child: Row(
              children: [
                Chip(
                  label: Text(
                    diagnostics.isEmpty
                        ? 'Compiled'
                        : '${diagnostics.length} issue(s)',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  avatar: Icon(
                    diagnostics.isEmpty
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 12,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                if (pendingConnection != null) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: _controller.cancelPendingConnection,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      textStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pendingConnection == null
                        ? (compiledFunction == null
                              ? 'Compile diagnostics update as you edit.'
                              : '${compiledFunction.functionName} -> ${_typeLabel(compiledFunction.returnType)}')
                        : 'Tap an input socket to finish the link.',
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                return NodeEditorCanvas<_MathNodeBodyData>(
                  viewportController: _viewportController,
                  nodes: nodes,
                  links: graph.links,
                  selectedNodeId: _controller.selectedNodeId,
                  pendingPropertyId: pendingConnection?.propertyId,
                  onSelectNode: _controller.selectNode,
                  onSetNodePosition: _controller.setNodePosition,
                  onSocketTap: (nodeId, propertyId) {
                    _controller.handleSocketTap(
                      nodeId: nodeId,
                      propertyId: propertyId,
                    );
                  },
                  onCancelPendingConnection:
                      _controller.cancelPendingConnection,
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
                  onRequestSocketMenu: (node, socket, globalPosition) {
                    return _showSocketMenu(
                      context: context,
                      node: node,
                      socket: socket,
                      globalPosition: globalPosition,
                    );
                  },
                  buildNodeBody: (context, nodeViewModel) {
                    return _MathNodeBodyCard(data: nodeViewModel.bodyData!);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<NodeEditorNodeViewModel<_MathNodeBodyData>> _buildNodeViewModels() {
    return _controller.graph.nodes
        .map((node) {
          final definition = _controller.definitionForNode(node);
          final bindings = _controller.boundPropertiesForNode(node);
          final diagnostics = _controller.diagnosticsForNode(node.id);
          return NodeEditorNodeViewModel<_MathNodeBodyData>(
            id: node.id,
            title: node.name,
            position: node.position,
            icon: _iconForDefinition(definition),
            accentColor: _colorForDefinition(context, definition),
            bodyHeight: _mathNodeBodyHeight,
            bodyData: _MathNodeBodyData(
              outputLabel: _typeLabel(definition.outputDefinition?.valueType),
              statusLabel: diagnostics.isEmpty
                  ? 'Compiled'
                  : diagnostics.first.message,
              hasErrors: diagnostics.isNotEmpty,
            ),
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
        })
        .toList(growable: false);
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
        _MathNodePickerMenuEntry(
          definitions: _controller.nodeDefinitions,
          maxHeight: 420,
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
      _controller.addNodeAt(
        action.substring(4),
        Vector2(scenePosition.dx, scenePosition.dy),
      );
    }
  }

  Future<String?> _showAddNodeMenu({
    required BuildContext context,
    required Offset globalPosition,
  }) {
    return showMenu<String>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: [
        _MathNodePickerMenuEntry(
          definitions: _controller.nodeDefinitions,
          maxHeight: 420,
        ),
      ],
    );
  }

  Future<void> _showNodeMenu({
    required BuildContext context,
    required NodeEditorNodeViewModel<_MathNodeBodyData> node,
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
    }
  }

  Future<void> _showSocketMenu({
    required BuildContext context,
    required NodeEditorNodeViewModel<_MathNodeBodyData> node,
    required NodeEditorSocketViewModel socket,
    required Offset globalPosition,
  }) async {
    if (!socket.isConnected) {
      return;
    }
    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(context, globalPosition),
      items: const [
        PopupMenuItem<String>(
          value: 'disconnect',
          height: 30,
          child: Text('Disconnect'),
        ),
      ],
    );
    if (!context.mounted || action == null) {
      return;
    }
    if (action == 'disconnect') {
      _controller.disconnectSocket(nodeId: node.id, propertyId: socket.id);
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
}

class _MathNodeBodyData {
  const _MathNodeBodyData({
    required this.outputLabel,
    required this.statusLabel,
    required this.hasErrors,
  });

  final String outputLabel;
  final String statusLabel;
  final bool hasErrors;
}

class _MathNodeBodyCard extends StatelessWidget {
  const _MathNodeBodyCard({required this.data});

  final _MathNodeBodyData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.outputLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: data.hasErrors
                ? colorScheme.errorContainer.withValues(alpha: 0.55)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            data.statusLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _MathNodePickerMenuEntry extends PopupMenuEntry<String> {
  const _MathNodePickerMenuEntry({
    required this.definitions,
    required this.maxHeight,
  });

  final List<MathNodeDefinition> definitions;
  final double maxHeight;

  @override
  double get height => maxHeight;

  @override
  bool represents(String? value) => false;

  @override
  State<_MathNodePickerMenuEntry> createState() =>
      _MathNodePickerMenuEntryState();
}

class _MathNodePickerMenuEntryState extends State<_MathNodePickerMenuEntry> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedDefinitions = _groupedDefinitions();
    final filteredDefinitions = groupedDefinitions.values
        .expand((definitions) => definitions)
        .toList(growable: false);
    final isSearching = _query.isNotEmpty;
    return SizedBox(
      width: 700,
      height: widget.maxHeight,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Math Node',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search nodes by name',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredDefinitions.isEmpty
                  ? const Center(child: Text('No matching math nodes.'))
                  : Scrollbar(
                      thumbVisibility: false,
                      child: ListView(
                        children: isSearching
                            ? filteredDefinitions
                                  .map(
                                    (definition) =>
                                        _buildNodeTile(context, definition),
                                  )
                                  .toList(growable: false)
                            : groupedDefinitions.entries
                                  .map((entry) {
                                    final category = entry.key;
                                    final definitions = entry.value;
                                    return _MathNodeCategorySection(
                                      title: _categoryLabel(category),
                                      initiallyExpanded: false,
                                      children: definitions
                                          .map(
                                            (definition) => _buildNodeTile(
                                              context,
                                              definition,
                                            ),
                                          )
                                          .toList(growable: false),
                                    );
                                  })
                                  .toList(growable: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<MathNodeKind, List<MathNodeDefinition>> _groupedDefinitions() {
    final result = <MathNodeKind, List<MathNodeDefinition>>{};
    for (final definition in widget.definitions) {
      if (_query.isNotEmpty &&
          !definition.label.toLowerCase().contains(_query) &&
          !definition.description.toLowerCase().contains(_query)) {
        continue;
      }
      result
          .putIfAbsent(
            definition.compileMetadata.kind,
            () => <MathNodeDefinition>[],
          )
          .add(definition);
    }
    for (final entry in result.values) {
      entry.sort((left, right) => left.label.compareTo(right.label));
    }
    return result;
  }

  Widget _buildNodeTile(BuildContext context, MathNodeDefinition definition) {
    return ListTile(
      dense: true,
      leading: Icon(
        _iconForDefinition(definition),
        color: _colorForDefinition(context, definition),
      ),
      title: Text(definition.label),
      subtitle: definition.description.isEmpty
          ? null
          : Text(
              definition.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Text(
        _typeLabel(definition.outputDefinition?.valueType),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      onTap: () {
        Navigator.of(context).pop('add:${definition.id}');
      },
    );
  }
}

class _MathNodeCategorySection extends StatelessWidget {
  const _MathNodeCategorySection({
    required this.title,
    required this.children,
    required this.initiallyExpanded,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      childrenPadding: EdgeInsets.zero,
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      initiallyExpanded: initiallyExpanded,
      children: children,
    );
  }
}

IconData _iconForDefinition(MathNodeDefinition definition) {
  switch (definition.compileMetadata.kind) {
    case MathNodeKind.constant:
      return Icons.pin_outlined;
    case MathNodeKind.inputParameter:
      return Icons.input_outlined;
    case MathNodeKind.builtin:
      return Icons.gps_fixed_outlined;
    case MathNodeKind.sampler:
      return Icons.texture_outlined;
    case MathNodeKind.operation:
      return Icons.functions_outlined;
    case MathNodeKind.variableSet:
      return Icons.drive_file_rename_outline;
    case MathNodeKind.variableGet:
      return Icons.inventory_2_outlined;
    case MathNodeKind.graphOutput:
      return Icons.east_outlined;
    case MathNodeKind.control:
      return Icons.alt_route_outlined;
  }
}

Color _colorForDefinition(BuildContext context, MathNodeDefinition definition) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (definition.compileMetadata.kind) {
    case MathNodeKind.constant:
      return colorScheme.primary;
    case MathNodeKind.inputParameter:
      return colorScheme.secondary;
    case MathNodeKind.builtin:
      return colorScheme.tertiary;
    case MathNodeKind.sampler:
      return Colors.orange.shade300;
    case MathNodeKind.operation:
      return Colors.cyan.shade300;
    case MathNodeKind.variableSet:
    case MathNodeKind.variableGet:
      return Colors.purple.shade300;
    case MathNodeKind.graphOutput:
      return Colors.green.shade300;
    case MathNodeKind.control:
      return Colors.amber.shade300;
  }
}

String _typeLabel(GraphValueType? type) {
  if (type == null) {
    return 'Unknown';
  }
  switch (type) {
    case GraphValueType.boolean:
      return 'bool';
    case GraphValueType.integer:
      return 'int';
    case GraphValueType.integer2:
      return 'ivec2';
    case GraphValueType.integer3:
      return 'ivec3';
    case GraphValueType.integer4:
      return 'ivec4';
    case GraphValueType.float:
      return 'float';
    case GraphValueType.float2:
      return 'vec2';
    case GraphValueType.float3:
      return 'vec3';
    case GraphValueType.float4:
      return 'vec4';
    case GraphValueType.float3x3:
      return 'mat3';
    case GraphValueType.stringValue:
      return 'string';
    case GraphValueType.workspaceResource:
      return 'resource';
    case GraphValueType.enumChoice:
      return 'enum';
    case GraphValueType.gradient:
      return 'gradient';
    case GraphValueType.colorBezierCurve:
      return 'curve';
    case GraphValueType.textBlock:
      return 'text';
  }
}

String _categoryLabel(MathNodeKind kind) {
  switch (kind) {
    case MathNodeKind.constant:
      return 'Constants';
    case MathNodeKind.inputParameter:
      return 'Inputs';
    case MathNodeKind.builtin:
      return 'Builtins';
    case MathNodeKind.sampler:
      return 'Samplers';
    case MathNodeKind.operation:
      return 'Operations';
    case MathNodeKind.variableSet:
    case MathNodeKind.variableGet:
      return 'Variables';
    case MathNodeKind.graphOutput:
      return 'Outputs';
    case MathNodeKind.control:
      return 'Control Flow';
  }
}
