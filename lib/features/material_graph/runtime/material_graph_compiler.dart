import 'package:collection/collection.dart';

import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../../math_graph/runtime/math_graph_compiler.dart';
import '../../workspace/workspace_controller.dart';
import '../material_graph_catalog.dart';
import '../material_node_definition.dart';
import '../material_output_size.dart';
import '../material_socket_compatibility.dart';
import 'material_graph_backed_resolver.dart';
import 'material_execution_ir.dart';

class MaterialGraphCompiler {
  MaterialGraphCompiler({
    required MaterialGraphCatalog catalog,
    WorkspaceController? workspaceController,
    MathGraphCompiler? mathGraphCompiler,
  }) : _catalog = catalog,
       _resolver = MaterialGraphBackedNodeResolver(
         catalog: catalog,
         workspaceController: workspaceController,
         mathGraphCompiler: mathGraphCompiler,
       );

  final MaterialGraphCatalog _catalog;
  final MaterialGraphBackedNodeResolver _resolver;

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
            nodesById: nodesById,
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
    required Map<String, GraphNodeDocument> nodesById,
    required Map<String, GraphLinkDocument> linkByInputPropertyId,
    required MaterialResolvedOutputSize graphOutputSize,
    required Map<String, MaterialResolvedOutputSize>
    resolvedOutputSizesByNodeId,
  }) {
    final resolution = _resolver.resolveNode(node);
    final definition = resolution.definition;
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

    if (definition.isGraphInput) {
      final outputDefinition = definition.properties.firstWhere(
        (property) => property.propertyType == GraphPropertyType.output,
      );
      final outputProperty = _propertyForDefinition(node, outputDefinition);
      final graphInputTexture = _compileGraphInputTextureInput(
        node: node,
        definition: definition,
      );
      if (graphInputTexture != null) {
        textureInputs.add(graphInputTexture);
      }
      return MaterialCompiledNodePass(
        nodeId: node.id,
        nodeName: node.name,
        definitionId: definition.id,
        executionKind: definition.runtime.executionKind,
        program: _programForDefinition(
          definition,
          generatedProgram: resolution.program,
        ),
        textureInputs: textureInputs,
        parameterBindings: parameterBindings,
        output: MaterialCompiledOutputBinding(
          propertyId: outputProperty.id,
          propertyKey: outputProperty.definitionKey,
          bindingKey: outputDefinition.key,
          valueType: outputDefinition.valueType,
          kind: MaterialPassOutputKind.preview,
        ),
        upstreamNodeIds: const <String>[],
        resolvedOutputSize: resolvedOutputSize,
        diagnostics: resolution.diagnostics,
      );
    }

    for (final propertyDefinition in definition.properties) {
      final property = _propertyForDefinition(node, propertyDefinition);

      if (propertyDefinition.propertyType == GraphPropertyType.output) {
        outputDefinition ??= propertyDefinition;
        outputProperty ??= property;
        continue;
      }

      final bindingKey = propertyDefinition.key;
      final isTextureInput =
          propertyDefinition.socket &&
          propertyDefinition.propertyType == GraphPropertyType.input &&
          propertyDefinition.socketTransport == GraphSocketTransport.texture;
      final isValueInput =
          propertyDefinition.socket &&
          propertyDefinition.propertyType == GraphPropertyType.input &&
          propertyDefinition.socketTransport == GraphSocketTransport.value;
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

      if (isValueInput) {
        final link = linkByInputPropertyId[property.id];
        if (link != null) {
          upstreamNodeIds.add(link.fromNodeId);
        }
        parameterBindings.add(
          MaterialCompiledParameterBinding(
            propertyId: property.id,
            propertyKey: property.definitionKey,
            bindingKey: bindingKey,
            valueType: propertyDefinition.valueType,
            value: _resolveValueInputBinding(
              property: property,
              propertyDefinition: propertyDefinition,
              link: link,
              nodesById: nodesById,
            ),
          ),
        );
        continue;
      }

      if (_isBaseOutputSizeProperty(propertyDefinition.key)) {
        continue;
      }
      if (definition.id == materialTexelGraphNodeDefinitionId &&
          propertyDefinition.key == materialTexelGraphResourcePropertyKey) {
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
        _propertyForDefinition(node, resolvedOutputDefinition);

    return MaterialCompiledNodePass(
      nodeId: node.id,
      nodeName: node.name,
      definitionId: definition.id,
      executionKind: definition.runtime.executionKind,
      program: _programForDefinition(
        definition,
        generatedProgram: resolution.program,
      ),
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
      diagnostics: resolution.diagnostics,
    );
  }

  MaterialCompiledProgram? _programForDefinition(
    MaterialNodeDefinition definition, {
    MaterialCompiledProgram? generatedProgram,
  }) {
    if (generatedProgram != null) {
      return generatedProgram;
    }
    final shaderAssetId = definition.runtime.shaderAssetId;
    if (shaderAssetId == null || shaderAssetId.isEmpty) {
      return null;
    }
    return MaterialCompiledProgram.asset(assetId: shaderAssetId);
  }

  GraphNodePropertyData _propertyForDefinition(
    GraphNodeDocument node,
    GraphPropertyDefinition definition,
  ) {
    return node.propertyByDefinitionKey(definition.key) ??
        GraphNodePropertyData(
          id: '${node.id}:${definition.key}',
          definitionKey: definition.key,
          value: _catalog.defaultValueForProperty(definition),
        );
  }

  MaterialCompiledTextureInput? _compileGraphInputTextureInput({
    required GraphNodeDocument node,
    required MaterialNodeDefinition definition,
  }) {
    final valuePropertyKey = definition.inputValuePropertyKey;
    if (valuePropertyKey == null) {
      return null;
    }
    final valueProperty = node.propertyByDefinitionKey(valuePropertyKey);
    if (valueProperty == null) {
      return null;
    }
    final resourcePropertyKey = definition.inputResourcePropertyKey;
    final resourceProperty = resourcePropertyKey == null
        ? null
        : node.propertyByDefinitionKey(resourcePropertyKey);
    final fallbackValue =
        resourceProperty != null &&
            (resourceProperty.value.resourceIdValue?.isNotEmpty ?? false)
        ? resourceProperty.value.deepCopy()
        : valueProperty.value.deepCopy();
    return MaterialCompiledTextureInput(
      propertyId: valueProperty.id,
      propertyKey: valueProperty.definitionKey,
      bindingKey: 'MainTex',
      valueType: fallbackValue.valueType,
      fallbackValue: fallbackValue,
    );
  }

  GraphValueData _resolveValueInputBinding({
    required GraphNodePropertyData property,
    required GraphPropertyDefinition propertyDefinition,
    required GraphLinkDocument? link,
    required Map<String, GraphNodeDocument> nodesById,
  }) {
    if (link == null) {
      return property.value.deepCopy();
    }
    final sourceNode = nodesById[link.fromNodeId];
    if (sourceNode == null) {
      return property.value.deepCopy();
    }
    final sourceDefinition = _catalog.definitionById(sourceNode.definitionId);
    final sourceOutputProperty = sourceNode.propertyById(link.fromPropertyId);
    if (sourceOutputProperty == null) {
      return property.value.deepCopy();
    }
    final sourceOutputDefinition = sourceDefinition.propertyDefinition(
      sourceOutputProperty.definitionKey,
    );
    if (!materialSocketDefinitionsCompatible(
      fromDefinition: sourceOutputDefinition,
      toDefinition: propertyDefinition,
    )) {
      return property.value.deepCopy();
    }
    final sourceValuePropertyKey = sourceDefinition.inputValuePropertyKey;
    if (!sourceDefinition.isGraphInput || sourceValuePropertyKey == null) {
      return property.value.deepCopy();
    }
    final sourceValue = sourceNode.propertyByDefinitionKey(
      sourceValuePropertyKey,
    );
    if (sourceValue == null ||
        sourceValue.value.valueType != propertyDefinition.valueType) {
      return property.value.deepCopy();
    }
    return sourceValue.value.deepCopy();
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
