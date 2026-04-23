import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../graph/models/graph_schema.dart';

const double propertyEditorCornerRadius = 8;

InputDecoration propertyEditorDenseInputDecoration({
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 7,
  ),
  String? labelText,
  String? hintText,
}) {
  return InputDecoration(
    isDense: true,
    contentPadding: contentPadding,
    labelText: labelText,
    hintText: hintText,
  );
}

class PropertyEditorCard extends StatelessWidget {
  const PropertyEditorCard({
    super.key,
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
        borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
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

class PropertyEditorNumericValueEditor extends StatelessWidget {
  const PropertyEditorNumericValueEditor({
    super.key,
    required this.value,
    required this.integer,
    required this.onChanged,
    required this.step,
    this.min,
    this.max,
    this.footer,
  });

  final double value;
  final bool integer;
  final double? min;
  final double? max;
  final double step;
  final ValueChanged<double> onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PropertyEditorNumberField(
          value: value,
          integer: integer,
          min: min,
          max: max,
          step: step,
          onChanged: onChanged,
        ),
        if (footer != null) ...[const SizedBox(height: 6), footer!],
      ],
    );
  }
}

class PropertyEditorVectorNumberEditor extends StatelessWidget {
  const PropertyEditorVectorNumberEditor({
    super.key,
    required this.values,
    required this.labels,
    required this.integer,
    required this.step,
    required this.onChanged,
    this.min,
    this.max,
    this.footer,
  });

  final List<double> values;
  final List<String> labels;
  final bool integer;
  final double? min;
  final double? max;
  final double step;
  final ValueChanged<List<double>> onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(values.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == values.length - 1 ? 0 : 6,
            ),
            child: _PropertyEditorNumberField(
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
        if (footer != null) ...[const SizedBox(height: 6), footer!],
      ],
    );
  }
}

class PropertyEditorStringValueEditor extends StatefulWidget {
  const PropertyEditorStringValueEditor({
    super.key,
    required this.initialValue,
    required this.onSubmitted,
  });

  final String initialValue;
  final ValueChanged<String> onSubmitted;

  @override
  State<PropertyEditorStringValueEditor> createState() =>
      _PropertyEditorStringValueEditorState();
}

class _PropertyEditorStringValueEditorState
    extends State<PropertyEditorStringValueEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PropertyEditorStringValueEditor oldWidget) {
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
      decoration: propertyEditorDenseInputDecoration(),
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

class PropertyEditorBooleanValueEditor extends StatelessWidget {
  const PropertyEditorBooleanValueEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.trueLabel = 'Enabled',
    this.falseLabel = 'Disabled',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String trueLabel;
  final String falseLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          visualDensity: VisualDensity.compact,
          onChanged: (nextValue) {
            if (nextValue == null) {
              return;
            }
            onChanged(nextValue);
          },
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value ? trueLabel : falseLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class PropertyEditorEnumChoiceEditor extends StatelessWidget {
  const PropertyEditorEnumChoiceEditor({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onChanged,
  });

  final int currentValue;
  final List<EnumChoiceOption> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<int>(
      initialValue: currentValue,
      isDense: true,
      isExpanded: true,
      itemHeight: kMinInteractiveDimension,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
      dropdownColor: theme.colorScheme.surfaceContainerLow,
      decoration: propertyEditorDenseInputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      items: options
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
        onChanged(nextValue);
      },
    );
  }
}

class PropertyEditorPowerOfTwoPreview extends StatelessWidget {
  const PropertyEditorPowerOfTwoPreview.scalar({
    super.key,
    required double value,
  }) : _value = value,
       _values = null,
       labels = const <String>[];

  const PropertyEditorPowerOfTwoPreview.vector({
    super.key,
    required List<double> values,
    this.labels = const ['Width', 'Height'],
  }) : _values = values,
       _value = null;

