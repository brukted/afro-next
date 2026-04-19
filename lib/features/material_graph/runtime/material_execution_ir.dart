import '../../graph/models/graph_models.dart';
import '../../graph/models/graph_schema.dart';
import '../material_node_definition.dart';
import '../material_output_size.dart';

enum MaterialPassOutputKind { preview, finalOutput }

class MaterialResolvedOutputSize {
  const MaterialResolvedOutputSize({
    required this.width,
    required this.height,
    required this.widthLog2,
    required this.heightLog2,
  });

  final int width;
  final int height;
  final int widthLog2;
  final int heightLog2;

  String get extentLabel => '${width}x$height';

  String get extentDiagnostic => 'Extent: $extentLabel';

  factory MaterialResolvedOutputSize.fromLog2(MaterialOutputSizeValue value) {
    final clamped = value.clampAbsolute();
    return MaterialResolvedOutputSize(
      width: clamped.width,
      height: clamped.height,
      widthLog2: clamped.widthLog2,
      heightLog2: clamped.heightLog2,
    );
  }
}

class MaterialCompiledTextureInput {
  const MaterialCompiledTextureInput({
    required this.propertyId,
    required this.propertyKey,
    required this.bindingKey,
    required this.valueType,
    required this.fallbackValue,
    this.sourceNodeId,
    this.sourcePropertyId,
  });

  final String propertyId;
  final String propertyKey;
  final String bindingKey;
  final GraphValueType valueType;
  final GraphValueData fallbackValue;
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
    required this.resolvedOutputSize,
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
  final MaterialResolvedOutputSize resolvedOutputSize;
}

class MaterialCompiledGraph {
  const MaterialCompiledGraph({
    required this.graphId,
    required this.nodePasses,
    required this.nodePassesByNodeId,
    required this.topologicalNodeIds,
    required this.downstreamNodeIdsByNodeId,
    required this.defaultOutputNodeId,
    required this.resolvedGraphOutputSize,
  });

  final String graphId;
  final List<MaterialCompiledNodePass> nodePasses;
  final Map<String, MaterialCompiledNodePass> nodePassesByNodeId;
  final List<String> topologicalNodeIds;
  final Map<String, List<String>> downstreamNodeIdsByNodeId;
  final String? defaultOutputNodeId;
  final MaterialResolvedOutputSize resolvedGraphOutputSize;

  MaterialCompiledNodePass? passForNode(String nodeId) =>
      nodePassesByNodeId[nodeId];

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
