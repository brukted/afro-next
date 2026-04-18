import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector4;

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/widgets/panel_frame.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_schema.dart';
import '../material_graph/material_graph_controller.dart';

class PropertyEditorPanel extends StatelessWidget {
  const PropertyEditorPanel({
    super.key,
    required this.controller,
  });

  final MaterialGraphController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasGraph) {
      return const PanelFrame(
        title: 'Property Editor',
        subtitle: 'Select a material graph',
        child: Center(child: Text('No editable material graph selected.')),
      );
    }

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
    final accentColor = Vector4ColorAdapter.toFlutterColor(definition.accentColor);

    return PanelFrame(
      title: 'Property Editor',
      subtitle: node.name,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Icon(definition.icon, color: accentColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(definition.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
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
          const SizedBox(height: 16),
          Text(
            'Properties',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...properties
              .where((property) => property.isEditable)
              .map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _EditablePropertyField(
                    controller: controller,
                    nodeId: node.id,
                    property: property,
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Text(
            'Sockets',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...properties
              .where((property) => property.definition.isSocket)
              .map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SocketSummaryTile(
                    controller: controller,
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

  final MaterialGraphController controller;
  final String nodeId;
  final GraphPropertyBinding property;

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
          decoration: InputDecoration(
            labelText: property.label,
            isDense: true,
          ),
          items: definition.enumOptions
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option.value,
                  child: Text(option.label),
                ),
              )
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
        final color = property.value as Vector4;
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
  final Vector4 color;
  final void Function({double? red, double? green, double? blue, double? alpha})
      onChanged;

  @override
  Widget build(BuildContext context) {
    final flutterColor = Vector4ColorAdapter.toFlutterColor(color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: flutterColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ChannelSlider(
          label: 'R',
          color: Colors.red,
          value: color.x,
          onChanged: (value) => onChanged(red: value),
        ),
        _ChannelSlider(
          label: 'G',
          color: Colors.green,
          value: color.y,
          onChanged: (value) => onChanged(green: value),
        ),
        _ChannelSlider(
          label: 'B',
          color: Colors.blue,
          value: color.z,
          onChanged: (value) => onChanged(blue: value),
        ),
        _ChannelSlider(
          label: 'A',
          color: Colors.white,
          value: color.w,
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
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              activeColor: color,
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SocketSummaryTile extends StatelessWidget {
  const _SocketSummaryTile({
    required this.controller,
    required this.property,
  });

  final MaterialGraphController controller;
  final GraphPropertyBinding property;

  @override
  Widget build(BuildContext context) {
    final direction = property.definition.socketDirection!;
    final isConnected = direction == GraphSocketDirection.input
        ? controller.hasIncomingLink(property.id)
        : controller.hasOutgoingLink(property.id);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              direction == GraphSocketDirection.input
                  ? Icons.arrow_right_alt
                  : Icons.arrow_left,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(property.label)),
            Text(
              isConnected ? 'connected' : 'open',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
