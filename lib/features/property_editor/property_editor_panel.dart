import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:vector_math/vector_math.dart' show Vector2, Vector3, Vector4;

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/widgets/panel_frame.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import '../material_graph/material_graph_controller.dart';
import '../material_graph/material_output_size.dart';
import '../workspace/models/workspace_models.dart';
import '../workspace/workspace_controller.dart';
import 'color_curve_editor.dart';
import 'shared_property_editor_components.dart';

class PropertyEditorPanel extends StatelessWidget {
  const PropertyEditorPanel({
    super.key,
    required this.controller,
    this.workspaceController,
  });

  final MaterialGraphController controller;
  final WorkspaceController? workspaceController;

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.22,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                  workspaceController: workspaceController,
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
      ),
    );
  }
}

class _EditablePropertyField extends StatelessWidget {
  const _EditablePropertyField({
    required this.controller,
    required this.workspaceController,
    required this.nodeId,
    required this.property,
  });

  final MaterialGraphController controller;
  final WorkspaceController? workspaceController;
  final String nodeId;
  final GraphPropertyBinding property;

  @override
  Widget build(BuildContext context) {
    final definition = property.definition;

    return PropertyEditorCard(
      label: property.label,
      description: definition.description == 'Empty desc'
          ? null
          : definition.description,
      badge: _buildBadge(context),
      child: switch (definition.valueType) {
        GraphValueType.integer => PropertyEditorNumericValueEditor(
          value: (property.value as int).toDouble(),
          integer: true,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 1,
          footer: definition.valueUnit == GraphValueUnit.power2
              ? PropertyEditorPowerOfTwoPreview.scalar(
                  value: (property.value as int).toDouble(),
                )
              : null,
          onChanged: (nextValue) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer(nextValue.round()),
          ),
        ),
        GraphValueType.integer2 => PropertyEditorVectorNumberEditor(
          values: (property.value as List<int>)
              .map((value) => value.toDouble())
              .toList(),
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          integer: true,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 1,
          onChanged: (values) {
            final nextValue = MaterialOutputSizeValue.fromInteger2(
              values.map((value) => value.round()).toList(),
            );
            if (controller.updateOutputSizeProperty(
              nodeId: nodeId,
              propertyKey: property.definition.key,
              value: GraphValueData.integer2(nextValue.asInteger2),
            )) {
              return;
            }
            controller.updatePropertyValue(
              nodeId: nodeId,
              propertyId: property.id,
              value: GraphValueData.integer2(nextValue.asInteger2),
            );
          },
          footer: definition.valueUnit == GraphValueUnit.power2
              ? _PowerOfTwoSummary(
                  value: MaterialOutputSizeValue.fromInteger2(
                    (property.value as List<int>).toList(growable: false),
                  ),
                  mode: controller
                      .outputSizeSettingsForNode(controller.nodeById(nodeId)!)
                      .mode,
                )
              : null,
        ),
        GraphValueType.integer3 => PropertyEditorVectorNumberEditor(
          values: (property.value as List<int>)
              .map((value) => value.toDouble())
              .toList(),
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
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
        GraphValueType.integer4 => PropertyEditorVectorNumberEditor(
          values: (property.value as List<int>)
              .map((value) => value.toDouble())
              .toList(),
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
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
        GraphValueType.float => PropertyEditorNumericValueEditor(
          value: property.value as double,
          integer: false,
          min: definition.min?.toDouble(),
          max: definition.max?.toDouble(),
          step: definition.step ?? 0.01,
          footer: definition.valueUnit == GraphValueUnit.power2
              ? PropertyEditorPowerOfTwoPreview.scalar(
                  value: property.value as double,
                )
              : null,
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
        GraphValueType.float3 when propertyEditorUsesColorEditor(definition) =>
          _ColorEditor(
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
        GraphValueType.float4 when propertyEditorUsesColorEditor(definition) =>
          _ColorEditor(
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
        GraphValueType.float3x3 => _FloatMatrix3Field(
          property: property,
          nodeId: nodeId,
          controller: controller,
        ),
        GraphValueType.stringValue => PropertyEditorStringValueEditor(
          initialValue: property.value as String,
          onSubmitted: (nextValue) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.stringValue(nextValue),
          ),
        ),
        GraphValueType.workspaceResource => _WorkspaceResourcePickerField(
          property: property,
          nodeId: nodeId,
          controller: controller,
          workspaceController: workspaceController,
        ),
        GraphValueType.boolean => PropertyEditorBooleanValueEditor(
          value: property.value as bool,
          onChanged: (nextValue) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.boolean(nextValue),
          ),
        ),
        GraphValueType.enumChoice => PropertyEditorEnumChoiceEditor(
          currentValue: property.value as int,
          options: definition.enumOptions,
          onChanged: (nextValue) {
            if (controller.updateOutputSizeProperty(
              nodeId: nodeId,
              propertyKey: property.definition.key,
              value: GraphValueData.enumChoice(nextValue),
            )) {
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
        GraphValueType.gradient => _GradientField(
          gradient: property.valueData.asGradient(),
          onChanged: (nextGradient) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.gradient(nextGradient),
          ),
        ),
        GraphValueType.textBlock => _TextBlockField(
          value: property.valueData.asTextBlock(),
          onChanged: (nextText) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.textBlock(nextText),
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
    final labels = propertyEditorVectorLabels(
      definition.valueType,
      definition.valueUnit,
    );
    final values = switch (definition.valueType) {
      GraphValueType.float2 => _vector2ToList(property.value as Vector2),
      GraphValueType.float3 => _vector3ToList(property.value as Vector3),
      GraphValueType.float4 => _vector4ToList(property.value as Vector4),
      _ => const <double>[],
    };

    return PropertyEditorVectorNumberEditor(
      values: values,
      labels: labels,
      integer: false,
      min: definition.min?.toDouble(),
      max: definition.max?.toDouble(),
      step: definition.step ?? 0.01,
      footer: definition.valueUnit == GraphValueUnit.power2
          ? PropertyEditorPowerOfTwoPreview.vector(
              values: values,
              labels: labels,
            )
          : null,
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

class _FloatMatrix3Field extends StatelessWidget {
  const _FloatMatrix3Field({
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
    final values = property.valueData.asFloat3x3();
    final labels = const [
      'M00',
      'M01',
      'M02',
      'M10',
      'M11',
      'M12',
      'M20',
      'M21',
      'M22',
    ];

    return PropertyEditorVectorNumberEditor(
      values: values,
      labels: labels,
      integer: false,
      min: definition.min?.toDouble(),
      max: definition.max?.toDouble(),
      step: definition.step ?? 0.01,
      onChanged: (nextValues) {
        controller.updatePropertyValue(
          nodeId: nodeId,
          propertyId: property.id,
          value: GraphValueData.float3x3(nextValues),
        );
      },
    );
  }
}

class _WorkspaceResourcePickerField extends StatelessWidget {
  const _WorkspaceResourcePickerField({
    required this.property,
    required this.nodeId,
    required this.controller,
    required this.workspaceController,
  });

  final GraphPropertyBinding property;
  final String nodeId;
  final MaterialGraphController controller;
  final WorkspaceController? workspaceController;

  @override
  Widget build(BuildContext context) {
    final workspaceController = this.workspaceController;
    if (workspaceController == null || !workspaceController.isInitialized) {
      return const Text('Workspace assets are unavailable.');
    }

    final workspaceKinds = _workspaceKindsForGraphKinds(
      property.definition.resourceKinds,
    );
    final resources = workspaceController.resourcesForKinds(workspaceKinds);
    final currentValue = property.valueData.asWorkspaceResource();
    final hasCurrentValue =
        currentValue.isNotEmpty &&
        resources.any((resource) => resource.id == currentValue);
    final dropdownValue = hasCurrentValue ? currentValue : '';

    return DropdownButtonFormField<String>(
      initialValue: dropdownValue,
      isDense: true,
      isExpanded: true,
      itemHeight: kMinInteractiveDimension,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
      dropdownColor: Theme.of(context).colorScheme.surfaceContainerLow,
      decoration: propertyEditorDenseInputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('None')),
        ...resources.map(
          (resource) => DropdownMenuItem<String>(
            value: resource.id,
            child: Text(resource.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (nextValue) {
        controller.updatePropertyValue(
          nodeId: nodeId,
          propertyId: property.id,
          value: GraphValueData.workspaceResource(nextValue ?? ''),
        );
      },
    );
  }
}

class _GradientField extends StatelessWidget {
  const _GradientField({required this.gradient, required this.onChanged});

  final GraphGradientData gradient;
  final ValueChanged<GraphGradientData> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = gradient.normalized();
    final colors = normalized.stops
        .map((stop) => Vector4ColorAdapter.toFlutterColor(stop.color))
        .toList(growable: false);
    final stops = normalized.stops
        .map((stop) => stop.position)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            gradient: LinearGradient(colors: colors, stops: stops),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(normalized.stops.length, (index) {
          final stop = normalized.stops[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == normalized.stops.length - 1 ? 0 : 8,
            ),
            child: Row(
              children: [
                Builder(
                  builder: (buttonContext) {
                    return InkWell(
                      onTap: () async {
                        await _pickVectorColor(
                          buttonContext,
                          stop.color,
                          includeAlpha: true,
                          onChanged: (picked) {
                            final updated = List<GraphGradientStopData>.from(
                              normalized.stops,
                            );
                            updated[index] = stop.copyWith(color: picked);
                            onChanged(
                              GraphGradientData(stops: updated).normalized(),
                            );
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Vector4ColorAdapter.toFlutterColor(stop.color),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: stop.position,
                    min: 0,
                    max: 1,
                    onChanged: (nextValue) {
                      final updated = List<GraphGradientStopData>.from(
                        normalized.stops,
                      );
                      updated[index] = stop.copyWith(position: nextValue);
                      onChanged(GraphGradientData(stops: updated).normalized());
                    },
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: Text(
                    _formatNumber(stop.position, false),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: normalized.stops.length <= 2
                      ? null
                      : () {
                          final updated = List<GraphGradientStopData>.from(
                            normalized.stops,
                          )..removeAt(index);
                          onChanged(
                            GraphGradientData(stops: updated).normalized(),
                          );
                        },
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final updated = List<GraphGradientStopData>.from(normalized.stops)
                ..add(
                  GraphGradientStopData(position: 0.5, color: Vector4.all(1)),
                );
              onChanged(GraphGradientData(stops: updated).normalized());
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add Stop'),
          ),
        ),
      ],
    );
  }
}

class _TextBlockField extends StatelessWidget {
  const _TextBlockField({required this.value, required this.onChanged});

  final GraphTextData value;
  final ValueChanged<GraphTextData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Text', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        PropertyEditorStringValueEditor(
          initialValue: value.text,
          onSubmitted: (nextValue) =>
              onChanged(value.copyWith(text: nextValue)),
        ),
        const SizedBox(height: 8),
        Text('Font Family', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        PropertyEditorStringValueEditor(
          initialValue: value.fontFamily,
          onSubmitted: (nextValue) =>
              onChanged(value.copyWith(fontFamily: nextValue)),
        ),
        const SizedBox(height: 8),
        PropertyEditorNumericValueEditor(
          value: value.fontSize,
          integer: false,
          min: 1,
          max: 256,
          step: 1,
          onChanged: (nextValue) =>
              onChanged(value.copyWith(fontSize: nextValue)),
        ),
        const SizedBox(height: 8),
        Text('Background Color', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        _ColorEditor(
          color: value.backgroundColor,
          includeAlpha: true,
          onColorPicked: (nextColor) =>
              onChanged(value.copyWith(backgroundColor: nextColor)),
          onChannelChanged: (index, nextValue) {
            final current = value.backgroundColor;
            final next = switch (index) {
              0 => Vector4(nextValue, current.y, current.z, current.w),
              1 => Vector4(current.x, nextValue, current.z, current.w),
              2 => Vector4(current.x, current.y, nextValue, current.w),
              _ => Vector4(current.x, current.y, current.z, nextValue),
            };
            onChanged(value.copyWith(backgroundColor: next));
          },
        ),
        const SizedBox(height: 8),
        Text('Text Color', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        _ColorEditor(
          color: value.textColor,
          includeAlpha: true,
          onColorPicked: (nextColor) =>
              onChanged(value.copyWith(textColor: nextColor)),
          onChannelChanged: (index, nextValue) {
            final current = value.textColor;
            final next = switch (index) {
              0 => Vector4(nextValue, current.y, current.z, current.w),
              1 => Vector4(current.x, nextValue, current.z, current.w),
              2 => Vector4(current.x, current.y, nextValue, current.w),
              _ => Vector4(current.x, current.y, current.z, nextValue),
            };
            onChanged(value.copyWith(textColor: next));
          },
        ),
      ],
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

class _PowerOfTwoSummary extends StatelessWidget {
  const _PowerOfTwoSummary({required this.value, required this.mode});

  final MaterialOutputSizeValue value;
  final MaterialOutputSizeMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widthLabel = mode == MaterialOutputSizeMode.absolute
        ? '${value.widthLog2} = ${materialOutputSizePixelsForLog2(value.widthLog2)} px'
        : _relativePowerOfTwoLabel(value.widthLog2);
    final heightLabel = mode == MaterialOutputSizeMode.absolute
        ? '${value.heightLog2} = ${materialOutputSizePixelsForLog2(value.heightLog2)} px'
        : _relativePowerOfTwoLabel(value.heightLog2);
    return Text(
      'Width $widthLabel, Height $heightLabel',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
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
            Builder(
              builder: (buttonContext) {
                return InkWell(
                  onTap: () => _pickColor(buttonContext, swatchColor),
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
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              includeAlpha ? 'RGBA' : 'RGB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Builder(
              builder: (buttonContext) {
                return TextButton(
                  onPressed: () => _pickColor(buttonContext, swatchColor),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Pick'),
                );
              },
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
    await _pickVectorColor(
      context,
      initialValue,
      includeAlpha: includeAlpha,
      onChanged: (nextColor) {
        onColorPicked(
          includeAlpha
              ? nextColor
              : Vector4(nextColor.x, nextColor.y, nextColor.z, color.w),
        );
      },
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
            width: _numberFieldLabelWidth(widget.label!),
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
        borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
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

Set<WorkspaceResourceKind> _workspaceKindsForGraphKinds(
  List<GraphResourceKind> kinds,
) {
  return kinds.map((kind) {
    return switch (kind) {
      GraphResourceKind.image => WorkspaceResourceKind.image,
      GraphResourceKind.svg => WorkspaceResourceKind.svg,
    };
  }).toSet();
}

Future<void> _pickVectorColor(
  BuildContext context,
  Vector4 initialValue, {
  required bool includeAlpha,
  required ValueChanged<Vector4> onChanged,
}) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (renderBox == null || overlay == null) {
    return;
  }

  final anchorTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
  final anchorRect = anchorTopLeft & renderBox.size;
  await Navigator.of(context).push<void>(
    _ColorPickerPopupRoute(
      anchorRect: anchorRect,
      initialColor: Vector4ColorAdapter.toFlutterColor(initialValue),
      includeAlpha: includeAlpha,
      onColorChanged: (color) {
        onChanged(Vector4ColorAdapter.fromFlutterColor(color));
      },
    ),
  );
}

class _ColorPickerPopupRoute extends PopupRoute<void> {
  _ColorPickerPopupRoute({
    required this.anchorRect,
    required this.initialColor,
    required this.includeAlpha,
    required this.onColorChanged,
  });

  final Rect anchorRect;
  final Color initialColor;
  final bool includeAlpha;
  final ValueChanged<Color> onColorChanged;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String get barrierLabel => 'Dismiss color picker';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 140);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _ColorPickerPopover(
      anchorRect: anchorRect,
      initialColor: initialColor,
      includeAlpha: includeAlpha,
      onColorChanged: onColorChanged,
      animation: animation,
    );
  }
}

class _ColorPickerPopover extends StatefulWidget {
  const _ColorPickerPopover({
    required this.anchorRect,
    required this.initialColor,
    required this.includeAlpha,
    required this.onColorChanged,
    required this.animation,
  });

  final Rect anchorRect;
  final Color initialColor;
  final bool includeAlpha;
  final ValueChanged<Color> onColorChanged;
  final Animation<double> animation;

  @override
  State<_ColorPickerPopover> createState() => _ColorPickerPopoverState();
}

class _ColorPickerPopoverState extends State<_ColorPickerPopover> {
  static const Duration _applyDebounce = Duration(milliseconds: 180);

  late Color _draftColor;
  late Color _lastAppliedColor;
  Timer? _applyTimer;
  bool _revertOnDispose = false;

  @override
  void initState() {
    super.initState();
    _draftColor = widget.initialColor;
    _lastAppliedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _applyTimer?.cancel();
    if (_revertOnDispose) {
      if (_lastAppliedColor != widget.initialColor) {
        widget.onColorChanged(widget.initialColor);
      }
    } else if (_draftColor != _lastAppliedColor) {
      widget.onColorChanged(_draftColor);
    }
    super.dispose();
  }

  void _scheduleApply(Color nextColor) {
    setState(() {
      _draftColor = nextColor;
    });
    _applyTimer?.cancel();
    _applyTimer = Timer(_applyDebounce, () {
      _lastAppliedColor = _draftColor;
      widget.onColorChanged(_draftColor);
    });
  }

  void _cancelAndClose() {
    _revertOnDispose = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          CustomSingleChildLayout(
            delegate: _ColorPickerPopoverLayoutDelegate(
              anchorRect: widget.anchorRect,
            ),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.96,
                  end: 1,
                ).animate(curvedAnimation),
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Material(
                    elevation: 18,
                    color: theme.colorScheme.surfaceContainerHigh,
                    shadowColor: Colors.black45,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pick color', style: theme.textTheme.titleSmall),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 296,
                            child: ColorPicker(
                              pickerColor: _draftColor,
                              enableAlpha: widget.includeAlpha,
                              colorPickerWidth: 250,
                              pickerAreaHeightPercent: 0.72,
                              portraitOnly: true,
                              displayThumbColor: true,
                              labelTypes: const [],
                              hexInputBar: true,
                              onColorChanged: _scheduleApply,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _cancelAndClose,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _ColorPickerPopoverLayoutDelegate({required this.anchorRect});

  final Rect anchorRect;
  static const double _screenPadding = 12;
  static const double _verticalGap = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: 0,
      maxWidth: constraints.maxWidth - (_screenPadding * 2),
      minHeight: 0,
      maxHeight: constraints.maxHeight - (_screenPadding * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final availableWidth = size.width - childSize.width - _screenPadding;
    final desiredLeft = anchorRect.left.clamp(
      _screenPadding,
      availableWidth < _screenPadding ? _screenPadding : availableWidth,
    );
    final spaceBelow = size.height - anchorRect.bottom - _screenPadding;
    final showBelow =
        spaceBelow >= childSize.height + _verticalGap ||
        anchorRect.top < childSize.height;
    final desiredTop = showBelow
        ? anchorRect.bottom + _verticalGap
        : anchorRect.top - childSize.height - _verticalGap;
    final maxTop = size.height - childSize.height - _screenPadding;
    final top = desiredTop.clamp(
      _screenPadding,
      maxTop < _screenPadding ? _screenPadding : maxTop,
    );
    return Offset(desiredLeft.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(covariant _ColorPickerPopoverLayoutDelegate oldDelegate) {
    return anchorRect != oldDelegate.anchorRect;
  }
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

double _numberFieldLabelWidth(String label) {
  if (label.length <= 1) {
    return 18;
  }
  if (label.length <= 3) {
    return 26;
  }
  return 44;
}

String _relativePowerOfTwoLabel(int delta) {
  if (delta == 0) {
    return 'inherits base size';
  }
  final sign = delta > 0 ? '+' : '';
  return '$sign$delta => 2^$delta multiplier';
}

List<double> _vector2ToList(Vector2 value) => [value.x, value.y];

List<double> _vector3ToList(Vector3 value) => [value.x, value.y, value.z];

List<double> _vector4ToList(Vector4 value) => [
  value.x,
  value.y,
  value.z,
  value.w,
];
