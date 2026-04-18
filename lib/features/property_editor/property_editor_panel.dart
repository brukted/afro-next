import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:vector_math/vector_math.dart' show Vector2, Vector3, Vector4;

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/widgets/panel_frame.dart';
import 'color_curve_editor.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import '../material_graph/material_graph_controller.dart';

class PropertyEditorPanel extends StatelessWidget {
  const PropertyEditorPanel({super.key, required this.controller});

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
    final editableProperties = properties
        .where((property) => property.isEditable)
        .toList(growable: false);
    final outputProperties = properties
        .where(
          (property) =>
              property.definition.propertyType == GraphPropertyType.output,
        )
        .toList(growable: false);
    final accentColor = Vector4ColorAdapter.toFlutterColor(
      definition.accentColor,
    );

    return PanelFrame(
      title: 'Property Editor',
      subtitle: node.name,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(definition.icon, color: accentColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.label,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (definition.description.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            definition.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...editableProperties.map(
            (property) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EditablePropertyField(
                controller: controller,
                nodeId: node.id,
                property: property,
              ),
            ),
          ),
          if (outputProperties.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Outputs',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ...outputProperties.map(
              (property) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SocketSummaryTile(
                  controller: controller,
                  property: property,
                ),
              ),
            ),
          ],
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
    final theme = Theme.of(context);

    return _PropertyCard(
      label: property.label,
      description: definition.description == 'Empty desc'
          ? null
          : definition.description,
      badge: _buildBadge(context),
      child: switch (definition.valueType) {
        GraphValueType.integer => _NumericValueEditor(
          value: (property.value as int).toDouble(),
          integer: true,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 1,
          onChanged: (nextValue) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer(nextValue.round()),
          ),
        ),
        GraphValueType.integer2 => _VectorNumberEditor(
          values: (property.value as List<int>)
              .map((value) => value.toDouble())
              .toList(),
          labels: const ['X', 'Y'],
          integer: true,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 1,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer2(
              values.map((value) => value.round()).toList(),
            ),
          ),
        ),
        GraphValueType.integer3 => _VectorNumberEditor(
          values: (property.value as List<int>)
              .map((value) => value.toDouble())
              .toList(),
          labels: const ['X', 'Y', 'Z'],
          integer: true,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 1,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer3(
              values.map((value) => value.round()).toList(),
            ),
          ),
        ),
        GraphValueType.integer4 => _VectorNumberEditor(
          values: (property.value as List<int>)
              .map((value) => value.toDouble())
              .toList(),
          labels: const ['X', 'Y', 'Z', 'W'],
          integer: true,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 1,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer4(
              values.map((value) => value.round()).toList(),
            ),
          ),
        ),
        GraphValueType.float => _NumericValueEditor(
          value: property.value as double,
          integer: false,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 0.01,
          onChanged: (nextValue) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.float(nextValue),
          ),
        ),
        GraphValueType.float2 => _FloatVectorField(
          property: property,
          nodeId: nodeId,
          controller: controller,
        ),
        GraphValueType.float3 when definition.isColor => _ColorEditor(
          color: (() {
            final value = property.value as Vector3;
            return Vector4(value.x, value.y, value.z, 1);
          })(),
          includeAlpha: false,
          onColorPicked: (nextColor) {
            controller.updatePropertyValue(
              nodeId: nodeId,
              propertyId: property.id,
              value: GraphValueData.float3(
                Vector3(nextColor.x, nextColor.y, nextColor.z),
              ),
            );
          },
          onChannelChanged: (index, nextValue) {
            final current = property.valueData.asFloat3();
            final next = switch (index) {
              0 => Vector3(nextValue, current.y, current.z),
              1 => Vector3(current.x, nextValue, current.z),
              _ => Vector3(current.x, current.y, nextValue),
            };
            controller.updatePropertyValue(
              nodeId: nodeId,
              propertyId: property.id,
              value: GraphValueData.float3(next),
            );
          },
        ),
        GraphValueType.float3 => _FloatVectorField(
          property: property,
          nodeId: nodeId,
          controller: controller,
        ),
        GraphValueType.float4 when definition.isColor => _ColorEditor(
          color: property.valueData.asFloat4(),
          includeAlpha: true,
          onColorPicked: (nextColor) {
            controller.updatePropertyValue(
              nodeId: nodeId,
              propertyId: property.id,
              value: GraphValueData.float4(nextColor),
            );
          },
          onChannelChanged: (index, nextValue) {
            final current = property.valueData.asFloat4();
            final next = switch (index) {
              0 => Vector4(nextValue, current.y, current.z, current.w),
              1 => Vector4(current.x, nextValue, current.z, current.w),
              2 => Vector4(current.x, current.y, nextValue, current.w),
              _ => Vector4(current.x, current.y, current.z, nextValue),
            };
            controller.updatePropertyValue(
              nodeId: nodeId,
              propertyId: property.id,
              value: GraphValueData.float4(next),
            );
          },
        ),
        GraphValueType.float4 => _FloatVectorField(
          property: property,
          nodeId: nodeId,
          controller: controller,
        ),
        GraphValueType.stringValue => _StringValueEditor(
          initialValue: property.value as String,
          onSubmitted: (nextValue) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.stringValue(nextValue),
          ),
        ),
        GraphValueType.boolean => Row(
          children: [
            Checkbox(
              value: property.value as bool,
              visualDensity: VisualDensity.compact,
              onChanged: (nextValue) {
                if (nextValue == null) {
                  return;
                }
                controller.updatePropertyValue(
                  nodeId: nodeId,
                  propertyId: property.id,
                  value: GraphValueData.boolean(nextValue),
                );
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                (property.value as bool) ? 'Enabled' : 'Disabled',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        GraphValueType.enumChoice => DropdownButtonFormField<int>(
          initialValue: property.value as int,
          isDense: true,
          isExpanded: true,
          itemHeight: kMinInteractiveDimension,
          menuMaxHeight: 320,
          borderRadius: BorderRadius.circular(10),
          dropdownColor: theme.colorScheme.surfaceContainerLow,
          decoration: _denseInputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
          ),
          items: definition.enumOptions
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option.value,
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (nextValue) {
            if (nextValue == null) {
              return;
            }
            controller.updatePropertyValue(
              nodeId: nodeId,
              propertyId: property.id,
              value: GraphValueData.enumChoice(nextValue),
            );
          },
        ),
        GraphValueType.colorBezierCurve => _CurveSummaryField(
          curve: property.value as GraphColorCurveData,
          onChanged: (nextCurve) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.colorCurve(nextCurve),
          ),
        ),
      },
    );
  }

  Widget? _buildBadge(BuildContext context) {
    if (!property.definition.isSocket) {
      return null;
    }

    final direction = property.definition.socketDirection;
    if (direction == null) {
      return null;
    }

    final isConnected = direction == GraphSocketDirection.input
        ? controller.hasIncomingLink(property.id)
        : controller.hasOutgoingLink(property.id);
    return _MetaBadge(
      label: '${direction.name} ${isConnected ? 'connected' : 'open'}',
      tone: isConnected ? BadgeTone.active : BadgeTone.subtle,
    );
  }
}

