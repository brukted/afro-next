import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector2, Vector3, Vector4;

import '../../shared/widgets/panel_frame.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import '../property_editor/shared_property_editor_components.dart';
import 'math_graph_controller.dart';
import 'runtime/math_graph_ir.dart';

class MathGraphInspectorPanel extends StatelessWidget {
  const MathGraphInspectorPanel({super.key, required this.controller});

  final MathGraphController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasGraph) {
      return const PanelFrame(
        title: 'Math Inspector',
        subtitle: 'Select a math graph',
        child: Center(child: Text('No editable math graph selected.')),
      );
    }

    final node = controller.selectedNode;
    final diagnostics = controller.diagnostics;
    final compiledFunction = controller.compiledFunction;
    final inputNodes = controller.graphInputNodes;

    return PanelFrame(
      title: 'Math Inspector',
      subtitle: node?.name ?? controller.graph.name,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          if (node != null) ...[
            _NodeDetailsCard(controller: controller, node: node),
            const SizedBox(height: 10),
            ...controller
                .boundPropertiesForNode(node)
                .where((property) {
                  return property.isEditable;
                })
                .map(
                  (property) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MathPropertyField(
                      controller: controller,
                      nodeId: node.id,
                      property: property,
                    ),
                  ),
                ),
            const SizedBox(height: 10),
          ] else
            const _EmptySelectionCard(),
          _MathGraphInputsCard(controller: controller, nodes: inputNodes),
          const SizedBox(height: 10),
          _DiagnosticsCard(diagnostics: diagnostics),
          const SizedBox(height: 10),
          _CompiledSourceCard(
            compiledFunction: compiledFunction,
            hasErrors: controller.hasErrors,
          ),
        ],
      ),
    );
  }
}

class _MathGraphInputsCard extends StatelessWidget {
  const _MathGraphInputsCard({required this.controller, required this.nodes});

  final MathGraphController controller;
  final List<GraphNodeDocument> nodes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Graph Inputs', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (nodes.isEmpty)
              Text(
                'No input nodes in this graph.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...nodes.map((node) {
                final definition = controller.definitionForNode(node);
                final identifier =
                    node.propertyByDefinitionKey('identifier')?.value.stringValue ??
                    node.name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(node.name),
                            Text(
                              '$identifier · ${propertyEditorTypeLabel(definition.outputDefinition?.valueType)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => controller.selectNode(node.id),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _EmptySelectionCard extends StatelessWidget {
  const _EmptySelectionCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Select a node to edit its properties.'),
      ),
    );
  }
}

class _NodeDetailsCard extends StatelessWidget {
  const _NodeDetailsCard({required this.controller, required this.node});

  final MathGraphController controller;
  final GraphNodeDocument node;

