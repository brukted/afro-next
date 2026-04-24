import '../../features/material_graph/material_node_definition.dart';
import '../../features/material_graph/runtime/material_execution_ir.dart';

enum VulkanDescriptorBindingKind {
  uniformBuffer,
  sampler,
  sampledImage,
  storageImage,
}

enum VulkanImageTargetUsage { transientPass, preview, finalOutput }

enum VulkanShaderKind { asset, generated }

class VulkanShaderAsset {
  const VulkanShaderAsset.asset({
    required String assetId,
    required this.stage,
    this.entryPoint = 'main',
  }) : kind = VulkanShaderKind.asset,
       assetId = assetId,
       source = null,
       cacheKey = assetId;

  const VulkanShaderAsset.generated({
    required String source,
    required String cacheKey,
    required this.stage,
    this.entryPoint = 'main',
  }) : kind = VulkanShaderKind.generated,
       assetId = null,
       source = source,
       cacheKey = cacheKey;

  final VulkanShaderKind kind;
  final String? assetId;
  final String? source;
  final String cacheKey;
  final MaterialNodeExecutionKind stage;
  final String entryPoint;

  String get displayLabel => assetId ?? 'generated:$cacheKey';
}

class VulkanDescriptorBindingSpec {
  const VulkanDescriptorBindingSpec({
    required this.set,
    required this.binding,
    required this.name,
    required this.kind,
  });

  final int set;
  final int binding;
  final String name;
  final VulkanDescriptorBindingKind kind;
}

class VulkanMaterialPipelineCacheKey {
  const VulkanMaterialPipelineCacheKey({
    required this.shaderKey,
    required this.executionKind,
    required this.sampledInputCount,
  });

  final String shaderKey;
  final MaterialNodeExecutionKind executionKind;
  final int sampledInputCount;
}

class VulkanImageTargetPlan {
  const VulkanImageTargetPlan({
    required this.id,
    required this.nodeId,
    required this.usage,
  });

  final String id;
  final String nodeId;
  final VulkanImageTargetUsage usage;
}

class VulkanMaterialPassPlan {
  const VulkanMaterialPassPlan({
    required this.nodeId,
    required this.shader,
    required this.descriptorBindings,
    required this.outputTarget,
    required this.pipelineCacheKey,
    required this.isSupported,
    required this.resolvedOutputSize,
  });

  final String nodeId;
  final VulkanShaderAsset? shader;
  final List<VulkanDescriptorBindingSpec> descriptorBindings;
  final VulkanImageTargetPlan outputTarget;
  final VulkanMaterialPipelineCacheKey pipelineCacheKey;
  final bool isSupported;
  final MaterialResolvedOutputSize resolvedOutputSize;
}

class VulkanMaterialBackendPlan {
  const VulkanMaterialBackendPlan({
    required this.graphId,
    required this.passes,
    required this.passesByNodeId,
    required this.previewTargetIdsByNodeId,
    required this.finalOutputTargetId,
  });

  final String graphId;
  final List<VulkanMaterialPassPlan> passes;
  final Map<String, VulkanMaterialPassPlan> passesByNodeId;
  final Map<String, String> previewTargetIdsByNodeId;
  final String? finalOutputTargetId;

  VulkanMaterialPassPlan? passForNode(String nodeId) => passesByNodeId[nodeId];
}