  final double? _value;
  final List<double>? _values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final text = switch ((_value, _values)) {
      (final value?, null) =>
        '2^${_formatPropertyEditorNumber(value, false)} = ${_formatPowerOfTwoResult(value)}',
      (null, final values?) => List.generate(
        math.min(values.length, labels.length),
        (index) =>
            '${labels[index]} 2^${_formatPropertyEditorNumber(values[index], false)} = ${_formatPowerOfTwoResult(values[index])}',
      ).join(', '),
      _ => '',
    };
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PropertyEditorNumberField extends StatefulWidget {
  const _PropertyEditorNumberField({
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
  State<_PropertyEditorNumberField> createState() =>
      _PropertyEditorNumberFieldState();
}

class _PropertyEditorNumberFieldState
    extends State<_PropertyEditorNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatPropertyEditorNumber(widget.value, widget.integer),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _PropertyEditorNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    final nextText = _formatPropertyEditorNumber(widget.value, widget.integer);
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
    final sliderRange = _resolvePropertyEditorSliderRange(
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
            width: _propertyEditorNumberFieldLabelWidth(widget.label!),
            child: Text(
              widget.label!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              divisions: _propertyEditorSliderDivisions(
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
            decoration: propertyEditorDenseInputDecoration(),
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
      _controller.text = _formatPropertyEditorNumber(
        widget.value,
        widget.integer,
      );
      return;
    }

    var nextValue = widget.integer ? parsed.roundToDouble() : parsed;
    if (widget.min != null) {
      nextValue = nextValue < widget.min! ? widget.min! : nextValue;
    }
    if (widget.max != null) {
      nextValue = nextValue > widget.max! ? widget.max! : nextValue;
    }

    _controller.text = _formatPropertyEditorNumber(nextValue, widget.integer);
    if (nextValue != widget.value) {
      widget.onChanged(nextValue);
    }
  }
}

List<String> propertyEditorVectorLabels(
  GraphValueType valueType,
  GraphValueUnit valueUnit,
) {
  if (valueUnit == GraphValueUnit.power2 &&
      (valueType == GraphValueType.integer2 ||
          valueType == GraphValueType.float2)) {
    return const ['Width', 'Height'];
  }
  if (valueUnit == GraphValueUnit.color) {
    return switch (valueType) {
      GraphValueType.float3 => const ['R', 'G', 'B'],
      GraphValueType.float4 => const ['R', 'G', 'B', 'A'],
      _ => _defaultVectorLabels(valueType),
    };
  }
  return _defaultVectorLabels(valueType);
}

bool propertyEditorUsesColorEditor(GraphPropertyDefinition definition) {
  return definition.valueUnit == GraphValueUnit.color &&
      (definition.valueType == GraphValueType.float3 ||
          definition.valueType == GraphValueType.float4);
}

String propertyEditorTypeLabel(GraphValueType? type) {
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

String _formatPropertyEditorNumber(double value, bool integer) {
  if (integer) {
    return value.round().toString();
  }
  final text = value.toStringAsFixed(3);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

List<String> _defaultVectorLabels(GraphValueType valueType) {
  return switch (valueType) {
    GraphValueType.integer2 || GraphValueType.float2 => const ['X', 'Y'],
    GraphValueType.integer3 || GraphValueType.float3 => const ['X', 'Y', 'Z'],
    GraphValueType.integer4 ||
    GraphValueType.float4 => const ['X', 'Y', 'Z', 'W'],
    _ => const <String>[],
  };
}

String _formatPowerOfTwoResult(double exponent) {
  final result = math.pow(2, exponent).toDouble();
  final rounded = result.roundToDouble();
  if ((result - rounded).abs() < 1e-6) {
    return rounded.round().toString();
  }
  return _formatPropertyEditorNumber(result, false);
}

({double min, double max}) _resolvePropertyEditorSliderRange({
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

int? _propertyEditorSliderDivisions({
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

double _propertyEditorNumberFieldLabelWidth(String label) {
  if (label.length <= 1) {
    return 18;
  }
  if (label.length <= 3) {
    return 26;
  }
  return 44;
}
