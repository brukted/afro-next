import 'package:flutter/material.dart';

import '../../shared/widgets/panel_frame.dart';
import '../material_graph/models/material_graph_models.dart';
import '../workspace/workspace_controller.dart';

class PropertyEditorPanel extends StatelessWidget {
  const PropertyEditorPanel({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final node = controller.selectedNode;
    if (node == null) {
      return const PanelFrame(
        title: 'Property Editor',
        subtitle: 'Select a node to inspect it.',
        child: Center(child: Text('Nothing selected')),
      );
    }

    final theme = Theme.of(context);
    final definition = controller.definitionForNode(node);
    final properties = controller.boundPropertiesForNode(node);

    return PanelFrame(
      title: 'Property Editor',
      subtitle: node.name,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(definition.icon, color: definition.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(definition.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      definition.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Inputs',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...properties
              .where((property) => property.isEditable)
              .map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _EditablePropertyField(
                    controller: controller,
                    nodeId: node.id,
                    property: property,
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
            'Sockets',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          ...properties
              .where((property) => property.definition.isSocket)
              .map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SocketSummaryTile(
                    controller: controller,
                    nodeId: node.id,
                    property: property,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _EditablePropertyField extends StatelessWidget {
  const _EditablePropertyField({
    required this.controller,
    required this.nodeId,
    required this.property,
  });

  final WorkspaceController controller;
  final String nodeId;
  final GraphNodePropertyView property;

  @override
  Widget build(BuildContext context) {
    final definition = property.definition;

    switch (definition.valueType) {
      case GraphValueType.scalar:
        final value = property.value as double;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${property.label}: ${value.toStringAsFixed(2)}'),
            Slider(
              value: value,
              min: definition.min ?? 0,
              max: definition.max ?? 1,
              onChanged: (nextValue) {
                controller.updateScalarProperty(
                  nodeId: nodeId,
                  propertyId: property.id,
                  value: nextValue,
                );
              },
            ),
          ],
        );
      case GraphValueType.enumChoice:
        final value = property.value as int;
        return DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: property.label),
          items: definition.enumOptions
              .map((option) {
                return DropdownMenuItem<int>(
                  value: option.value,
                  child: Text(option.label),
                );
              })
              .toList(growable: false),
          onChanged: (nextValue) {
            if (nextValue == null) {
              return;
            }

            controller.updateEnumProperty(
              nodeId: nodeId,
              propertyId: property.id,
              value: nextValue,
            );
          },
        );
      case GraphValueType.color:
        final color = property.value as Color;
        return _ColorEditor(
          label: property.label,
          color: color,
          onChanged:
              ({double? red, double? green, double? blue, double? alpha}) {
                controller.updateColorProperty(
                  nodeId: nodeId,
                  propertyId: property.id,
                  red: red,
                  green: green,
                  blue: blue,
                  alpha: alpha,
                );
              },
        );
    }
  }
}

class _ColorEditor extends StatelessWidget {
  const _ColorEditor({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final void Function({double? red, double? green, double? blue, double? alpha})
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ChannelSlider(
          label: 'R',
          color: Colors.red,
          value: color.r,
          onChanged: (value) => onChanged(red: value),
        ),
        _ChannelSlider(
          label: 'G',
          color: Colors.green,
          value: color.g,
          onChanged: (value) => onChanged(green: value),
        ),
        _ChannelSlider(
          label: 'B',
          color: Colors.blue,
          value: color.b,
          onChanged: (value) => onChanged(blue: value),
        ),
        _ChannelSlider(
          label: 'A',
          color: Colors.white,
          value: color.a,
          onChanged: (value) => onChanged(alpha: value),
        ),
      ],
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(activeTrackColor: color, thumbColor: color),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

class _SocketSummaryTile extends StatelessWidget {
  const _SocketSummaryTile({
    required this.controller,
    required this.nodeId,
    required this.property,
  });

  final WorkspaceController controller;
  final String nodeId;
  final GraphNodePropertyView property;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInput =
        property.definition.socketDirection == GraphSocketDirection.input;
    final relatedLinks = controller.activeGraph.links
        .where((link) {
          return isInput
              ? link.toPropertyId == property.id
              : link.fromPropertyId == property.id;
        })
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInput ? Icons.input_outlined : Icons.output_outlined,
                size: 18,
                color: isInput
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(property.label)),
              Text(
                relatedLinks.isEmpty
                    ? 'Unlinked'
                    : '${relatedLinks.length} link(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (relatedLinks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...relatedLinks.map((link) {
              final connectedNode = controller.activeGraph.nodes.firstWhere(
                (node) =>
                    node.id == (isInput ? link.fromNodeId : link.toNodeId),
              );
              final connectedPropertyLabel = controller.labelForProperty(
                nodeId: connectedNode.id,
                propertyId: isInput ? link.fromPropertyId : link.toPropertyId,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${connectedNode.name} • $connectedPropertyLabel',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (isInput)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.removeLink(link.id),
                        icon: const Icon(Icons.link_off_outlined, size: 18),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
