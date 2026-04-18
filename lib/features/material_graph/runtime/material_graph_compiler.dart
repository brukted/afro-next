import 'package:collection/collection.dart';

import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../material_graph_catalog.dart';
import 'material_execution_ir.dart';

class MaterialGraphCompiler {
  const MaterialGraphCompiler({required MaterialGraphCatalog catalog})
    : _catalog = catalog;

  final MaterialGraphCatalog _catalog;

  MaterialCompiledGraph compile(GraphDocument graph) {
    final nodesById = {for (final node in graph.nodes) node.id: node};
    final incomingCounts = <String, int>{
      for (final node in graph.nodes) node.id: 0,
    };
    final outgoingNodeIds = <String, List<String>>{
      for (final node in graph.nodes) node.id: <String>[],
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

    final nodePasses = orderedNodeIds
        .map(
          (nodeId) => _compileNodePass(graph: graph, node: nodesById[nodeId]!),
        )
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
    );
  }

  MaterialCompiledNodePass _compileNodePass({
    required GraphDocument graph,
    required GraphNodeDocument node,
  }) {
    final definition = _catalog.definitionById(node.definitionId);
    final linkByInputPropertyId = {
      for (final link in graph.links) link.toPropertyId: link,
    };
    final textureInputs = <MaterialCompiledTextureInput>[];
    final parameterBindings = <MaterialCompiledParameterBinding>[];
    GraphPropertyDefinition? outputDefinition;
    GraphNodePropertyData? outputProperty;
    final upstreamNodeIds = <String>{};

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
      if (isTextureInput) {
        final link = linkByInputPropertyId[property.id];
        if (link != null) {
          upstreamNodeIds.add(link.fromNodeId);
        }
        textureInputs.add(
          MaterialCompiledTextureInput(
            propertyId: property.id,
            propertyKey: property.definitionKey,
            bindingKey: bindingKey,
            valueType: propertyDefinition.valueType,
            fallbackValue: property.value.deepCopy(),
            sourceNodeId: link?.fromNodeId,
            sourcePropertyId: link?.fromPropertyId,
          ),
        );
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
    );
  }
}