  @override
  Widget build(BuildContext context) {
    final definition = controller.definitionForNode(node);
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              definition.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (definition.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                definition.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    propertyEditorTypeLabel(
                      definition.outputDefinition?.valueType,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(definition.compileMetadata.kind.name),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    controller.diagnosticsForNode(node.id).isEmpty
                        ? 'Compiled'
                        : '${controller.diagnosticsForNode(node.id).length} issue(s)',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MathPropertyField extends StatelessWidget {
  const _MathPropertyField({
    required this.controller,
    required this.nodeId,
    required this.property,
  });

  final MathGraphController controller;
  final String nodeId;
  final GraphPropertyBinding property;

  @override
  Widget build(BuildContext context) {
    final definition = property.definition;
    final description =
        definition.description == definition.label ||
            definition.description == 'Empty desc'
        ? null
        : definition.description;

    return PropertyEditorCard(
      label: property.label,
      description: description,
      child: switch (definition.valueType) {
        GraphValueType.boolean => PropertyEditorBooleanValueEditor(
          value: property.valueData.boolValue ?? false,
          onChanged: (value) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.boolean(value),
          ),
        ),
        GraphValueType.integer => PropertyEditorNumericValueEditor(
          value: (property.value as int).toDouble(),
          integer: true,
          step: definition.step ?? 1,
          footer: definition.valueUnit == GraphValueUnit.power2
              ? PropertyEditorPowerOfTwoPreview.scalar(
                  value: (property.value as int).toDouble(),
                )
              : null,
          onChanged: (value) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer(value.round()),
          ),
        ),
        GraphValueType.float => PropertyEditorNumericValueEditor(
          value: property.value as double,
          integer: false,
          step: definition.step ?? 0.01,
          footer: definition.valueUnit == GraphValueUnit.power2
              ? PropertyEditorPowerOfTwoPreview.scalar(
                  value: property.value as double,
                )
              : null,
          onChanged: (value) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.float(value),
          ),
        ),
        GraphValueType.integer2 => PropertyEditorVectorNumberEditor(
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          values: (property.value as List<int>)
              .map((entry) => entry.toDouble())
              .toList(growable: false),
          integer: true,
          step: definition.step ?? 1,
          footer: definition.valueUnit == GraphValueUnit.power2
              ? PropertyEditorPowerOfTwoPreview.vector(
                  values: (property.value as List<int>)
                      .map((entry) => entry.toDouble())
                      .toList(growable: false),
                  labels: propertyEditorVectorLabels(
                    definition.valueType,
                    definition.valueUnit,
                  ),
                )
              : null,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer2(
              values.map((entry) => entry.round()).toList(),
            ),
          ),
        ),
        GraphValueType.integer3 => PropertyEditorVectorNumberEditor(
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          values: (property.value as List<int>)
              .map((entry) => entry.toDouble())
              .toList(growable: false),
          integer: true,
          step: definition.step ?? 1,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer3(
              values.map((entry) => entry.round()).toList(),
            ),
          ),
        ),
        GraphValueType.integer4 => PropertyEditorVectorNumberEditor(
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          values: (property.value as List<int>)
              .map((entry) => entry.toDouble())
              .toList(growable: false),
          integer: true,
          step: definition.step ?? 1,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.integer4(
              values.map((entry) => entry.round()).toList(),
            ),
          ),
        ),
        GraphValueType.float2 => PropertyEditorVectorNumberEditor(
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          values: _vectorToList(property.valueData.asFloat2()),
          integer: false,
          step: definition.step ?? 0.01,
          footer: definition.valueUnit == GraphValueUnit.power2
              ? PropertyEditorPowerOfTwoPreview.vector(
                  values: _vectorToList(property.valueData.asFloat2()),
                  labels: propertyEditorVectorLabels(
                    definition.valueType,
                    definition.valueUnit,
                  ),
                )
              : null,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.float2(Vector2(values[0], values[1])),
          ),
        ),
        GraphValueType.float3 => PropertyEditorVectorNumberEditor(
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          values: _vector3ToList(property.valueData.asFloat3()),
          integer: false,
          step: definition.step ?? 0.01,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.float3(
              Vector3(values[0], values[1], values[2]),
            ),
          ),
        ),
        GraphValueType.float4 => PropertyEditorVectorNumberEditor(
          labels: propertyEditorVectorLabels(
            definition.valueType,
            definition.valueUnit,
          ),
          values: _vector4ToList(property.valueData.asFloat4()),
          integer: false,
          step: definition.step ?? 0.01,
          onChanged: (values) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.float4(
              Vector4(values[0], values[1], values[2], values[3]),
            ),
          ),
        ),
        GraphValueType.stringValue => PropertyEditorStringValueEditor(
          initialValue: property.value as String,
          onSubmitted: (value) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.stringValue(value),
          ),
        ),
        GraphValueType.enumChoice => PropertyEditorEnumChoiceEditor(
          currentValue: property.valueData.enumValue ?? property.value as int,
          options: definition.enumOptions,
          onChanged: (value) => controller.updatePropertyValue(
            nodeId: nodeId,
            propertyId: property.id,
            value: GraphValueData.enumChoice(value),
          ),
        ),
        _ => Text(
          'Unsupported editor for ${definition.valueType.name}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      },
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.diagnostics});

  final List<MathCompileDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Diagnostics',
      child: diagnostics.isEmpty
          ? const Text('No compiler diagnostics.')
          : Column(
              children: diagnostics
                  .map(
                    (diagnostic) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: diagnostic.isError
                            ? colorScheme.errorContainer.withValues(alpha: 0.55)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diagnostic.code,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(diagnostic.message),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _CompiledSourceCard extends StatelessWidget {
  const _CompiledSourceCard({
    required this.compiledFunction,
    required this.hasErrors,
  });

  final MathCompiledFunction? compiledFunction;
  final bool hasErrors;

  @override
  Widget build(BuildContext context) {
    final function = compiledFunction;
    return _SectionCard(
      title: 'Generated GLSL',
      child: function == null
          ? Text(
              hasErrors
                  ? 'Generated GLSL is unavailable until the graph compiles cleanly.'
                  : 'No compiled output yet.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${function.functionName} -> ${propertyEditorTypeLabel(function.returnType)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                if (function.parameters.isNotEmpty)
                  Text(
                    function.parameters
                        .map((parameter) => parameter.name)
                        .join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      function.source,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(propertyEditorCornerRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

List<double> _vectorToList(Vector2 value) => [value.x, value.y];

List<double> _vector3ToList(Vector3 value) => [value.x, value.y, value.z];

List<double> _vector4ToList(Vector4 value) => [
  value.x,
  value.y,
  value.z,
  value.w,
];
