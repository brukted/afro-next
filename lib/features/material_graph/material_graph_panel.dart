import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/widgets/panel_frame.dart';
import '../../vulkan/resources/preview_render_target.dart';
import '../graph/models/graph_schema.dart';
import '../node_editor/node_editor_canvas.dart';
import '../node_editor/node_editor_models.dart';
import '../node_editor/node_editor_viewport.dart';
import 'material_graph_controller.dart';
import 'material_node_definition.dart';
import 'material_output_size.dart';
import 'runtime/material_execution_ir.dart';

class MaterialGraphPanel extends StatefulWidget {
  const MaterialGraphPanel({super.key, required this.controller});

  final MaterialGraphController controller;

  @override
  State<MaterialGraphPanel> createState() => _MaterialGraphPanelState();
}

final double _materialNodePreviewSurfaceExtent =
    nodeEditorNodeWidth - nodeEditorBodyPadding.horizontal;
const double _materialNodePreviewFooterSpacing = 6;
const double _materialNodePreviewFooterHeight = 28;
final double _materialNodePreviewBodyHeight =
    _materialNodePreviewSurfaceExtent +
    _materialNodePreviewFooterSpacing +
    _materialNodePreviewFooterHeight;

class _MaterialGraphPanelState extends State<MaterialGraphPanel> {
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

  MaterialGraphController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    if (!_controller.hasGraph) {
      return const PanelFrame(
        title: 'Material Editor',
        subtitle: 'Select a material graph',
        child: Center(child: Text('No material graph selected.')),
      );
    }

    final graph = _controller.graph;
    final rendererState = _controller.rendererState;
    final pendingConnection = _controller.pendingConnection;

