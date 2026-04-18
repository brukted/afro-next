import '../../features/material_graph/material_node_definition.dart';

enum VulkanDescriptorBindingKind {
  uniformBuffer,
  sampler,
  sampledImage,
  storageImage,
}

enum VulkanImageTargetUsage {
  transientPass,
  preview,
  finalOutput,
}

class VulkanShaderAsset {
  const VulkanShaderAsset({
    required this.assetId,
    required this.stage,
    this.entryPoint = 'main',
  });

  final String assetId;
  final MaterialNodeExecutionKind stage;
  final String entryPoint;
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
    required this.shaderAssetId,
    required this.executionKind,
    required this.sampledInputCount,
  });

  final String shaderAssetId;
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
  });

  final String nodeId;
  final VulkanShaderAsset? shader;
  final List<VulkanDescriptorBindingSpec> descriptorBindings;
  final VulkanImageTargetPlan outputTarget;
  final VulkanMaterialPipelineCacheKey pipelineCacheKey;
  final bool isSupported;
}

class VulkanMaterialBackendPlan {
  const VulkanMaterialBackendPlan({
    required this.graphId,
    required this.passes,
    required this.previewTargetIdsByNodeId,
    required this.finalOutputTargetId,
  });

  final String graphId;
  final List<VulkanMaterialPassPlan> passes;
  final Map<String, String> previewTargetIdsByNodeId;
  final String? finalOutputTargetId;

  VulkanMaterialPassPlan? passForNode(String nodeId) {
    for (final pass in passes) {
      if (pass.nodeId == nodeId) {
        return pass;
      }
    }
    return null;
  }
}