class _FloatVectorField extends StatelessWidget {
  const _FloatVectorField({
    required this.property,
    required this.nodeId,
    required this.controller,
  });

  final GraphPropertyBinding property;
  final String nodeId;
  final MaterialGraphController controller;

  @override
  Widget build(BuildContext context) {
    final definition = property.definition;
    final labels = switch (definition.valueType) {
      GraphValueType.float2 => const ['X', 'Y'],
      GraphValueType.float3 => const ['X', 'Y', 'Z'],
      GraphValueType.float4 => const ['X', 'Y', 'Z', 'W'],
      _ => const <String>[],
    };
    final values = switch (definition.valueType) {
      GraphValueType.float2 => _vector2ToList(property.value as Vector2),
      GraphValueType.float3 => _vector3ToList(property.value as Vector3),
      GraphValueType.float4 => _vector4ToList(property.value as Vector4),
      _ => const <double>[],
    };

    return _VectorNumberEditor(
      values: values,
      labels: labels,
      integer: false,
      min: definition.min?.toDouble(),
      max: definition.max?.toDouble(),
      step: definition.step ?? 0.01,
      onChanged: (nextValues) {
        final nextValue = switch (definition.valueType) {
          GraphValueType.float2 => GraphValueData.float2(
            Vector2(nextValues[0], nextValues[1]),
          ),
          GraphValueType.float3 => GraphValueData.float3(
            Vector3(nextValues[0], nextValues[1], nextValues[2]),
          ),
          GraphValueType.float4 => GraphValueData.float4(
            Vector4(nextValues[0], nextValues[1], nextValues[2], nextValues[3]),
          ),
          _ => null,
        };
        if (nextValue == null) {
          return;
        }
        controller.updatePropertyValue(
          nodeId: nodeId,
          propertyId: property.id,
          value: nextValue,
        );
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.label,
    required this.child,
    this.description,
    this.badge,
  });

  final String label;
  final String? description;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge!],
              ],
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