    return PanelFrame(
      title: 'Material Editor',
      subtitle: graph.name,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Add node',
          onSelected: _controller.addNode,
          itemBuilder: (context) => _controller.nodeDefinitions
              .map(
                (definition) => PopupMenuItem<String>(
                  value: definition.id,
                  child: _NodeDefinitionLabel(definition: definition),
                ),
              )
              .toList(growable: false),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.add_circle_outline, size: 16),
          ),
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
                    rendererState.backendLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  avatar: const Icon(Icons.memory_outlined, size: 12),
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pendingConnection == null
                        ? rendererState.summary
                        : 'Tap an input socket to finish the link.',
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    _resolvedGraphSizeLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  avatar: const Icon(Icons.aspect_ratio_outlined, size: 12),
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => _showOutputSizeSettingsDialog(context),
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
                  child: const Text('Output Size'),
                ),
                if (pendingConnection != null)
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
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final nodes = _buildNodeViewModels();
                return NodeEditorCanvas<PreviewRenderTarget?>(
                  viewportController: _viewportController,
                  nodes: nodes,
                  links: graph.links,
                  selectedNodeId: _controller.selectedNodeId,
                  pendingPropertyId: _controller.pendingConnection?.propertyId,
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
                    return MaterialNodePreviewCard(
                      title: nodeViewModel.title,
                      preview: nodeViewModel.bodyData,
                      resolvedOutputSizeLabel: _resolvedNodeSizeLabel(
                        nodeViewModel.id,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<NodeEditorNodeViewModel<PreviewRenderTarget?>> _buildNodeViewModels() {
    return _controller.graph.nodes
        .map((node) {
          final definition = _controller.definitionForNode(node);
          final accentColor = Vector4ColorAdapter.toFlutterColor(
            definition.accentColor,
          );
          final bindings = _controller.boundPropertiesForNode(node);

          return NodeEditorNodeViewModel<PreviewRenderTarget?>(
            id: node.id,
            title: node.name,
            position: node.position,
            icon: definition.icon,
            accentColor: accentColor,
            bodyHeight: _materialNodePreviewBodyHeight,
            bodyData: _controller.previewForNode(node.id),
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
        _sectionHeader(context, 'Add node'),
        ..._controller.nodeDefinitions.map(
          (definition) => PopupMenuItem<String>(
            value: 'add:${definition.id}',
            height: 30,
            child: _NodeDefinitionLabel(definition: definition),
          ),
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
      final definitionId = action.substring(4);
      _controller.addNodeAt(
        definitionId,
        Vector2(scenePosition.dx, scenePosition.dy),
      );
    }
  }

  Future<void> _showNodeMenu({
    required BuildContext context,
    required NodeEditorNodeViewModel node,
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
      default:
        return;
    }
  }

  Future<void> _showSocketMenu({
    required BuildContext context,
    required NodeEditorNodeViewModel node,
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

    switch (action) {
      case 'disconnect':
        _controller.disconnectSocket(nodeId: node.id, propertyId: socket.id);
        return;
      default:
        return;
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

  PopupMenuEntry<String> _sectionHeader(BuildContext context, String label) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 26,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String get _resolvedGraphSizeLabel {
    return _resolvedSizeLabel(
      _controller.resolvedGraphOutputSize,
      fallback: 'Graph size',
    );
  }

  String _resolvedNodeSizeLabel(String nodeId) {
    return _resolvedSizeLabel(
      _controller.resolvedOutputSizeForNode(nodeId),
      fallback: 'Pending',
    );
  }

  String _resolvedSizeLabel(
    MaterialResolvedOutputSize? resolved, {
    required String fallback,
  }) {
    return resolved?.extentLabel ?? fallback;
  }

  Future<void> _showOutputSizeSettingsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final graphSettings = _controller.graphOutputSizeSettings;
                final sessionSize = _controller.sessionParentOutputSize;
                final resolved = _controller.resolvedGraphOutputSize;
                final range =
                    graphSettings.mode == MaterialOutputSizeMode.absolute
                    ? (
                        min: materialOutputSizeMinLog2,
                        max: materialOutputSizeMaxLog2,
                      )
                    : (
                        min: materialOutputSizeRelativeMinDelta,
                        max: materialOutputSizeRelativeMaxDelta,
                      );
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Output Size Settings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _OutputSizeSection(
                        title: 'Graph',
                        subtitle: resolved == null
                            ? null
                            : 'Resolved: ${resolved.width}x${resolved.height}',
                        mode: graphSettings.mode,
                        value: graphSettings.value,
                        min: range.min,
                        max: range.max,
                        onModeChanged: _controller.updateGraphOutputSizeMode,
                        onValueChanged: _controller.updateGraphOutputSizeValue,
                      ),
                      const SizedBox(height: 14),
                      _OutputSizeSection(
                        title: 'Editor Parent Size',
                        subtitle:
                            'Used when the graph resolves upward to the editor session.',
                        mode: MaterialOutputSizeMode.absolute,
                        value: sessionSize,
                        min: materialOutputSizeMinLog2,
                        max: materialOutputSizeMaxLog2,
                        modeEnabled: false,
                        onModeChanged: (_) {},
                        onValueChanged:
                            _controller.updateSessionParentOutputSize,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _OutputSizeSection extends StatelessWidget {
  const _OutputSizeSection({
    required this.title,
    required this.mode,
    required this.value,
    required this.min,
    required this.max,
    required this.onModeChanged,
    required this.onValueChanged,
    this.subtitle,
    this.modeEnabled = true,
  });

  final String title;
  final String? subtitle;
  final MaterialOutputSizeMode mode;
  final MaterialOutputSizeValue value;
  final int min;
  final int max;
  final bool modeEnabled;
  final ValueChanged<MaterialOutputSizeMode> onModeChanged;
  final ValueChanged<MaterialOutputSizeValue> onValueChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<MaterialOutputSizeMode>(
              initialValue: mode,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mode',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: materialOutputSizeModeOptions
                  .map(
                    (option) => DropdownMenuItem<MaterialOutputSizeMode>(
                      value: materialOutputSizeModeFromEnumValue(option.value),
                      child: Text(option.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: !modeEnabled
                  ? null
                  : (nextValue) {
                      if (nextValue != null) {
                        onModeChanged(nextValue);
                      }
                    },
            ),
            const SizedBox(height: 10),
            _OutputSizeVectorEditor(
              value: value,
              min: min,
              max: max,
              onChanged: onValueChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputSizeVectorEditor extends StatelessWidget {
  const _OutputSizeVectorEditor({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final MaterialOutputSizeValue value;
  final int min;
  final int max;
  final ValueChanged<MaterialOutputSizeValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OutputSizeIntField(
            label: 'Width',
            value: value.widthLog2,
            min: min,
            max: max,
            onChanged: (nextValue) {
              onChanged(value.copyWith(widthLog2: nextValue));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OutputSizeIntField(
            label: 'Height',
            value: value.heightLog2,
            min: min,
            max: max,
            onChanged: (nextValue) {
              onChanged(value.copyWith(heightLog2: nextValue));
            },
          ),
        ),
      ],
    );
  }
}

class _OutputSizeIntField extends StatefulWidget {
  const _OutputSizeIntField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<_OutputSizeIntField> createState() => _OutputSizeIntFieldState();
}

class _OutputSizeIntFieldState extends State<_OutputSizeIntField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _OutputSizeIntField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    final nextText = widget.value.toString();
    if (_controller.text != nextText) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      onTapOutside: (_) => _submit(),
      onFieldSubmitted: (_) => _submit(),
    );
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    final nextValue = (parsed ?? widget.value).clamp(widget.min, widget.max);
    _controller.text = nextValue.toString();
    if (nextValue != widget.value) {
      widget.onChanged(nextValue);
    }
  }
}

class _NodeDefinitionLabel extends StatelessWidget {
  const _NodeDefinitionLabel({required this.definition});

  final MaterialNodeDefinition definition;

  String? get _tooltipMessage {
    final description = definition.description.trim();
    if (description.isEmpty ||
        description == 'Empty desc' ||
        description == definition.label) {
      return null;
    }
    return description;
  }

  @override
  Widget build(BuildContext context) {
    final tooltipMessage = _tooltipMessage;
    return Row(
      children: [
        Icon(
          definition.icon,
          size: 16,
          color: Vector4ColorAdapter.toFlutterColor(definition.accentColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(definition.label, overflow: TextOverflow.ellipsis),
        ),
        if (tooltipMessage != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltipMessage,
            child: MouseRegion(
              cursor: SystemMouseCursors.help,
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: Theme.of(context).hintColor.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class MaterialNodePreviewCard extends StatelessWidget {
  const MaterialNodePreviewCard({
    super.key,
    required this.title,
    required this.preview,
    this.resolvedOutputSizeLabel = '',
    this.previewTextureBuilder,
  });

  final String title;
  final PreviewRenderTarget? preview;
  final String resolvedOutputSizeLabel;
  final Widget Function(BuildContext context, PreviewTextureDescriptor texture)?
  previewTextureBuilder;

  @override
  Widget build(BuildContext context) {
    final texture = preview?.texture;
    final hasTexture = preview?.hasTexture ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF121720),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final surfaceHeight = math.max(
              0.0,
              constraints.maxHeight -
                  _materialNodePreviewFooterSpacing -
                  _materialNodePreviewFooterHeight,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: surfaceHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasTexture && texture != null
                        ? _LivePreviewSurface(
                            texture: texture,
                            previewTextureBuilder: previewTextureBuilder,
                          )
                        : ColoredBox(
                            color: const Color(0xFF171D27),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  preview?.diagnostics.firstOrNull ?? title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: _materialNodePreviewFooterSpacing),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SizedBox(
                    height: _materialNodePreviewFooterHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview?.label ?? 'Preview',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (preview != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                resolvedOutputSizeLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                              ),
                            ),
                          if (preview != null)
                            Text(
                              preview!.status.name,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LivePreviewSurface extends StatelessWidget {
  const _LivePreviewSurface({
    required this.texture,
    this.previewTextureBuilder,
  });

  final PreviewTextureDescriptor texture;
  final Widget Function(BuildContext context, PreviewTextureDescriptor texture)?
  previewTextureBuilder;

  static const _previewKey = Key('material-node-live-preview');

  @override
  Widget build(BuildContext context) {
    final aspectRatio = texture.height == 0
        ? 1.0
        : texture.width / texture.height;
    final textureChild =
        previewTextureBuilder?.call(context, texture) ??
        Texture(
          key: _previewKey,
          textureId: texture.textureId,
          filterQuality: FilterQuality.medium,
        );

    return _AlphaPreviewBackground(
      child: Center(
        child: AspectRatio(aspectRatio: aspectRatio, child: textureChild),
      ),
    );
  }
}

class _AlphaPreviewBackground extends StatelessWidget {
  const _AlphaPreviewBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TransparencyCheckerPainter(), child: child);
  }
}

class _TransparencyCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 10.0;
    final lightPaint = Paint()..color = const Color(0xFF3B404C);
    final darkPaint = Paint()..color = const Color(0xFF242933);

    for (var y = 0.0; y < size.height; y += tileSize) {
      for (var x = 0.0; x < size.width; x += tileSize) {
        final isLightTile =
            ((x / tileSize).floor() + (y / tileSize).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isLightTile ? lightPaint : darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
