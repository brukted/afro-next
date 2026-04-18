import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../material_node_definition.dart';

enum MaterialPassOutputKind {
  preview,
  finalOutput,
}

class MaterialCompiledTextureInput {
  const MaterialCompiledTextureInput({
    required this.propertyId,
    required this.propertyKey,
    required this.bindingKey,
    required this.valueType,
    this.sourceNodeId,
    this.sourcePropertyId,
  });

  final String propertyId;
  final String propertyKey;
  final String bindingKey;
  final GraphValueType valueType;
  final String? sourceNodeId;
  final String? sourcePropertyId;

  bool get isConnected => sourceNodeId != null && sourcePropertyId != null;
}

class MaterialCompiledParameterBinding {
  const MaterialCompiledParameterBinding({
    required this.propertyId,
    required this.propertyKey,
    required this.bindingKey,
    required this.valueType,
    required this.value,
  });

  final String propertyId;
  final String propertyKey;
  final String bindingKey;
  final GraphValueType valueType;
  final GraphValueData value;
}

class MaterialCompiledOutputBinding {
  const MaterialCompiledOutputBinding({
    required this.propertyId,
    required this.propertyKey,
    required this.bindingKey,
    required this.valueType,
    required this.kind,
  });

  final String propertyId;
  final String propertyKey;
  final String bindingKey;
  final GraphValueType valueType;
  final MaterialPassOutputKind kind;
}

class MaterialCompiledNodePass {
  const MaterialCompiledNodePass({
    required this.nodeId,
    required this.nodeName,
    required this.definitionId,
    required this.executionKind,
    required this.shaderAssetId,
    required this.textureInputs,
    required this.parameterBindings,
    required this.output,
    required this.upstreamNodeIds,
  });

  final String nodeId;
  final String nodeName;
  final String definitionId;
  final MaterialNodeExecutionKind executionKind;
  final String? shaderAssetId;
  final List<MaterialCompiledTextureInput> textureInputs;
  final List<MaterialCompiledParameterBinding> parameterBindings;
  final MaterialCompiledOutputBinding output;
  final List<String> upstreamNodeIds;
}

class MaterialCompiledGraph {
  const MaterialCompiledGraph({
    required this.graphId,
    required this.nodePasses,
    required this.topologicalNodeIds,
    required this.downstreamNodeIdsByNodeId,
    required this.defaultOutputNodeId,
  });

  final String graphId;
  final List<MaterialCompiledNodePass> nodePasses;
  final List<String> topologicalNodeIds;
  final Map<String, List<String>> downstreamNodeIdsByNodeId;
  final String? defaultOutputNodeId;

  MaterialCompiledNodePass? passForNode(String nodeId) {
    for (final pass in nodePasses) {
      if (pass.nodeId == nodeId) {
        return pass;
      }
    }
    return null;
  }

  Set<String> expandDirtyNodes(Iterable<String> dirtyRoots) {
    final expanded = <String>{};
    final pending = <String>[];

    for (final root in dirtyRoots) {
      if (expanded.add(root)) {
        pending.add(root);
      }
    }

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final children = downstreamNodeIdsByNodeId[current];
      if (children == null) {
        continue;
      }

      for (final child in children) {
        if (expanded.add(child)) {
          pending.add(child);
        }
      }
    }

    return expanded;
  }
}