enum BadgeTone { subtle, active }

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.tone});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = tone == BadgeTone.active;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.36)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _NumericValueEditor extends StatelessWidget {
  const _NumericValueEditor({
    required this.value,
    required this.integer,
    required this.onChanged,
    this.min,
    this.max,
    required this.step,
  });

  final double value;
  final bool integer;
  final double? min;
  final double? max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _NumberField(
      value: value,
      integer: integer,
      min: min,
      max: max,
      step: step,
      onChanged: onChanged,
    );
  }
}

class _VectorNumberEditor extends StatelessWidget {
  const _VectorNumberEditor({
    required this.values,
    required this.labels,
    required this.integer,
    required this.step,
    required this.onChanged,
    this.min,
    this.max,
  });

  final List<double> values;
  final List<String> labels;
  final bool integer;
  final double? min;
  final double? max;
  final double step;
  final ValueChanged<List<double>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(values.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == values.length - 1 ? 0 : 6),
          child: _NumberField(
            label: labels[index],
            value: values[index],
            integer: integer,
            min: min,
            max: max,
            step: step,
            onChanged: (nextValue) {
              final updated = List<double>.from(values);
              updated[index] = nextValue;
              onChanged(updated);
            },
          ),
        );
      }),
    );
  }
}

class _ColorEditor extends StatelessWidget {
  const _ColorEditor({
    required this.color,
    required this.includeAlpha,
    required this.onChannelChanged,
    required this.onColorPicked,
  });

  final Vector4 color;
  final bool includeAlpha;
  final void Function(int index, double value) onChannelChanged;
  final ValueChanged<Vector4> onColorPicked;

  @override
  Widget build(BuildContext context) {
    final labels = includeAlpha
        ? const ['R', 'G', 'B', 'A']
        : const ['R', 'G', 'B'];
    final values = includeAlpha
        ? _vector4ToList(color)
        : <double>[color.x, color.y, color.z];
    final swatchColor = includeAlpha
        ? color
        : Vector4(color.x, color.y, color.z, 1);

    return Column(
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => _pickColor(context, swatchColor),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Vector4ColorAdapter.toFlutterColor(swatchColor),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              includeAlpha ? 'RGBA' : 'RGB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _pickColor(context, swatchColor),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Pick'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(values.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == values.length - 1 ? 0 : 6,
            ),
            child: _NumberField(
              label: labels[index],
              value: values[index],
              integer: false,
              min: 0,
              max: 1,
              step: 0.01,
              onChanged: (nextValue) => onChannelChanged(index, nextValue),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pickColor(BuildContext context, Vector4 initialValue) async {
    var draftColor = Vector4ColorAdapter.toFlutterColor(initialValue);
    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Pick Color'),
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              content: SizedBox(
                width: 300,
                child: ColorPicker(
                  pickerColor: draftColor,
                  enableAlpha: includeAlpha,
                  colorPickerWidth: 250,
                  pickerAreaHeightPercent: 0.72,
                  portraitOnly: true,
                  displayThumbColor: true,
                  labelTypes: const [],
                  hexInputBar: true,
                  onColorChanged: (nextColor) {
                    setState(() {
                      draftColor = nextColor;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(draftColor),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedColor == null) {
      return;
    }

    final nextColor = Vector4ColorAdapter.fromFlutterColor(pickedColor);
    onColorPicked(
      includeAlpha
          ? nextColor
          : Vector4(nextColor.x, nextColor.y, nextColor.z, color.w),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.value,
    required this.integer,
    required this.step,
    required this.onChanged,
    this.label,
    this.min,
    this.max,
  });

  final String? label;
  final double value;
  final bool integer;
  final double? min;
  final double? max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatNumber(widget.value, widget.integer),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    final nextText = _formatNumber(widget.value, widget.integer);
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
    final sliderRange = _resolveSliderRange(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      integer: widget.integer,
      step: widget.step,
    );
    return Row(
      children: [
        if (widget.label != null)
          SizedBox(
            width: 18,
            child: Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (widget.label != null) const SizedBox(width: 6),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              value: widget.value.clamp(sliderRange.min, sliderRange.max),
              min: sliderRange.min,
              max: sliderRange.max,
              divisions: _sliderDivisions(
                min: sliderRange.min,
                max: sliderRange.max,
                step: widget.step,
                integer: widget.integer,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: _denseInputDecoration(),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
            ],
            onTapOutside: (_) => _commitText(),
            onFieldSubmitted: (_) => _commitText(),
          ),
        ),
      ],
    );
  }

  void _commitText() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = _formatNumber(widget.value, widget.integer);
      return;
    }

    var nextValue = widget.integer ? parsed.roundToDouble() : parsed;
    if (widget.min != null) {
      nextValue = nextValue < widget.min! ? widget.min! : nextValue;
    }
    if (widget.max != null) {
      nextValue = nextValue > widget.max! ? widget.max! : nextValue;
    }

    _controller.text = _formatNumber(nextValue, widget.integer);
    if (nextValue != widget.value) {
      widget.onChanged(nextValue);
    }
  }
}

class _StringValueEditor extends StatefulWidget {
  const _StringValueEditor({
    required this.initialValue,
    required this.onSubmitted,
  });

  final String initialValue;
  final ValueChanged<String> onSubmitted;

  @override
  State<_StringValueEditor> createState() => _StringValueEditorState();
}

class _StringValueEditorState extends State<_StringValueEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _StringValueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    if (_controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
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
      decoration: _denseInputDecoration(),
      onTapOutside: (_) => _submit(),
      onFieldSubmitted: (_) => _submit(),
    );
  }

  void _submit() {
    if (_controller.text != widget.initialValue) {
      widget.onSubmitted(_controller.text);
    }
  }
}

class _CurveSummaryField extends StatelessWidget {
  const _CurveSummaryField({required this.curve, required this.onChanged});

