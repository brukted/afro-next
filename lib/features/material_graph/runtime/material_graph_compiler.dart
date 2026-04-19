import 'package:collection/collection.dart';

import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../material_graph_catalog.dart';
import '../material_node_definition.dart';
import '../material_output_size.dart';
import 'material_execution_ir.dart';

class MaterialGraphCompiler {
  const MaterialGraphCompiler({required MaterialGraphCatalog catalog})
    : _catalog = catalog;

  final MaterialGraphCatalog _catalog;

  MaterialCompiledGraph compile(
    GraphDocument graph, {
    MaterialOutputSizeSettings graphOutputSizeSettings =
        const MaterialOutputSizeSettings(),
    MaterialOutputSizeValue sessionParentOutputSize =
        const MaterialOutputSizeValue.parentDefault(),
  }) {
    final nodesById = {for (final node in graph.nodes) node.id: node};
    final incomingCounts = <String, int>{
      for (final node in graph.nodes) node.id: 0,
    };
    final outgoingNodeIds = <String, List<String>>{
      for (final node in graph.nodes) node.id: <String>[],
    };
    final linkByInputPropertyId = {
      for (final link in graph.links) link.toPropertyId: link,
    };

    for (final link in graph.links) {
      incomingCounts.update(
        link.toNodeId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      outgoingNodeIds
          .putIfAbsent(link.fromNodeId, () => <String>[])
          .add(link.toNodeId);
    }

    final remainingCounts = Map<String, int>.from(incomingCounts);
    final ready = graph.nodes
        .where((node) => remainingCounts[node.id] == 0)
        .map((node) => node.id)
        .toList(growable: true);
    final orderedNodeIds = <String>[];

    while (ready.isNotEmpty) {
      final nodeId = ready.removeAt(0);
      orderedNodeIds.add(nodeId);
      for (final childId in outgoingNodeIds[nodeId] ?? const <String>[]) {
        final nextCount = (remainingCounts[childId] ?? 1) - 1;
        remainingCounts[childId] = nextCount;
        if (nextCount == 0) {
          ready.add(childId);
        }
      }
    }

    if (orderedNodeIds.length != graph.nodes.length) {
      for (final node in graph.nodes) {
        if (!orderedNodeIds.contains(node.id)) {
          orderedNodeIds.add(node.id);
        }
      }
    }

    final resolvedGraphOutputSize = _resolveGraphOutputSize(
      graphOutputSizeSettings,
      sessionParentOutputSize,
    );
    final resolvedOutputSizesByNodeId = <String, MaterialResolvedOutputSize>{};
    final nodePasses = orderedNodeIds
        .map((nodeId) {
          final pass = _compileNodePass(
            node: nodesById[nodeId]!,
            linkByInputPropertyId: linkByInputPropertyId,
            graphOutputSize: resolvedGraphOutputSize,
            resolvedOutputSizesByNodeId: resolvedOutputSizesByNodeId,
          );
          resolvedOutputSizesByNodeId[nodeId] = pass.resolvedOutputSize;
          return pass;
        })
        .toList(growable: false);

    return MaterialCompiledGraph(
      graphId: graph.id,
      nodePasses: nodePasses,
      nodePassesByNodeId: {for (final pass in nodePasses) pass.nodeId: pass},
      topologicalNodeIds: orderedNodeIds,
      downstreamNodeIdsByNodeId: outgoingNodeIds.map(
        (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
      ),
      defaultOutputNodeId: orderedNodeIds.lastOrNull,
      resolvedGraphOutputSize: resolvedGraphOutputSize,
    );
  }

  MaterialCompiledNodePass _compileNodePass({
    required GraphNodeDocument node,
    required Map<String, GraphLinkDocument> linkByInputPropertyId,
    required MaterialResolvedOutputSize graphOutputSize,
    required Map<String, MaterialResolvedOutputSize>
    resolvedOutputSizesByNodeId,
  }) {
    final definition = _catalog.definitionById(node.definitionId);
    final textureInputs = <MaterialCompiledTextureInput>[];
    final parameterBindings = <MaterialCompiledParameterBinding>[];
    GraphPropertyDefinition? outputDefinition;
    GraphNodePropertyData? outputProperty;
    final upstreamNodeIds = <String>{};
    final resolvedOutputSize = _resolveNodeOutputSize(
      node: node,
      definition: definition,
      linkByInputPropertyId: linkByInputPropertyId,
      graphOutputSize: graphOutputSize,
      resolvedOutputSizesByNodeId: resolvedOutputSizesByNodeId,
    );

    for (final propertyDefinition in definition.properties) {
      final property = node.propertyByDefinitionKey(propertyDefinition.key);
      if (property == null) {
        continue;
      }

      if (propertyDefinition.propertyType == GraphPropertyType.output) {
        outputDefinition ??= propertyDefinition;
        outputProperty ??= property;
        continue;
      }

      final bindingKey = propertyDefinition.key;
      final isTextureInput =
          propertyDefinition.socket &&
          propertyDefinition.propertyType == GraphPropertyType.input;
      final generatedTextureBindingKey =
          propertyDefinition.runtimeTextureBindingKey;
      if (isTextureInput || generatedTextureBindingKey != null) {
        final link = linkByInputPropertyId[property.id];
        if (link != null) {
          upstreamNodeIds.add(link.fromNodeId);
        }
        textureInputs.add(
          MaterialCompiledTextureInput(
            propertyId: property.id,
            propertyKey: property.definitionKey,
            bindingKey: generatedTextureBindingKey ?? bindingKey,
            valueType: propertyDefinition.valueType,
            fallbackValue: property.value.deepCopy(),
            sourceNodeId: link?.fromNodeId,
            sourcePropertyId: link?.fromPropertyId,
          ),
        );
        continue;
      }

      if (_isBaseOutputSizeProperty(propertyDefinition.key)) {
        continue;
      }

      parameterBindings.add(
        MaterialCompiledParameterBinding(
          propertyId: property.id,
          propertyKey: property.definitionKey,
          bindingKey: bindingKey,
          valueType: propertyDefinition.valueType,
          value: property.value.deepCopy(),
        ),
      );
    }

    final resolvedOutputDefinition =
        outputDefinition ??
        definition.properties.firstWhere((property) {
          return property.propertyType == GraphPropertyType.output;
        });
    final resolvedOutputProperty =
        outputProperty ??
        node.propertyByDefinitionKey(resolvedOutputDefinition.key)!;

    return MaterialCompiledNodePass(
      nodeId: node.id,
      nodeName: node.name,
      definitionId: definition.id,
      executionKind: definition.runtime.executionKind,
      shaderAssetId: definition.runtime.shaderAssetId,
      textureInputs: textureInputs,
      parameterBindings: parameterBindings,
      output: MaterialCompiledOutputBinding(
        propertyId: resolvedOutputProperty.id,
        propertyKey: resolvedOutputProperty.definitionKey,
        bindingKey: resolvedOutputDefinition.key,
        valueType: resolvedOutputDefinition.valueType,
        kind: MaterialPassOutputKind.preview,
      ),
      upstreamNodeIds: upstreamNodeIds.toList(growable: false),
      resolvedOutputSize: resolvedOutputSize,
    );
  }

  MaterialResolvedOutputSize _resolveGraphOutputSize(
    MaterialOutputSizeSettings graphOutputSizeSettings,
    MaterialOutputSizeValue sessionParentOutputSize,
  ) {
    return switch (graphOutputSizeSettings.mode) {
      MaterialOutputSizeMode.absolute => MaterialResolvedOutputSize.fromLog2(
        graphOutputSizeSettings.value.clampAbsolute(),
      ),
      MaterialOutputSizeMode.relativeToInput ||
      MaterialOutputSizeMode.relativeToParent =>
        MaterialResolvedOutputSize.fromLog2(
          sessionParentOutputSize.add(
            graphOutputSizeSettings.value.clampRelative(),
          ),
        ),
    };
  }

  MaterialResolvedOutputSize _resolveNodeOutputSize({
    required GraphNodeDocument node,
    required MaterialNodeDefinition definition,
    required Map<String, GraphLinkDocument> linkByInputPropertyId,
    required MaterialResolvedOutputSize graphOutputSize,
    required Map<String, MaterialResolvedOutputSize>
    resolvedOutputSizesByNodeId,
  }) {
    final outputSizeSettings = _nodeOutputSizeSettings(node);
    if (outputSizeSettings.mode == MaterialOutputSizeMode.absolute) {
      return MaterialResolvedOutputSize.fromLog2(
        outputSizeSettings.normalizeValue(outputSizeSettings.value),
      );
    }

    final inheritedSize = switch (outputSizeSettings.mode) {
      MaterialOutputSizeMode.absolute => graphOutputSize,
      MaterialOutputSizeMode.relativeToParent => graphOutputSize,
      MaterialOutputSizeMode.relativeToInput =>
        _resolvePrimaryInputSize(
              node: node,
              definition: definition,
              linkByInputPropertyId: linkByInputPropertyId,
              resolvedOutputSizesByNodeId: resolvedOutputSizesByNodeId,
            ) ??
            graphOutputSize,
    };
    return MaterialResolvedOutputSize.fromLog2(
      MaterialOutputSizeValue(
        widthLog2: inheritedSize.widthLog2,
        heightLog2: inheritedSize.heightLog2,
      ).add(outputSizeSettings.normalizeValue(outputSizeSettings.value)),
    );
  }

  MaterialResolvedOutputSize? _resolvePrimaryInputSize({
    required GraphNodeDocument node,
    required MaterialNodeDefinition definition,
    required Map<String, GraphLinkDocument> linkByInputPropertyId,
    required Map<String, MaterialResolvedOutputSize>
    resolvedOutputSizesByNodeId,
  }) {
    final primaryInputKey = definition.resolvedPrimaryInputPropertyKey;
    if (primaryInputKey == null) {
      return null;
    }
    final primaryInputProperty = node.propertyByDefinitionKey(primaryInputKey);
    if (primaryInputProperty == null) {
      return null;
    }
    final link = linkByInputPropertyId[primaryInputProperty.id];
    if (link == null) {
      return null;
    }
    return resolvedOutputSizesByNodeId[link.fromNodeId];
  }

  MaterialOutputSizeSettings _nodeOutputSizeSettings(GraphNodeDocument node) {
    return materialOutputSizeSettingsFromStorage(
      modeValue: node
          .propertyByDefinitionKey(materialNodeOutputSizeModeKey)
          ?.value
          .enumValue,
      value: node
          .propertyByDefinitionKey(materialNodeOutputSizeValueKey)
          ?.value
          .integerValues,
    );
  }

  bool _isBaseOutputSizeProperty(String key) {
    return key == materialNodeOutputSizeModeKey ||
        key == materialNodeOutputSizeValueKey;
  }
}