  final GraphColorCurveData curve;
  final ValueChanged<GraphColorCurveData> onChanged;

  @override
  Widget build(BuildContext context) {
    return ColorBezierCurveEditor(curve: curve, onChanged: onChanged);
  }
}

class _SocketSummaryTile extends StatelessWidget {
  const _SocketSummaryTile({required this.controller, required this.property});

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
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(
              direction == GraphSocketDirection.input
                  ? Icons.arrow_right_alt
                  : Icons.arrow_left,
              size: 15,
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

InputDecoration _denseInputDecoration({
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 8,
  ),
}) {
  return InputDecoration(isDense: true, contentPadding: contentPadding);
}

({double min, double max}) _resolveSliderRange({
  required double value,
  required bool integer,
  required double step,
  double? min,
  double? max,
}) {
  if (min != null && max != null && max > min) {
    return (min: min, max: max);
  }

  final baseStep = step <= 0 ? (integer ? 1.0 : 0.01) : step;
  final radius = integer
      ? (value.abs() + 10).clamp(10, 1000).toDouble()
      : ((value.abs() * 1.5) + (baseStep * 100)).clamp(1, 1000).toDouble();
  final inferredMin = min ?? (value < 0 ? value - radius : 0);
  final inferredMax = max ?? (value >= 0 ? value + radius : 0);
  if (inferredMax <= inferredMin) {
    return (min: inferredMin, max: inferredMin + baseStep.abs() + 1);
  }
  return (min: inferredMin, max: inferredMax);
}

int? _sliderDivisions({
  required double min,
  required double max,
  required double step,
  required bool integer,
}) {
  final range = max - min;
  if (range <= 0) {
    return null;
  }

  final increment = integer ? 1.0 : step.abs();
  if (increment <= 0) {
    return null;
  }

  final divisions = (range / increment).round();
  if (divisions <= 0 || divisions > 1000) {
    return null;
  }
  return divisions;
}

String _formatNumber(double value, bool integer) {
  if (integer) {
    return value.round().toString();
  }

  final text = value.toStringAsFixed(3);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

List<double> _vector2ToList(Vector2 value) => [value.x, value.y];

List<double> _vector3ToList(Vector3 value) => [value.x, value.y, value.z];

List<double> _vector4ToList(Vector4 value) => [
  value.x,
  value.y,
  value.z,
  value.w,
];
